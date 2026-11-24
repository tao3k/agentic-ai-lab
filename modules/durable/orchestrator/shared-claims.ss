;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Zero-SubAgent Concurrent Shared-Context `:ID:` Ownership Engine (Slice 49):
;;; - Ambient L0/L1 peer claim perception (`shared-context-perceive-claims`)
;;; - Extend-Never-Overwrite enforcement (`shared-context-assert-write-owner`,
;;;   `shared-context-extend!`)
;;; - Fenced WAL claims & heartbeat-expiry custody takeover
;;;   (`shared-context-claim!`, `shared-context-handover!`)

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list filter find filter-map)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph)
        "contracts.ss"
        "org-projection.ss")

(export shared-context-perceive-claims
        shared-context-assert-write-owner
        shared-context-claim!
        shared-context-extend!
        shared-context-handover!)

(def (claim-journal-key task-id node-id)
  (string-append "orchestrator:claim:" task-id ":" node-id))

(def (shared-context-perceive-claims org-source-text)
  (let* ((graph (org-source-element-graph org-source-text))
         (qctx (make-org-element-query-context graph))
         (records (org-element-graph-records graph))
         (headlines (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                               (filter (lambda (r) (equal? (.ref r 'kind) "headline")) records))))
    (filter-map
     (lambda (h)
       (let ((hid (org-element-property qctx h "property:ID"))
             (owner (org-element-property qctx h "property:OWNER_ACTOR"))
             (cstate (org-element-property qctx h "property:CLAIM_STATE"))
             (epoch (parse-positive-int (org-element-property qctx h "property:CLAIM_LEASE_EPOCH") 0))
             (hb (parse-positive-int (org-element-property qctx h "property:CLAIM_HEARTBEAT_AT") 0))
             (ttl (parse-positive-int (org-element-property qctx h "property:CLAIM_TTL_SEC") 120))
             (wt (or (org-element-property qctx h "property:CLAIM_WORKTREE") "main"))
             (extends-id (org-element-property qctx h "property:EXTENDS_ID")))
         (and hid
              (or owner cstate extends-id)
              (make-checked-shared-claim
               hid owner (or cstate "unclaimed") epoch hb ttl wt extends-id
               (cons (.ref h 'start) (.ref h 'end))))))
     headlines)))

(def (find-claim-in-org org-source-text node-id)
  (find (lambda (c) (equal? (.ref c 'node-id) node-id))
        (shared-context-perceive-claims org-source-text)))

(def (shared-context-assert-write-owner org-source-text node-id actor)
  (let ((claim (find-claim-in-org org-source-text node-id)))
    (cond
     ((or (not claim)
          (not (.ref claim 'owner-actor))
          (not (equal? (.ref claim 'claim-state) "claimed-active")))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #t
          reason: 'node-unclaimed-or-inactive
          node-id: node-id
          actor: actor
          current-owner: (and claim (.ref claim 'owner-actor))))
     ((equal? (.ref claim 'owner-actor) actor)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #t
          reason: 'active-owner-matched
          node-id: node-id
          actor: actor
          current-owner: actor))
     (else
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #f
          reason: 'non-owner-overwrite-forbidden
          node-id: node-id
          actor: actor
          current-owner: (.ref claim 'owner-actor))))))

(def (shared-context-claim! journal task-id node-id actor
                            worktree: (worktree "main")
                            scope-digest: (scope-digest "")
                            now: (now 0)
                            ttl: (ttl 120)
                            org-source: (org-source ""))
  (let ((check (shared-context-assert-write-owner org-source node-id actor)))
    (if (not (.ref check 'admitted?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.claim-result.v1
          claimed?: #f
          reason: (.ref check 'reason)
          node-id: node-id
          actor: actor
          current-owner: (.ref check 'current-owner)
          next-org-source: org-source)
      (let* ((existing (find-claim-in-org org-source node-id))
             (next-epoch (+ 1 (if existing (.ref existing 'claim-lease-epoch) 0)))
             (next-org
              (upsert-property-in-drawer
               org-source node-id
               (list (cons "OWNER_ACTOR" actor)
                     (cons "CLAIM_STATE" "claimed-active")
                     (cons "CLAIM_LEASE_EPOCH" (number->string next-epoch))
                     (cons "CLAIM_HEARTBEAT_AT" (number->string now))
                     (cons "CLAIM_TTL_SEC" (number->string ttl))
                     (cons "CLAIM_SCOPE_DIGEST" scope-digest)
                     (cons "CLAIM_WORKTREE" worktree))))
             (receipt (.o bind-these: #f
                          kind: 'agentic-ai-lab.durable.claim-receipt.v1
                          task-id: task-id
                          node-id: node-id
                          owner-actor: actor
                          claim-lease-epoch: next-epoch
                          heartbeat-at: now
                          lease-ttl: ttl
                          digest: (canonical-sha256 (list task-id node-id actor next-epoch now))))
             (key (claim-journal-key task-id node-id)))
        (when journal
          (journal-put-fenced! journal (string-append key ":" (number->string next-epoch)) key receipt))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.claim-result.v1
            claimed?: #t
            reason: 'claimed-active
            node-id: node-id
            actor: actor
            claim-lease-epoch: next-epoch
            next-org-source: next-org
            receipt: receipt)))))

(def (shared-context-extend! journal task-id parent-node-id new-node-id actor title
                             body: (body "")
                             role: (role "extension")
                             now: (now 0)
                             org-source: (org-source ""))
  (if (equal? parent-node-id new-node-id)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.extend-result.v1
        extended?: #f
        reason: 'extension-id-must-be-disjoint-from-parent
        parent-node-id: parent-node-id
        new-node-id: new-node-id
        next-org-source: org-source)
    (let* ((sep (if (and (> (string-length org-source) 0)
                         (not (char=? (string-ref org-source (- (string-length org-source) 1)) #\newline)))
                  "\n" ""))
           (ext-block
            (string-append
             sep
             "*** TODO " title "\n"
             ":PROPERTIES:\n"
             ":ID: " new-node-id "\n"
             ":ROLE: " role "\n"
             ":EXTENDS_ID: " parent-node-id "\n"
             ":OWNER_ACTOR: " actor "\n"
             ":CLAIM_STATE: claimed-active\n"
             ":CLAIM_LEASE_EPOCH: 1\n"
             ":CLAIM_HEARTBEAT_AT: " (number->string now) "\n"
             ":END:\n"
             (if (> (string-length body) 0) (string-append body "\n") "")))
           (next-org (string-append org-source ext-block))
           (receipt (.o bind-these: #f
                        kind: 'agentic-ai-lab.durable.extend-receipt.v1
                        task-id: task-id
                        parent-node-id: parent-node-id
                        new-node-id: new-node-id
                        actor: actor
                        role: role
                        digest: (canonical-sha256 (list task-id parent-node-id new-node-id actor now))))
           (key (claim-journal-key task-id new-node-id)))
      (when journal
        (journal-put-fenced! journal (string-append key ":ext") key receipt))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.extend-result.v1
          extended?: #t
          reason: 'disjoint-peer-extension-appended
          parent-node-id: parent-node-id
          new-node-id: new-node-id
          actor: actor
          next-org-source: next-org
          receipt: receipt))))

(def (shared-context-handover! journal task-id node-id next-actor
                               now: (now 0)
                               force-explicit?: (force-explicit? #f)
                               custody-oid: (custody-oid #f)
                               org-source: (org-source ""))
  (let ((claim (find-claim-in-org org-source node-id)))
    (if (not claim)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.handover-result.v1
          handed-over?: #f
          reason: 'node-not-claimed
          node-id: node-id
          next-org-source: org-source)
      (let* ((hb (.ref claim 'heartbeat-at))
             (ttl (.ref claim 'lease-ttl))
             (expired? (>= now (+ hb ttl)))
             (has-custody? (and (string? custody-oid) (> (string-length custody-oid) 0))))
        (cond
         ((and (not force-explicit?) (not expired?))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'active-lease-not-expired
              node-id: node-id
              current-owner: (.ref claim 'owner-actor)
              expires-at: (+ hb ttl)
              next-org-source: org-source))
         ((not has-custody?)
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'handover-requires-custody-snapshot
              node-id: node-id
              next-org-source: org-source))
         (else
          (let* ((next-epoch (+ 1 (.ref claim 'claim-lease-epoch)))
                 (next-org
                  (upsert-property-in-drawer
                   org-source node-id
                   (list (cons "OWNER_ACTOR" next-actor)
                         (cons "CLAIM_STATE" "claimed-active")
                         (cons "CLAIM_LEASE_EPOCH" (number->string next-epoch))
                         (cons "CLAIM_HEARTBEAT_AT" (number->string now))
                         (cons "CUSTODY_OID" custody-oid))))
                 (receipt (.o bind-these: #f
                              kind: 'agentic-ai-lab.durable.handover-receipt.v1
                              task-id: task-id
                              node-id: node-id
                              prior-owner: (.ref claim 'owner-actor)
                              next-owner: next-actor
                              claim-lease-epoch: next-epoch
                              custody-oid: custody-oid
                              via-expiry?: expired?
                              digest: (canonical-sha256
                                       (list task-id node-id next-actor next-epoch custody-oid))))
                 (key (claim-journal-key task-id node-id)))
            (when journal
              (journal-put-fenced! journal (string-append key ":ho:" (number->string next-epoch)) key receipt))
            (.o bind-these: #f
                kind: 'agentic-ai-lab.durable.handover-result.v1
                handed-over?: #t
                reason: (if expired? 'expired-lease-custody-takeover 'explicit-custody-handover)
                node-id: node-id
                prior-owner: (.ref claim 'owner-actor)
                next-owner: next-actor
                claim-lease-epoch: next-epoch
                custody-oid: custody-oid
                next-org-source: next-org
                receipt: receipt))))))))
