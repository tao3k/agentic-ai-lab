;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: makefile-tool runtime stages prove descriptor handoff behavior.
;;; Invariant: tests emulate runtime responses without executing Makefile work.

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
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/workflow/flows)

(export tutorial-makefile-runtime-test)

;; : (-> Alist Value ArtifactHandle RuntimeResponseAlist)
(def (makefile-runtime-response envelope value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id (cdr (assoc 'request-id envelope)))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((tutorial . makefile-runtime-stage)))))

;; : (-> Alist ExecutionRequest)
(def (makefile-envelope-request envelope)
  (cdr (assoc 'request envelope)))

;; : (-> ExecutionRequest Symbol)
(def (makefile-external-operation request)
  (cadr (execution-request-request request)))

;; : (-> ExecutionRequest Payload)
(def (makefile-external-payload request)
  (caddr (execution-request-request request)))

;; : (-> Alist Symbol Value Value)
(def (makefile-alist-ref alist key default)
  (let (entry (assoc key alist))
    (if entry (cdr entry) default)))

;;; Stage 17 uses the stdout-response boundary while preserving makefile-tool
;;; parse/run as separate external task operations.
;; : (-> Procedure Procedure ArgumentsBuilder)
(def (makefile-runtime-response-arguments record-parse record-run)
  (lambda (envelope)
    (let* ((request (makefile-envelope-request envelope))
           (operation (makefile-external-operation request))
           (payload (makefile-external-payload request)))
      (cond
       ((eq? operation 'makefile-tool-parse)
        (record-parse request)
        (let (plan (list (cons 'plan 'makefile-tool-plan)
                         (cons 'working-directory
                               (makefile-alist-ref payload
                                                   'working-directory
                                                   "."))
                         (cons 'makefile
                               (makefile-alist-ref payload
                                                   'makefile
                                                   "Makefile"))
                         (cons 'sources
                               (makefile-alist-ref payload 'sources '()))))
          (list
           (object->string
            (makefile-runtime-response
             envelope
             plan
             '(artifact stage-17-makefile-plan))))))
       ((eq? operation 'makefile-tool-run)
        (record-run request)
        (let* ((input (execution-request-input request))
               (plan (adapter-result-value input))
               (result
                (list (cons 'target
                            (makefile-alist-ref payload 'target ""))
                      (cons 'binary
                            (makefile-alist-ref payload 'binary ""))
                      (cons 'process-output
                            '(stdout "makefile-tool hello output"))
                      (cons 'plan-sources
                            (makefile-alist-ref plan 'sources '())))))
          (list
           (object->string
            (makefile-runtime-response
             envelope
             result
             '(artifact stage-17-hello-output))))))
       (else
        (list
         (object->string
          (makefile-runtime-response
           envelope
           '(unexpected-makefile-tool-operation)
           '(artifact unexpected-makefile-tool)))))))))

;;; Boundary:
;;; - Request envelopes are built from public task-adapter-request data.
;;; - Manifest tests do not depend on runner internals.
;; : (-> ExecutionRequest Symbol ArtifactHandle RuntimeRequestEnvelope)
(def (makefile-runtime-envelope request request-id artifact)
  (list (cons 'schema +runtime-request-schema+)
        (cons 'request-id request-id)
        (cons 'request request)
        (cons 'artifact-handle artifact)))

;; : Flow
(def macro-makefile-runtime-flow
  (make-makefile-tool-workflow 'macro-makefile-runtime-flow))

;; : RuntimeCommandDescriptor
(def macro-makefile-tool-cli
  (make-makefile-tool-runtime-command-descriptor
   'macro-makefile-tool-cli
   "/usr/bin/agentic-ai-lab-runtime"
   (list (cons 'runtime-name "agentic-ai-lab-runtime")
         (cons 'tutorial 'macro-stage))))

;;; This suite protects tutorial runtime receipts so documentation examples stay
;;; aligned with executable behavior.
;; : TestSuite
(def tutorial-makefile-runtime-test
  (test-suite "funflow makefile-tool runtime result ladder"
    (yuanxu-test-case "stage 17 descriptor command drives makefile tool workflow"
      (let ((seen-parse #f)
            (seen-run #f))
        (let* ((descriptor
                (make-makefile-tool-runtime-command-descriptor
                 'stage-17-makefile-tool-runtime
                 "/bin/echo"
                 (list (cons 'arguments
                             (makefile-runtime-response-arguments
                              (lambda (request) (set! seen-parse request))
                              (lambda (request) (set! seen-run request))))
                       (cons 'tutorial 'stage-17))))
               (runtime-command (runtime-command-descriptor->command descriptor))
               (config (make-rust-run-config
                        (list (cons 'runtime-command runtime-command))))
               (flow (make-makefile-tool-workflow 'makefile-tool-stage-17))
               (result (run-result-value
                        (run-flow-with-config config flow 'makefile-project)))
               (value (adapter-result-value result)))
          (check-equal? (runtime-command-descriptor-protocol descriptor)
                        'stdout-s-expression)
          (check-equal? (runtime-command-kind runtime-command) 'process)
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-artifact-handle result)
                        '(artifact stage-17-hello-output))
          (check-equal? (cdr (assoc 'process-output value))
                        '(stdout "makefile-tool hello output"))
          (check-equal? (cdr (assoc 'plan-sources value))
                        '("main.cpp" "hello.cpp" "factorial.cpp"))
          (check-equal? (makefile-external-operation seen-parse)
                        'makefile-tool-parse)
          (check-equal? (makefile-external-operation seen-run)
                        'makefile-tool-run)
          (check-equal? (adapter-result-artifact-handle
                         (execution-request-input seen-run))
                        '(artifact stage-17-makefile-plan)))))
    (yuanxu-test-case "stage 18 makefile tool descriptor manifest exposes rust cli handoff"
      (let* ((descriptor
              (make-makefile-tool-runtime-command-descriptor
               'stage-18-makefile-tool-cli
               "/usr/bin/agentic-ai-lab-runtime"
               (list (cons 'runtime-name "agentic-ai-lab-runtime")
                     (cons 'tutorial 'stage-18))))
             (flow (make-makefile-tool-workflow 'makefile-tool-stage-18))
             (parse-task (car (flow-steps flow)))
             (run-task (cadr (flow-steps flow)))
             (parse-request
              (task-adapter-request parse-task
                                    'makefile-project
                                    'makefile-tool-stage-18
                                    '(node makefile-tool-stage-18 0)
                                    '()
                                    'local-eager
                                    '()))
             (run-request
              (task-adapter-request run-task
                                    '(adapter-result makefile-plan)
                                    'makefile-tool-stage-18
                                    '(node makefile-tool-stage-18 1)
                                    '((node makefile-tool-stage-18 0))
                                    'local-eager
                                    '()))
             (parse-manifest
              (runtime-command-descriptor->manifest
               descriptor
               (makefile-runtime-envelope
                parse-request
                'stage-18-parse-request
                '(artifact stage-18-parse))))
             (run-manifest
              (runtime-command-descriptor->manifest
               descriptor
               (makefile-runtime-envelope
                run-request
                'stage-18-run-request
                '(artifact stage-18-run))))
             (parse-args (cdr (assoc 'arguments parse-manifest)))
             (run-args (cdr (assoc 'arguments run-manifest))))
        (check-equal? (cdr (assoc 'schema parse-manifest))
                      +runtime-command-descriptor-schema+)
        (check-equal? (cdr (assoc 'name parse-manifest))
                      'stage-18-makefile-tool-cli)
        (check-equal? (cdr (assoc 'executable parse-manifest))
                      "/usr/bin/agentic-ai-lab-runtime")
        (check-equal? (cdr (assoc 'metadata parse-manifest))
                      '((workflow . makefile-tool)
                        (runtime . rust-cli-compatible)
                        (runtime-name . "agentic-ai-lab-runtime")
                        (tutorial . stage-18)))
        (check-equal? (member "--operation" parse-args)
                      '("--operation"
                        "makefile-tool-parse"
                        "--working-directory"
                        "funflow-examples/makefile-tool/test"
                        "--makefile"
                        "Makefile"
                        "--sources"
                        "(\"main.cpp\" \"hello.cpp\" \"factorial.cpp\")"))
        (check-equal? (member "--operation" run-args)
                      '("--operation"
                        "makefile-tool-run"
                        "--target"
                        "hello"
                        "--binary"
                        "./hello"
                        "--expected-output"
                        "process-output"))
        (check-equal? (cdr (assoc 'argv run-manifest))
                      (cons "/usr/bin/agentic-ai-lab-runtime" run-args))))
    (yuanxu-test-case "authors makefile runtime descriptor with Gerbil macros"
      (let* ((parse-task (car (flow-steps macro-makefile-runtime-flow)))
             (parse-request
              (task-adapter-request parse-task
                                    'makefile-project
                                    'macro-makefile-runtime-flow
                                    '(node macro-makefile-runtime-flow 0)
                                    '()
                                    'local-eager
                                    '()))
             (manifest
              (runtime-command-descriptor->manifest
               macro-makefile-tool-cli
               (makefile-runtime-envelope
                parse-request
                'macro-parse-request
                '(artifact macro-parse))))
             (args (cdr (assoc 'arguments manifest))))
        (check-equal? (runtime-command-descriptor-name macro-makefile-tool-cli)
                      'macro-makefile-tool-cli)
        (check-equal? (cdr (assoc 'schema manifest))
                      +runtime-command-descriptor-schema+)
        (check-equal? (cdr (assoc 'metadata manifest))
                      '((workflow . makefile-tool)
                        (runtime . rust-cli-compatible)
                        (runtime-name . "agentic-ai-lab-runtime")
                        (tutorial . macro-stage)))
        (check-equal? (member "--operation" args)
                      '("--operation"
                        "makefile-tool-parse"
                        "--working-directory"
                        "funflow-examples/makefile-tool/test"
                        "--makefile"
                        "Makefile"
                        "--sources"
                        "(\"main.cpp\" \"hello.cpp\" \"factorial.cpp\")"))))))
