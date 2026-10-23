;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime tutorial stages prove Docker/Store handoff behavior.
;;; Invariant: these tests keep heavy runtime semantics behind command output.

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
        :agentic-ai-lab/modules/docker/interface
        :yuanxu/modules/funflow/store
        :agentic-ai-lab/modules/workflow/flows)

(export tutorial-runtime-result-test)

;; : (-> Alist Value ArtifactHandle RuntimeResponseAlist)
(def (tutorial-runtime-response envelope value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id (cdr (assoc 'request-id envelope)))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((tutorial . runtime-stage)))))

;; : (-> Alist ExecutionRequest)
(def (runtime-envelope-request envelope)
  (cdr (assoc 'request envelope)))

;; : (-> ExecutionRequest DockerConfig)
(def (runtime-docker-config request)
  (cadr (execution-request-request request)))

;; : (-> ExecutionRequest Symbol)
(def (runtime-store-operation request)
  (cadr (execution-request-request request)))

;; : (-> ExecutionRequest Payload)
(def (runtime-store-payload request)
  (caddr (execution-request-request request)))

;; : (-> DockerConfig Symbol Value Value)
(def (docker-config-ref config key default)
  (let (entry (assoc key config))
    (if entry (cdr entry) default)))

;; : (-> ExecutionRequest DockerConfig Value)
(def (ccompilation-visible-result request docker)
  (if (and (equal? (docker-config-ref docker 'image #f) "gcc:9.3.0")
           (equal? (docker-config-ref docker 'command #f) "gcc")
           (equal? (execution-request-input request) 3))
    15
    '(unexpected-ccompilation-request)))

;;; Stage 8 and 9 share runtime behavior; Stage 9 changes only how the command
;;; is declared, proving descriptors are the replaceable Rust CLI seam.
;; : (-> Procedure Procedure ArtifactHandle ArtifactHandle ArgumentsBuilder)
(def (docker-store-runtime-arguments record-docker record-store docker-artifact store-artifact)
  (lambda (envelope)
    (let (request (runtime-envelope-request envelope))
      (cond
       ((eq? (execution-request-kind request) 'docker)
        (record-docker request)
        (let* ((docker (runtime-docker-config request))
               (visible (ccompilation-visible-result request docker)))
          (list
           (object->string
            (tutorial-runtime-response envelope visible docker-artifact)))))
       ((eq? (execution-request-kind request) 'store)
        (record-store request)
        (let* ((input (execution-request-input request))
               (manifest
                (list
                 (cons 'operation (runtime-store-operation request))
                 (cons 'payload (runtime-store-payload request))
                 (cons 'input-value (adapter-result-value input))
                 (cons 'input-artifact (adapter-result-artifact-handle input)))))
          (list
           (object->string
            (tutorial-runtime-response envelope manifest store-artifact)))))
       (else
        (list
         (object->string
          (tutorial-runtime-response
           envelope
           '(unexpected-request-kind)
           '(artifact unexpected-runtime-request)))))))))

;;; This suite protects runtime result examples used by tutorial-level docs and
;;; downstream agent prompts.
;; : TestSuite
(def tutorial-runtime-result-test
  (test-suite "funflow tutorial runtime result ladder"
    (yuanxu-test-case "stage 7 docker process runtime command returns CCompilation visible result"
      (let (seen-request #f)
        (let* ((runtime-command
                (make-stdout-runtime-command
                 'stage-7-ccompilation
                 "/bin/echo"
                 (lambda (envelope)
                   (set! seen-request (runtime-envelope-request envelope))
                   (let* ((docker (runtime-docker-config seen-request))
                          (visible (ccompilation-visible-result seen-request docker)))
                     (list (object->string
                            (tutorial-runtime-response
                             envelope
                             visible
                             '(artifact ccompilation-output))))))
                 '((tutorial . stage-7))))
               (config (make-docker-run-config
                        (list (cons 'runtime-command runtime-command))))
               (flow (docker-flow 'compile-c
                                  "gcc:9.3.0"
                                  "gcc"
                                  '("/example/double.c" "/example/main.c" "-o" "/output/main")
                                  '(((store-item . example-src)
                                     (mount-path . "/example"))
                                    ((store-item . output-dir)
                                     (mount-path . "/output")))
                                  'process-handle
                                  'integer
                                  'integer))
               (result (run-result-value
                        (run-flow-with-config config flow 3)))
               (docker (runtime-docker-config seen-request)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-value result) 15)
          (check-equal? (adapter-result-artifact-handle result)
                        '(artifact ccompilation-output))
          (check-equal? (runtime-command-name runtime-command)
                        'stage-7-ccompilation)
          (check-equal? (runtime-command-kind runtime-command) 'process)
          (check-equal? (execution-request-kind seen-request) 'docker)
          (check-equal? (docker-config-ref docker 'image #f) "gcc:9.3.0")
          (check-equal? (docker-config-ref docker 'output-policy #f)
                        'process-handle))))
    (yuanxu-test-case "stage 8 docker artifact feeds store manifest"
      (let ((seen-docker #f)
            (seen-store #f))
        (let* ((runtime-command
                (make-stdout-runtime-command
                 'stage-8-docker-store
                 "/bin/echo"
                 (docker-store-runtime-arguments
                  (lambda (request) (set! seen-docker request))
                  (lambda (request) (set! seen-store request))
                  '(artifact stage-8-ccompilation-output)
                  '(artifact stage-8-store-manifest))
                 '((tutorial . stage-8))))
               (config (make-docker-store-run-config
                        (list (cons 'runtime-command runtime-command))))
               (compile-flow
                (docker-flow 'compile-c-stage-8
                             "gcc:9.3.0"
                             "gcc"
                             '("/example/double.c" "/example/main.c" "-o" "/output/main")
                             '(((store-item . example-src)
                                (mount-path . "/example"))
                               ((store-item . output-dir)
                                (mount-path . "/output")))
                             'process-handle
                             'integer
                             'process-handle))
               (store-output
                (store-flow 'store-c-binary
                            'put
                            '((store-item . c-binary)
                              (path . "/output/main"))
                            'process-handle
                            'artifact-manifest))
               (flow (flow-then 'compile-and-store compile-flow store-output))
               (result (run-result-value
                        (run-flow-with-config config flow 3)))
               (manifest (adapter-result-value result)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-artifact-handle result)
                        '(artifact stage-8-store-manifest))
          (check-equal? (cdr (assoc 'operation manifest)) 'put)
          (check-equal? (cdr (assoc 'payload manifest))
                        '((store-item . c-binary)
                          (path . "/output/main")))
          (check-equal? (cdr (assoc 'input-value manifest)) 15)
          (check-equal? (cdr (assoc 'input-artifact manifest))
                        '(artifact stage-8-ccompilation-output))
          (check-equal? (execution-request-kind seen-docker) 'docker)
          (check-equal? (execution-request-kind seen-store) 'store)
          (check-equal? (runtime-command-name runtime-command)
                        'stage-8-docker-store))))
    (yuanxu-test-case "stage 9 descriptor command drives docker store workflow"
      (let ((seen-docker #f)
            (seen-store #f))
        (let* ((descriptor
                (make-stdout-runtime-command-descriptor
                 'stage-9-docker-store-runtime
                 "/bin/echo"
                 (docker-store-runtime-arguments
                  (lambda (request) (set! seen-docker request))
                  (lambda (request) (set! seen-store request))
                  '(artifact stage-9-ccompilation-output)
                  '(artifact stage-9-store-manifest))
                 '((tutorial . stage-9)
                   (runtime . rust-cli-compatible))))
               (runtime-command (runtime-command-descriptor->command descriptor))
               (config (make-docker-store-run-config
                        (list (cons 'runtime-command runtime-command))))
               (compile-flow
                (docker-flow 'compile-c-stage-9
                             "gcc:9.3.0"
                             "gcc"
                             '("/example/double.c" "/example/main.c" "-o" "/output/main")
                             '(((store-item . example-src)
                                (mount-path . "/example"))
                               ((store-item . output-dir)
                                (mount-path . "/output")))
                             'process-handle
                             'integer
                             'process-handle))
               (store-output
                (store-flow 'store-c-binary-stage-9
                            'put
                            '((store-item . c-binary-stage-9)
                              (path . "/output/main"))
                            'process-handle
                            'artifact-manifest))
               (flow (flow-then 'compile-and-store-stage-9
                                compile-flow
                                store-output))
               (result (run-result-value
                        (run-flow-with-config config flow 3)))
               (manifest (adapter-result-value result)))
          (check-equal? (runtime-command-descriptor-protocol descriptor)
                        'stdout-s-expression)
          (check-equal? (runtime-command-descriptor-executable descriptor)
                        "/bin/echo")
          (check-equal? (runtime-command-kind runtime-command) 'process)
          (check-equal? (cdr (assoc 'protocol
                                    (runtime-command-metadata runtime-command)))
                        'stdout-s-expression)
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-artifact-handle result)
                        '(artifact stage-9-store-manifest))
          (check-equal? (cdr (assoc 'operation manifest)) 'put)
          (check-equal? (cdr (assoc 'input-value manifest)) 15)
          (check-equal? (cdr (assoc 'input-artifact manifest))
                        '(artifact stage-9-ccompilation-output))
          (check-equal? (execution-request-kind seen-docker) 'docker)
          (check-equal? (execution-request-kind seen-store) 'store)
          (check-equal? (runtime-command-name runtime-command)
                        'stage-9-docker-store-runtime))))
    (yuanxu-test-case "stage 10 descriptor manifest exposes rust cli handoff"
      (let* ((descriptor
              (make-stdout-runtime-command-descriptor
               'stage-10-rust-cli
               "/usr/bin/agentic-ai-lab-runtime"
               (lambda (envelope)
                 (list "run"
                       "--request-id"
                       (symbol->string (cdr (assoc 'request-id envelope)))
                       "--response-protocol"
                       "stdout-s-expression"))
               '((tutorial . stage-10)
                 (runtime . rust-cli-compatible))))
             (envelope
              (list (cons 'schema +runtime-request-schema+)
                    (cons 'request-id 'stage-10-request)
                    (cons 'request '(docker-store workflow))
                    (cons 'artifact-handle '(artifact stage-10-output))))
             (manifest (runtime-command-descriptor->manifest descriptor envelope)))
        (check-equal? (cdr (assoc 'schema manifest))
                      +runtime-command-descriptor-schema+)
        (check-equal? (cdr (assoc 'request-schema manifest))
                      +runtime-request-schema+)
        (check-equal? (cdr (assoc 'name manifest)) 'stage-10-rust-cli)
        (check-equal? (cdr (assoc 'protocol manifest)) 'stdout-s-expression)
        (check-equal? (cdr (assoc 'executable manifest))
                      "/usr/bin/agentic-ai-lab-runtime")
        (check-equal? (cdr (assoc 'arguments manifest))
                      '("run"
                        "--request-id"
                        "stage-10-request"
                        "--response-protocol"
                        "stdout-s-expression"))
        (check-equal? (cdr (assoc 'argv manifest))
                      '("/usr/bin/agentic-ai-lab-runtime"
                        "run"
                        "--request-id"
                        "stage-10-request"
                        "--response-protocol"
                        "stdout-s-expression"))
        (check-equal? (cdr (assoc 'metadata manifest))
                      '((tutorial . stage-10)
                        (runtime . rust-cli-compatible)))))))
