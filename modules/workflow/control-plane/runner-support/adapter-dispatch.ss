;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: adapter-routed task dispatch and receipt classification helpers.
;;; Invariant: runner orchestration imports these helpers but owns DAG control.

(import :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/runtime-protocol
        :poo-flow/modules/workflow/control-plane/runtime-adapter)

(export adapter-result-for-task
        adapter-result-failure
        adapter-receipt-status
        adapter-cache-decision)

;;; Adapter dispatch preserves runtime adapter operations while keeping
;;; extension-specific task request interpretation outside the runner.
;; : (-> TaskFamilyRegistry RuntimeAdapter Task ExecutionRequest AdapterResult)
(defpoo-core-receipt-projection
  unsupported-adapter-operation-detail (operation task)
  (bindings ())
  (fields ((operation operation)
           (task (task-name task)))))

;; : (-> TaskFamilyRegistry RuntimeAdapter Task ExecutionRequest AdapterResult)
(def (adapter-result-for-task task-registry adapter task request)
  (let ((operation (task-adapter-operation-in task-registry task)))
    (cond
     ((eq? operation 'store-put)
      (adapter-store-put adapter request))
     ((eq? operation 'store-get)
      (adapter-store-get adapter (task-request-payload task)))
     ((eq? operation 'submit)
      (adapter-submit adapter request))
     (else
      (raise-control-plane-failure
       'runner
       'unsupported-adapter-operation
       "unsupported adapter operation"
       (unsupported-adapter-operation-detail operation task))))))

;;; Adapter failures remain runtime-owned but are wrapped before receipt
;;; persistence so replay and audit code can inspect the same failure shape.
;; : (-> RuntimeAdapter AdapterResult MaybeExecutionFailure)
(defpoo-core-receipt-projection
  adapter-result-error-detail (adapter adapter-result)
  (bindings ())
  (fields ((adapter (runtime-adapter-name adapter))
           (request-id (adapter-result-request-id adapter-result))
           (error (adapter-result-error adapter-result)))))

(defpoo-core-receipt-projection
  adapter-result-failed-status-detail (adapter adapter-result)
  (bindings ())
  (fields ((adapter (runtime-adapter-name adapter))
           (request-id (adapter-result-request-id adapter-result))
           (status (adapter-result-status adapter-result)))))

;; : (-> RuntimeAdapter AdapterResult MaybeExecutionFailure)
(def (adapter-result-failure adapter adapter-result)
  (cond
   ((adapter-result-error adapter-result)
    (control-plane-failure
     'runtime-adapter
     'adapter-failure
     "runtime adapter returned an error"
     (adapter-result-error-detail adapter adapter-result)
     #t))
   ((eq? (adapter-result-status adapter-result) 'failed)
    (control-plane-failure
     'runtime-adapter
     'adapter-failure
     "runtime adapter failed without a detailed error"
     (adapter-result-failed-status-detail adapter adapter-result)
     #t))
   (else #f)))

;;; Adapter receipt status is the policy-visible edge for runtime handoff.
;; : (-> MaybeExecutionFailure AdapterResult Symbol)
(def (adapter-receipt-status failure adapter-result)
  (if failure
    'failed
    (adapter-result-status adapter-result)))

;;; Adapter evidence is derived after runtime handoff because only the adapter
;;; result knows the durable request id, status, and artifact handle.
;; : (-> TaskFamilyRegistry Task AdapterResult AdapterEvidence)
(def (adapter-result-evidence task-registry task adapter-result)
  (list 'adapter-result
        (task-name task)
        (task-kind task)
        (task-adapter-operation-in task-registry task)
        (adapter-result-status adapter-result)
        (adapter-result-request-id adapter-result)
        (adapter-result-artifact-handle adapter-result)))

;;; Local tasks keep strategy-owned cache policy; adapter-routed tasks record
;;; generic runtime evidence instead of pretending to know cache semantics.
;; : (-> TaskFamilyRegistry Strategy Task Input AdapterResult CacheDecision)
(def (adapter-cache-decision task-registry strategy task input adapter-result)
  (if (task-adapter-routed?-in task-registry task)
    (adapter-result-evidence task-registry task adapter-result)
    (strategy-cache-decision strategy task input adapter-result)))
