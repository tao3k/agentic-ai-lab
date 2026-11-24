;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; ASCENT 4-predicate scheduler, C4 POO entity hierarchy (Repo -> Worktree ->
;;; Task -> SubTask), and fenced durable-journal lifecycle operations.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
                 context-org-source)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-elements-gql
                 agentic-ai-lab-ai-agentic-context-org-element-graph
                 agentic-ai-lab-ai-agentic-context-headline-set-todo)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-progressive-rules
                 agentic-ai-lab-ai-agentic-context-ascent-progressive-plan)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-get)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 DurableGovernedStrategy.
                 strategy-archive-guard
                 funflow-resume-plan)
        "contracts.ss"
        "org-projection.ss")

(export RepoNode.
        WorktreeNode.
        TaskNode.
        SubTaskNode.
        run-ascent-orchestration-rules
        default-task-orchestration-plan
        durable-orchestrator-record-cas!
        durable-orchestrator-completed-cas
        durable-orchestrator-commit-archive!
        durable-orchestrator-reopen!
        durable-orchestrator-recover)

(def (index-list items)
  (let loop ((rest items) (i 0) (acc '()))
    (if (null? rest)
      (reverse acc)
      (loop (cdr rest) (+ i 1) (cons (list 1 i) acc)))))

(def (run-ascent-orchestration-rules task-id root-done? dag-valid? dag-complete?
                                     all-checklists-done? already-archived?
                                     in-flight-ids pending-effects recovery-ids
                                     ready-ids focused-on-blur? peeked?)
  (let* ((ready-vec (list->vector ready-ids))
         (recov-vec (list->vector recovery-ids))
         (tid-rows '((1)))
         (root-done-rows (if root-done? tid-rows '()))
         (dag-valid-rows (if dag-valid? tid-rows '()))
         (dag-complete-rows (if dag-complete? tid-rows '()))
         (checklists-done-rows (if all-checklists-done? tid-rows '()))
         (quiescent-rows (if (and (null? in-flight-ids) (null? pending-effects)) tid-rows '()))
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
        kind: 'agentic-ai-lab.durable.ascent-orchestration-facts.v1
        ready-to-schedule: (map (lambda (i) (vector-ref ready-vec i)) ready-indices)
        needs-recovery: (map (lambda (i) (vector-ref recov-vec i)) recov-indices)
        ready-to-auto-archive?: (pair? (relational-query-name solution 'ready_to_auto_archive))
        tab-visible?: (pair? (relational-query-name solution 'tab_visible)))))

(def (default-task-orchestration-plan task org-source-text journal-state)
  (let* ((task-id (opt-ref task 'task-id "task"))
         (rules (node-effective-rules task org-source-text))
         (strategy-base (opt-ref task 'strategy DurableGovernedStrategy.))
         (strategy (.o (:: @ strategy-base)
                       require-sod-reviewer: (.ref rules 'require-sod-reviewer)
                       max-concurrency: (.ref rules 'max-concurrency)
                       focused-tab-archive: (.ref rules 'focused-tab-archive)))
         (dag-proj (task-funflow-dag task org-source-text))
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
         (ascent-facts
          (run-ascent-orchestration-rules
           task-id
           (eq? (.ref dag-proj 'root-status) 'done)
           (.ref dag 'valid?)
           (and (.ref resume 'complete?) archive-guard-ok?)
           (.ref dag-proj 'all-checklists-done?)
           (.ref dag-proj 'root-archived?)
           in-flight-ids
           pending-effects
           recovery-ids
           (.ref resume 'ready-frontier)
           focused-keep?
           peeked?))
         (progressive
          (with-catch
            (lambda (_err) #f)
            (lambda ()
              (let* ((src-cut-obj (context-org-source (or (opt-ref task 'org-path task-id) task-id)
                                                      1
                                                      org-source-text
                                                      #t))
                     (elem-graph (agentic-ai-lab-ai-agentic-context-org-element-graph
                                  task-id (list src-cut-obj))))
                (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
                 elem-graph
                 (.o focus-property-ids: (list (.ref dag-proj 'root-id))
                     drill-downs: (opt-ref journal-state 'drill-downs '()))))))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.task-orchestration-plan.v1
        task-id: task-id
        effective-rules: rules
        dag-projection: dag-proj
        resume-plan: resume
        ready-to-schedule: (.ref ascent-facts 'ready-to-schedule)
        needs-recovery: (.ref ascent-facts 'needs-recovery)
        ready-to-auto-archive?: (.ref ascent-facts 'ready-to-auto-archive?)
        tab-visible?: (.ref ascent-facts 'tab-visible?)
        progressive-plan: progressive)))

;;; ---------------------------------------------------------------------------
;;; C4 Linearized POO Entity Prototypes (Repo -> Worktree -> Task -> SubTask)
;;; ---------------------------------------------------------------------------

(def RepoNode.
  (.o (:: self)
      kind: 'agentic-ai-lab.durable.repo-node.v1
      repo-id: "repo-default"
      topology-path: "topology.org"
      index-path: "index.org"
      org-graph: #f
      features: '(+plan-a-index +funflow-dag +cas-resume +durable-agenda
                  +auto-archive +progressive-l0-l3 +two-stage-repair +worktrunk)
      policy: DurableTaskPolicy.
      strategy: DurableGovernedStrategy.
      .effective-rules: (lambda (org-source-text)
                          (default-effective-rules self org-source-text))
      .project-workbench-tabs: (lambda (task-records journal-state peek-set focused-task-id)
                                 (default-project-workbench-tabs self task-records journal-state
                                                                 peek-set focused-task-id))))

(def WorktreeNode.
  (.o worktree: "main"
      branch: "main"
      source-cut: "HEAD"
      grant-scope: 'worktree-local))

(def TaskNode.
  (.o (:: self)
      task-id: "task-default"
      org-path: #f
      scope-root-id: #f
      context-scope: #f
      restriction-envelope: #f
      trust-tier: 'verified
      .artifact-path: (default-task-artifact-path self)
      .funflow-dag: (lambda (org-source-text)
                      (default-task-funflow-dag self org-source-text))
      .orchestration-plan: (lambda (org-source-text journal-state)
                             (default-task-orchestration-plan self org-source-text journal-state))
      .archive-transition: (lambda (org-source-text index-source-text timestamp)
                             (default-task-archive-transition self org-source-text index-source-text timestamp))))

(def SubTaskNode.
  (.o (:: @ TaskNode.)
      node-id: #f
      needs: '()
      after-start: #f
      model-tier: 'builder
      disclosure-depth: 2))

;;; ---------------------------------------------------------------------------
;;; Fenced Durable Journal Operations
;;; ---------------------------------------------------------------------------

(def (cas-journal-key task-id node-id)
  (string-append "orchestrator:cas:" task-id ":"
                 (if (symbol? node-id) (symbol->string node-id) node-id)))

(def (archive-journal-key task-id)
  (string-append "orchestrator:archive:" task-id))

(def (reopen-journal-key task-id)
  (string-append "orchestrator:reopen:" task-id))

(def (durable-orchestrator-record-cas! journal task-id node-id fingerprint result-digest)
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

(def (durable-orchestrator-completed-cas journal task-id dag)
  (let ((table (make-hash-table-eq)))
    (for-each
     (lambda (node-id)
       (let ((saved (journal-get journal (cas-journal-key task-id node-id))))
         (when (and (object? saved) (.slot? saved 'fingerprint))
           (hash-put! table node-id (.ref saved 'fingerprint)))))
     (.ref dag 'node-ids))
    table))

(def (durable-orchestrator-commit-archive! journal task org-source-text index-source-text
                                           journal-state timestamp)
  (let* ((plan (task-orchestration-plan task org-source-text journal-state))
         (task-id (.ref plan 'task-id)))
    (if (not (.ref plan 'ready-to-auto-archive?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.archive-commit-result.v1
          committed?: #f
          reason: 'archive-guard-not-satisfied
          task-id: task-id
          plan: plan)
      (let* ((trans (task-archive-transition task org-source-text index-source-text timestamp))
             (receipt (.ref trans 'receipt))
             (key (archive-journal-key task-id))
             (tx-id (string-append key ":" (.ref receipt 'digest))))
        (journal-put-fenced! journal tx-id key receipt)
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.archive-commit-result.v1
            committed?: #t
            task-id: task-id
            next-task-org: (.ref trans 'next-task-org)
            next-index-org: (.ref trans 'next-index-org)
            receipt: receipt
            plan: plan)))))

(def (durable-orchestrator-reopen! journal task org-source-text index-source-text timestamp)
  (let* ((paths (task-artifact-path task))
         (task-id (.ref paths 'task-id))
         (worktree (.ref paths 'worktree))
         (task-path (.ref paths 'task-org-path))
         (unarchived (remove-archive-tag-and-closed org-source-text))
         (dag-before (task-funflow-dag task unarchived))
         (root-id (.ref dag-before 'root-id))
         (reopened-res
          (agentic-ai-lab-ai-agentic-context-headline-set-todo unarchived root-id "TODO"))
         (next-task-org (if (string? reopened-res) reopened-res (.ref reopened-res 'source)))
         (next-index-org (upsert-index-entry index-source-text
                                             task-id
                                             root-id
                                             (.ref dag-before 'root-title)
                                             worktree
                                             task-path
                                             'todo
                                             (.ref dag-before 'checklist-done)
                                             (.ref dag-before 'checklist-total)
                                             #f
                                             timestamp))
         (receipt (.o bind-these: #f
                      kind: 'agentic-ai-lab.durable.reopen-receipt.v1
                      task-id: task-id
                      timestamp: timestamp
                      digest: (canonical-sha256 (list task-id timestamp next-task-org))))
         (key (reopen-journal-key task-id))
         (tx-id (string-append key ":" (.ref receipt 'digest))))
    (journal-put-fenced! journal tx-id key receipt)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.reopen-result.v1
        reopened?: #t
        task-id: task-id
        next-task-org: next-task-org
        next-index-org: next-index-org
        receipt: receipt)))

(def (durable-orchestrator-recover journal task org-source-text
                                   in-flight-ids: (in-flight-ids '())
                                   unclosed-attempts: (unclosed-attempts '())
                                   governance-context: (governance-context (.o)))
  (let* ((task-id (opt-ref task 'task-id "task"))
         (dag-proj (task-funflow-dag task org-source-text))
         (dag (.ref dag-proj 'dag))
         (completed-cas (durable-orchestrator-completed-cas journal task-id dag))
         (jstate (.o bind-these: #f
                     completed-cas: completed-cas
                     in-flight-ids: in-flight-ids
                     unclosed-attempts: unclosed-attempts
                     recovery-required?: (pair? unclosed-attempts)
                     governance-context: governance-context))
         (plan (task-orchestration-plan task org-source-text jstate)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.recovery-snapshot.v1
        task-id: task-id
        completed-cas-count: (hash-length completed-cas)
        plan: plan)))
