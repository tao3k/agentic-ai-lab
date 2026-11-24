;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scoped Detour Prototypes, Fail-Closed CLOS 4-Exit Reconciler
;;; (.defmethod-bundle), Monotonic OrgOverlay(g) Lens, and Zero-Token
;;; Org-Elements Mainline Re-Anchoring Engine (Slice 49).

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :clan/poo/mop .defgeneric .defmethod .defmethod-bundle
                 clos-call clos-compose-method-bundles
                 clos-generic-function clos-generic-protocol)
        (only-in :std/list/list filter delete-duplicates/hash)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 funflow-envelope-meet)
        "contracts.ss"
        "ascent-planner.ss")

(export DetourNode.
        BlockerDetourNode.
        SideQuestDetourNode.
        DetourExitState.
        CompletedExit.
        ParkedExit.
        CancelledExit.
        PromotedToTaskExit.
        AnchorKind.
        MainlineStepAnchor.
        InvariantGateAnchor.
        DetourExitProtocol
        DetourExitMethods
        reconcile-detour-exit
        durable-reconcile-detour-exit
        task-apply-org-overlay
        task-reanchor-mainline)

(.def (DetourNode. @ SubTaskNode.)
  role: 'detour
  detour-kind: 'side-quest
  return-anchor: #f
  detour-depth: 1
  max-detour-depth: 2)

(.def (BlockerDetourNode. @ DetourNode.)
  detour-kind: 'blocker)

(.def (SideQuestDetourNode. @ DetourNode.)
  detour-kind: 'side-quest)

(.def DetourExitState.
  exit-kind: 'abstract-exit)

(.def (CompletedExit. @ DetourExitState.)
  exit-kind: 'completed
  outcome-receipt-digest: #f
  defeat-conditions: '())

(.def (ParkedExit. @ DetourExitState.)
  exit-kind: 'parked-custody
  custody-oid: #f
  defeat-conditions: '())

(.def (CancelledExit. @ DetourExitState.)
  exit-kind: 'cancelled
  defeat-conditions: '())

(.def (PromotedToTaskExit. @ DetourExitState.)
  exit-kind: 'promoted-to-task
  promoted-task-id: #f)

(.def AnchorKind.
  anchor-kind: 'abstract-anchor)

(.def (MainlineStepAnchor. @ AnchorKind.)
  anchor-kind: 'mainline-step
  anchor-id: #f
  mainline-counterexample-core: '())

(.def (InvariantGateAnchor. @ AnchorKind.)
  anchor-kind: 'invariant-gate
  anchor-id: #f
  mainline-counterexample-core: '())

(def (merge-counterexample-core prior newly-discovered)
  (delete-duplicates/hash (append (if (list? prior) prior '())
                                  (if (list? newly-discovered) newly-discovered '()))))

(def DetourExitProtocol
  (clos-generic-protocol 'durable/detour-exit-reconcile))

(.defgeneric reconcile-detour-exit (detour exit-state anchor)
  (protocol DetourExitProtocol))

(.defmethod-bundle DetourExitMethods DetourExitProtocol
  (.defmethod (reconcile-detour-exit detour exit-state anchor)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.detour-reconcile.v1
        admitted?: #f
        exit-kind: (opt-ref exit-state 'exit-kind 'unknown)
        reason: 'unsupported-detour-exit-crossing))
  (.defmethod (reconcile-detour-exit (detour (prototype DetourNode.))
                                     (exit-state (prototype CompletedExit.))
                                     (anchor (prototype AnchorKind.)))
    (let* ((receipt (opt-ref exit-state 'outcome-receipt-digest #f))
           (has-receipt? (and (string? receipt) (> (string-length receipt) 0)))
           (next-core (merge-counterexample-core
                       (opt-ref anchor 'mainline-counterexample-core '())
                       (opt-ref exit-state 'defeat-conditions '()))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.detour-reconcile.v1
          admitted?: has-receipt?
          exit-kind: 'completed
          reason: (if has-receipt? 'detour-completed-and-reanchored 'missing-outcome-receipt-digest)
          return-anchor: (or (opt-ref detour 'return-anchor #f) (opt-ref anchor 'anchor-id #f))
          folded-disclosure-depth: 0
          unblocks-mainline?: has-receipt?
          next-counterexample-core: next-core
          custody-oid: #f
          promoted-task-id: #f)))
  (.defmethod (reconcile-detour-exit (detour (prototype DetourNode.))
                                     (exit-state (prototype ParkedExit.))
                                     (anchor (prototype AnchorKind.)))
    (let* ((custody (opt-ref exit-state 'custody-oid #f))
           (has-custody? (and (string? custody) (> (string-length custody) 0)))
           (blocker? (eq? (opt-ref detour 'detour-kind 'side-quest) 'blocker))
           (next-core (merge-counterexample-core
                       (opt-ref anchor 'mainline-counterexample-core '())
                       (opt-ref exit-state 'defeat-conditions '()))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.detour-reconcile.v1
          admitted?: has-custody?
          exit-kind: 'parked-custody
          reason: (if has-custody? 'detour-parked-to-custody 'missing-custody-oid)
          return-anchor: (or (opt-ref detour 'return-anchor #f) (opt-ref anchor 'anchor-id #f))
          folded-disclosure-depth: 1
          unblocks-mainline?: (and has-custody? (not blocker?))
          next-counterexample-core: next-core
          custody-oid: custody
          promoted-task-id: #f)))
  (.defmethod (reconcile-detour-exit (detour (prototype DetourNode.))
                                     (exit-state (prototype CancelledExit.))
                                     (anchor (prototype AnchorKind.)))
    (let* ((defeats (opt-ref exit-state 'defeat-conditions '()))
           (has-defeats? (and (list? defeats) (pair? defeats)))
           (next-core (merge-counterexample-core
                       (opt-ref anchor 'mainline-counterexample-core '())
                       defeats)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.detour-reconcile.v1
          admitted?: has-defeats?
          exit-kind: 'cancelled
          reason: (if has-defeats?
                    'detour-cancelled-defeaters-preserved
                    'cancelled-detour-must-record-defeat-conditions)
          return-anchor: (or (opt-ref detour 'return-anchor #f) (opt-ref anchor 'anchor-id #f))
          folded-disclosure-depth: 0
          unblocks-mainline?: has-defeats?
          next-counterexample-core: next-core
          custody-oid: #f
          promoted-task-id: #f)))
  (.defmethod (reconcile-detour-exit (detour (prototype DetourNode.))
                                     (exit-state (prototype PromotedToTaskExit.))
                                     (anchor (prototype AnchorKind.)))
    (let* ((new-tid (opt-ref exit-state 'promoted-task-id #f))
           (valid-tid? (and (string? new-tid) (> (string-length new-tid) 0))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.detour-reconcile.v1
          admitted?: valid-tid?
          exit-kind: 'promoted-to-task
          reason: (if valid-tid? 'detour-promoted-to-task-tab 'missing-promoted-task-id)
          return-anchor: (or (opt-ref detour 'return-anchor #f) (opt-ref anchor 'anchor-id #f))
          folded-disclosure-depth: 0
          unblocks-mainline?: #f
          next-counterexample-core: (opt-ref anchor 'mainline-counterexample-core '())
          custody-oid: #f
          promoted-task-id: new-tid))))

(def detour-exit-dispatcher
  (clos-compose-method-bundles
   (clos-generic-function 'reconcile-detour-exit 3 protocol: DetourExitProtocol)
   (list DetourExitMethods)))

(def (durable-reconcile-detour-exit detour exit-state anchor)
  (clos-call detour-exit-dispatcher detour exit-state anchor))

(def (task-apply-org-overlay task overlay)
  (let* ((parent-env (opt-ref task 'restriction-envelope #f))
         (overlay-env (opt-ref overlay 'restriction-envelope #f))
         (next-env (funflow-envelope-meet parent-env overlay-env))
         (parent-policy (opt-ref task 'policy DurableTaskPolicy.))
         (next-policy
          (.o (:: @ parent-policy)
              bind-these: #f
              max-concurrency: (opt-ref overlay 'max-parallel (opt-ref parent-policy 'max-concurrency 4))
              retry-budget: (opt-ref overlay 'retry-budget (opt-ref parent-policy 'retry-budget 2))
              max-detour-depth: (opt-ref overlay 'max-detour-depth (opt-ref parent-policy 'max-detour-depth 2)))))
    (.o (:: @ task)
        bind-these: #f
        policy: next-policy
        restriction-envelope: next-env
        overlay-epoch: (+ 1 (opt-ref task 'overlay-epoch 0)))))

(def (task-reanchor-mainline task org-source-text
                             mainline-core: (mainline-core '())
                             max-detour-depth: (max-detour-depth 2))
  (let* ((graph (org-source-element-graph org-source-text))
         (qctx (make-org-element-query-context graph))
         (records (org-element-graph-records graph))
         (headlines (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                               (filter (lambda (r) (equal? (.ref r 'kind) "headline")) records)))
         (mainline-done 0)
         (mainline-total 0)
         (open-blockers '())
         (open-side-quests '())
         (completed-detours '())
         (unsatisfied-invariants '())
         (max-observed-depth 0)
         (return-anchor #f))
    (for-each
     (lambda (h)
       (let* ((hid (or (org-element-property qctx h "property:ID") ""))
              (role (or (org-element-property qctx h "property:ROLE") "mainline"))
              (dkind (or (org-element-property qctx h "property:DETOUR_KIND") "side-quest"))
              (anchor (org-element-property qctx h "property:RETURN_ANCHOR"))
              (depth (parse-positive-int (org-element-property qctx h "property:DETOUR_DEPTH")
                                         (if (equal? role "detour") 1 0)))
              (inv (org-element-property qctx h "property:INVARIANT"))
              (todo (or (org-element-property qctx h "todo-keyword") ""))
              (done? (or (equal? todo "DONE") (equal? todo "CANCELLED"))))
         (when (> depth max-observed-depth)
           (set! max-observed-depth depth))
         (when (and inv (not done?))
           (set! unsatisfied-invariants (cons (if (> (string-length hid) 0) hid inv) unsatisfied-invariants)))
         (cond
          ((equal? role "detour")
           (when (and anchor (not return-anchor))
             (set! return-anchor anchor))
           (cond
            (done?
             (set! completed-detours (cons hid completed-detours)))
            ((equal? dkind "blocker")
             (set! open-blockers (cons hid open-blockers)))
            (else
             (set! open-side-quests (cons hid open-side-quests)))))
          ((> (or (org-element-property qctx h "level") 1) 1)
           (set! mainline-total (+ mainline-total 1))
           (when done?
             (set! mainline-done (+ mainline-done 1)))))))
     headlines)
    (let* ((open-b (reverse open-blockers))
           (open-sq (reverse open-side-quests))
           (comp-d (reverse completed-detours))
           (unsat-inv (reverse unsatisfied-invariants))
           (depth-exceeded? (> max-observed-depth max-detour-depth))
           (archive-blocked? (or (pair? open-b) (pair? unsat-inv))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.mainline-alignment.v1
          task-id: (opt-ref task 'task-id "task")
          mainline-done: mainline-done
          mainline-total: mainline-total
          open-blocker-detours: open-b
          open-side-quests: open-sq
          completed-detours: comp-d
          unsatisfied-invariants: unsat-inv
          max-detour-depth-observed: max-observed-depth
          depth-guard-triggered?: depth-exceeded?
          return-anchor-id: return-anchor
          counterexample-core: mainline-core
          auto-archive-blocked?: archive-blocked?))))
