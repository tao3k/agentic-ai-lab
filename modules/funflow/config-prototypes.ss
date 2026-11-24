;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow POO prototype families.
;;; Invariant: this owner declares static prototype slots and predicates only.

(import (only-in :clan/poo/object .ref)
        :tao3k/yuanxu/profile-composition/module-prototype-syntax)

(export funflow-check
        funflow-pipeline
        funflow-dag-edge
        funflow-composition-step
        funflow-functional-dag
        funflow-normalized-flow
        funflow-plan
        yuanxu-funflow-poo-check?
        yuanxu-funflow-poo-pipeline?
        yuanxu-funflow-dag-edge?
        yuanxu-funflow-composition-step?
        yuanxu-funflow-functional-dag?
        yuanxu-funflow-normalized-flow?
        yuanxu-funflow-plan?
        +yuanxu-funflow-check-prototype-kind+
        +yuanxu-funflow-pipeline-prototype-kind+
        +yuanxu-funflow-dag-edge-prototype-kind+
        +yuanxu-funflow-composition-step-prototype-kind+
        +yuanxu-funflow-functional-dag-prototype-kind+
        +yuanxu-funflow-normalized-flow-prototype-kind+
        +yuanxu-funflow-plan-prototype-kind+)

;; : Symbol
(def +yuanxu-funflow-check-prototype-kind+
  'yuanxu.funflow.check.prototype)

;; : Symbol
(def +yuanxu-funflow-pipeline-prototype-kind+
  'yuanxu.funflow.pipeline.prototype)

;; : Symbol
(def +yuanxu-funflow-dag-edge-prototype-kind+
  'yuanxu.funflow.dag-edge.prototype)

;; : Symbol
(def +yuanxu-funflow-composition-step-prototype-kind+
  'yuanxu.funflow.composition-step.prototype)

;; : Symbol
(def +yuanxu-funflow-functional-dag-prototype-kind+
  'yuanxu.funflow.functional-dag.prototype)

;; : Symbol
(def +yuanxu-funflow-normalized-flow-prototype-kind+
  'yuanxu.funflow.normalized-flow.prototype)

;; : Symbol
(def +yuanxu-funflow-plan-prototype-kind+
  'yuanxu.funflow.plan.prototype)

;; : YuanxuFunflowCheckPrototype
(defpoo-module-config-prototype
  funflow-check
  (slots ((kind +yuanxu-funflow-check-prototype-kind+)
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

;; : YuanxuFunflowPipelinePrototype
(defpoo-module-config-prototype
  funflow-pipeline
  (slots ((kind +yuanxu-funflow-pipeline-prototype-kind+)
          (pipeline-name #f)
          (checks '())
          (metadata '())
          (runtime-executed #f))))

;; : YuanxuFunflowDagEdgePrototype
(defpoo-module-config-prototype
  funflow-dag-edge
  (slots ((kind +yuanxu-funflow-dag-edge-prototype-kind+)
          (from #f)
          (to #f)
          (composition-style 'kleisli)
          (metadata '())
          (runtime-executed #f))))

;; : YuanxuFunflowCompositionStepPrototype
(defpoo-module-config-prototype
  funflow-composition-step
  (slots ((kind +yuanxu-funflow-composition-step-prototype-kind+)
          (schema 'yuanxu.modules.funflow.composition-step.v1)
          (step-kind #f)
          (check-name #f)
          (from #f)
          (to #f)
          (composition-style #f)
          (metadata '())
          (runtime-executed #f))))

;; : YuanxuFunflowFunctionalDagPrototype
(defpoo-module-config-prototype
  funflow-functional-dag
  (slots ((kind +yuanxu-funflow-functional-dag-prototype-kind+)
          (schema 'yuanxu.modules.funflow.functional-dag.v1)
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

;; : YuanxuFunflowNormalizedFlowPrototype
(defpoo-module-config-prototype
  funflow-normalized-flow
  (slots ((kind +yuanxu-funflow-normalized-flow-prototype-kind+)
          (schema 'yuanxu.modules.funflow.normalized-flow.v1)
          (name #f)
          (pipeline-name #f)
          (source 'use-module-funflow)
          (normalized-form '(use-module funflow normalized-flow))
          (policy-family 'funflow)
          (functional-dag #f)
          (stages '())
          (source-map '())
          (runtime-contract 'yuanxu.anyio.v1)
          (metadata '())
          (diagnostics '())
          (valid? #t)
          (runtime-executed #f))))

;; : YuanxuFunflowPlanPrototype
(defpoo-module-config-prototype
  funflow-plan
  (slots ((kind +yuanxu-funflow-plan-prototype-kind+)
          (schema 'yuanxu.modules.funflow.plan.v1)
          (name #f)
          (version 1)
          (origin 'use-module-funflow)
          (normalized-flow #f)
          (node-table '#())
          (edge-table '#())
          (policy-table '#())
          (effect-table '#())
          (runtime-contract 'yuanxu.anyio.v1)
          (source-map '())
          (diagnostics '())
          (valid? #t)
          (runtime-owner "python-anyio")
          (runtime-executed #f))))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-poo-check?
  +yuanxu-funflow-check-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-poo-pipeline?
  +yuanxu-funflow-pipeline-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-dag-edge?
  +yuanxu-funflow-dag-edge-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-composition-step?
  +yuanxu-funflow-composition-step-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-functional-dag?
  +yuanxu-funflow-functional-dag-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-normalized-flow?
  +yuanxu-funflow-normalized-flow-prototype-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  yuanxu-funflow-plan?
  +yuanxu-funflow-plan-prototype-kind+)
