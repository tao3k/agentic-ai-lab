;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: strategies choose planning policy, not runtime execution.
;;; Invariant: heavy execution remains in runner/runtime-adapter code.

(import :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/plan
        :poo-flow/modules/workflow/control-plane/task)

(export make-strategy
        strategy?
        strategy-name
        strategy-capabilities
        strategy-cache-policy
        strategy-failure-policy
        strategy-planner
        make-local-eager-strategy
        make-cached-local-eager-strategy
        strategy-plan
        strategy-planner-for-flow-in
        strategy-planner-for-flow
        strategy-can-select-frontier?
        strategy-ready-frontier
        strategy-ready-frontier-ids
        strategy-admit-ready-frontier-ids
        strategy-can-run-locally-in
        strategy-can-run-locally?
        strategy-cache-decision)

;;; The planner slot is the only executable policy hook; other fields are
;;; declarative metadata used for task and graph-frontier capability checks.
;; : (-> Symbol [Symbol] Symbol Symbol Planner Strategy)
(defstruct strategy
  (name
   capabilities
   cache-policy
   failure-policy
   planner)
  transparent: #t)

;;; The default strategy mirrors Funflow's eager local path while still lowering
;;; to an inspectable plan before any runner touches execution.
;; : (-> Unit Strategy)
(def (make-local-eager-strategy)
  (make-strategy 'local-eager
                 '(pure scheme external branch graph-frontier)
                 'no-cache
                 'fail-fast
                 default-linear-plan))

;;; Cached eager execution records cache intent in receipts but leaves durable
;;; cache materialization to the runtime adapter/Rust boundary.
;; : (-> Unit Strategy)
(def (make-cached-local-eager-strategy)
  (make-strategy 'cached-local-eager
                 '(pure scheme external branch graph-frontier)
                 'cache-output
                 'fail-fast
                 default-linear-plan))

;; : (-> Flow ExecutionPlan)
(def (default-linear-plan flow)
  (flow->linear-plan flow))

;; : (-> Strategy Flow ExecutionPlan)
(def (strategy-plan strategy flow)
  ((strategy-planner-for-flow strategy flow) flow))

;;; Flow descriptors declare the planner policy; strategies bind supported
;;; descriptor planner names to concrete plan functions.
;; : (-> Strategy Symbol Alist)
(defpoo-core-receipt-projection
  strategy-unsupported-flow-planner-detail (strategy planner)
  (bindings ())
  (fields ((strategy (strategy-name strategy))
           (planner planner))))

;; : (-> Strategy FlowDeclarationRegistry Flow Planner)
(def (strategy-planner-for-flow-in strategy registry flow)
  (let ((planner (flow-declaration-planner
                  (flow-declaration-descriptor-in registry flow))))
    (cond
     ((eq? planner 'linear-dag) (strategy-planner strategy))
     (else
      (raise-control-plane-failure
       'strategy
       'unsupported-flow-planner
       "strategy does not support flow planner"
       (strategy-unsupported-flow-planner-detail strategy planner))))))

;; : (-> Strategy Flow Planner)
(def (strategy-planner-for-flow strategy flow)
  (strategy-planner-for-flow-in strategy default-flow-declaration-registry flow))

;;; Frontier support is capability-gated so later strategies can opt out of
;;; graph scheduling without changing the execution-plan data model.
;; : (-> Strategy Boolean)
(def (strategy-can-select-frontier? strategy)
  (and (memq 'graph-frontier (strategy-capabilities strategy)) #t))

;;; Strategy owns the policy decision to expose a ready frontier; plan owns the
;;; pure graph predicate that computes it.
;; : (-> Strategy Alist)
(defpoo-core-receipt-projection
  strategy-unsupported-frontier-detail (strategy)
  (bindings ())
  (fields ((strategy (strategy-name strategy)))))

;; : (-> Strategy ExecutionPlan [Id] [PlanNode])
(def (strategy-ready-frontier strategy plan completed-node-ids)
  (if (strategy-can-select-frontier? strategy)
    (execution-plan-ready-nodes plan completed-node-ids)
    (raise-control-plane-failure
     'strategy
     'unsupported-frontier
     "strategy cannot select graph frontier"
     (strategy-unsupported-frontier-detail strategy))))

;;; The id projection is the stable receipt/adapter surface for frontier
;;; evidence when callers do not need plan-node payloads.
;; : (-> Strategy ExecutionPlan [Id] [Id])
(def (strategy-ready-frontier-ids strategy plan completed-node-ids)
  (if (strategy-can-select-frontier? strategy)
    (execution-plan-ready-node-ids plan completed-node-ids)
    (raise-control-plane-failure
     'strategy
     'unsupported-frontier
     "strategy cannot select graph frontier"
     (strategy-unsupported-frontier-detail strategy))))

;;; Incremental runners may already own the pure frontier calculation.  The
;;; strategy still admits the capability and preserves the same typed failure.
;; : (-> Strategy [Id] [Id])
(def (strategy-admit-ready-frontier-ids strategy frontier-ids)
  (if (strategy-can-select-frontier? strategy)
    frontier-ids
    (raise-control-plane-failure
     'strategy
     'unsupported-frontier
     "strategy cannot select graph frontier"
     (strategy-unsupported-frontier-detail strategy))))

;; : (-> Strategy TaskFamilyRegistry Task Boolean)
(def (strategy-can-run-locally-in strategy registry task)
  (and (memq (task-capability-in registry task) (strategy-capabilities strategy))
       (task-local?-in registry task)))

;; : (-> Strategy Task Boolean)
(def (strategy-can-run-locally? strategy task)
  (strategy-can-run-locally-in strategy default-task-family-registry task))

;;; Cache decisions are evidence values, not storage actions; runners copy them
;;; into receipts so adapters can later materialize the policy.
;; : (-> Strategy Task Input Output CacheDecision)
(def (strategy-cache-decision strategy task input output)
  (let ((policy (strategy-cache-policy strategy)))
    (cond
     ((eq? policy 'no-cache)
      (list 'cache-bypass (task-name task) (task-kind task)))
     ((eq? policy 'cache-output)
      (list 'cache-miss (task-name task) (task-kind task) input output))
     (else
      (list 'cache-policy policy (task-name task) (task-kind task) input output)))))
