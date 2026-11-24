;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow module configuration belongs to the Funflow module owner.
;;; Invariant: this file only declares maintained Funflow module rows.

(import (only-in :clan/poo/object .ref object<-alist)
        :tao3k/yuanxu/utilities/final-projection-syntax
        (only-in :tao3k/agentic-ai-lab/modules/funflow/check-funs
                 yuanxu-cicd-alist-ref
                 yuanxu-cicd-symbol-member?)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/check-objects
                 yuanxu-cicd-check-map-name
                 yuanxu-cicd-check-map?)
        :tao3k/agentic-ai-lab/modules/funflow/config-prototypes
        :tao3k/agentic-ai-lab/modules/funflow/dependency-graph)

(export yuanxu-funflow-cicd-default-payload
        +yuanxu-funflow-workflow-agreement-contract+
        funflow-check
        funflow-pipeline
        yuanxu-funflow-poo-check?
        yuanxu-funflow-poo-pipeline?
        yuanxu-funflow-poo-check->cicd-check
        yuanxu-funflow-poo-pipeline->check-map
        funflow-dag-edge
        funflow-composition-step
        funflow-functional-dag
        funflow-normalized-flow
        funflow-plan
        yuanxu-funflow-dag-edge
        yuanxu-funflow-dag-edge?
        yuanxu-funflow-dag-edge->alist
        yuanxu-funflow-composition-step
        yuanxu-funflow-composition-step?
        yuanxu-funflow-composition-step->alist
        yuanxu-funflow-functional-dag?
        yuanxu-funflow-functional-dag->alist
        yuanxu-funflow-normalized-flow?
        yuanxu-funflow-normalized-flow->alist
        yuanxu-funflow-plan?
        yuanxu-funflow-plan->alist
        yuanxu-funflow-plan->runtime-projection
        yuanxu-funflow-check-map->functional-dag
        yuanxu-funflow-check-map->normalized-flow
        yuanxu-funflow-normalized-flow->plan
        yuanxu-funflow-check-map->plan
        yuanxu-funflow-poo-pipeline->functional-dag
        yuanxu-funflow-poo-pipeline->normalized-flow
        yuanxu-funflow-poo-pipeline->plan
        yuanxu-funflow-workflow-ref?
        yuanxu-funflow-workflow-agreement
)

;;; The CI/CD payload is a Funflow feature, not a new top-level category. It is
;;; inspectable module data; adapters such as GitHub, Docker, or Nix stay out.
;; : UserModuleFlagEntry
(import (only-in "config-adapter.ss"
                 yuanxu-funflow-require
                 yuanxu-funflow-poo-check->cicd-check
                 yuanxu-funflow-poo-pipeline->check-map))

(def yuanxu-funflow-cicd-default-payload
  '(+cicd
    (checks +parallel +typed-receipts)
    (artifacts +export)
    (release +manual-gate)
    (webhook +server)
    (runtime +manifest-handoff)))

;;; Workflow agreement is Funflow-owned vocabulary. Loop engines can reference
;;; these refs, but the validity of a Funflow workflow stays with this module.
;; : Symbol
(def +yuanxu-funflow-workflow-agreement-contract+
  'yuanxu.funflow.workflow-agreement.v1)

;; : (-> Symbol Boolean)
(def (yuanxu-funflow-workflow-ref? workflow-ref)
  (or (eq? workflow-ref 'funflow)
      (eq? workflow-ref 'funflow-cicd)))

;;; Boundary: funflow check map names is the policy-visible edge for policy
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [YuanxuCicdCheckMap] [Symbol])
(def (yuanxu-funflow-check-map-names check-maps)
  (cond
   ((null? check-maps) '())
   (else
    (cons (yuanxu-cicd-check-map-name (car check-maps))
          (yuanxu-funflow-check-map-names (cdr check-maps))))))

;;; `funflow-cicd` requires at least one declared pipeline/check-map. Plain
;;; non-Funflow refs remain valid but explicitly outside Funflow ownership.
;; : (-> Symbol [YuanxuCicdCheckMap] [Alist])
(def (yuanxu-funflow-workflow-agreement-diagnostics workflow-ref check-maps)
  (cond
   ((and (eq? workflow-ref 'funflow-cicd)
         (null? check-maps))
    (list
     (yuanxu-product-field-rows
      (field 'workflow-ref)
      (code 'missing-funflow-workflow-pipeline)
      (workflow-ref workflow-ref))))
   (else '())))

;; : (-> [YuanxuCicdCheckMap] Alist)
(def (yuanxu-funflow-workflow-agreement-summary check-maps)
  (yuanxu-product-field-rows
   (pipeline-count (length check-maps))
   (pipeline-names (map yuanxu-cicd-check-map-name check-maps))
   (functional-dag-rows
    (map (lambda (check-map)
           (yuanxu-funflow-functional-dag->alist
            (yuanxu-funflow-check-map->functional-dag check-map)))
         check-maps))))

;;; The agreement is report-only data that lets loop-engine handoff receipts
;;; prove whether a workflow ref is backed by a Funflow-owned pipeline.
;; : (-> Symbol [YuanxuCicdCheckMap] Alist)
(def (yuanxu-funflow-workflow-agreement workflow-ref check-maps)
  (let* ((diagnostics
          (yuanxu-funflow-workflow-agreement-diagnostics
           workflow-ref
           check-maps))
         (summary
          (yuanxu-funflow-workflow-agreement-summary check-maps))
         (functional-dag-rows
          (yuanxu-cicd-alist-ref summary 'functional-dag-rows '())))
    (yuanxu-product-field-rows
     (kind 'funflow-workflow-agreement)
     (contract +yuanxu-funflow-workflow-agreement-contract+)
     (workflow-ref workflow-ref)
     (funflow-owned? (yuanxu-funflow-workflow-ref? workflow-ref))
     (pipeline-count
      (yuanxu-cicd-alist-ref summary 'pipeline-count 0))
     (pipeline-names
      (yuanxu-cicd-alist-ref summary 'pipeline-names '()))
     (functional-dag-count (length functional-dag-rows))
     (functional-dags functional-dag-rows)
     (diagnostic-count (length diagnostics))
     (diagnostics diagnostics)
     (valid? (null? diagnostics))
     (runtime-owner "marlin-agent-core")
     (runtime-executed #f))))

;;; POO check and pipeline objects stay shallow: Funflow owns the public
;;; prototype surface, while sandbox profile refs and runtime descriptors remain
;;; unresolved until later module/object validation.
;; : (forall (a) (-> String Boolean a Void))
;;; Funflow `:needs` names other checks in the same pipeline. Object/profile
;;; inheritance stays in `:inherits` so the two extension axes do not blur.
;; : (-> [FunflowPipelineDependencyRefCandidate] Boolean)
;;; Boundary: funflow optional metadata is the policy-visible edge for policy
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (forall (a) (-> Symbol a [Pair] [Pair]))
;;; Boundary: funflow list metadata is the policy-visible edge for policy
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol List [Pair] [Pair])
;; : (-> Symbol Symbol [Alist] YuanxuFunflowDagEdge)
(def (yuanxu-funflow-dag-edge from to . maybe-metadata)
  (yuanxu-funflow-require "funflow DAG edge from must be a symbol"
                            (symbol? from)
                            from)
  (yuanxu-funflow-require "funflow DAG edge to must be a symbol"
                            (symbol? to)
                            to)
  (object<-alist
   (list
    (cons 'kind +yuanxu-funflow-dag-edge-prototype-kind+)
    (cons 'from from)
    (cons 'to to)
    (cons 'composition-style 'kleisli)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata)))
    (cons 'runtime-executed #f))))

;; : (-> Symbol MaybeSymbol MaybeSymbol MaybeSymbol [Alist] YuanxuFunflowCompositionStep)
(def (yuanxu-funflow-composition-step step-kind check-name from to . maybe-metadata)
  (yuanxu-funflow-require "funflow composition step kind must be a symbol"
                            (symbol? step-kind)
                            step-kind)
  (yuanxu-funflow-require "funflow composition step check-name must be a symbol or #f"
                            (or (not check-name) (symbol? check-name))
                            check-name)
  (yuanxu-funflow-require "funflow composition step from must be a symbol or #f"
                            (or (not from) (symbol? from))
                            from)
  (yuanxu-funflow-require "funflow composition step to must be a symbol or #f"
                            (or (not to) (symbol? to))
                            to)
  (object<-alist
   (list
    (cons 'kind +yuanxu-funflow-composition-step-prototype-kind+)
    (cons 'schema 'yuanxu.modules.funflow.composition-step.v1)
    (cons 'step-kind step-kind)
    (cons 'check-name check-name)
    (cons 'from from)
    (cons 'to to)
    (cons 'composition-style
          (if (eq? step-kind 'kleisli-bind) 'kleisli 'arrow))
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata)))
    (cons 'runtime-executed #f))))

;; : (-> YuanxuFunflowDagEdge Alist)
(defpoo-final-projection
  yuanxu-funflow-dag-edge->alist (edge)
  (bindings ((_guard
              (yuanxu-funflow-require
               "funflow DAG edge projection requires an edge"
               (yuanxu-funflow-dag-edge? edge)
               edge))))
  (fields ((kind (.ref edge 'kind))
           (from (.ref edge 'from))
           (to (.ref edge 'to))
           (composition-style (.ref edge 'composition-style))
           (metadata (.ref edge 'metadata))
           (runtime-executed (.ref edge 'runtime-executed)))))

;; : (-> [YuanxuFunflowDagEdge] [Alist])
(defpoo-final-projection-batch
  yuanxu-funflow-dag-edges->alists (edges)
  (projector yuanxu-funflow-dag-edge->alist)
  (error-message "funflow DAG edge projection requires a list"))

;; : (-> YuanxuFunflowCompositionStep Alist)
(defpoo-final-projection
  yuanxu-funflow-composition-step->alist (step)
  (bindings ((_guard
              (yuanxu-funflow-require
               "funflow composition step projection requires a composition step"
               (yuanxu-funflow-composition-step? step)
               step))))
  (fields ((kind (.ref step 'kind))
           (schema (.ref step 'schema))
           (step-kind (.ref step 'step-kind))
           (check-name (.ref step 'check-name))
           (from (.ref step 'from))
           (to (.ref step 'to))
           (composition-style (.ref step 'composition-style))
           (metadata (.ref step 'metadata))
           (runtime-executed (.ref step 'runtime-executed)))))

;; : (-> [YuanxuFunflowCompositionStep] [Alist])
(defpoo-final-projection-batch
  yuanxu-funflow-composition-steps->alists (steps)
  (projector yuanxu-funflow-composition-step->alist)
  (error-message "funflow composition step projection requires a list"))

;; : (-> [YuanxuFunflowDagEdge] [Symbol] [Symbol] Pair)
(def (yuanxu-funflow-edge-endpoint-summary/rev edges sources-rev targets-rev)
  (if (null? edges)
    (cons (reverse sources-rev) (reverse targets-rev))
    (yuanxu-funflow-edge-endpoint-summary/rev
     (cdr edges)
     (cons (.ref (car edges) 'from) sources-rev)
     (cons (.ref (car edges) 'to) targets-rev))))

;; : (-> [YuanxuFunflowDagEdge] Alist)
(def (yuanxu-funflow-edge-endpoint-summary edges)
  (let (summary
        (yuanxu-funflow-edge-endpoint-summary/rev edges '() '()))
    (list
     (cons 'sources (car summary))
     (cons 'targets (cdr summary)))))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (yuanxu-funflow-nodes-not-in nodes blocked-nodes)
  (cond
   ((null? nodes) '())
   ((yuanxu-cicd-symbol-member? (car nodes) blocked-nodes)
    (yuanxu-funflow-nodes-not-in (cdr nodes) blocked-nodes))
   (else
    (cons (car nodes)
          (yuanxu-funflow-nodes-not-in (cdr nodes) blocked-nodes)))))

;; : (-> Alist YuanxuFunflowDagEdge)
(def (yuanxu-funflow-dependency-edge->dag-edge edge)
  (yuanxu-funflow-dag-edge
   (yuanxu-cicd-alist-ref edge 'from #f)
   (yuanxu-cicd-alist-ref edge 'to #f)
   (yuanxu-product-field-rows
    (source 'workflow-cicd-dependency-graph))))

;; : (-> [Alist] [YuanxuFunflowDagEdge])
(def (yuanxu-funflow-dependency-edges->dag-edges edges)
  (cond
   ((null? edges) '())
   ((pair? edges)
    (cons (yuanxu-funflow-dependency-edge->dag-edge (car edges))
          (yuanxu-funflow-dependency-edges->dag-edges (cdr edges))))
   (else
    (error "funflow dependency edges must be a list" edges))))

;; : (-> Symbol YuanxuFunflowCompositionStep)
(def (yuanxu-funflow-node->composition-step node)
  (yuanxu-funflow-composition-step
   'arrow-node
   node
   #f
   #f
   (yuanxu-product-field-rows
    (source 'funflow-functional-kernel))))

;; : (-> YuanxuFunflowDagEdge YuanxuFunflowCompositionStep)
(def (yuanxu-funflow-edge->composition-step edge)
  (yuanxu-funflow-composition-step
   'kleisli-bind
   #f
   (.ref edge 'from)
   (.ref edge 'to)
   (yuanxu-product-field-rows
    (source 'funflow-functional-kernel)
    (edge-composition-style
     (.ref edge 'composition-style)))))

;; : (-> [Symbol] [YuanxuFunflowCompositionStep] [YuanxuFunflowCompositionStep])
(def (yuanxu-funflow-node-composition-steps/rev nodes steps-rev)
  (if (null? nodes)
    steps-rev
    (yuanxu-funflow-node-composition-steps/rev
     (cdr nodes)
     (cons (yuanxu-funflow-node->composition-step (car nodes))
           steps-rev))))

;; : (-> [YuanxuFunflowDagEdge] [YuanxuFunflowCompositionStep] [YuanxuFunflowCompositionStep])
(def (yuanxu-funflow-edge-composition-steps/rev edges steps-rev)
  (if (null? edges)
    steps-rev
    (yuanxu-funflow-edge-composition-steps/rev
     (cdr edges)
     (cons (yuanxu-funflow-edge->composition-step (car edges))
           steps-rev))))

;; : (-> [Symbol] [YuanxuFunflowDagEdge] [YuanxuFunflowCompositionStep])
(def (yuanxu-funflow-dag-composition-steps nodes edges)
  (reverse
   (yuanxu-funflow-edge-composition-steps/rev
    edges
    (yuanxu-funflow-node-composition-steps/rev nodes '()))))

;; : (-> YuanxuFunflowFunctionalDag Alist)
(defpoo-final-projection
  yuanxu-funflow-functional-dag->alist (dag)
  (bindings ((_guard
              (yuanxu-funflow-require
               "funflow functional DAG projection requires a DAG"
               (yuanxu-funflow-functional-dag? dag)
               dag))))
  (fields ((kind (.ref dag 'kind))
           (schema (.ref dag 'schema))
           (pipeline-name (.ref dag 'pipeline-name))
           (check-map (.ref dag 'check-map))
           (composition-style (.ref dag 'composition-style))
           (composition-steps
            (yuanxu-funflow-composition-steps->alists
             (.ref dag 'composition-steps)))
           (composition-step-count
            (.ref dag 'composition-step-count))
           (nodes (.ref dag 'nodes))
           (edges
            (yuanxu-funflow-dag-edges->alists
             (.ref dag 'edges)))
           (edge-count (.ref dag 'edge-count))
           (entry-nodes (.ref dag 'entry-nodes))
           (terminal-nodes (.ref dag 'terminal-nodes))
           (ready-order (.ref dag 'ready-order))
           (unordered-nodes (.ref dag 'unordered-nodes))
           (blocked-order? (.ref dag 'blocked-order?))
           (diagnostics (.ref dag 'diagnostics))
           (valid? (.ref dag 'valid?))
           (metadata (.ref dag 'metadata))
           (runtime-owner (.ref dag 'runtime-owner))
           (runtime-executed (.ref dag 'runtime-executed)))))

;; : (-> YuanxuFunflowNormalizedFlow Alist)
(defpoo-final-projection
  yuanxu-funflow-normalized-flow->alist (flow)
  (bindings ((_guard
              (yuanxu-funflow-require
               "funflow normalized-flow projection requires a normalized-flow"
               (yuanxu-funflow-normalized-flow? flow)
               flow))))
  (fields ((kind (.ref flow 'kind))
           (schema (.ref flow 'schema))
           (name (.ref flow 'name))
           (pipeline-name (.ref flow 'pipeline-name))
           (source (.ref flow 'source))
           (normalized-form (.ref flow 'normalized-form))
           (policy-family (.ref flow 'policy-family))
           (stages (.ref flow 'stages))
           (source-map (.ref flow 'source-map))
           (runtime-contract (.ref flow 'runtime-contract))
           (metadata (.ref flow 'metadata))
           (diagnostics (.ref flow 'diagnostics))
           (valid? (.ref flow 'valid?))
           (runtime-executed (.ref flow 'runtime-executed)))))

;; : (-> YuanxuFunflowPlan Alist)
(defpoo-final-projection
  yuanxu-funflow-plan->alist (plan)
  (bindings ((_guard
              (yuanxu-funflow-require
               "funflow plan projection requires a plan"
               (yuanxu-funflow-plan? plan)
               plan))))
  (fields ((kind (.ref plan 'kind))
           (schema (.ref plan 'schema))
           (name (.ref plan 'name))
           (version (.ref plan 'version))
           (origin (.ref plan 'origin))
           (normalized-flow (.ref plan 'normalized-flow))
           (node-table (.ref plan 'node-table))
           (edge-table (.ref plan 'edge-table))
           (policy-table (.ref plan 'policy-table))
           (effect-table (.ref plan 'effect-table))
           (runtime-contract (.ref plan 'runtime-contract))
           (source-map (.ref plan 'source-map))
           (diagnostics (.ref plan 'diagnostics))
           (valid? (.ref plan 'valid?))
           (runtime-owner (.ref plan 'runtime-owner))
           (runtime-executed (.ref plan 'runtime-executed)))))

;; : (-> YuanxuFunflowPlan Alist)
(def (yuanxu-funflow-plan->runtime-projection plan)
  (yuanxu-funflow-require
   "funflow runtime projection requires a plan"
   (yuanxu-funflow-plan? plan)
   plan)
   (yuanxu-product-field-rows
   (kind 'yuanxu.funflow.plan-projection)
   (schema 'yuanxu.funflow-plan-projection.v1)
   (origin (.ref plan 'origin))
   (runtime-contract (.ref plan 'runtime-contract))
   (source-map (.ref plan 'source-map))
   (plan (yuanxu-funflow-plan->alist plan))
   (runtime-executed #f)))

;; : (-> YuanxuFunflowCheckPrototype Alist)
;; : (-> YuanxuFunflowCheckPrototype YuanxuCicdCheck)
;;; Boundary: funflow poo checks to cicd checks is the policy-visible edge for
;;; policy behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [YuanxuFunflowCheckPrototype] [YuanxuCicdCheck])
;; : (-> YuanxuFunflowPipelinePrototype YuanxuCicdCheckMap)
;;; Functional DAGs are Funflow-owned POO objects derived from a pipeline. They
;;; keep the authoring model functional and inspectable while leaving runtime
;;; scheduling to Marlin.
;; : (-> YuanxuCicdCheckMap YuanxuFunflowFunctionalDag)
(def (yuanxu-funflow-check-map->functional-dag check-map)
  (yuanxu-funflow-require
   "funflow functional DAG requires a cicd check-map"
   (yuanxu-cicd-check-map? check-map)
   check-map)
  (let* ((graph (yuanxu-cicd-check-map->dependency-graph check-map))
         (nodes (yuanxu-cicd-alist-ref graph 'nodes '()))
         (edges (yuanxu-funflow-dependency-edges->dag-edges
                 (yuanxu-cicd-alist-ref graph 'edges '())))
         (composition-steps
          (yuanxu-funflow-dag-composition-steps nodes edges))
         (endpoint-summary
          (yuanxu-funflow-edge-endpoint-summary edges)))
    (object<-alist
     (list
      (cons 'kind +yuanxu-funflow-functional-dag-prototype-kind+)
      (cons 'schema 'yuanxu.modules.funflow.functional-dag.v1)
      (cons 'pipeline-name (yuanxu-cicd-check-map-name check-map))
      (cons 'check-map (yuanxu-cicd-check-map-name check-map))
      (cons 'composition-style 'arrow-kleisli)
      (cons 'composition-steps composition-steps)
      (cons 'composition-step-count (length composition-steps))
      (cons 'nodes nodes)
      (cons 'edges edges)
      (cons 'edge-count (length edges))
      (cons 'entry-nodes
            (yuanxu-funflow-nodes-not-in
             nodes
             (yuanxu-cicd-alist-ref endpoint-summary 'targets '())))
      (cons 'terminal-nodes
            (yuanxu-funflow-nodes-not-in
             nodes
             (yuanxu-cicd-alist-ref endpoint-summary 'sources '())))
      (cons 'ready-order
            (yuanxu-cicd-alist-ref graph 'ready-order '()))
      (cons 'unordered-nodes
            (yuanxu-cicd-alist-ref graph 'unordered-nodes '()))
      (cons 'blocked-order?
            (yuanxu-cicd-alist-ref graph 'blocked-order? #f))
      (cons 'diagnostics
            (yuanxu-cicd-alist-ref graph 'diagnostics '()))
      (cons 'valid?
            (yuanxu-cicd-alist-ref graph 'valid? #f))
      (cons 'metadata
            (yuanxu-product-field-rows
             (source 'funflow-functional-kernel)
             (dependency-graph-kind
              (yuanxu-cicd-alist-ref graph 'kind #f))))
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f)))))

;; : (-> YuanxuFunflowPipelinePrototype YuanxuFunflowFunctionalDag)
(def (yuanxu-funflow-poo-pipeline->functional-dag pipeline)
  (yuanxu-funflow-check-map->functional-dag
   (yuanxu-funflow-poo-pipeline->check-map pipeline)))

;; : (-> Symbol [Symbol] [Alist])
(def (yuanxu-funflow-source-map-rows flow-name stages)
  (cond
   ((null? stages) '())
   ((pair? stages)
    (cons
     (yuanxu-product-field-rows
      (stage (car stages))
      (source 'use-module-funflow)
      (path (list 'use-module 'funflow flow-name (car stages))))
     (yuanxu-funflow-source-map-rows flow-name (cdr stages))))
   (else
    (error "funflow normalized-flow stages must be a list" stages))))

;; : (-> YuanxuFunflowFunctionalDag Alist YuanxuFunflowNormalizedFlow)
(def (yuanxu-funflow-functional-dag->normalized-flow dag metadata)
  (yuanxu-funflow-require
   "funflow normalized-flow requires a functional DAG"
   (yuanxu-funflow-functional-dag? dag)
   dag)
  (let* ((flow-name (.ref dag 'pipeline-name))
         (stages (.ref dag 'nodes)))
    (object<-alist
     (list
      (cons 'kind +yuanxu-funflow-normalized-flow-prototype-kind+)
      (cons 'schema 'yuanxu.modules.funflow.normalized-flow.v1)
      (cons 'name flow-name)
      (cons 'pipeline-name flow-name)
      (cons 'source 'use-module-funflow)
      (cons 'normalized-form '(use-module funflow normalized-flow))
      (cons 'policy-family 'funflow)
      (cons 'functional-dag dag)
      (cons 'stages stages)
      (cons 'source-map (yuanxu-funflow-source-map-rows flow-name stages))
      (cons 'runtime-contract 'yuanxu.anyio.v1)
      (cons 'metadata metadata)
      (cons 'diagnostics (.ref dag 'diagnostics))
      (cons 'valid? (.ref dag 'valid?))
      (cons 'runtime-executed #f)))))

;; : (-> YuanxuCicdCheckMap YuanxuFunflowNormalizedFlow)
(def (yuanxu-funflow-check-map->normalized-flow check-map)
  (let* ((dag (yuanxu-funflow-check-map->functional-dag check-map))
         (metadata
          (yuanxu-product-field-rows
           (source 'use-module-funflow)
           (check-map (yuanxu-cicd-check-map-name check-map)))))
    (yuanxu-funflow-functional-dag->normalized-flow dag metadata)))

;; : (-> YuanxuFunflowPipelinePrototype YuanxuFunflowNormalizedFlow)
(def (yuanxu-funflow-poo-pipeline->normalized-flow pipeline)
  (yuanxu-funflow-check-map->normalized-flow
   (yuanxu-funflow-poo-pipeline->check-map pipeline)))

;; : (-> [Symbol] [Alist])
(def (yuanxu-funflow-node-table-rows nodes)
  (cond
   ((null? nodes) '())
   ((pair? nodes)
    (cons
     (yuanxu-product-field-rows
      (name (car nodes))
      (kind 'funflow-step)
      (runtime-executed #f))
     (yuanxu-funflow-node-table-rows (cdr nodes))))
   (else
    (error "funflow plan nodes must be a list" nodes))))

;; : (-> [YuanxuFunflowDagEdge] [Alist])
(def (yuanxu-funflow-edge-table-rows edges)
  (cond
   ((null? edges) '())
   ((pair? edges)
    (cons (yuanxu-funflow-dag-edge->alist (car edges))
          (yuanxu-funflow-edge-table-rows (cdr edges))))
   (else
    (error "funflow plan edges must be a list" edges))))

;; : (-> YuanxuFunflowNormalizedFlow YuanxuFunflowPlan)
(def (yuanxu-funflow-normalized-flow->plan flow)
  (yuanxu-funflow-require
   "funflow plan requires a normalized-flow"
   (yuanxu-funflow-normalized-flow? flow)
   flow)
  (let* ((dag (.ref flow 'functional-dag))
         (nodes (.ref dag 'nodes))
         (edges (.ref dag 'edges)))
    (object<-alist
     (list
      (cons 'kind +yuanxu-funflow-plan-prototype-kind+)
      (cons 'schema 'yuanxu.modules.funflow.plan.v1)
      (cons 'name (.ref flow 'name))
      (cons 'version 1)
      (cons 'origin 'use-module-funflow)
      (cons 'normalized-flow (.ref flow 'name))
      (cons 'node-table
            (list->vector (yuanxu-funflow-node-table-rows nodes)))
      (cons 'edge-table
            (list->vector (yuanxu-funflow-edge-table-rows edges)))
      (cons 'policy-table
            (vector
             (yuanxu-product-field-rows
              (policy-family (.ref flow 'policy-family)))))
      (cons 'effect-table '#())
      (cons 'runtime-contract (.ref flow 'runtime-contract))
      (cons 'source-map (.ref flow 'source-map))
      (cons 'diagnostics (.ref flow 'diagnostics))
      (cons 'valid? (.ref flow 'valid?))
      (cons 'runtime-owner "python-anyio")
      (cons 'runtime-executed #f)))))

;; : (-> YuanxuCicdCheckMap YuanxuFunflowPlan)
(def (yuanxu-funflow-check-map->plan check-map)
  (yuanxu-funflow-normalized-flow->plan
   (yuanxu-funflow-check-map->normalized-flow check-map)))

;; : (-> YuanxuFunflowPipelinePrototype YuanxuFunflowPlan)
(def (yuanxu-funflow-poo-pipeline->plan pipeline)
  (yuanxu-funflow-check-map->plan
   (yuanxu-funflow-poo-pipeline->check-map pipeline)))

