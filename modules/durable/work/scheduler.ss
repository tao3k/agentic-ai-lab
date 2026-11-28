;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure, domain-agnostic Durable Work Scheduler:
;;; - gerbil-ascent 4-predicate scheduler (ready_to_schedule, needs_recovery,
;;;   ready_to_auto_archive, tab_visible) over abstract WorkSnapshot
;;; - FunFlow CAS DAG execution & crash recovery via fenced durable-journal
;;; - Pure functional WorkbenchTabProjection
;;; INVARIANT: ZERO orgize imports, ZERO ai-agentic-context imports.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-get)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 DurableGovernedStrategy.
                 strategy-archive-guard
                 funflow-dag-build
                 funflow-resume-plan)
        "contracts.ss")

(export default-work-effective-rules
        default-work-artifact-path
        default-work-funflow-dag
        run-ascent-work-rules
        default-work-orchestration-plan
        default-project-workbench-tabs
        durable-work-record-cas!
        durable-work-completed-cas
        durable-work-commit-archive!
        durable-work-reopen!
        durable-work-recover)

(def (default-work-effective-rules node rule-overrides)
  (let* ((policy (opt-ref node 'policy DurableWorkPolicy.))
         (ov-ref (lambda (k fallback)
                   (if (and (object? rule-overrides) (.slot? rule-overrides k))
                     (.ref rule-overrides k)
                     fallback)))
         (split-wm (ov-ref 'split-line-watermark (opt-ref policy 'split-line-watermark 800)))
         (focus-d (ov-ref 'default-focus-depth (opt-ref policy 'default-focus-depth 2)))
         (req-sod (or (opt-ref policy 'require-sod-reviewer #f)
                      (ov-ref 'require-sod-reviewer #f)))
         (fold-th (ov-ref 'fold-thinking-by-default (opt-ref policy 'fold-thinking-by-default #t)))
         (drill (and (opt-ref policy 'allow-agent-drill-down #t)
                     (ov-ref 'allow-agent-drill-down #t)))
         (focused-arch (opt-ref policy 'focused-tab-archive 'on-blur))
         (scratch-prom (opt-ref policy 'scratch-promotion 'on-plan))
         (reopen-m (opt-ref policy 'reopen-mode 'peek-until-edit))
         (max-c (opt-ref policy 'max-concurrency 4))
         (retry-b (opt-ref policy 'retry-budget 2))
         (max-dd (opt-ref policy 'max-detour-depth 2)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.effective-rules.v1
        split-line-watermark: split-wm
        default-focus-depth: focus-d
        require-sod-reviewer: req-sod
        fold-thinking-by-default: fold-th
        allow-agent-drill-down: drill
        focused-tab-archive: focused-arch
        scratch-promotion: scratch-prom
        reopen-mode: reopen-m
        max-concurrency: max-c
        retry-budget: retry-b
        max-detour-depth: max-dd)))

(def (default-work-artifact-path task)
  (let* ((task-id (opt-ref task 'task-id "task-unnamed"))
         (explicit (opt-ref task 'artifact-path (opt-ref task 'org-path #f)))
         (index-p (opt-ref task 'index-path "index.org"))
         (worktree (opt-ref task 'worktree "main"))
         (task-p (or explicit (string-append "work/" task-id ".org"))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.work-artifact-path.v1
        task-id: task-id
        worktree: worktree
        index-path: index-p
        task-artifact-path: task-p
        task-org-path: task-p)))

(def (default-work-funflow-dag task snapshot)
  (let* ((strategy (opt-ref task 'strategy DurableGovernedStrategy.))
         (dag (funflow-dag-build (.ref snapshot 'dag-nodes) strategy: strategy))
         (cdone (.ref snapshot 'checklist-done))
         (ctotal (.ref snapshot 'checklist-total)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.work-dag-projection.v1
        task-id: (.ref snapshot 'task-id)
        root-id: (.ref snapshot 'root-id)
        root-title: (.ref snapshot 'root-title)
        root-status: (.ref snapshot 'root-status)
        root-archived?: (.ref snapshot 'root-archived?)
        checklist-done: cdone
        checklist-total: ctotal
        all-checklists-done?: (= cdone ctotal)
        dag: dag)))

(def (index-list items)
  (let loop ((rest items) (i 0) (acc '()))
    (if (null? rest)
      (reverse acc)
      (loop (cdr rest) (+ i 1) (cons (list 1 i) acc)))))

(def (run-ascent-work-rules task-id root-done? dag-valid? dag-complete?
                            all-checklists-done? no-open-blockers? no-open-invariants?
                            already-archived? in-flight-ids pending-effects recovery-ids
                            ready-ids focused-on-blur? peeked?)
  (let* ((ready-vec (list->vector ready-ids))
         (recov-vec (list->vector recovery-ids))
         (tid-rows '((1)))
         (root-done-rows (if root-done? tid-rows '()))
         (dag-valid-rows (if dag-valid? tid-rows '()))
         (dag-complete-rows (if dag-complete? tid-rows '()))
         (checklists-done-rows (if all-checklists-done? tid-rows '()))
         (no-blockers-rows (if no-open-blockers? tid-rows '()))
         (invariants-met-rows (if no-open-invariants? tid-rows '()))
         (quiescent-rows (if (and (null? in-flight-ids)
                                  (null? pending-effects)
                                  (null? recovery-ids))
                           tid-rows
                           '()))
         (active-rows (if (not already-archived?) tid-rows '()))
         (focused-keep-rows (if focused-on-blur? tid-rows '()))
         (peeked-rows (if peeked? tid-rows '()))
         (ready-node-rows (index-list ready-ids))
         (attempt-rows (index-list recovery-ids))
         (program
          (relational-program
           (relation root_done (t) root-done-rows)
           (relation dag_valid (t) dag-valid-rows)
           (relation dag_complete (t) dag-complete-rows)
           (relation checklists_done (t) checklists-done-rows)
           (relation no_open_blockers (t) no-blockers-rows)
           (relation invariants_met (t) invariants-met-rows)
           (relation journal_quiescent (t) quiescent-rows)
           (relation task_active (t) active-rows)
           (relation focused_keep (t) focused-keep-rows)
           (relation peeked (t) peeked-rows)
           (relation ready_node (t n) ready-node-rows)
           (relation unclosed_attempt (t a) attempt-rows)
           (relation ready_to_schedule (t n))
           (relation needs_recovery (t a))
           (relation ready_to_auto_archive (t))
           (relation tab_visible (t))
           (rule (ready_to_schedule ?t ?n) (ready_node ?t ?n) (dag_valid ?t) (task_active ?t))
           (rule (needs_recovery ?t ?a) (unclosed_attempt ?t ?a))
           (rule (ready_to_auto_archive ?t)
                 (root_done ?t)
                 (dag_valid ?t)
                 (dag_complete ?t)
                 (checklists_done ?t)
                 (no_open_blockers ?t)
                 (invariants_met ?t)
                 (journal_quiescent ?t)
                 (task_active ?t))
           (rule (tab_visible ?t) (task_active ?t))
           (rule (tab_visible ?t) (focused_keep ?t))
           (rule (tab_visible ?t) (peeked ?t))
           (limits 1024 2048 2048)))
         (solution (relational-solve (relational-admit program)))
         (ready-indices (list-sort < (map cadr (relational-query-name solution 'ready_to_schedule))))
         (recov-indices (list-sort < (map cadr (relational-query-name solution 'needs_recovery)))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.ascent-work-facts.v1
        ready-to-schedule: (map (lambda (i) (vector-ref ready-vec i)) ready-indices)
        needs-recovery: (map (lambda (i) (vector-ref recov-vec i)) recov-indices)
        ready-to-auto-archive?: (pair? (relational-query-name solution 'ready_to_auto_archive))
        tab-visible?: (pair? (relational-query-name solution 'tab_visible)))))

(def (default-work-orchestration-plan task snapshot journal-state)
  (let* ((task-id (.ref snapshot 'task-id))
         (rules (work-effective-rules task (opt-ref snapshot 'rule-overrides #f)))
         (strategy-base (opt-ref task 'strategy DurableGovernedStrategy.))
         (strategy (.o (:: @ strategy-base)
                       require-sod-reviewer: (.ref rules 'require-sod-reviewer)
                       max-concurrency: (.ref rules 'max-concurrency)
                       focused-tab-archive: (.ref rules 'focused-tab-archive)))
         (dag-proj (work-funflow-dag task snapshot))
         (dag (.ref dag-proj 'dag))
         (completed-cas (opt-ref journal-state 'completed-cas #f))
         (in-flight-ids (opt-ref journal-state 'in-flight-ids '()))
         (pending-effects (opt-ref journal-state 'pending-effects '()))
         (recovery-ids (opt-ref journal-state 'unclosed-attempts '()))
         (gov-context (opt-ref journal-state 'governance-context (.o)))
         (resume (funflow-resume-plan dag
                                      completed-cas-table: completed-cas
                                      in-flight-ids: in-flight-ids
                                      strategy: strategy
                                      context: gov-context))
         (archive-guard-ok? (strategy-archive-guard strategy dag resume journal-state))
         (focused-keep? (and (opt-ref journal-state 'focused? #f)
                             (eq? (.ref rules 'focused-tab-archive) 'on-blur)))
         (peeked? (and (opt-ref journal-state 'peeked? #f) #t))
         (no-blockers? (null? (opt-ref snapshot 'open-blocker-detours '())))
         (no-invariants? (null? (opt-ref snapshot 'unsatisfied-invariants '())))
         (ascent-facts
          (run-ascent-work-rules
           task-id
           (eq? (.ref dag-proj 'root-status) 'done)
           (.ref dag 'valid?)
           (and (.ref resume 'complete?) archive-guard-ok?)
           (.ref dag-proj 'all-checklists-done?)
           no-blockers?
           no-invariants?
           (.ref dag-proj 'root-archived?)
           in-flight-ids
           pending-effects
           recovery-ids
           (.ref resume 'ready-frontier)
           focused-keep?
           peeked?)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.work-orchestration-plan.v1
        task-id: task-id
        effective-rules: rules
        dag-projection: dag-proj
        resume-plan: resume
        ready-to-schedule: (.ref ascent-facts 'ready-to-schedule)
        needs-recovery: (.ref ascent-facts 'needs-recovery)
        ready-to-auto-archive?: (.ref ascent-facts 'ready-to-auto-archive?)
        tab-visible?: (.ref ascent-facts 'tab-visible?))))

(def (default-project-workbench-tabs owner task-records journal-state peek-set focused-task-id)
  (let* ((policy (opt-ref owner 'policy DurableWorkPolicy.))
         (focused-policy (opt-ref policy 'focused-tab-archive 'on-blur))
         (peek-list (if (list? peek-set) peek-set '()))
         (pinned (list (.o id: 'index
                           label: "Index"
                           kind: 'index
                           closable?: #f
                           mode: 'pinned)))
         (dynamic-rev '())
         (archived-rev '()))
    (for-each
     (lambda (rec)
       (let* ((tid (.ref rec 'task-id))
              (title (opt-ref rec 'title tid))
              (status (opt-ref rec 'status 'todo))
              (archived? (opt-ref rec 'archived? #f))
              (done-c (opt-ref rec 'checklist-done 0))
              (total-c (opt-ref rec 'checklist-total 0))
              (worktree (opt-ref rec 'worktree (opt-ref owner 'worktree "main")))
              (focused? (and focused-task-id (equal? tid focused-task-id)))
              (peeked? (and (member tid peek-list) #t)))
         (when archived?
           (set! archived-rev
                 (cons (.o bind-these: #f
                           task-id: tid
                           title: title
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t)
                       archived-rev)))
         (cond
          ((not archived?)
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #f
                           mode: 'active)
                       dynamic-rev)))
          ((and archived? peeked?)
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t
                           mode: 'peek-readonly)
                       dynamic-rev)))
          ((and archived? focused? (eq? focused-policy 'on-blur))
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t
                           mode: 'archived-pending-blur)
                       dynamic-rev)))
          (else (void)))))
     task-records)
    (let ((dyn (reverse dynamic-rev))
          (arch (reverse archived-rev)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.workbench-tab-projection.v1
          pinned-tabs: pinned
          dynamic-tabs: dyn
          archived-index: arch
          visible-tab-ids: (cons 'index (map (lambda (t) (.ref t 'id)) dyn))))))

;;; ---------------------------------------------------------------------------
;;; Fenced Durable Journal Operations (Pure Engine)
;;; ---------------------------------------------------------------------------

(def (cas-journal-key task-id node-id)
  (string-append "orchestrator:cas:" task-id ":"
                 (if (symbol? node-id) (symbol->string node-id) node-id)))

(def (archive-journal-key task-id)
  (string-append "orchestrator:archive:" task-id))

(def (reopen-journal-key task-id)
  (string-append "orchestrator:reopen:" task-id))

(def (durable-work-record-cas! journal task-id node-id fingerprint result-digest)
  (let* ((key (cas-journal-key task-id node-id))
         (tx-id (string-append key ":" fingerprint))
         (entry (.o bind-these: #f
                    kind: 'agentic-ai-lab.durable.cas-entry.v1
                    task-id: task-id
                    node-id: (if (symbol? node-id) node-id (string->symbol node-id))
                    fingerprint: fingerprint
                    result-digest: result-digest)))
    (journal-put-fenced! journal tx-id key entry)
    entry))

(def (durable-work-completed-cas journal task-id dag)
  (let ((table (make-hash-table-eq)))
    (for-each
     (lambda (node-id)
       (let ((saved (journal-get journal (cas-journal-key task-id node-id))))
         (when (and (object? saved) (.slot? saved 'fingerprint))
           (hash-put! table node-id (.ref saved 'fingerprint)))))
     (.ref dag 'node-ids))
    table))

(def (durable-work-commit-archive! journal task snapshot journal-state timestamp)
  (let* ((plan (work-orchestration-plan task snapshot journal-state))
         (task-id (.ref plan 'task-id)))
    (if (not (.ref plan 'ready-to-auto-archive?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.archive-commit-result.v1
          committed?: #f
          reason: 'archive-guard-not-satisfied
          task-id: task-id
          plan: plan)
      (let* ((ts (if (and (string? timestamp) (> (string-length timestamp) 0))
                   timestamp
                   "2026-11-24 Tue 00:00"))
             (digest (canonical-sha256
                      (list 'agentic-ai-lab.durable.archive-receipt.v1
                            task-id ts (.ref (.ref plan 'dag-projection) 'root-id))))
             (receipt (.o bind-these: #f
                          kind: 'agentic-ai-lab.durable.archive-receipt.v1
                          task-id: task-id
                          timestamp: ts
                          digest: digest))
             (key (archive-journal-key task-id))
             (tx-id (string-append key ":" digest)))
        (when journal
          (journal-put-fenced! journal tx-id key receipt))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.archive-commit-result.v1
            committed?: #t
            task-id: task-id
            timestamp: ts
            receipt: receipt
            plan: plan)))))

(def (durable-work-reopen! journal task snapshot timestamp)
  (let* ((task-id (.ref snapshot 'task-id))
         (archived-in-snap? (opt-ref snapshot 'root-archived? #f))
         (archived-in-journal? (and journal (object? (journal-get journal (archive-journal-key task-id))))))
    (if (and journal (not archived-in-snap?) (not archived-in-journal?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.reopen-result.v1
          reopened?: #f
          reason: 'task-not-archived
          task-id: task-id)
      (let* ((ts (if (and (string? timestamp) (> (string-length timestamp) 0))
                   timestamp
                   "2026-11-24 Tue 00:00"))
             (digest (canonical-sha256 (list 'agentic-ai-lab.durable.reopen-receipt.v1 task-id ts)))
             (receipt (.o bind-these: #f
                          kind: 'agentic-ai-lab.durable.reopen-receipt.v1
                          task-id: task-id
                          timestamp: ts
                          digest: digest))
             (key (reopen-journal-key task-id))
             (tx-id (string-append key ":" digest)))
        (when journal
          (journal-put-fenced! journal tx-id key receipt))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.reopen-result.v1
            reopened?: #t
            task-id: task-id
            timestamp: ts
            receipt: receipt)))))

(def (durable-work-recover journal task snapshot
                           in-flight-ids: (in-flight-ids '())
                           unclosed-attempts: (unclosed-attempts '())
                           governance-context: (governance-context (.o)))
  (let* ((task-id (.ref snapshot 'task-id))
         (dag-proj (work-funflow-dag task snapshot))
         (dag (.ref dag-proj 'dag))
         (completed-cas (durable-work-completed-cas journal task-id dag))
         (jstate (.o bind-these: #f
                     completed-cas: completed-cas
                     in-flight-ids: in-flight-ids
                     unclosed-attempts: unclosed-attempts
                     recovery-required?: (pair? unclosed-attempts)
                     governance-context: governance-context))
         (plan (work-orchestration-plan task snapshot jstate)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.recovery-snapshot.v1
        task-id: task-id
        completed-cas-count: (hash-length completed-cas)
        plan: plan)))
