;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: execution policies package strategy evidence for runtime handoff.
;;; Invariant: policies are immutable snapshots, not schedulers or executors.

(import :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/projection-syntax)

(export make-execution-policy
        execution-policy?
        execution-policy-strategy
        execution-policy-cache-policy
        execution-policy-failure-policy
        execution-policy-capabilities
        execution-policy-frontier
        strategy-execution-policy
        execution-policy->alist
        execution-policy-allows?
        execution-policy-cache-enabled?)

;;; A policy snapshot is the Rust-facing view of strategy metadata at a single
;;; execution frontier.
;; : (-> Strategy CachePolicy FailurePolicy [Symbol] [Id] ExecutionPolicy)
(defstruct execution-policy
  (strategy
   cache-policy
   failure-policy
   capabilities
   frontier)
  transparent: #t)

;;; Strategy-owned metadata is frozen at the runner boundary before an adapter
;;; receives a request, so host runtimes do not need to inspect Scheme objects.
;; : (-> Strategy [Id] ExecutionPolicy)
(def (strategy-execution-policy strategy frontier)
  (make-execution-policy (strategy-name strategy)
                         (strategy-cache-policy strategy)
                         (strategy-failure-policy strategy)
                         (strategy-capabilities strategy)
                         frontier))

;;; The alist form is the stable request/receipt shape for future Rust
;;; serialization; it intentionally avoids embedding Gerbil structs.
;; : (-> ExecutionPolicy Alist)
(defpoo-core-receipt-projection
  execution-policy->alist (policy)
  (bindings ())
  (fields ((strategy (execution-policy-strategy policy))
           (cache-policy (execution-policy-cache-policy policy))
           (failure-policy (execution-policy-failure-policy policy))
           (capabilities (execution-policy-capabilities policy))
           (frontier (execution-policy-frontier policy)))))

;; : (-> ExecutionPolicy Symbol Boolean)
(def (execution-policy-allows? policy capability)
  (and (memq capability (execution-policy-capabilities policy)) #t))

;; : (-> ExecutionPolicy Boolean)
(def (execution-policy-cache-enabled? policy)
  (not (eq? (execution-policy-cache-policy policy) 'no-cache)))
