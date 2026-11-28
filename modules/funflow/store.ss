;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in "store-flow.ss" make-store-task store-flow put-dir-flow get-dir-flow)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures type-description))
;;; Owner: Store/CAS workflow alignment lives in this workflow module.
;;; Boundary: core provides generic task, strategy, config, and adapter slots.
;;; Import contract: users opt in through =:tao3k/agentic-ai-lab/modules/funflow/store= exports.
;;; Runtime contract: this module emits artifact-store request data only.
;;; Runtime contract: CAS materialization and cache reuse stay runtime-owned.
;;; Policy evidence: receipts carry generic adapter observations from core.

(import (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure raise-control-plane-failure)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/task
                 make-task-family-descriptor task-family-registry-extend
                 default-task-family-registry task? task-name task-kind
                 task-request-operation task-request-payload)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/strategy
                 make-strategy strategy-name strategy-capabilities
                 strategy-cache-policy strategy-failure-policy strategy-planner
                 make-local-eager-strategy make-cached-local-eager-strategy)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-adapter
                 make-runtime-adapter runtime-adapter-name
                 runtime-adapter-capabilities runtime-adapter-submitter
                 runtime-adapter-fetcher runtime-adapter-store-putter
                 runtime-adapter-store-getter make-rust-adapter
                 make-request-only-adapter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/config make-run-config)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
                 default-flow-declaration-registry flow-name flow-steps
                 flow-input-contract flow-output-contract))

(export store-task-family-descriptor
        +store-content-address-receipt-schema+
        make-store-task-family-registry
        store-enable-strategy
        make-store-enabled-strategy
        make-cached-store-enabled-strategy
        make-store-enabled-adapter
        make-store-run-config
        make-store-rust-run-config
        make-store-task
        task-store-operation
        task-store-payload
        task-store-put?
        task-store-get?
        store-flow
        put-dir-flow
        get-dir-flow
        make-store-content-address-receipt
        store-content-address-receipt?
        store-content-address-receipt-schema
        store-content-address-receipt-flow
        store-content-address-receipt-operation
        store-content-address-receipt-payload
        store-content-address-receipt-input-contract
        store-content-address-receipt-output-contract
        store-content-address-receipt-address-algorithm
        store-content-address-receipt-content-address
        store-content-address-receipt-runtime-executed
        store-flow->content-address-receipt)

;; : (-> Unit Symbol)
(def +store-content-address-receipt-schema+
  'yuanxu.extensions.store-content-address-receipt.v1)

;;; Report-only CAS evidence mirrors Funflow's content-addressed store promise
;;; without claiming that Scheme has materialized or fetched any store item.
;; : (-> Symbol Symbol Symbol Payload Contract Contract Symbol Value Boolean StoreContentAddressReceipt)
(defstruct store-content-address-receipt
  (schema
   flow
   operation
   payload
   input-contract
   output-contract
   address-algorithm
   content-address
   runtime-executed)
  transparent: #t
  final: #t)

;;; Boundary: store task adapter dispatch is the policy-visible edge for
;;; workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Task AdapterOperation)
(def (store-task-adapter-dispatch task)
  (cond
   ((task-store-put? task) 'store-put)
   ((task-store-get? task) 'store-get)
   (else
    (raise-control-plane-failure
     'store-extension
     'unsupported-store-operation
     "unsupported store operation"
     (list (cons 'task (task-name task))
           (cons 'operation (task-store-operation task)))))))

;; : (-> Unit TaskFamilyDescriptor)
(def store-task-family-descriptor
  (make-task-family-descriptor 'store
                               'store
                               'adapter
                               'rust-or-external-runtime
                               store-task-adapter-dispatch))

;;; Boundary: make store task family registry is the policy-visible edge for
;;; workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [TaskFamilyRegistry] TaskFamilyRegistry)
(def (make-store-task-family-registry . maybe-registry)
  (task-family-registry-extend
   (if (null? maybe-registry) default-task-family-registry (car maybe-registry))
   store-task-family-descriptor))

;;; Boundary: capabilities with is the policy-visible edge for workflow
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (forall (a) (-> [a] [a] [a]))
(def (store-values/tail values tail)
  (foldr cons tail values))

;; : (-> [Symbol] Symbol [Symbol])
(def (capabilities-with capability-set capability)
  (if (memq capability capability-set)
    capability-set
    (store-values/tail capability-set (list capability))))

;; : (-> Strategy Strategy)
(def (store-enable-strategy strategy)
  (make-strategy (strategy-name strategy)
                 (capabilities-with (strategy-capabilities strategy) 'store)
                 (strategy-cache-policy strategy)
                 (strategy-failure-policy strategy)
                 (strategy-planner strategy)))

;;; Store-aware strategies are opt-in wrappers over core strategy policy. Core
;;; stays unaware of Store/CAS while extension users get normal validation.
;; : (-> Unit Strategy)
(def (make-store-enabled-strategy)
  (store-enable-strategy (make-local-eager-strategy)))

;; : (-> Unit Strategy)
(def (make-cached-store-enabled-strategy)
  (store-enable-strategy (make-cached-local-eager-strategy)))

;; : (-> RuntimeAdapter RuntimeAdapter)
(def (make-store-enabled-adapter adapter)
  (make-runtime-adapter (runtime-adapter-name adapter)
                        (capabilities-with (runtime-adapter-capabilities adapter)
                                           'store)
                        (runtime-adapter-submitter adapter)
                        (runtime-adapter-fetcher adapter)
                        (runtime-adapter-store-putter adapter)
                        (runtime-adapter-store-getter adapter)))

;;; Boundary: store option is the policy-visible edge for workflow behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Alist Symbol Value Value)
(def (store-option options key default)
  (let (entry (assoc key options))
    (if entry
      (cdr entry)
      default)))

;;; Boundary: make store run config is the policy-visible edge for workflow
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Alist] RunConfig)
(def (make-store-run-config . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (make-run-config 'store-request-only
                     (make-store-enabled-strategy)
                     (make-store-enabled-adapter (make-request-only-adapter))
                     (append '((runtime . request-only)
                               (extension . store))
                             options)
                     (make-store-task-family-registry)
                     default-flow-declaration-registry)))

;;; Boundary: make store rust run config is the policy-visible edge for
;;; workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Alist] RunConfig)
(def (make-store-rust-run-config . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (command (store-option options 'runtime-command #f)))
    (make-run-config 'store-rust
                     (make-store-enabled-strategy)
                     (make-store-enabled-adapter (make-rust-adapter command))
                     (append '((runtime . rust)
                               (extension . store))
                             options)
                     (make-store-task-family-registry)
                     default-flow-declaration-registry)))

;;; Store operation accessors keep CAS semantics explicit at the extension
;;; boundary without requiring runners to destructure store request data.
;; : (-> Task (U Symbol #f))
(def (task-store-operation task)
  (if (eq? (task-kind task) 'store)
    (task-request-operation task)
    #f))

;;; Boundary: task store payload is the policy-visible edge for workflow
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Task (U Payload #f))
(def (task-store-payload task)
  (if (eq? (task-kind task) 'store)
    (task-request-payload task)
    #f))

;; : (-> Task Boolean)
(def (task-store-put? task)
  (eq? (task-store-operation task) 'put))

;; : (-> Task Boolean)
(def (task-store-get? task)
  (eq? (task-store-operation task) 'get))

;;; Boundary: store flow primary task is the policy-visible edge for workflow
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Flow Task)
(def (store-flow-primary-task flow)
  (let (steps (flow-steps flow))
    (if (and (pair? steps)
             (task? (car steps))
             (eq? (task-kind (car steps)) 'store))
      (car steps)
      (raise-control-plane-failure
       'store-extension
       'expected-store-flow
       "expected a flow whose first step is a store task"
       (list (cons 'flow (flow-name flow)))))))

;;; Content address receipts are discovery artifacts: Rust/Marlin may use them
;;; to bind a real CAS store, while Scheme only records the declared hash fact.
;; : (-> Flow Symbol Value StoreContentAddressReceipt)
(def (store-flow->content-address-receipt flow address-algorithm content-address)
  (let (task (store-flow-primary-task flow))
    (make-store-content-address-receipt
     +store-content-address-receipt-schema+
     (flow-name flow)
     (task-store-operation task)
     (task-store-payload task)
     (type-description (flow-input-contract flow))
     (type-description (flow-output-contract flow))
     address-algorithm
     content-address
     #f)))
