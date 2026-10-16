;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runner validation checks planned steps against strategy/adapter support.

(import :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/plan
        :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/runtime-adapter)

(export validate-plan-node)

;; : (-> Strategy Symbol Task Alist)
(defpoo-core-receipt-projection
  unsupported-task-capability-detail (strategy capability task)
  (bindings ())
  (fields ((strategy (strategy-name strategy))
           (capability capability)
           (task-kind (task-kind task)))))

;; : (-> RuntimeAdapter Symbol Task Alist)
(defpoo-core-receipt-projection
  unsupported-adapter-capability-detail (adapter capability task)
  (bindings ())
  (fields ((adapter (runtime-adapter-name adapter))
           (capability capability)
           (task-kind (task-kind task)))))

;; : (-> TaskFamilyRegistry Strategy RuntimeAdapter PlanNode Boolean)
(def (validate-plan-node task-registry strategy adapter node)
  (validate-step task-registry strategy adapter (plan-node-step node)))

;; : (-> TaskFamilyRegistry Strategy RuntimeAdapter Step Boolean)
(def (validate-step task-registry strategy adapter step)
  (when (task? step)
    (validate-task task-registry strategy adapter step)))

;; : (-> TaskFamilyRegistry Strategy RuntimeAdapter Task Boolean)
(def (validate-task task-registry strategy adapter task)
  (let ((capability (task-capability-in task-registry task)))
    (unless (memq capability (strategy-capabilities strategy))
      (raise-control-plane-failure
       'runner
       'unsupported-task-capability
       "strategy does not support task kind"
       (unsupported-task-capability-detail strategy capability task)))
    (when (task-adapter-routed?-in task-registry task)
      (unless (adapter-supports? adapter capability)
        (raise-control-plane-failure
         'runner
         'unsupported-adapter-capability
         "adapter does not support task kind"
         (unsupported-adapter-capability-detail adapter capability task))))))
