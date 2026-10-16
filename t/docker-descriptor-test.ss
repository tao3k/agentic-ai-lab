;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Docker descriptor tests cover tutorial-shaped request data only.
;;; Invariant: Scheme never pulls images, mounts volumes, or executes Docker.

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
        :poo-flow/modules/docker/interface
        :poo-flow/modules/agent-sandbox/resource)

(export docker-descriptor-test)

;; : (-> Value Alist AdapterResult)
(def (runtime-result value artifact)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id '(runtime docker-test))
        (cons 'status 'completed)
        (cons 'value value)
        (cons 'artifact-handle artifact)
        (cons 'error #f)
        (cons 'metadata '((runtime . docker-descriptor-test)))))

;; : (-> ExecutionRequest Alist)
(def (request-config request)
  (cadr (execution-request-request request)))

;;; This suite protects Docker descriptor shape while sandbox execution remains
;;; outside the Scheme unit-test boundary.
;; : TestSuite
(def docker-descriptor-test
  (test-suite "docker task descriptor"
    (poo-flow-test-case "captures CCompilation-style docker payload"
      (let (seen-request #f)
        (let* ((command (lambda (envelope)
                          (set! seen-request (cdr (assoc 'request envelope)))
                          (runtime-result 15 '(artifact ccompilation-output))))
               (config (make-docker-run-config
                        (list (cons 'runtime-command command))))
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
                                  'process-handle))
               (result (run-result-value
                        (run-flow-with-config config flow 3)))
               (docker (request-config seen-request)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-value result) 15)
          (check-equal? (execution-request-kind seen-request) 'docker)
          (check-equal? (cdr (assoc 'image docker)) "gcc:9.3.0")
          (check-equal? (cdr (assoc 'command docker)) "gcc")
          (check-equal? (cdr (assoc 'output-policy docker)) 'process-handle))))
    (poo-flow-test-case "captures ExternalConfig-style rendered arguments"
      (let (seen-request #f)
        (let* ((source (list (cons 'env
                                   (list (cons 'SECOND_GREETING "I'm from an env var!")))
                             (cons 'file
                                   (list (cons 'ourMessage "Hello from the flow.yaml")))))
               (arguments (list (make-config-argument 'file 'ourMessage #f)
                                (make-config-argument 'env 'SECOND_GREETING #f)
                                (make-config-argument 'placeholder 'par3 #f)))
               (rendered (render-config-arguments source arguments))
               (command (lambda (envelope)
                          (set! seen-request (cdr (assoc 'request envelope)))
                          (runtime-result "Hello from the flow.yaml I'm from an env var! hello-from-placeholder"
                                          '(artifact external-config-output))))
               (config (make-docker-run-config
                        (list (cons 'runtime-command command))))
               (flow (docker-flow 'configured-echo
                                  "alpine:latest"
                                  "echo"
                                  rendered
                                  '()
                                  'empty-store-item
                                  'unit
                                  'artifact))
               (result (run-result-value
                        (run-flow-with-config config flow #!void)))
               (docker (request-config seen-request)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-value result)
                        "Hello from the flow.yaml I'm from an env var! hello-from-placeholder")
          (check-equal? (cdr (assoc 'image docker)) "alpine:latest")
          (check-equal? (cdr (assoc 'command docker)) "echo")
          (check-equal? (cdr (assoc 'args docker))
                        '("Hello from the flow.yaml"
                          "I'm from an env var!"
                          ((placeholder . par3)))))))
    (poo-flow-test-case "merges DockerTaskInput with left-biased bindings and args"
      (let* ((left (make-docker-task-input
                    (list (make-sandbox-volume-binding 'source-item "/work" 'read)
                          (make-sandbox-volume-binding 'config-item "/config" 'read))
                    (list (cons 'message "hello")
                          (cons 'mode "left"))))
             (right (make-docker-task-input
                     (list (make-sandbox-volume-binding 'other-source "/work" 'read)
                           (make-sandbox-volume-binding 'cache-item "/cache" 'read))
                     (list (cons 'message "ignored")
                           (cons 'count "3"))))
             (merged (docker-task-input-merge left right))
             (request (docker-task-input->request merged)))
        (check-equal? (cdr (assoc 'input-bindings request))
                      '(((store-item . source-item)
                         (mount-path . "/work")
                         (mode . read)
                         (read-only? . #t))
                        ((store-item . config-item)
                         (mount-path . "/config")
                         (mode . read)
                         (read-only? . #t))
                        ((store-item . cache-item)
                         (mount-path . "/cache")
                         (mode . read)
                         (read-only? . #t))))
        (check-equal? (cdr (assoc 'args-vals request))
                      '((message . "hello")
                        (mode . "left")
                        (count . "3")))))
    (poo-flow-test-case "exposes Funflow dockerFlow-shaped task input boundary"
      (let* ((flow (docker-task-flow 'parameterized-docker
                                     "alpine:latest"
                                     "echo"
                                     (list "fixed" (list (cons 'placeholder 'message)))))
             (task (car (flow-steps flow)))
             (input (make-docker-task-input
                     (list (make-sandbox-volume-binding 'script-item "/script" 'read))
                     (list (cons 'message "hello"))))
             (receipt (docker-flow->task-input-receipt flow input)))
        (check-equal? (task-input-contract task) 'docker-task-input)
        (check-equal? (task-output-contract task) 'cas-item)
        (check-equal? (task-docker-volumes task) '())
        (check-equal? (docker-task-input-receipt-schema receipt)
                      +docker-task-input-receipt-schema+)
        (check-equal? (docker-task-input-receipt-flow receipt)
                      'parameterized-docker)
        (check-equal? (docker-task-input-receipt-image receipt)
                      "alpine:latest")
        (check-equal? (docker-task-input-receipt-command receipt)
                      "echo")
        (check-equal? (docker-task-input-receipt-args receipt)
                      '("fixed" ((placeholder . message))))
        (check-equal? (docker-task-input-receipt-input-bindings receipt)
                      '(((store-item . script-item)
                         (mount-path . "/script")
                         (mode . read)
                         (read-only? . #t))))
        (check-equal? (docker-task-input-receipt-args-vals receipt)
                      '((message . "hello")))
        (check-equal? (docker-task-input-receipt-output-policy receipt)
                      'cas-item)
        (check-equal? (docker-task-input-receipt-runtime-executed receipt)
                      #f)))
    (poo-flow-test-case "passes DockerTaskInput through runtime request envelope"
      (let (seen-request #f)
        (let* ((command (lambda (envelope)
                          (set! seen-request (cdr (assoc 'request envelope)))
                          (runtime-result '(cas item out) '(artifact docker-output))))
               (config (make-docker-run-config
                        (list (cons 'runtime-command command))))
               (flow (docker-task-flow 'docker-input-flow
                                       "alpine:latest"
                                       "cat"
                                       (list (list (cons 'placeholder 'filename)))))
               (input (make-docker-task-input
                       (list (make-sandbox-volume-binding 'text-item "/input" 'read))
                       (list (cons 'filename "/input/message.txt"))))
               (result (run-result-value
                        (run-flow-with-config config flow input)))
               (docker (request-config seen-request)))
          (check-equal? (adapter-result-status result) 'completed)
          (check-equal? (adapter-result-value result) '(cas item out))
          (check-equal? (execution-request-kind seen-request) 'docker)
          (check-equal? (execution-request-input seen-request) input)
          (check-equal? (cdr (assoc 'image docker)) "alpine:latest")
          (check-equal? (cdr (assoc 'output-policy docker)) 'cas-item))))))
