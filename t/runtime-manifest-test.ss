;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime manifest tests cover durable CLI handoff consumption.
;;; Invariant: manifests remain request-bound so Rust can run the same argv.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/modules/funflow/control-plane/api)

(export runtime-manifest-test)

;;; This suite keeps runtime manifest projection stable for downstream runtime
;;; selection and diagnostic tooling.
;; : TestSuite
(def runtime-manifest-test
  (test-suite "runtime command manifest"
    (yuanxu-test-case "runtime command descriptor exports cli manifest"
      (let* ((descriptor
              (make-stdout-runtime-command-descriptor
               'manifest-runtime-command
               "/usr/bin/agentic-ai-lab-runtime"
               (lambda (envelope)
                 (list "--request-id"
                       (symbol->string (cdr (assoc 'request-id envelope)))))
               '((runtime . rust-cli))))
             (envelope
              (list (cons 'schema +runtime-request-schema+)
                    (cons 'request-id 'manifest-request)
                    (cons 'request '(runtime manifest))
                    (cons 'artifact-handle '(artifact manifest-output))))
             (manifest (runtime-command-descriptor->manifest descriptor envelope)))
        (check-equal? (cdr (assoc 'schema manifest))
                      +runtime-command-descriptor-schema+)
        (check-equal? (cdr (assoc 'request-schema manifest))
                      +runtime-request-schema+)
        (check-equal? (cdr (assoc 'request-id manifest)) 'manifest-request)
        (check-equal? (cdr (assoc 'artifact-handle manifest))
                      '(artifact manifest-output))
        (check-equal? (cdr (assoc 'protocol manifest)) 'stdout-s-expression)
        (check-equal? (cdr (assoc 'executable manifest))
                      "/usr/bin/agentic-ai-lab-runtime")
        (check-equal? (cdr (assoc 'arguments manifest))
                      '("--request-id" "manifest-request"))
        (check-equal? (cdr (assoc 'argv manifest))
                      '("/usr/bin/agentic-ai-lab-runtime"
                        "--request-id"
                        "manifest-request"))))
    (yuanxu-test-case "runtime command manifest consumer executes stdout protocol"
      (let* ((envelope
              (list (cons 'schema +runtime-request-schema+)
                    (cons 'operation 'submit)
                    (cons 'request-id 'manifest-consumer-request)
                    (cons 'request '(runtime manifest consumer))
                    (cons 'artifact-handle '(artifact manifest-consumer-output))
                    (cons 'policy '((runtime . manifest-consumer)))
                    (cons 'plan-id 'manifest-plan)
                    (cons 'node-id '(node manifest 0 external runtime))
                    (cons 'frontier '())))
             (descriptor
              (make-stdout-runtime-command-descriptor
               'manifest-consumer-command
               "/bin/echo"
               (lambda (_envelope)
                 (list (object->string
                        (list (cons 'schema +runtime-response-schema+)
                              (cons 'request-id 'manifest-consumer-request)
                              (cons 'status 'completed)
                              (cons 'value 'manifest-consumed)
                              (cons 'artifact-handle
                                    '(artifact manifest-consumer-output))
                              (cons 'error #f)
                              (cons 'metadata
                                    '((runtime . manifest-consumer)))))))))
             (manifest (runtime-command-descriptor->manifest descriptor envelope))
             (command (runtime-command-manifest->command manifest))
             (adapter-result (run-runtime-command-manifest manifest))
             (command-result (runtime-command-call command envelope)))
        (check-equal? (runtime-command-manifest? manifest) #t)
        (check-equal? (runtime-command-manifest-argv manifest)
                      (cdr (assoc 'argv manifest)))
        (check-equal? (cdr (assoc 'runtime
                                  (runtime-command-manifest-envelope manifest)))
                      'manifest)
        (check-equal? (runtime-command-kind command) 'procedure)
        (check-equal? (adapter-result-status adapter-result) 'completed)
        (check-equal? (adapter-result-value adapter-result) 'manifest-consumed)
        (check-equal? (adapter-result-artifact-handle adapter-result)
                      '(artifact manifest-consumer-output))
        (check-equal? (adapter-result-status command-result) 'completed)))
    (yuanxu-test-case "runtime command manifest rejects unsupported protocol"
      (let* ((manifest
              (list (cons 'schema +runtime-command-descriptor-schema+)
                    (cons 'request-schema +runtime-request-schema+)
                    (cons 'request-id 'bad-manifest-request)
                    (cons 'artifact-handle '(artifact bad-manifest))
                    (cons 'name 'bad-manifest-command)
                    (cons 'protocol 'json-lines)
                    (cons 'executable "/bin/echo")
                    (cons 'arguments '())
                    (cons 'argv '("/bin/echo"))
                    (cons 'metadata '())))
             (adapter-result (run-runtime-command-manifest manifest)))
        (check-equal? (adapter-result-status adapter-result) 'failed)
        (check-equal? (adapter-result-request-id adapter-result)
                      'bad-manifest-request)
        (check-equal? (cdr (assoc 'code (adapter-result-error adapter-result)))
                      'unsupported-runtime-command-manifest-protocol)))))
