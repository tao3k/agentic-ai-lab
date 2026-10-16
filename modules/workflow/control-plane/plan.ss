;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: planning produces inspectable control-plane artifacts.
;;; Invariant: execution stays in the runner/runtime-adapter layer.

(import :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/task)

(export make-plan-node
        plan-node?
        plan-node-id
        plan-node-ordinal
        plan-node-step
        plan-node-kind
        plan-node-name
        plan-node-dependencies
        flow-dag-receipt-kind
        +flow-dag-runtime-manifest-schema+
        make-execution-plan
        execution-plan?
        execution-plan-flow-name
        execution-plan-nodes
        execution-plan-input-contract
        execution-plan-output-contract
        flow->linear-plan
        execution-plan-node-ids
        execution-plan-dependency-edges
        execution-plan-root-nodes
        execution-plan-terminal-nodes
        execution-plan-root-node-ids
        execution-plan-terminal-node-ids
        execution-plan-ready-nodes
        execution-plan-ready-node-ids
        plan-node-root?
        plan-node-depends-on?
        plan-node-ready?
        plan-node->dag-entry
        execution-plan->dag-receipt
        flow->dag-receipt
        execution-plan->dag-runtime-manifest
        flow->dag-runtime-manifest
        plan-empty?
        plan-node-count)

;;; A node keeps both the original step and normalized metadata; dependencies
;;; expose a DAG-ready plan without moving execution into Scheme.
;; : (-> Symbol Nat Step Symbol Symbol [Symbol] PlanNode)
(defstruct plan-node
  (id
   ordinal
   step
   kind
   name
   dependencies)
  transparent: #t)

;;; The plan mirrors the flow boundary contracts while exposing a flat node
;;; stream for strategy selection and audit receipts.
;; : (-> Symbol [PlanNode] Contract Contract ExecutionPlan)
(defstruct execution-plan
  (flow-name
   nodes
   input-contract
   output-contract)
  transparent: #t)

;;; DAG receipts are report-only graph projections. They are not run receipts,
;;; and they must not imply scheduling, adapter submission, or state writes.
;; : (-> Unit FlowDagReceiptKind)
(def flow-dag-receipt-kind
  "poo-flow.core.flow-dag-receipt.v1")

;;; Boundary: runtime manifest schema is discovery metadata only.
;;; Intent: Marlin can discover DAG receipt shape without guessing entrypoints.
;; : (-> Unit FlowDagRuntimeManifestSchema)
(def +flow-dag-runtime-manifest-schema+
  'poo-flow.core.flow-dag-runtime-manifest.v1)

;; : (-> Flow ExecutionPlan)
(def (flow->linear-plan flow)
  (make-execution-plan (flow-name flow)
                       (steps->plan-nodes (flow-name flow) (flow-steps flow))
                       (flow-input-contract flow)
                       (flow-output-contract flow)))

;;; Ordinals and predecessor pairs are data, not loop state: together they
;;; preserve order while exposing dependency edges for later schedulers.
;; : (-> Symbol [Step] [PlanNode])
(def (steps->plan-nodes flow-name steps)
  (let ((lowered (lower-steps flow-name steps '() 0)))
    (car lowered)))

;;; Boundary: step name is the policy-visible edge for core behavior, keeping
;;; validation, lookup, or projection responsibilities centralized for callers.
;;; Boundary: step kind is the policy-visible edge for core behavior, keeping
;;; validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Symbol Nat Step [Id] PlanNode)
(def (step->plan-node flow-name ordinal step dependencies)
  (let* ((kind (step-kind step))
         (name (step-name step))
         (id (plan-node-id-for flow-name ordinal step)))
    (make-plan-node id ordinal step kind name dependencies)))

;;; Intent: lower declarations into a topologically sorted node stream.
;;; The returned triple is nodes, current terminal ids, and the next ordinal;
;;; branch lowering uses the terminal ids to create fan-out and join edges.
;; : (-> Symbol [Step] [Id] Nat LoweredSteps)
(def (lower-steps flow-name steps previous-terminal-ids ordinal)
  (if (null? steps)
    (list '() previous-terminal-ids ordinal)
    (let* ((lowered-step (lower-step flow-name
                                     (car steps)
                                     previous-terminal-ids
                                     ordinal))
           (step-nodes (car lowered-step))
           (step-terminals (cadr lowered-step))
           (next-ordinal (caddr lowered-step))
           (lowered-rest (lower-steps flow-name
                                      (cdr steps)
                                      step-terminals
                                      next-ordinal)))
      (list (append step-nodes (car lowered-rest))
            (cadr lowered-rest)
            (caddr lowered-rest)))))

;;; Boundary: lower step is the policy-visible edge for core behavior, keeping
;;; validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Symbol Step [Id] Nat LoweredStep)
(def (lower-step flow-name step previous-terminal-ids ordinal)
  (if (branch-step? step)
    (lower-branch-step flow-name step previous-terminal-ids ordinal)
    (lower-linear-step flow-name step previous-terminal-ids ordinal)))

;;; A normal step becomes one node; branch-specific fan-out is handled by
;;; lower-branch-step so the linear case keeps the old node id shape.
;; : (-> Symbol Step [Id] Nat LoweredStep)
(def (lower-linear-step flow-name step previous-terminal-ids ordinal)
  (let ((node (step->plan-node flow-name ordinal step previous-terminal-ids)))
    (list (list node)
          (list (plan-node-id node))
          (+ ordinal 1))))

;;; Branch lowering creates two parallel flow nodes with the same prerequisites
;;; and one join node that depends on both branch results.
;; : (-> Symbol BranchStep [Id] Nat LoweredStep)
(def (lower-branch-step flow-name branch previous-terminal-ids ordinal)
  (let* ((left-flow (branch-step-left branch))
         (right-flow (branch-step-right branch))
         (left-node (branch-arm-node flow-name
                                     ordinal
                                     'branch-left
                                     left-flow
                                     previous-terminal-ids))
         (right-node (branch-arm-node flow-name
                                      (+ ordinal 1)
                                      'branch-right
                                      right-flow
                                      previous-terminal-ids))
         (join-node (make-plan-node (branch-join-node-id flow-name
                                                         (+ ordinal 2)
                                                         branch)
                                    (+ ordinal 2)
                                    branch
                                    'branch
                                    (branch-step-name branch)
                                    (list (plan-node-id left-node)
                                          (plan-node-id right-node)))))
    (list (list left-node right-node join-node)
          (list (plan-node-id join-node))
          (+ ordinal 3))))

;; : (-> Symbol Nat Symbol Flow [Id] PlanNode)
(def (branch-arm-node plan-flow-name ordinal kind flow dependencies)
  (make-plan-node (list 'node plan-flow-name ordinal kind (flow-name flow))
                  ordinal
                  flow
                  kind
                  (flow-name flow)
                  dependencies))

;; : (-> Symbol Nat BranchStep Id)
(def (branch-join-node-id plan-flow-name ordinal branch)
  (list 'node plan-flow-name ordinal 'branch (branch-step-name branch)))

;; : (-> Symbol Nat Step Symbol)
(def (plan-node-id-for flow-name ordinal step)
  (list 'node flow-name ordinal (step-kind step) (step-name step)))

;;; Graph inspection is deliberately read-only: strategies and receipts can
;;; reason about topology without smuggling scheduling behavior into planning.
;; : (-> [PlanNode] [Id] [Id])
(def (plan-nodes->ids/rev nodes ids-rev)
  (if (null? nodes)
    ids-rev
    (plan-nodes->ids/rev
     (cdr nodes)
     (cons (plan-node-id (car nodes)) ids-rev))))

;; : (-> [PlanNode] [Id])
(def (plan-nodes->ids nodes)
  (reverse (plan-nodes->ids/rev nodes '())))

;; : (-> ExecutionPlan [Id])
(def (execution-plan-node-ids plan)
  (plan-nodes->ids (execution-plan-nodes plan)))

;;; Edges are emitted as prerequisite -> dependent pairs, matching the order a
;;; scheduler or Rust adapter needs for readiness and receipt correlation.
;; : (-> ExecutionPlan [[Id Id]])
(def (execution-plan-dependency-edges plan)
  (nodes->dependency-edges (execution-plan-nodes plan)))

;;; Root and terminal frontiers give later DAG schedulers stable boundary
;;; facts while the current runner continues to execute the linear node stream.
;; : (-> ExecutionPlan [PlanNode])
(def (execution-plan-root-nodes plan)
  (select-plan-nodes plan-node-root? (execution-plan-nodes plan)))

;; : (-> ExecutionPlan [Id])
;;; Root ids are a compact receipt field for consumers that only need DAG
;;; frontier facts, not the full plan-node payload.
;; : (-> ExecutionPlan [Id])
(def (execution-plan-root-node-ids plan)
  (plan-nodes->ids (execution-plan-root-nodes plan)))

;;; Intent: compute the sink frontier by filtering plan nodes against the
;;; dependency-edge table.
;;; The one-argument predicate receives each candidate node and checks whether
;;; its id appears as a prerequisite endpoint.
;;; Keeping this as a frontier selection preserves DAG shape without mixing
;;; edge discovery and terminal-node policy in one manual loop.
;; : (-> ExecutionPlan [PlanNode])
(def (execution-plan-terminal-nodes plan)
  (let ((edges (execution-plan-dependency-edges plan)))
    (select-plan-nodes
     (lambda (node)
       (not (id-has-dependent? (plan-node-id node) edges)))
     (execution-plan-nodes plan))))

;; : (-> ExecutionPlan [Id])
;;; Terminal ids identify the sink frontier for handoff receipts and future
;;; schedulers without implying that Scheme will execute those sinks.
;; : (-> ExecutionPlan [Id])
(def (execution-plan-terminal-node-ids plan)
  (plan-nodes->ids (execution-plan-terminal-nodes plan)))

;;; Intent: compute the runnable frontier from completed node ids without
;;; changing the plan's original node order.
;;; The one-argument predicate tests each candidate node against a completed-id
;;; set, so future schedulers can choose from ready nodes without re-parsing
;;; flow steps or task internals.
;; : (-> ExecutionPlan [Id] [PlanNode])
(def (execution-plan-ready-nodes plan completed-node-ids)
  (select-plan-nodes
   (lambda (node)
     (plan-node-ready? node completed-node-ids))
   (execution-plan-nodes plan)))

;;; Intent: expose a lightweight frontier shape for strategy receipts and
;;; adapter requests that do not need the full plan-node payload.
;; : (-> ExecutionPlan [Id] [Id])
(def (execution-plan-ready-node-ids plan completed-node-ids)
  (plan-nodes->ids (execution-plan-ready-nodes plan completed-node-ids)))

;;; Dependency predicates stay at the node/id level so tests and adapters can
;;; audit graph shape without depending on task internals.
;; : (-> PlanNode Boolean)
(def (plan-node-root? node)
  (null? (plan-node-dependencies node)))

;;; Dependency checks compare normalized node ids instead of step names, so
;;; nested flows and repeated task names remain unambiguous to adapters.
;; : (-> PlanNode Id Boolean)
(def (plan-node-depends-on? node dependency-id)
  (id-member? dependency-id (plan-node-dependencies node)))

;;; Readiness has two independent guards: the node itself must not already be
;;; complete, and every declared dependency must be present in the completed
;;; id set.
;; : (-> PlanNode [Id] Boolean)
(def (plan-node-ready? node completed-node-ids)
  (and (not (id-member? (plan-node-id node) completed-node-ids))
       (ids-subset? (plan-node-dependencies node) completed-node-ids)))

;;; Edge expansion is factored from the public API to keep future non-linear
;;; plan constructors responsible only for node dependencies, not edge shape.
;; : (-> [PlanNode] [[Id Id]])
(def (nodes->dependency-edges nodes)
  (if (null? nodes)
    '()
    (append (node->dependency-edges (car nodes))
            (nodes->dependency-edges (cdr nodes)))))

;;; Intent: project each dependency id into a prerequisite-to-dependent edge
;;; owned by this node while keeping dependency order stable.
;; : (-> [Id] Id [[Id Id]] [[Id Id]])
(def (dependency-ids->edges/rev dependency-ids dependent-id edges-rev)
  (if (null? dependency-ids)
    edges-rev
    (dependency-ids->edges/rev
     (cdr dependency-ids)
     dependent-id
     (cons (list (car dependency-ids) dependent-id) edges-rev))))

;; : (-> PlanNode [[Id Id]])
(def (node->dependency-edges node)
  (reverse
   (dependency-ids->edges/rev
    (plan-node-dependencies node)
    (plan-node-id node)
    '())))

;;; Node entries are the per-node part of the strategy-facing DAG receipt.
;;; They intentionally omit the raw step payload so external consumers inspect
;;; topology without receiving executable Scheme procedures or task internals.
;; : (-> PlanNode Alist)
(defpoo-core-receipt-projection
  plan-node->dag-entry (node)
  (bindings ())
  (fields ((id (plan-node-id node))
           (ordinal (plan-node-ordinal node))
           (kind (plan-node-kind node))
           (name (plan-node-name node))
           (dependencies (plan-node-dependencies node)))))

;; : (-> [PlanNode] [Alist] [Alist])
(def (plan-nodes->dag-entries/rev nodes entries-rev)
  (if (null? nodes)
    entries-rev
    (plan-nodes->dag-entries/rev
     (cdr nodes)
     (cons (plan-node->dag-entry (car nodes)) entries-rev))))

;; : (-> [PlanNode] [Alist])
(def (plan-nodes->dag-entries nodes)
  (reverse (plan-nodes->dag-entries/rev nodes '())))

;;; The DAG receipt is a durable planning projection for Marlin and strategy
;;; code. It reports graph shape only; runtime execution remains behind runner
;;; and adapter layers.
;; : (-> ExecutionPlan Alist)
(defpoo-core-receipt-projection
  execution-plan->dag-receipt (plan)
  (bindings ())
  (fields ((kind flow-dag-receipt-kind)
           (flow (execution-plan-flow-name plan))
           (input-contract (execution-plan-input-contract plan))
           (output-contract (execution-plan-output-contract plan))
           (node-count (plan-node-count plan))
           (nodes (plan-nodes->dag-entries (execution-plan-nodes plan)))
           (node-ids (execution-plan-node-ids plan))
           (dependency-edges (execution-plan-dependency-edges plan))
           (root-node-ids (execution-plan-root-node-ids plan))
           (terminal-node-ids (execution-plan-terminal-node-ids plan))
           (strategy-facing #t)
           (report-only #t)
           (descriptor-realized? #f)
           (runtime-executed #f))))

;;; Flow projection is the ergonomic entrypoint for functional-kernel arrows:
;;; callers hand it a declaration and receive graph evidence, not execution.
;; : (-> Flow Alist)
(def (flow->dag-receipt flow)
  (execution-plan->dag-receipt (flow->linear-plan flow)))

;;; Runtime manifest projection is the discovery surface for Marlin-facing
;;; consumers. It wraps the report-only DAG receipt and names the Scheme
;;; entrypoints, but it never schedules nodes or submits adapter requests.
;; : (-> ExecutionPlan RequestId Alist)
(defpoo-core-receipt-projection
  execution-plan->dag-runtime-manifest* (plan request-id)
  (bindings ((receipt (execution-plan->dag-receipt plan))))
  (fields ((schema +flow-dag-runtime-manifest-schema+)
           (kind 'flow-dag-runtime-manifest)
           (bridge 'runtime-manifest)
           (producer 'poo-flow)
           (consumer 'marlin-agent-core)
           (operation 'inspect-flow-dag)
           (request-id request-id)
           (flow (execution-plan-flow-name plan))
           (receipt-schema flow-dag-receipt-kind)
           (dag-receipt receipt)
           (node-count (plan-node-count plan))
           (node-ids (execution-plan-node-ids plan))
           (dependency-edges (execution-plan-dependency-edges plan))
           (root-node-ids (execution-plan-root-node-ids plan))
           (terminal-node-ids (execution-plan-terminal-node-ids plan))
           (entrypoints
            '((flow . flow->dag-runtime-manifest)
              (execution-plan . execution-plan->dag-runtime-manifest)
              (receipt . flow->dag-receipt)))
           (runtime-boundary
            '((local-execution . validation-only)
              (production-execution . marlin-agent-core)))
           (control-owner 'gerbil)
           (execution-owner 'marlin-agent-core)
           (report-only #t)
           (descriptor-realized? #f)
           (runtime-executed #f))))

;; : (-> ExecutionPlan [RequestId] Alist)
(def (execution-plan->dag-runtime-manifest plan . maybe-request-id)
  (execution-plan->dag-runtime-manifest*
   plan
   (if (null? maybe-request-id)
     #f
     (car maybe-request-id))))

;;; Flow projection is the public ergonomic discovery entrypoint. It lowers the
;;; flow to a plan first so Marlin receives the same manifest shape whether the
;;; caller starts from a flow declaration or an already planned graph.
;; : (-> Flow [RequestId] Alist)
(def (flow->dag-runtime-manifest flow . maybe-request-id)
  (let ((plan (flow->linear-plan flow)))
    (if (null? maybe-request-id)
      (execution-plan->dag-runtime-manifest plan)
      (execution-plan->dag-runtime-manifest plan (car maybe-request-id)))))

;;; Boundary: select plan nodes is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Predicate [PlanNode] [PlanNode])
(def (select-plan-nodes predicate nodes)
  (cond
   ((null? nodes) '())
   ((predicate (car nodes))
    (cons (car nodes)
          (select-plan-nodes predicate (cdr nodes))))
   (else
    (select-plan-nodes predicate (cdr nodes)))))

;;; Boundary: id has dependent predicate is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Id [[Id Id]] Boolean)
(def (id-has-dependent? id edges)
  (cond
   ((null? edges) #f)
   ((equal? id (car (car edges))) #t)
   (else (id-has-dependent? id (cdr edges)))))

;;; Boundary: id member predicate is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Id [Id] Boolean)
(def (id-member? id ids)
  (cond
   ((null? ids) #f)
   ((equal? id (car ids)) #t)
   (else (id-member? id (cdr ids)))))

;;; Boundary: ids subset predicate is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Id] [Id] Boolean)
(def (ids-subset? candidate-ids available-ids)
  (cond
   ((null? candidate-ids) #t)
   ((id-member? (car candidate-ids) available-ids)
    (ids-subset? (cdr candidate-ids) available-ids))
   (else #f)))

;;; Boundary: step kind is the policy-visible edge for core behavior, keeping
;;; validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Step Symbol)
(def (step-kind step)
  (cond
   ((task? step) (task-kind step))
   ((flow? step) 'flow)
   ((branch-step? step) 'branch)
   ((try-step? step) 'try)
   ((kleisli-step? step) 'kleisli)
   (else (error "flow step is neither task nor flow" step))))

;;; Boundary: step name is the policy-visible edge for core behavior, keeping
;;; validation, lookup, or projection responsibilities centralized for callers.
;; : (-> Step Symbol)
(def (step-name step)
  (cond
   ((task? step) (task-name step))
   ((flow? step) (flow-name step))
   ((branch-step? step) (branch-step-name step))
   ((try-step? step) (try-step-name step))
   ((kleisli-step? step) (kleisli-step-name step))
   (else (error "flow step is neither task nor flow" step))))

;; : (-> ExecutionPlan Boolean)
(def (plan-empty? plan)
  (null? (execution-plan-nodes plan)))

;; : (-> ExecutionPlan Nat)
(def (plan-node-count plan)
  (length (execution-plan-nodes plan)))
