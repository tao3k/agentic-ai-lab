;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runner interprets plans and emits receipts.
;;; Invariant: adapter calls remain behind runtime-adapter functions.

(import :poo-flow/modules/workflow/control-plane/projection-syntax
        :core/utilities/algorithms
        :poo-flow/modules/workflow/control-plane/receipt
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/plan
        :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/policy
        :poo-flow/modules/workflow/control-plane/runtime-protocol
        :poo-flow/modules/workflow/control-plane/runtime-adapter
        :poo-flow/modules/workflow/control-plane/replay
        :poo-flow/modules/workflow/control-plane/runner-support/validation
        :poo-flow/modules/workflow/control-plane/runner-support/receipt
        :poo-flow/modules/workflow/control-plane/runner-support/adapter-dispatch)

(export make-run-result
        run-result?
        run-result-value
        run-result-receipt
        make-runner
        runner?
        runner-strategy
        runner-adapter
        runner-task-registry
        runner-flow-registry
        runner-plan
        runner-ready-frontier
        runner-ready-frontier-ids
        runner-validate
        runner-run
        runner-run-either
        runner-run-value-or-recover
        runner-run-replay-report)

;; : (-> Value Receipt RunResult)
(defstruct run-result (value receipt) transparent: #t)

;; : (-> Strategy RuntimeAdapter TaskFamilyRegistry FlowDeclarationRegistry RunnerState)
(defstruct runner-state (strategy adapter task-registry flow-registry)
  transparent: #t)

;;; Public runner construction keeps the two-argument control-plane API stable
;;; while allowing configured entrypoints to supply POO descriptor registries.
;; : (-> Strategy RuntimeAdapter [TaskFamilyRegistry] [FlowDeclarationRegistry] Runner)
(def (make-runner strategy adapter . registries)
  (make-runner-state strategy
                     adapter
                     (if (null? registries)
                       default-task-family-registry
                       (car registries))
                     (if (or (null? registries) (null? (cdr registries)))
                       default-flow-declaration-registry
                       (cadr registries))))

;; : (-> RunnerCandidate Boolean)
(def (runner? runner)
  (runner-state? runner))

;; : (-> Runner Strategy)
(def (runner-strategy runner)
  (runner-state-strategy runner))

;; : (-> Runner RuntimeAdapter)
(def (runner-adapter runner)
  (runner-state-adapter runner))

;; : (-> Runner TaskFamilyRegistry)
(def (runner-task-registry runner)
  (runner-state-task-registry runner))

;; : (-> Runner FlowDeclarationRegistry)
(def (runner-flow-registry runner)
  (runner-state-flow-registry runner))

;; : (-> Runner Flow ExecutionPlan)
(def (runner-plan runner flow)
  ((strategy-planner-for-flow-in
    (runner-strategy runner)
    (runner-flow-registry runner)
    flow)
   flow))

;;; Frontier queries follow the same runner boundary as execution: flow is
;;; lowered once, then strategy decides which graph facts are policy-visible.
;; : (-> Runner Flow [Id] [PlanNode])
(def (runner-ready-frontier runner flow completed-node-ids)
  (let ((strategy (runner-strategy runner)))
    (strategy-ready-frontier strategy
                             (runner-plan runner flow)
                             completed-node-ids)))

;;; Id-only frontier output is the adapter-friendly form; it avoids leaking
;;; task closures or Scheme plan-node payloads across runtime boundaries.
;; : (-> Runner Flow [Id] [Id])
(def (runner-ready-frontier-ids runner flow completed-node-ids)
  (let ((strategy (runner-strategy runner)))
    (strategy-ready-frontier-ids strategy
                                 (runner-plan runner flow)
                                 completed-node-ids)))

;; : (-> Runner Flow Boolean)
(def (runner-validate runner flow)
  (runner-validate-plan runner (runner-plan runner flow)))

;;; Replay reporting runs the normal interpreter first, then validates the
;;; emitted receipt against the same plan that drove execution.
;; : (-> Runner Flow Input ReplayReport)
(def (runner-run-replay-report runner flow input)
  (let* ((plan (runner-plan runner flow))
         (result (runner-run runner flow input)))
    (validate-replay-report plan (run-result-receipt result))))

;;; Boundary: validation is the only pre-run traversal over planned nodes.
;;; Invariant: each node is checked against both strategy and adapter support.
;; : (-> Runner ExecutionPlan Boolean)
(def (runner-validate-plan runner plan)
  (let ((strategy (runner-strategy runner))
        (adapter (runner-adapter runner))
        (task-registry (runner-task-registry runner)))
    (for-each (lambda (node) (validate-plan-node task-registry strategy adapter node))
              (execution-plan-nodes plan))
    #t))

;; : (-> Runner Policy)
(defpoo-core-receipt-projection
  runner-registry-policy (runner)
  (bindings ())
  (fields ((task-registry
            (task-family-registry-name (runner-task-registry runner)))
           (flow-registry
            (flow-declaration-registry-name (runner-flow-registry runner))))))

;; : (-> Runner Strategy [Id] Policy)
(def (runner-execution-policy-alist runner strategy frontier)
  (append (execution-policy->alist
           (strategy-execution-policy strategy frontier))
          (runner-registry-policy runner)))

;;; Execution returns both the final value and a root receipt that contains the
;;; child receipts produced by each planned step.
;; : (-> Runner Flow Input RunResult)
(def (runner-run runner flow input)
  (let ((strategy (runner-strategy runner)))
    (let ((plan (runner-plan runner flow)))
      (runner-validate-plan runner plan)
      (let* ((frontier-state
              (poo-flow-make-frontier-state
               (execution-plan-nodes plan)
               plan-node-id plan-node-ordinal plan-node-dependencies))
             (root-frontier
              (strategy-admit-ready-frontier-ids
               strategy
               (poo-flow-frontier-state-ready-ids frontier-state)))
             (result
              (run-plan-nodes
               runner plan strategy (execution-plan-nodes plan) input
               '() (poo-flow-make-value-index) frontier-state)))
        (let ((value (car result))
              (children (reverse (cdr result))))
          (make-run-result
           value
           (make-receipt (execution-plan-flow-name plan)
                         #f
                         'flow
                         #f
                         (strategy-name strategy)
                         (runner-execution-policy-alist runner strategy root-frontier)
                         'local
                         #f
                         input
                         value
                         'no-cache
                         root-frontier
                         'ok
                         #f
                         children)))))))

;;; Boundary:
;;; - Recovery handles both local thrown failures and adapter-failed receipts.
;;; - Successful runs return the normal run value.
;; : (-> Runner Flow Input FailureHandler Value)
(def (runner-run-value-or-recover runner flow input handler)
  (try-control-plane
   (lambda ()
     (let* ((result (runner-run runner flow input))
            (failed (first-failed-receipt (run-result-receipt result))))
       (if failed
         (handler failed)
         (run-result-value result))))
   handler))

;;; Runner-level try projection mirrors Funflow's =tryE= observable contract:
;;; local throws and failed adapter receipts become left values, while normal
;;; completion keeps the successful value on the right.
;; : (-> Runner Flow Input TryResult)
(def (runner-run-either runner flow input)
  (try-control-plane
   (lambda ()
     (let* ((result (runner-run runner flow input))
            (failed (first-failed-receipt (run-result-receipt result))))
       (if failed
         (make-try-left (receipt-error failed))
         (make-try-right (run-result-value result)))))
   make-try-left))

;;; Boundary: this recursive driver is the topology interpreter loop.
;;; Invariant: frontier state owns graph progress while the value index feeds
;;; dependency outputs into later DAG nodes.
;; : (-> Runner ExecutionPlan Strategy [PlanNode] Input [Receipt] HashTable FrontierState StepSequenceResult)
(def (run-plan-nodes runner plan strategy nodes input receipts value-index frontier-state)
  (if (null? nodes)
    (cons (plan-output-value plan value-index input) receipts)
    (let* ((node (car nodes))
           (frontier
            (strategy-admit-ready-frontier-ids
             strategy
             (poo-flow-frontier-state-ready-ids frontier-state)))
           (node-input (node-input-value node value-index input))
           (step-result (run-plan-node runner plan strategy node node-input frontier))
           (value (car step-result))
           (receipt (cdr step-result)))
      (poo-flow-value-index-put! value-index (plan-node-id node) value)
      (poo-flow-frontier-state-complete! frontier-state (plan-node-id node))
      (run-plan-nodes runner plan strategy (cdr nodes) input
                      (cons receipt receipts) value-index frontier-state))))

;;; Node dispatch stays shape-based: task nodes execute work, flow nodes wrap
;;; nested runs, and branch nodes join dependency values.
;; : (-> PlanNode Step Alist)
(defpoo-core-receipt-projection
  runner-unsupported-step-detail (node step)
  (bindings ())
  (fields ((node-id (plan-node-id node))
           (step step))))

;; : (-> Runner ExecutionPlan Strategy PlanNode Input [Id] StepResult)
(def (run-plan-node runner plan strategy node input frontier)
  (let ((step (plan-node-step node)))
    (cond
     ((task? step)
      (run-task runner plan strategy node step input frontier))
     ((flow? step)
      (let ((nested (runner-run runner step input)))
        (cons (run-result-value nested)
              (make-flow-step-receipt runner plan strategy node step input frontier nested))))
     ((try-step? step)
      (run-try-step runner plan strategy node step input frontier))
     ((kleisli-step? step)
      (run-kleisli-step runner plan strategy node step input frontier))
     ((branch-step? step)
      (cons input
            (make-branch-receipt runner plan strategy node step input frontier)))
     (else
      (raise-control-plane-failure
       'runner
       'unsupported-step
       "flow step is neither task nor flow"
       (runner-unsupported-step-detail node step))))))

;;; Flow nodes wrap nested receipts so top-level replay can still match each
;;; planned DAG node to one top-level child receipt.
;; : (-> Runner ExecutionPlan Strategy PlanNode Flow Input [Id] RunResult Receipt)
(def (make-flow-step-receipt runner plan strategy node flow input frontier nested)
  (make-receipt (execution-plan-flow-name plan)
                (flow-name flow)
                (plan-node-kind node)
                (plan-node-id node)
                (strategy-name strategy)
                (runner-execution-policy-alist runner strategy frontier)
                'local
                #f
                input
                (run-result-value nested)
                'no-cache
                frontier
                'ok
                #f
                (list (run-result-receipt nested))))

;;; Try nodes are local control-plane recovery points. They catch structured
;;; failures from the protected source and turn them into =try-left= values;
;;; successful runs become =try-right= values.
;; : (-> Runner ExecutionPlan Strategy PlanNode TryStep Input [Id] StepResult)
(def (run-try-step runner plan strategy node step input frontier)
  (let* ((projection (try-step-projection runner (try-step-source step) input))
         (value (car projection))
         (children (cdr projection)))
    (cons value
          (make-receipt (execution-plan-flow-name plan)
                        (try-step-name step)
                        'try
                        (plan-node-id node)
                        (strategy-name strategy)
                        (runner-execution-policy-alist runner strategy frontier)
                        'local
                        #f
                        input
                        value
                        'no-cache
                        frontier
                        'ok
                        #f
                        children))))

;; : (-> Runner ExecutionPlan Strategy PlanNode KleisliStep Input Value [Id] Receipt StepResult)
(def (run-kleisli-source-failure-result runner
                                       plan
                                       strategy
                                       node
                                       step
                                       input
                                       source-value
                                       frontier
                                       source-receipt
                                       source-failed)
  (cons source-value
        (make-kleisli-receipt runner
                              plan
                              strategy
                              node
                              step
                              input
                              source-value
                              frontier
                              'failed
                              (receipt-error source-failed)
                              (list source-receipt))))

;;; Boundary: run kleisli bound flow result is the policy-visible edge for core behavior, keeping validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Runner ExecutionPlan Strategy PlanNode KleisliStep Input Value [Id] Receipt Flow StepResult)
(def (run-kleisli-bound-flow-result runner
                                   plan
                                   strategy
                                   node
                                   step
                                   input
                                   source-value
                                   frontier
                                   source-receipt
                                   bound-flow)
  (let* ((bound-result (runner-run runner bound-flow source-value))
         (bound-value (run-result-value bound-result))
         (bound-receipt (run-result-receipt bound-result))
         (bound-failed (first-failed-receipt bound-receipt)))
    (cons bound-value
          (make-kleisli-receipt runner
                                plan
                                strategy
                                node
                                step
                                input
                                bound-value
                                frontier
                                (if bound-failed 'failed 'ok)
                                (if bound-failed
                                  (receipt-error bound-failed)
                                  #f)
                                (list source-receipt bound-receipt)))))

;; : (-> PlanNode KleisliStep Value Value Failure)
(defpoo-core-receipt-projection
  invalid-kleisli-binder-result-detail (node step source-value bound-flow)
  (bindings ())
  (fields ((node-id (plan-node-id node))
           (step-name (kleisli-step-name step))
           (source-value source-value)
           (binder-result bound-flow))))

;; : (-> PlanNode KleisliStep Value Value Failure)
(def (raise-invalid-kleisli-binder-result node step source-value bound-flow)
  (raise-control-plane-failure
   'runner
   'invalid-kleisli-binder-result
   "kleisli binder did not return a flow"
   (invalid-kleisli-binder-result-detail
    node
    step
    source-value
    bound-flow)))

;;; Boundary: run kleisli bound result is the policy-visible edge for core behavior, keeping validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Runner ExecutionPlan Strategy PlanNode KleisliStep Input Value [Id] Receipt StepResult)
(def (run-kleisli-bound-result runner
                              plan
                              strategy
                              node
                              step
                              input
                              source-value
                              frontier
                              source-receipt)
  (let (bound-flow ((kleisli-step-binder step) source-value))
    (if (flow? bound-flow)
      (run-kleisli-bound-flow-result runner
                                    plan
                                    strategy
                                    node
                                    step
                                    input
                                    source-value
                                    frontier
                                    source-receipt
                                    bound-flow)
      (raise-invalid-kleisli-binder-result node step source-value bound-flow))))

;;; Kleisli nodes are dynamic composition points: the source flow runs first,
;;; then its value selects the next flow through the binder procedure.
;; : (-> Runner ExecutionPlan Strategy PlanNode KleisliStep Input [Id] StepResult)
(def (run-kleisli-step runner plan strategy node step input frontier)
  (let* ((source-result (runner-run runner (kleisli-step-source step) input))
         (source-value (run-result-value source-result))
         (source-receipt (run-result-receipt source-result))
         (source-failed (first-failed-receipt source-receipt)))
    (if source-failed
      (run-kleisli-source-failure-result runner
                                        plan
                                        strategy
                                        node
                                        step
                                        input
                                        source-value
                                        frontier
                                        source-receipt
                                        source-failed)
      (run-kleisli-bound-result runner
                               plan
                               strategy
                               node
                               step
                               input
                               source-value
                               frontier
                               source-receipt))))

;; : (-> Runner ExecutionPlan Strategy PlanNode KleisliStep Input Value [Id] Symbol Error [Receipt] Receipt)
(def (make-kleisli-receipt runner plan strategy node step input output frontier status error children)
  (make-receipt (execution-plan-flow-name plan)
                (kleisli-step-name step)
                'kleisli
                (plan-node-id node)
                (strategy-name strategy)
                (runner-execution-policy-alist runner strategy frontier)
                'local
                #f
                input
                output
                'no-cache
                frontier
                status
                error
                children))

;;; Projection keeps the protected flow's receipt tree when execution reached
;;; the runner, while local thrown failures still become receipt-free lefts.
;; : (-> Runner Flow Input (Pair TryResult [Receipt]))
(def (try-step-projection runner source input)
  (try-control-plane
   (lambda ()
     (let* ((nested (runner-run runner source input))
            (receipt (run-result-receipt nested))
            (failed (first-failed-receipt receipt)))
       (cons (if failed
               (make-try-left (receipt-error failed))
               (make-try-right (run-result-value nested)))
             (list receipt))))
   (lambda (failure)
     (cons (make-try-left failure) '()))))

;;; Branch join nodes are local control-plane joins: their input is the list of
;;; dependency values produced by branch arms.
;; : (-> Runner ExecutionPlan Strategy PlanNode BranchStep Value [Id] Receipt)
(def (make-branch-receipt runner plan strategy node branch input frontier)
  (make-receipt (execution-plan-flow-name plan)
                (branch-step-name branch)
                'branch
                (plan-node-id node)
                (strategy-name strategy)
                (runner-execution-policy-alist runner strategy frontier)
                'local
                #f
                input
                input
                'no-cache
                frontier
                'ok
                #f
                '()))

;; : (-> [PlanNode] [Id])
(def (runner-plan-node-ids nodes)
  (map plan-node-id nodes))

;; : (-> ExecutionPlan HashTable Value Value)
(def (plan-output-value plan values default-input)
  (let ((terminal-values (node-values (runner-plan-node-ids
                                       (execution-plan-terminal-nodes plan))
                                      values)))
    (cond
     ((null? terminal-values) default-input)
     ((null? (cdr terminal-values)) (car terminal-values))
     (else terminal-values))))

;;; Node input selection follows dependency cardinality: roots receive the
;;; original input, one dependency passes a scalar value, and joins receive the
;;; ordered dependency value list.
;; : (-> PlanNode HashTable Value Value)
(def (node-input-value node values default-input)
  (let ((dependencies (plan-node-dependencies node)))
    (cond
     ((null? dependencies) default-input)
     ((null? (cdr dependencies)) (value-for-node-id (car dependencies) values))
     (else (node-values dependencies values)))))

;;; Dependency ids are already in plan order, so this projection preserves the
;;; branch-left and branch-right ordering expected by join receipts.
;; : (-> [Id] HashTable [Value])
(def (node-values ids values)
  (map (lambda (id) (value-for-node-id id values))
       ids))

;;; Missing dependency values indicate a malformed plan order rather than an
;;; application failure, so the runner raises a control-plane error.
;; : (-> Id Alist)
(defpoo-core-receipt-projection
  missing-dependency-value-detail (id)
  (bindings ())
  (fields ((node-id id))))

;; : (-> Id HashTable Value)
(def (value-for-node-id id value-index)
  (let-values (((present? value)
                (poo-flow-value-index-ref value-index id)))
    (if present?
      value
      (raise-control-plane-failure
       'runner
       'missing-dependency-value
       "missing dependency value"
       (missing-dependency-value-detail id)))))

;;; Boundary: local tasks run in-process, while routed tasks cross the adapter.
;;; Invariant: both branches return the same value/receipt pair shape.
;; : (-> Runner ExecutionPlan Strategy PlanNode Task Input [Id] StepResult)
(defpoo-core-receipt-projection
  unsupported-task-kind-detail (task)
  (bindings ())
  (fields ((task-kind (task-kind task)))))

;; : (-> Runner ExecutionPlan Strategy PlanNode Task Input [Id] StepResult)
(def (run-task runner plan strategy node task input frontier)
  (let ((task-registry (runner-task-registry runner)))
    (cond
     ((strategy-can-run-locally-in strategy task-registry task)
      (let* ((policy (runner-execution-policy-alist runner strategy frontier))
             (value ((task-executor task) input))
             (cache (strategy-cache-decision strategy task input value)))
        (cons value
              (make-receipt (execution-plan-flow-name plan)
                            (task-name task)
                            (task-kind task)
                            (plan-node-id node)
                            (strategy-name strategy)
                            policy
                            'local
                            #f
                            input
                            value
                            cache
                            frontier
                            'ok
                            #f
                            '()))))
     ((task-adapter-routed?-in task-registry task)
      (let* ((policy (runner-execution-policy-alist runner strategy frontier))
             (request (task-adapter-request task
                                             input
                                             (execution-plan-flow-name plan)
                                             (plan-node-id node)
                                             frontier
                                             (strategy-name strategy)
                                             policy))
             (adapter-result (adapter-result-for-task task-registry (runner-adapter runner) task request))
             (cache (adapter-cache-decision task-registry strategy task input adapter-result))
             (failure (adapter-result-failure (runner-adapter runner) adapter-result)))
        (cons adapter-result
              (make-receipt (execution-plan-flow-name plan)
                            (task-name task)
                            (task-kind task)
                            (plan-node-id node)
                            (strategy-name strategy)
                            (execution-request-policy request)
                            (runtime-adapter-name (runner-adapter runner))
                            (adapter-result-request-id adapter-result)
                            input
                            adapter-result
                            cache
                            frontier
                            (adapter-receipt-status failure adapter-result)
                            failure
                            '()))))
     (else
      (raise-control-plane-failure
       'runner
       'unsupported-task-kind
       "unsupported task kind"
       (unsupported-task-kind-detail task))))))
