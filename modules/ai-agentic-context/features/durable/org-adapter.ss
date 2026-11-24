;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Context `+durable` Org Adapter (Layer 2 Thin Declarative Schema Codec):
;;; Bidirectional Org-Elements / Org-Edit <-> Pure Durable Work Engine Codec.
;;;
;;; Engineering Boundary:
;;; - Layer 0 (`gerbil-parser/graph-support/edit`): UTF-8 SpanEdit algebra.
;;; - Layer 1 (`orgize/org-elements` + `orgize/org-edit`): typed parsing,
;;;   property:* queries, canonical Org formatting, and verified span edits.
;;; - Layer 2 (this file): pure schema projection + declarative `(org-edit ...)`
;;;   plans over Pure `modules/durable/work.ss` (ZERO string/drawer surgery,
;;;   owned by `ai-agentic-context/features/durable`, ZERO Org under `durable`).

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/type Type. define-type)
        (only-in :std/list/list filter filter-map)
        (only-in :std/string/misc string-trim string-split)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph/todo-profile
                 org-source-slice
                 org-graph-headlines
                 org-headline-level
                 org-headline-property
                 org-headline-has-tag?
                 org-headline-todo-state
                 org-headline-checklist-stats
                 org-graph-checklist-stats
                 +org-edit-default-todo-keywords+
                 +org-edit-default-done-keywords+
                 make-org-section-spec
                 org-edit set-todo add-tag remove-tag
                 set-planning remove-planning
                 upsert-properties upsert-section append-section
                 org-apply-edit org-apply-edits)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 funflow-dag-node)
        "../../../durable/work.ss")

(export org->work-snapshot
        org->claim-table
        org-work-funflow-dag
        org-work-orchestration-plan
        org-work-reanchor-mainline
        org-work-archive-transition
        org-work-commit-archive!
        org-work-reopen!
        org-work-recover
        org-shared-context-perceive-claims
        org-shared-context-assert-write-owner
        org-shared-context-claim!
        org-shared-context-extend!
        org-shared-context-handover!
        ContextDurableOrgExports)

;;; ---------------------------------------------------------------------------
;;; Minimal Value Decoders (Domain Schema Only — Zero Org Syntax Parsing)
;;; ---------------------------------------------------------------------------

(def (parse-org-workflow source-text)
  (org-source-element-graph/todo-profile source-text
                                         +org-edit-default-todo-keywords+
                                         +org-edit-default-done-keywords+))

(def (split-ws-ids text)
  (if (and (string? text) (> (string-length (string-trim text)) 0))
    (filter (lambda (tok) (> (string-length tok) 0))
            (map string-trim (string-split (string-trim text) #\space)))
    '()))

(def (parse-uint-or s default)
  (let ((n (and (string? s) (string->number (string-trim s)))))
    (if (and (exact-integer? n) (>= n 0)) n default)))

(def (status-symbol->org-todo status)
  (case status
    ((done) "DONE")
    ((in-progress) "IN_PROGRESS")
    ((blocked) "BLOCKED")
    ((review) "REVIEW")
    ((cancelled) "CANCELLED")
    ((failed) "FAILED")
    (else "TODO")))

;;; ---------------------------------------------------------------------------
;;; Org -> Pure Durable ClaimTable & WorkSnapshot Decoders
;;; ---------------------------------------------------------------------------

(def (org->claim-table org-source-text)
  (if (equal? (string-trim org-source-text) "")
    '()
    (let* ((graph (parse-org-workflow org-source-text))
           (ctx (make-org-element-query-context graph)))
      (filter-map
       (lambda (h)
         (let ((hid (org-headline-property ctx h "ID"))
               (owner (org-headline-property ctx h "OWNER_ACTOR"))
               (cstate (org-headline-property ctx h "CLAIM_STATE"))
               (epoch (parse-uint-or (org-headline-property ctx h "CLAIM_LEASE_EPOCH") 0))
               (hb (parse-uint-or (org-headline-property ctx h "CLAIM_HEARTBEAT_AT") 0))
               (ttl (parse-uint-or (org-headline-property ctx h "CLAIM_TTL_SEC") 120))
               (wt (or (org-headline-property ctx h "CLAIM_WORKTREE") "main"))
               (extends-id (org-headline-property ctx h "EXTENDS_ID")))
           (and hid
                (or owner cstate extends-id)
                (make-checked-work-claim
                 hid owner (or cstate "unclaimed") epoch hb ttl wt extends-id
                 (cons (.ref h 'start) (.ref h 'end))))))
       (org-graph-headlines graph)))))

(def (org->work-snapshot task org-source-text rule-overrides: (rule-overrides #f))
  (let* ((graph (parse-org-workflow org-source-text))
         (ctx (make-org-element-query-context graph))
         (bytes (string->utf8 org-source-text))
         (headlines (org-graph-headlines graph))
         (source-cut (opt-ref task 'source-cut "cut-0"))
         (rules (work-effective-rules task rule-overrides))
         (policy-digest (canonical-sha256
                         (list (.ref rules 'require-sod-reviewer)
                               (.ref rules 'focused-tab-archive)
                               (.ref rules 'default-focus-depth))))
         (root-h (and (pair? headlines) (car headlines)))
         (sub-hs (if (and (pair? headlines) (pair? (cdr headlines))) (cdr headlines) headlines))
         (dag-nodes
          (map
           (lambda (h)
             (let*-values
                 (((prop-id) (or (org-headline-property ctx h "ID")
                                 (org-headline-property ctx h "CUSTOM_ID")
                                 (string-append "h-" (number->string (.ref h 'start)))))
                  ((deps) (split-ws-ids (org-headline-property ctx h "DEPENDS_ON")))
                  ((fin-for) (org-headline-property ctx h "FINALIZER_FOR"))
                  ((tier-str) (org-headline-property ctx h "MODEL_TIER"))
                  ((tier) (if tier-str (string->symbol (string-downcase tier-str)) 'builder))
                  ((h-start) (.ref h 'start))
                  ((h-end) (.ref h 'end))
                  ((h-text) (org-source-slice bytes h-start h-end))
                  ((st) (org-headline-todo-state ctx h))
                  ((_d _t chk-ok?) (org-headline-checklist-stats ctx graph h)))
               (funflow-dag-node
                prop-id
                needs: deps
                after-start: fin-for
                source-cut: source-cut
                input-digest: (canonical-sha256 h-text)
                contract-digest: (canonical-sha256 (list prop-id deps fin-for))
                policy-digest: policy-digest
                status: st
                checklists-done?: chk-ok?
                span: (cons h-start h-end)
                scope: (.o bind-these: #f
                           task-id: (opt-ref task 'task-id "task")
                           worktree: (opt-ref task 'worktree "main")
                           source-cut: source-cut
                           actor: (org-headline-property ctx h "AGENT_ID")
                           reviewer-id: (org-headline-property ctx h "REVIEWER_AGENT_ID")
                           restriction-envelope: (opt-ref task 'restriction-envelope #f)
                           trust-tier: (opt-ref task 'trust-tier 'verified))
                model-tier: tier)))
           sub-hs))
         (mainline-done 0) (mainline-total 0)
         (open-blockers '()) (open-sq '()) (comp-detours '()) (unsat-inv '())
         (max-depth 0) (return-anchor #f))
    (for-each
     (lambda (h)
       (let* ((hid (or (org-headline-property ctx h "ID") ""))
              (role (or (org-headline-property ctx h "ROLE") "mainline"))
              (dkind (or (org-headline-property ctx h "DETOUR_KIND") "side-quest"))
              (anchor (org-headline-property ctx h "RETURN_ANCHOR"))
              (depth (parse-uint-or (org-headline-property ctx h "DETOUR_DEPTH")
                                    (if (equal? role "detour") 1 0)))
              (inv (org-headline-property ctx h "INVARIANT"))
              (st (org-headline-todo-state ctx h))
              (done? (or (eq? st 'done) (eq? st 'cancelled))))
         (when (> depth max-depth) (set! max-depth depth))
         (when (and inv (not done?))
           (set! unsat-inv (cons (if (> (string-length hid) 0) hid inv) unsat-inv)))
         (cond
          ((equal? role "detour")
           (when (and anchor (not return-anchor)) (set! return-anchor anchor))
           (cond
            (done? (set! comp-detours (cons hid comp-detours)))
            ((equal? dkind "blocker") (set! open-blockers (cons hid open-blockers)))
            (else (set! open-sq (cons hid open-sq)))))
          ((> (org-headline-level ctx h) 1)
           (set! mainline-total (+ mainline-total 1))
           (when done? (set! mainline-done (+ mainline-done 1)))))))
     headlines)
    (let-values (((chk-done chk-total _all?) (org-graph-checklist-stats ctx graph)))
      (make-checked-work-snapshot
       task-id: (opt-ref task 'task-id "task")
       root-id: (if root-h
                  (or (org-headline-property ctx root-h "ID")
                      (opt-ref task 'scope-root-id (opt-ref task 'task-id "task-root")))
                  (opt-ref task 'scope-root-id (opt-ref task 'task-id "task-root")))
       root-title: (if root-h
                     (or (org-element-property ctx root-h "title") (opt-ref task 'task-id "Task"))
                     (opt-ref task 'task-id "Task"))
       root-status: (if root-h (org-headline-todo-state ctx root-h) 'todo)
       root-archived?: (and root-h (org-headline-has-tag? ctx root-h "ARCHIVE"))
       checklist-done: chk-done
       checklist-total: chk-total
       dag-nodes: dag-nodes
       mainline-done: mainline-done
       mainline-total: mainline-total
       open-blocker-detours: (reverse open-blockers)
       open-side-quests: (reverse open-sq)
       completed-detours: (reverse comp-detours)
       unsatisfied-invariants: (reverse unsat-inv)
       max-detour-depth-observed: max-depth
       return-anchor-id: return-anchor
       claims: (org->claim-table org-source-text)
       rule-overrides: rule-overrides))))

;;; ---------------------------------------------------------------------------
;;; Declarative Org Index Entry Spec Builder (Consumed by `orgize/org-edit`)
;;; ---------------------------------------------------------------------------

(def (make-index-section-spec task-id root-id title worktree task-path
                              status done-count total-count archived? timestamp)
  (make-org-section-spec
   1 title
   todo: (status-symbol->org-todo status)
   cookie: (and (> total-count 0)
                (string-append "[" (number->string done-count) "/"
                               (number->string total-count) "]"))
   tags: (if archived? '("ARCHIVE") '())
   planning: (if archived? (list (cons "CLOSED" timestamp)) '())
   properties: (list (cons "ID" root-id)
                     (cons "TASK_ID" task-id)
                     (cons "WORKTREE" worktree)
                     (cons "TASK_FILE" task-path))
   body: (string-append "[[file:" task-path "][" title "]]")))

(def (upsert-index-org index-text task-id root-id title worktree task-path
                       status done-count total-count archived? timestamp)
  (org-apply-edit
   index-text
   (upsert-section
    (lambda (ctx h)
      (or (equal? (org-headline-property ctx h "TASK_ID") task-id)
          (equal? (org-headline-property ctx h "ID") root-id)))
    (make-index-section-spec task-id root-id title worktree task-path
                             status done-count total-count archived? timestamp)
    "#+TITLE: Task Index\n\n")))

;;; ---------------------------------------------------------------------------
;;; Org-Backed Durable Operations (Pure `work.ss` + Verified `orgize/org-edit`)
;;; ---------------------------------------------------------------------------

(def (org-work-funflow-dag task org-source-text rule-overrides: (rule-overrides #f))
  (work-funflow-dag task (org->work-snapshot task org-source-text rule-overrides: rule-overrides)))

(def (org-work-orchestration-plan task org-source-text journal-state rule-overrides: (rule-overrides #f))
  (work-orchestration-plan task
                           (org->work-snapshot task org-source-text rule-overrides: rule-overrides)
                           journal-state))

(def (org-work-reanchor-mainline task org-source-text
                                 mainline-core: (mainline-core '())
                                 max-detour-depth: (max-detour-depth 2))
  (work-reanchor-mainline task
                          (org->work-snapshot task org-source-text)
                          mainline-core: mainline-core
                          max-detour-depth: max-detour-depth))

(def (org-work-archive-transition task org-source-text index-source-text timestamp)
  (let* ((paths (work-artifact-path task))
         (snap (org->work-snapshot task org-source-text))
         (task-id (.ref paths 'task-id))
         (ts (if (and (string? timestamp) (> (string-length timestamp) 0))
               timestamp "2026-11-24 Tue 00:00"))
         (next-task-org
          (org-apply-edits
           org-source-text
           (org-edit (add-tag 'first "ARCHIVE")
                     (set-planning 'first "CLOSED" ts))))
         (next-index-org
          (upsert-index-org index-source-text task-id
                            (.ref snap 'root-id) (.ref snap 'root-title)
                            (.ref paths 'worktree) (.ref paths 'task-org-path)
                            'done (.ref snap 'checklist-done) (.ref snap 'checklist-total)
                            #t ts))
         (receipt-digest (canonical-sha256
                          (list 'agentic-ai-lab.durable.archive-receipt.v1
                                task-id ts next-task-org next-index-org))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.archive-transition.v1
        task-id: task-id
        timestamp: ts
        next-task-org: next-task-org
        next-index-org: next-index-org
        receipt: (.o bind-these: #f
                     kind: 'agentic-ai-lab.durable.archive-receipt.v1
                     task-id: task-id timestamp: ts digest: receipt-digest))))

(def (org-work-commit-archive! journal task org-source-text index-source-text journal-state timestamp)
  (let* ((snap (org->work-snapshot task org-source-text))
         (res (durable-work-commit-archive! journal task snap journal-state timestamp)))
    (if (not (.ref res 'committed?))
      res
      (let ((trans (org-work-archive-transition task org-source-text index-source-text timestamp)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.archive-commit-result.v1
            committed?: #t
            task-id: (.ref res 'task-id)
            next-task-org: (.ref trans 'next-task-org)
            next-index-org: (.ref trans 'next-index-org)
            receipt: (.ref res 'receipt)
            plan: (.ref res 'plan))))))

(def (org-work-reopen! journal task org-source-text index-source-text timestamp)
  (let* ((paths (work-artifact-path task))
         (next-task-org
          (org-apply-edits
           org-source-text
           (org-edit (remove-tag 'first "ARCHIVE")
                     (remove-planning 'first "CLOSED")
                     (set-todo 'first "TODO"))))
         (snap (org->work-snapshot task next-task-org))
         (res (durable-work-reopen! journal task snap timestamp))
         (next-index-org
          (upsert-index-org index-source-text (.ref paths 'task-id)
                            (.ref snap 'root-id) (.ref snap 'root-title)
                            (.ref paths 'worktree) (.ref paths 'task-org-path)
                            'todo (.ref snap 'checklist-done) (.ref snap 'checklist-total)
                            #f (.ref res 'timestamp))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.reopen-result.v1
        reopened?: #t
        task-id: (.ref res 'task-id)
        next-task-org: next-task-org
        next-index-org: next-index-org
        receipt: (.ref res 'receipt))))

(def (org-work-recover journal task org-source-text
                       in-flight-ids: (in-flight-ids '())
                       unclosed-attempts: (unclosed-attempts '())
                       governance-context: (governance-context (.o)))
  (durable-work-recover journal task (org->work-snapshot task org-source-text)
                        in-flight-ids: in-flight-ids
                        unclosed-attempts: unclosed-attempts
                        governance-context: governance-context))

(def (org-shared-context-perceive-claims org-source-text)
  (org->claim-table org-source-text))

(def (org-shared-context-assert-write-owner org-source-text node-id actor)
  (work-assert-write-owner (org->claim-table org-source-text) node-id actor))

(def (org-shared-context-claim! journal task-id node-id actor
                                worktree: (worktree "main")
                                scope-digest: (scope-digest "")
                                now: (now 0)
                                ttl: (ttl 120)
                                org-source: (org-source ""))
  (let* ((claims (org->claim-table org-source))
         (res (work-claim! journal task-id claims node-id actor
                           worktree: worktree now: now ttl: ttl)))
    (if (not (.ref res 'claimed?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.claim-result.v1
          claimed?: #f reason: (.ref res 'reason)
          node-id: node-id actor: actor
          current-owner: (.ref res 'current-owner)
          next-org-source: org-source)
      (let ((next-org
             (if (equal? (string-trim org-source) "")
               org-source
               (org-apply-edit
                org-source
                (upsert-properties
                 node-id
                 (list (cons "OWNER_ACTOR" actor)
                       (cons "CLAIM_STATE" "claimed-active")
                       (cons "CLAIM_LEASE_EPOCH" (number->string (.ref res 'claim-lease-epoch)))
                       (cons "CLAIM_HEARTBEAT_AT" (number->string now))
                       (cons "CLAIM_TTL_SEC" (number->string ttl))
                       (cons "CLAIM_SCOPE_DIGEST" scope-digest)
                       (cons "CLAIM_WORKTREE" worktree)))))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.claim-result.v1
            claimed?: #t reason: 'claimed-active
            node-id: node-id actor: actor
            claim-lease-epoch: (.ref res 'claim-lease-epoch)
            next-org-source: next-org
            receipt: (.ref res 'receipt))))))

(def (org-shared-context-extend! journal task-id parent-node-id new-node-id actor title
                                 body: (body "")
                                 role: (role "extension")
                                 now: (now 0)
                                 org-source: (org-source ""))
  (let* ((claims (org->claim-table org-source))
         (res (work-extend! journal task-id claims parent-node-id new-node-id actor
                            role: role now: now)))
    (if (not (.ref res 'extended?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.extend-result.v1
          extended?: #f reason: (.ref res 'reason)
          parent-node-id: parent-node-id new-node-id: new-node-id
          next-org-source: org-source)
      (let ((next-org
             (org-apply-edit
              org-source
              (append-section
               (make-org-section-spec
                3 title
                todo: "TODO"
                properties: (list (cons "ID" new-node-id)
                                  (cons "ROLE" role)
                                  (cons "EXTENDS_ID" parent-node-id)
                                  (cons "OWNER_ACTOR" actor)
                                  (cons "CLAIM_STATE" "claimed-active")
                                  (cons "CLAIM_LEASE_EPOCH" "1")
                                  (cons "CLAIM_HEARTBEAT_AT" (number->string now)))
                body: (and (> (string-length body) 0) body))))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.extend-result.v1
            extended?: #t reason: 'disjoint-peer-extension-appended
            parent-node-id: parent-node-id new-node-id: new-node-id actor: actor
            next-org-source: next-org
            receipt: (.ref res 'receipt))))))

(def (org-shared-context-handover! journal task-id node-id next-actor
                                   now: (now 0)
                                   force-explicit?: (force-explicit? #f)
                                   custody-oid: (custody-oid #f)
                                   org-source: (org-source ""))
  (let* ((claims (org->claim-table org-source))
         (res (work-handover! journal task-id claims node-id next-actor
                              now: now force-explicit?: force-explicit? custody-oid: custody-oid)))
    (if (not (.ref res 'handed-over?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.handover-result.v1
          handed-over?: #f reason: (.ref res 'reason)
          node-id: node-id next-org-source: org-source)
      (let ((next-org
             (if (equal? (string-trim org-source) "")
               org-source
               (org-apply-edit
                org-source
                (upsert-properties
                 node-id
                 (list (cons "OWNER_ACTOR" next-actor)
                       (cons "CLAIM_STATE" "claimed-active")
                       (cons "CLAIM_LEASE_EPOCH" (number->string (.ref res 'claim-lease-epoch)))
                       (cons "CLAIM_HEARTBEAT_AT" (number->string now))
                       (cons "CUSTODY_OID" custody-oid)))))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.handover-result.v1
            handed-over?: #t reason: (.ref res 'reason)
            node-id: node-id
            prior-owner: (.ref res 'prior-owner) next-owner: next-actor
            claim-lease-epoch: (.ref res 'claim-lease-epoch)
            custody-oid: custody-oid
            next-org-source: next-org
            receipt: (.ref res 'receipt))))))

;;; ---------------------------------------------------------------------------
;;; Context `+durable` Org Adapter Exports (Owned by `ai-agentic-context`)
;;; ---------------------------------------------------------------------------

(def ContextDurableOrgExports
  (.o bind-these: #f
      org->work-snapshot: org->work-snapshot
      org->claim-table: org->claim-table
      funflow-dag: org-work-funflow-dag
      orchestration-plan: org-work-orchestration-plan
      reanchor-mainline: org-work-reanchor-mainline
      archive-transition: org-work-archive-transition
      commit-archive!: org-work-commit-archive!
      reopen!: org-work-reopen!
      recover: org-work-recover
      perceive-claims: org-shared-context-perceive-claims
      assert-write-owner: org-shared-context-assert-write-owner
      claim!: org-shared-context-claim!
      extend!: org-shared-context-extend!
      handover!: org-shared-context-handover!))
