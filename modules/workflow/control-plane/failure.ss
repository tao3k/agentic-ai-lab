;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: failures are typed control-plane data, not runtime strings.
;;; Invariant: heavy runtime errors are wrapped here before receipts persist them.

(import :poo-flow/modules/workflow/control-plane/projection-syntax)

(export make-execution-failure
        execution-failure?
        execution-failure-owner
        execution-failure-code
        execution-failure-message
        execution-failure-detail
        execution-failure-recoverable
        execution-failure-recoverable?
        make-try-result
        try-result?
        try-result-side
        try-result-value
        make-try-left
        make-try-right
        try-left?
        try-right?
        control-plane-failure
        control-plane-failure->alist
        try-control-plane
        throw-string-control-plane-failure
        raise-control-plane-failure)

;;; Execution failures are the Scheme-side explanation surface for planning,
;;; validation, adapter dispatch, and runtime handoff errors.
;; : (-> Symbol Symbol String Detail Boolean ExecutionFailure)
(defstruct execution-failure
  (owner
   code
   message
   detail
   recoverable)
  transparent: #t)

;;; Try results are the Scheme-side value form of Funflow's =tryE= Either:
;;; a recoverable failure becomes a left value, while success becomes right.
;; : (-> Symbol Value TryResult)
(defstruct try-result
  (side
   value)
  transparent: #t)

;; : (-> ExecutionFailure Boolean)
(def (execution-failure-recoverable? failure)
  (execution-failure-recoverable failure))

;; : (-> ExecutionFailure TryResult)
(def (make-try-left failure)
  (make-try-result 'left failure))

;; : (-> Value TryResult)
(def (make-try-right value)
  (make-try-result 'right value))

;; : (-> TryResult Boolean)
(def (try-left? result)
  (and (try-result? result)
       (eq? (try-result-side result) 'left)))

;; : (-> TryResult Boolean)
(def (try-right? result)
  (and (try-result? result)
       (eq? (try-result-side result) 'right)))

;; : (-> Symbol Symbol String Detail Boolean ExecutionFailure)
(def (control-plane-failure owner code message detail recoverable?)
  (make-execution-failure owner code message detail recoverable?))

;;; Raising the failure object directly keeps tests and callers tied to the
;;; structured payload instead of parsing implementation-specific error text.
;; : (-> Symbol Symbol String Detail [Boolean] Never)
(def (raise-control-plane-failure owner code message detail . maybe-recoverable)
  (raise (control-plane-failure owner
                                code
                                message
                                detail
                                (if (null? maybe-recoverable)
                                  #f
                                  (car maybe-recoverable)))))

;;; Alist projection is the durable shape for audit logs and future runtime
;;; bridge serialization.
;; : (-> ExecutionFailure Alist)
(defpoo-core-receipt-projection
  control-plane-failure->alist (failure)
  (bindings ())
  (fields ((owner (execution-failure-owner failure))
           (code (execution-failure-code failure))
           (message (execution-failure-message failure))
           (detail (execution-failure-detail failure))
           (recoverable (execution-failure-recoverable failure)))))

;;; Boundary:
;;; - This is the Scheme-side equivalent of Funflow's =tryE= catch boundary.
;;; - Non-control-plane exceptions are re-raised instead of being normalized.
;; : (-> Thunk FailureHandler Value)
(def (try-control-plane thunk handler)
  (with-catch
   (lambda (failure)
     (if (execution-failure? failure)
       (handler failure)
       (raise failure)))
   thunk))

;;; Boundary:
;;; - String throws model ErrorHandling's =throwStringFlow= result.
;;; - The raised value stays typed so recovery logic need not parse strings.
;; : (-> Unit Detail)
(defpoo-core-receipt-projection
  throw-string-flow-detail ()
  (bindings ())
  (fields ((source 'throw-string-flow))))

;; : (-> String Never)
(def (throw-string-control-plane-failure message)
  (raise-control-plane-failure
   'flow
   'thrown-string
   message
   (throw-string-flow-detail)
   #t))
