;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Kleisli tests cover value-dependent Functional + POO flow binding.
;;; Invariant: binders return ordinary flow declarations; runner owns execution.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :poo-flow/modules/workflow/control-plane/api)

(export functional-flow-kleisli-test)

;; : (-> Unit Runner)
(def (kleisli-runner)
  (make-runner (make-local-eager-strategy)
               (make-request-only-adapter)))

;; : (-> Flow Value Value)
(def (kleisli-run flow input)
  (run-result-value (runner-run (kleisli-runner) flow input)))

;; : (-> Symbol Alist MaybeValue)
(def (kleisli-alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (kleisli-alist-value key (cdr entries)))))

(defpoo-flow-arr kleisli-macro-inc
  kleisli-macro-inc
  (lambda (x) (+ x 1))
  'number
  'number)

(defpoo-flow-bind kleisli-macro-bound
  kleisli-macro-bound
  kleisli-macro-inc
  (lambda (value)
    (flow-arr 'kleisli-macro-bound-dynamic
              (lambda (current) (+ current value))
              'number
              'number))
  'number)

(defpoo-flow-kleisli kleisli-macro-kleisli
  kleisli-macro-kleisli
  kleisli-macro-inc
  (lambda (value)
    (flow-arr 'kleisli-macro-kleisli-dynamic
              (lambda (current) (+ current value))
              'number
              'number))
  'number)

;;; This suite keeps dependent composition out of the broader Arrow law owner.
;; : TestSuite
(def functional-flow-kleisli-test
  (test-suite "functional flow kleisli"
    (poo-flow-test-case "binds dynamically through the category object"
      (let* ((category default-flow-category)
             (inc (flow-category-arr category
                                     'inc
                                     (lambda (x) (+ x 1))
                                     'number
                                     'number))
             (bound (flow-category-bind
                     category
                     'bind-inc
                     inc
                     (lambda (value)
                       (if (> value 3)
                         (flow-arr 'dynamic-double
                                   (lambda (current) (* current 2))
                                   'number
                                   'number)
                         (flow-arr 'dynamic-inc
                                   (lambda (current) (+ current 1))
                                   'number
                                   'number)))
                     'number))
             (receipt (flow->dag-receipt bound))
             (result (runner-run (kleisli-runner) bound 3))
             (root-receipt (run-result-receipt result))
             (kleisli-receipt (car (receipt-children root-receipt))))
        (check-equal? (flow-step-count bound) 1)
        (check-equal? (kleisli-alist-value 'node-count receipt) 1)
        (check-equal? (kleisli-alist-value 'node-ids receipt)
                      '((node bind-inc 0 kleisli bind-inc)))
        (check-equal? (run-result-value result) 8)
        (check-equal? (receipt-kind kleisli-receipt) 'kleisli)
        (check-equal? (receipt-status kleisli-receipt) 'ok)
        (check-equal? (length (receipt-children kleisli-receipt)) 2)))
    (poo-flow-test-case "rejects binders that do not return flows"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (bad (flow-bind 'bad-bind
                             inc
                             (lambda (_value) 'not-a-flow)
                             'number))
             (failure (try-control-plane
                       (lambda () (kleisli-run bad 3))
                       (lambda (failure) failure))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-code failure)
                      'invalid-kleisli-binder-result)))
    (poo-flow-test-case "authors bind flows with hygienic macros"
      (check-equal? (flow-name kleisli-macro-bound) 'kleisli-macro-bound)
      (check-equal? (flow-name kleisli-macro-kleisli) 'kleisli-macro-kleisli)
      (check-equal? (kleisli-run kleisli-macro-bound 3) 8)
      (check-equal? (kleisli-run kleisli-macro-kleisli 2) 6))))
