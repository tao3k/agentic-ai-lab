;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scoped Detour 4-Exit Fail-Closed CLOS Reconciler (.defmethod-bundle),
;;; Monotonic Overlay Lens, and Pure Mainline Re-Anchoring over WorkSnapshot.
;;; INVARIANT: ZERO orgize imports, ZERO ai-agentic-context imports.

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :clan/poo/mop .defgeneric .defmethod .defmethod-bundle
                 clos-call clos-compose-method-bundles
                 clos-generic-function clos-generic-protocol)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 funflow-envelope-meet)
        "contracts.ss"
        "entities.ss")

(export DetourExitState.
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
        work-apply-overlay
        work-reanchor-mainline)

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

(def (work-apply-overlay task overlay)
  (let* ((parent-env (opt-ref task 'restriction-envelope #f))
         (overlay-env (opt-ref overlay 'restriction-envelope #f))
         (next-env (funflow-envelope-meet parent-env overlay-env))
         (parent-policy (opt-ref task 'policy DurableWorkPolicy.))
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

(def (work-reanchor-mainline task snapshot
                             mainline-core: (mainline-core '())
                             max-detour-depth: (max-detour-depth 2))
  (let* ((open-b (.ref snapshot 'open-blocker-detours))
         (open-sq (.ref snapshot 'open-side-quests))
         (comp-d (.ref snapshot 'completed-detours))
         (unsat-inv (.ref snapshot 'unsatisfied-invariants))
         (max-obs (.ref snapshot 'max-detour-depth-observed))
         (depth-exceeded? (> max-obs max-detour-depth))
         (archive-blocked? (or (pair? open-b) (pair? unsat-inv))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.mainline-alignment.v1
        task-id: (opt-ref task 'task-id (.ref snapshot 'task-id))
        mainline-done: (.ref snapshot 'mainline-done)
        mainline-total: (.ref snapshot 'mainline-total)
        open-blocker-detours: open-b
        open-side-quests: open-sq
        completed-detours: comp-d
        unsatisfied-invariants: unsat-inv
        max-detour-depth-observed: max-obs
        depth-guard-triggered?: depth-exceeded?
        return-anchor-id: (.ref snapshot 'return-anchor-id)
        counterexample-core: mainline-core
        auto-archive-blocked?: archive-blocked?)))
