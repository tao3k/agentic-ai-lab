;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow POO prototype families.
;;; Invariant: this owner declares static prototype slots and predicates only.

(import (only-in :clan/poo/object .ref)
        :core/profile-composition/module-prototype-syntax)

(export funflow-check
        funflow-pipeline
        funflow-dag-edge
        funflow-composition-step
        funflow-functional-dag
        funflow-normalized-flow
        funflow-plan
        poo-flow-funflow-poo-check?
        poo-flow-funflow-poo-pipeline?
        poo-flow-funflow-dag-edge?
        poo-flow-funflow-composition-step?
        poo-flow-funflow-functional-dag?
        poo-flow-funflow-normalized-flow?
        poo-flow-funflow-plan?
        +poo-flow-funflow-check-prototype-kind+
        +poo-flow-funflow-pipeline-prototype-kind+
        +poo-flow-funflow-dag-edge-prototype-kind+
        +poo-flow-funflow-composition-step-prototype-kind+
        +poo-flow-funflow-functional-dag-prototype-kind+
        +poo-flow-funflow-normalized-flow-prototype-kind+
        +poo-flow-funflow-plan-prototype-kind+)

;; : Symbol
(def +poo-flow-funflow-check-prototype-kind+
  'poo-flow.funflow.check.prototype)

;; : Symbol
(def +poo-flow-funflow-pipeline-prototype-kind+
  'poo-flow.funflow.pipeline.prototype)

;; : Symbol
(def +poo-flow-funflow-dag-edge-prototype-kind+
  'poo-flow.funflow.dag-edge.prototype)

;; : Symbol
(def +poo-flow-funflow-composition-step-prototype-kind+
  'poo-flow.funflow.composition-step.prototype)

;; : Symbol
(def +poo-flow-funflow-functional-dag-prototype-kind+
  'poo-flow.funflow.functional-dag.prototype)

;; : Symbol
(def +poo-flow-funflow-normalized-flow-prototype-kind+
  'poo-flow.funflow.normalized-flow.prototype)

;; : Symbol
(def +poo-flow-funflow-plan-prototype-kind+
  'poo-flow.funflow.plan.prototype)

;; : PooFlowFunflowCheckPrototype
(defpoo-module-config-prototype
  funflow-check
  (slots ((kind +poo-flow-funflow-check-prototype-kind+)
          (check-name #f)
          (profile-ref #f)
          (command-vector '())
          (input-bindings '())
          (config-sources '())
          (artifact-outputs '())
          (cache-intents '())
          (secret-requirements '())
          (result-protocol '())
          (runtime-mode 'manifest-handoff)
          (dependency-refs '())
          (durable-task-id #f)
          (action-class 'idempotent)
          (compensation-refs '())
          (artifact-retention 'workflow-retained)
          (observability #f)
          (observes '())
          (guards '())
          (report #f)
          (metadata '())
          (runtime-executed #f))))

;; : PooFlowFunflowPipelinePrototype
(defpoo-module-config-prototype
  funflow-pipeline
  (slots ((kind +poo-flow-funflow-pipeline-prototype-kind+)
          (pipeline-name #f)
          (checks '())
          (metadata '())
          (runtime-executed #f))))

;; : PooFlowFunflowDagEdgePrototype
(defpoo-module-config-prototype
  funflow-dag-edge
  (slots ((kind +poo-flow-funflow-dag-edge-prototype-kind+)
          (from #f)
          (to #f)
          (composition-style 'kleisli)
          (metadata '())
          (runtime-executed #f))))

;; : PooFlowFunflowCompositionStepPrototype
(defpoo-module-config-prototype
  funflow-composition-step
  (slots ((kind +poo-flow-funflow-composition-step-prototype-kind+)
          (schema 'poo-flow.modules.funflow.composition-step.v1)
          (step-kind #f)
          (check-name #f)
          (from #f)
          (to #f)
          (composition-style #f)
          (metadata '())
          (runtime-executed #f))))

;; : PooFlowFunflowFunctionalDagPrototype
(defpoo-module-config-prototype
  funflow-functional-dag
  (slots ((kind +poo-flow-funflow-functional-dag-prototype-kind+)
          (schema 'poo-flow.modules.funflow.functional-dag.v1)
          (pipeline-name #f)
          (check-map #f)
          (composition-style 'arrow-kleisli)
          (composition-steps '())
          (composition-step-count 0)
          (nodes '())
          (edges '())
          (edge-count 0)
          (entry-nodes '())
          (terminal-nodes '())
          (ready-order '())
          (unordered-nodes '())
          (blocked-order? #f)
          (diagnostics '())
          (valid? #t)
          (metadata '())
          (runtime-owner "marlin-agent-core")
          (runtime-executed #f))))

;; : PooFlowFunflowNormalizedFlowPrototype
(defpoo-module-config-prototype
  funflow-normalized-flow
  (slots ((kind +poo-flow-funflow-normalized-flow-prototype-kind+)
          (schema 'poo-flow.modules.funflow.normalized-flow.v1)
          (name #f)
          (pipeline-name #f)
          (source 'use-module-funflow)
          (normalized-form '(use-module funflow normalized-flow))
          (policy-family 'funflow)
          (functional-dag #f)
          (stages '())
          (source-map '())
          (runtime-contract 'poo-flow.anyio.v1)
          (metadata '())
          (diagnostics '())
          (valid? #t)
          (runtime-executed #f))))

;; : PooFlowFunflowPlanPrototype
(defpoo-module-config-prototype
  funflow-plan
  (slots ((kind +poo-flow-funflow-plan-prototype-kind+)
          (schema 'poo-flow.modules.funflow.plan.v1)
          (name #f)
          (version 1)
          (origin 'use-module-funflow)
          (normalized-flow #f)
          (node-table '#())
          (edge-table '#())
          (policy-table '#())
          (effect-table '#())
          (runtime-contract 'poo-flow.anyio.v1)
          (source-map '())
          (diagnostics '())
          (valid? #t)
          (runtime-owner "python-anyio")
          (runtime-executed #f))))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-poo-check?
  +poo-flow-funflow-check-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-poo-pipeline?
  +poo-flow-funflow-pipeline-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-dag-edge?
  +poo-flow-funflow-dag-edge-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-composition-step?
  +poo-flow-funflow-composition-step-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-functional-dag?
  +poo-flow-funflow-functional-dag-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-normalized-flow?
  +poo-flow-funflow-normalized-flow-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-funflow-plan?
  +poo-flow-funflow-plan-prototype-kind+)
