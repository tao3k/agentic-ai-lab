;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime bridge tests cover schema envelopes, not real Rust IO.
;;; Invariant: Scheme emits deterministic request/response data for adapters.

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
        :poo-flow/modules/workflow/control-plane/api
        :poo-flow/modules/workflow/store)

(export runtime-bridge-test)

;;; This suite protects runtime bridge receipts as data contracts between
;;; Scheme control-plane code and external runtimes.
(def runtime-bridge-test
  (test-suite "runtime bridge schema"
    (poo-flow-test-case "rust submit envelope carries schema and correlation ids"
      (let* ((flow (external-flow 'compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config (make-store-rust-run-config)
                                           flow
                                           'input-artifact))
             (adapter-result (run-result-value result))
             (envelope (adapter-result-value adapter-result)))
        (check-equal? (cdr (assoc 'schema envelope)) +runtime-request-schema+)
        (check-equal? (cdr (assoc 'operation envelope)) 'submit)
        (check-equal? (cdr (assoc 'request-id envelope))
                      '(rust-request compile external))
        (check-equal? (cdr (assoc 'artifact-handle envelope))
                      '(rust-artifact compile (node compile 0 external compile)))))
    (poo-flow-test-case "rust store put envelope preserves operation"
      (let* ((flow (store-flow 'put-cache
                               'put
                               '((path . "target"))
                               'artifact
                               'artifact))
             (result (run-flow-with-config (make-store-rust-run-config)
                                           flow
                                           'input-artifact))
             (adapter-result (run-result-value result))
             (envelope (adapter-result-value adapter-result)))
        (check-equal? (cdr (assoc 'schema envelope)) +runtime-request-schema+)
        (check-equal? (cdr (assoc 'operation envelope)) 'store-put)
        (check-equal? (cdr (assoc 'request-id envelope))
                      '(rust-request put-cache store))))
    (poo-flow-test-case "adapter results project to runtime response schema"
      (let* ((adapter-result (make-adapter-result '(runtime-request 1)
                                                  'submitted
                                                  'payload
                                                  '(artifact 1)
                                                  #f))
             (response (adapter-result->runtime-response
                        adapter-result
                        '((runtime . rust))))
             (shape (runtime-response->alist response)))
        (check-equal? (cdr (assoc 'schema shape)) +runtime-response-schema+)
        (check-equal? (cdr (assoc 'request-id shape)) '(runtime-request 1))
        (check-equal? (cdr (assoc 'status shape)) 'submitted)
        (check-equal? (cdr (assoc 'artifact-handle shape)) '(artifact 1))
        (check-equal? (cdr (assoc 'runtime (cdr (assoc 'metadata shape))))
                      'rust)))
    (poo-flow-test-case "configured rust command normalizes runtime response"
      (let (seen #f)
        (let* ((command
                (lambda (envelope)
                  (set! seen envelope)
                  (list (cons 'schema +runtime-response-schema+)
                        (cons 'request-id (cdr (assoc 'request-id envelope)))
                        (cons 'status 'completed)
                        (cons 'value 'runtime-output)
                        (cons 'artifact-handle '(artifact runtime-output))
                        (cons 'error #f)
                        (cons 'metadata '((runtime . rust-command))))))
               (runtime-command
                (make-procedure-runtime-command 'test-rust-command
                                                command
                                                '((test . runtime-bridge))))
               (config (make-rust-run-config
                        (list (cons 'runtime-command runtime-command))))
               (flow (external-flow 'compile
                                    'rust-build
                                    '((crate . "poo-flow"))
                                    'artifact
                                    'artifact))
               (result (run-flow-with-config config flow 'input-artifact))
               (adapter-result (run-result-value result)))
          (check-equal? (cdr (assoc 'operation seen)) 'submit)
          (check-equal? (runtime-command? runtime-command) #t)
          (check-equal? (runtime-command-kind runtime-command) 'procedure)
          (check-equal? (cdr (assoc 'test (runtime-command-metadata runtime-command)))
                        'runtime-bridge)
          (check-equal? (adapter-result-status adapter-result) 'completed)
          (check-equal? (adapter-result-request-id adapter-result)
                        '(rust-request compile external))
          (check-equal? (adapter-result-value adapter-result) 'runtime-output)
          (check-equal? (adapter-result-artifact-handle adapter-result)
                        '(artifact runtime-output)))))
    (poo-flow-test-case "process runtime command captures stdout through response decoder"
      (let* ((runtime-command
              (make-process-runtime-command
               'echo-runtime-command
               "/bin/echo"
               (lambda (envelope)
                 (list "runtime-output"))
               (lambda (envelope stdout)
                 (list (cons 'schema +runtime-response-schema+)
                       (cons 'request-id (cdr (assoc 'request-id envelope)))
                       (cons 'status 'completed)
                       (cons 'value stdout)
                       (cons 'artifact-handle '(artifact process-runtime-output))
                       (cons 'error #f)
                       (cons 'metadata '((runtime . process-command)))))
               '((test . runtime-bridge))))
             (config (make-rust-run-config
                      (list (cons 'runtime-command runtime-command))))
             (flow (external-flow 'compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result)))
        (check-equal? (runtime-command-kind runtime-command) 'process)
        (check-equal? (cdr (assoc 'executable
                                  (runtime-command-metadata runtime-command)))
                      "/bin/echo")
        (check-equal? (adapter-result-status adapter-result) 'completed)
        (check-equal? (adapter-result-value adapter-result) "runtime-output\n")
        (check-equal? (adapter-result-artifact-handle adapter-result)
                      '(artifact process-runtime-output))))
    (poo-flow-test-case "stdout runtime command reads runtime response s-expression"
      (let* ((runtime-command
              (make-stdout-runtime-command
               'stdout-runtime-command
               "/bin/echo"
               (lambda (envelope)
                 (list (object->string
                        (list (cons 'schema +runtime-response-schema+)
                              (cons 'request-id (cdr (assoc 'request-id envelope)))
                              (cons 'status 'completed)
                              (cons 'value 'stdout-output)
                              (cons 'artifact-handle '(artifact stdout-runtime-output))
                              (cons 'error #f)
                              (cons 'metadata '((runtime . stdout-command)))))))
               '((test . runtime-bridge))))
             (config (make-rust-run-config
                      (list (cons 'runtime-command runtime-command))))
             (flow (external-flow 'compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result)))
        (check-equal? (runtime-command-kind runtime-command) 'process)
        (check-equal? (adapter-result-status adapter-result) 'completed)
        (check-equal? (adapter-result-value adapter-result) 'stdout-output)
        (check-equal? (adapter-result-artifact-handle adapter-result)
                      '(artifact stdout-runtime-output))))
    (poo-flow-test-case "stdout runtime command descriptor materializes process command"
      (let* ((descriptor
              (make-stdout-runtime-command-descriptor
               'descriptor-runtime-command
               "/bin/echo"
               (lambda (envelope)
                 (list (object->string
                        (list (cons 'schema +runtime-response-schema+)
                              (cons 'request-id (cdr (assoc 'request-id envelope)))
                              (cons 'status 'completed)
                              (cons 'value 'descriptor-output)
                              (cons 'artifact-handle '(artifact descriptor-output))
                              (cons 'error #f)
                              (cons 'metadata '((runtime . descriptor)))))))
               '((test . runtime-bridge))))
             (runtime-command (runtime-command-descriptor->command descriptor))
             (config (make-rust-run-config
                      (list (cons 'runtime-command runtime-command))))
             (flow (external-flow 'descriptor-compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result)))
        (check-equal? (runtime-command-descriptor-protocol descriptor)
                      'stdout-s-expression)
        (check-equal? (runtime-command-kind runtime-command) 'process)
        (check-equal? (cdr (assoc 'protocol
                                  (runtime-command-metadata runtime-command)))
                      'stdout-s-expression)
        (check-equal? (adapter-result-status adapter-result) 'completed)
        (check-equal? (adapter-result-value adapter-result) 'descriptor-output)
        (check-equal? (adapter-result-artifact-handle adapter-result)
                      '(artifact descriptor-output))))
    (poo-flow-test-case "invalid runtime command response fails through adapter result"
      (let* ((command (lambda (envelope) 'not-a-runtime-response))
             (config (make-rust-run-config
                      (list (cons 'runtime-command command))))
             (flow (external-flow 'compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result)))
        (check-equal? (adapter-result-status adapter-result) 'failed)
        (check-equal? (cdr (assoc 'code (adapter-result-error adapter-result)))
                      'invalid-runtime-response)))
    (poo-flow-test-case "invalid runtime command descriptor fails through adapter result"
      (let* ((config (make-rust-run-config
                      (list (cons 'runtime-command '(not-a-runtime-command)))))
             (flow (external-flow 'compile
                                  'rust-build
                                  '((crate . "poo-flow"))
                                  'artifact
                                  'artifact))
             (result (run-flow-with-config config flow 'input-artifact))
             (adapter-result (run-result-value result)))
        (check-equal? (adapter-result-status adapter-result) 'failed)
        (check-equal? (cdr (assoc 'code (adapter-result-error adapter-result)))
                      'invalid-runtime-command)))))
