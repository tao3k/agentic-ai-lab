;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: failure tests cover typed control-plane payloads.
;;; Invariant: tests inspect failure structs, not exception message text.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :poo-flow/modules/workflow/control-plane/api)

(export failure-test)

;;; Failure capture keeps the tests on structured control-plane values instead
;;; of process exits or rendered messages.
;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;; failure-test-values/tail
;;   : (forall (a) (-> [a] [a] [a]))
;;   | doc m%
;;       Merge captured failure output fragments into the accumulated test tail
;;       without changing their observation order.
;;
;;       # Examples
;;       ```scheme
;;       (failure-test-values/tail '(failure) '(tail))
;;       ;; => (failure tail)
;;       ```
;;     %
(def (failure-test-values/tail values tail)
  (append values tail))

;;; Submit failure fixture preserves the request kind so receipt wrapping can be
;;; checked after the adapter reports failure.
;; : (-> ExecutionRequest AdapterResult)
(def (failing-submit request)
  (make-adapter-result '(failing-request)
                       'failed
                       #f
                       #f
                       (list (cons 'reason 'boom)
                             (cons 'request-kind (execution-request-kind request)))))

;;; Runtime slot failure fixture keeps value propagation visible when the runner
;;; converts backend failures into typed execution failures.
;; : (-> Value AdapterResult)
(def (failing-runtime-slot value)
  (make-adapter-result '(failing-slot)
                       'failed
                       #f
                       value
                       (list (cons 'reason 'boom))))

;;; Failing adapter slots let the runner exercise receipt failure wrapping
;;; without requiring the Rust runtime to exist in the Scheme test process.
;; : (-> RuntimeAdapter)
(def (make-failing-adapter)
  (make-runtime-adapter 'failing
                        '(external)
                        failing-submit
                        failing-runtime-slot
                        failing-submit
                        failing-runtime-slot))

;;; This suite locks structured failure payloads so policy callers can inspect
;;; errors without scraping text output.
;; : TestSuite
(def failure-test
  (test-suite "typed control-plane failures"
    (poo-flow-test-case "raises structured failure for unknown task family"
      (let (failure (capture-control-plane-failure
                     (lambda ()
                       (task-family-for-kind-in default-task-family-registry
                                                'unknown-runtime))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'task-registry)
        (check-equal? (execution-failure-code failure) 'unknown-task-family)
        (check-equal? (cdr (assoc 'kind (execution-failure-detail failure)))
                      'unknown-runtime)))
    (poo-flow-test-case "raises structured failure for unsupported planner"
      (let* ((descriptor (make-flow-declaration-descriptor
                          'unsupported-task-flow
                          'task
                          'unsupported-planner
                          'extension))
             (registry (make-flow-declaration-registry
                        'unsupported-flow-declarations
                        (list descriptor)))
             (flow (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (failure (capture-control-plane-failure
                       (lambda ()
                         (strategy-planner-for-flow-in
                          (make-local-eager-strategy)
                          registry
                          flow)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'strategy)
        (check-equal? (execution-failure-code failure) 'unsupported-flow-planner)
        (check-equal? (cdr (assoc 'planner (execution-failure-detail failure)))
                      'unsupported-planner)))
    (poo-flow-test-case "raises structured failure for missing dependency value"
      (let* ((task (make-pure-task 'inc (lambda (x) (+ x 1)) 'number 'number))
             (node (make-plan-node '(node malformed 0 pure inc)
                                   0
                                   task
                                   'pure
                                   'inc
                                   '((node missing 99 pure missing))))
             (plan (make-execution-plan 'malformed (list node) 'number 'number))
             (strategy (make-strategy 'malformed-plan
                                      '(pure graph-frontier)
                                      'no-cache
                                      'fail-fast
                                      (lambda (flow) plan)))
             (config (make-run-config 'malformed-plan
                                      strategy
                                      (make-request-only-adapter)
                                      '((runtime . request-only))))
             (flow (pure-flow 'ignored (lambda (x) x) 'number 'number))
             (failure (capture-control-plane-failure
                       (lambda ()
                         (run-flow-with-config config flow 1)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'runner)
        (check-equal? (execution-failure-code failure) 'missing-dependency-value)
        (check-equal? (cdr (assoc 'node-id (execution-failure-detail failure)))
                      '(node missing 99 pure missing))))
    (poo-flow-test-case "raises structured failure for unsupported adapter operation"
      (let* ((descriptor (make-task-family-descriptor 'custom
                                                      'external
                                                      'adapter
                                                      'rust-or-external-runtime
                                                      'custom-dispatch))
             (registry (make-task-family-registry
                        'custom-task-families
                        (failure-test-values/tail
                         task-family-descriptors
                         (list descriptor))))
             (task (make-task 'remote-custom
                              'custom
                              '(remote custom)
                              'value
                              'value
                              #f))
             (flow (flow-compose 'custom-flow (list task) 'value 'value))
             (config (make-run-config 'custom-dispatch
                                      (make-local-eager-strategy)
                                      (make-request-only-adapter)
                                      '((runtime . request-only))
                                      registry
                                      default-flow-declaration-registry))
             (failure (capture-control-plane-failure
                       (lambda ()
                         (run-flow-with-config config flow 'input)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'runner)
        (check-equal? (execution-failure-code failure) 'unsupported-adapter-operation)
        (check-equal? (cdr (assoc 'operation (execution-failure-detail failure)))
                      'custom-dispatch)))
    (poo-flow-test-case "wraps adapter result errors in receipt failures"
      (let* ((flow (external-flow 'remote 'submit '((payload . value)) 'value 'value))
             (config (make-run-config 'failing
                                      (make-local-eager-strategy)
                                      (make-failing-adapter)
                                      '((runtime . failing))))
             (result (run-flow-with-config config flow 'input))
             (child (car (receipt-children (run-result-receipt result))))
             (failure (receipt-error child)))
        (check-equal? (receipt-status child) 'failed)
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'runtime-adapter)
        (check-equal? (execution-failure-code failure) 'adapter-failure)
        (check-equal? (cdr (assoc 'adapter (execution-failure-detail failure)))
                      'failing)))
    (poo-flow-test-case "projects local and adapter failures into try-result values"
      (let* ((runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (flow (throw-string-flow 'throw-demo
                                      "try-result local failure"
                                      'unit
                                      'unit))
             (result (runner-run-either runner flow #!void))
             (failure (try-result-value result)))
        (check-equal? (try-left? result) #t)
        (check-equal? (execution-failure-code failure) 'thrown-string)
        (check-equal? (execution-failure-message failure)
                      "try-result local failure"))
      (let* ((flow (external-flow 'remote 'submit '((payload . value)) 'value 'value))
             (config (make-run-config 'failing
                                      (make-local-eager-strategy)
                                      (make-failing-adapter)
                                      '((runtime . failing))))
             (result (runner-run-either (run-config->runner config)
                                        flow
                                        'input))
             (failure (try-result-value result)))
        (check-equal? (try-left? result) #t)
        (check-equal? (execution-failure-owner failure) 'runtime-adapter)
        (check-equal? (execution-failure-code failure) 'adapter-failure))
      (let* ((flow (pure-flow 'ok (lambda (value) value) 'value 'value))
             (result (runner-run-either (make-runner (make-local-eager-strategy)
                                                     (make-request-only-adapter))
                                        flow
                                        'done)))
        (check-equal? (try-right? result) #t)
        (check-equal? (try-result-value result) 'done)))))
