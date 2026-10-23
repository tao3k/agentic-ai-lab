;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tutorial feature batch tests public APIs, not test-local helpers.
;;; Invariant: each case maps to a visible Funflow notebook result or descriptor.

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
        :agentic-ai-lab/modules/custom-task/interface
        :agentic-ai-lab/modules/docker/interface
        :agentic-ai-lab/modules/text/interface
        :agentic-ai-lab/modules/workflow/flows
        :yuanxu/modules/funflow/store)

;; : (-> RunConfig Flow Input Value)
(def (configured-run config flow input)
  (run-result-value (run-flow-with-config config flow input)))

;; : (-> Flow Input Value)
(def (local-run flow input)
  (run-result-value
   (runner-run
    (make-runner (make-local-eager-strategy)
                 (make-request-only-adapter))
    flow
    input)))

;; These fixtures exercise the public constructors directly.  Naming a value
;; does not require a second macro language or a compile-time binding layer.
;; : Flow
(def macro-custom-repeat
  (custom-repeat-flow 'macro-custom-repeat "woop!" 7 'string 'string))

;; : Flow
(def macro-docker-compile
  (docker-flow
   'macro-docker-compile
   "gcc:9.3.0"
   "gcc"
   '("/example/main.c" "-o" "/output/main")
   '(((store-item . example-src)
      (mount-path . "/example"))
     ((store-item . output-dir)
      (mount-path . "/output")))
   'process-handle
   'integer
   'process-handle))

;; : Flow
(def macro-store-put
  (store-flow
   'macro-store-put
   'put
   '((store-item . macro-output)
     (path . "/output/main"))
   'process-handle
   'artifact-manifest))

;; : Flow
(def macro-ccompilation-store
  (make-ccompilation-store-workflow 'macro-ccompilation-store))

;; : Flow
(def macro-tensorflow
  (make-tensorflow-workflow 'macro-tensorflow))

;; : Flow
(def macro-makefile-tool
  (make-makefile-tool-workflow 'macro-makefile-tool))

(export tutorial-feature-batch-test)

(def tutorial-feature-batch-test
  (test-suite "funflow tutorial feature batch"
    (yuanxu-test-case "stage 11 quick reference conditional and cached increment run"
      (let* ((limited-increment
              (conditional-flow 'limited-increment
                                (lambda (n) (< n 10))
                                (lambda (n) (+ n 1))
                                (lambda (_n) 0)
                                'number
                                'number))
             (limited-three
              (flow-then 'limited-three
                         (flow-then 'limited-two
                                    limited-increment
                                    limited-increment)
                         limited-increment)))
        (check-equal? (local-run limited-three 9) 1))
      (let (increments 0)
        (let* ((reset (pure-flow 'reset
                                 (lambda (_input) 0)
                                 'number
                                 'number))
               (cached-increment
                (cached-scheme-flow
                 'cached-increment
                 (lambda (input) input)
                 (lambda (input)
                   (set! increments (+ increments 1))
                   (+ input 1))
                 'number
                 'number))
               (flow (flow-then 'cached-twice
                                (flow-then 'reset-then-cache
                                           reset
                                           cached-increment)
                                (flow-then 'reset-then-cache-again
                                           reset
                                           cached-increment))))
          (check-equal? (local-run flow 99) 1)
          (check-equal? increments 1))))
    (yuanxu-test-case "stage 12 tutorial2 custom task interpreter runs through extension"
      (let* ((config (make-custom-run-config))
             (flow (custom-repeat-flow 'custom-repeat
                                       "woop!"
                                       7
                                       'string
                                       'string))
             (task (car (flow-steps flow)))
             (payload (task-custom-payload task)))
        (check-equal? (configured-run config flow "Kangaroo goes ")
                      "Kangaroo goes woop!woop!woop!woop!woop!woop!woop!")
        (check-equal? (task-kind task) 'custom)
        (check-equal? (task-custom-repeat? task) #t)
        (check-equal? (custom-repeat-spec-count payload) 7)))
    (yuanxu-test-case "stage 13 word count extension returns notebook counts"
      (let* ((sample "a and it try words a and it try words a and it try words
Lets This count give pipeline should Lets This count give pipeline should
FILE WordCount.hs complex-words numbers 123 punctuation!")
             (counts (word-counts sample))
             (lines (format-word-counts counts))
             (config (make-text-run-config))
             (flow (word-count-flow 'word-count 'text 'summary))
             (summary (configured-run config flow sample)))
        (check-equal? (word-count-ref counts "a") 3)
        (check-equal? (word-count-ref counts "and") 3)
        (check-equal? (word-count-ref counts "Lets") 2)
        (check-equal? (word-count-ref counts "FILE") 1)
        (check-equal? (word-count-ref counts "WordCounths") 1)
        (check-equal? (and (member "a: 3" lines) #t) #t)
        (check-equal? (and (member "Lets: 2" lines) #t) #t)
        (check-equal? (and (member "FILE: 1" lines) #t) #t)
        (check-equal? summary (word-count-summary sample))))
    (yuanxu-test-case "stage 14 ccompilation and tensorflow workflow descriptors are public"
      (let* ((compile-flow (make-ccompilation-flow 'compile-c))
             (compile-task (car (flow-steps compile-flow)))
             (compile-config (cadr (task-request compile-task)))
             (store-workflow (make-ccompilation-store-workflow 'compile-and-store))
             (store-plan (runner-plan
                          (run-config->runner (make-docker-store-run-config))
                          store-workflow))
             (tf-workflow (make-tensorflow-workflow 'tensorflow-demo))
             (tf-plan (runner-plan
                       (run-config->runner (make-docker-store-run-config))
                       tf-workflow))
             (train-task (car (flow-steps tf-workflow)))
             (infer-task (cadr (flow-steps tf-workflow))))
        (check-equal? (task-docker-image compile-task) "gcc:9.3.0")
        (check-equal? (task-docker-command compile-task) "gcc")
        (check-equal? (cdr (assoc 'args compile-config))
                      '("/example/double.c"
                        "/example/square.c"
                        "/example/main.c"
                        "-o"
                        "/output/main"))
        (check-equal? (execution-plan-node-ids store-plan)
                      '((node compile-and-store 0 docker compile-c)
                        (node compile-and-store 1 store store-c-binary)))
        (check-equal? (task-docker-image train-task)
                      "tensorflow/tensorflow:2.3.0")
        (check-equal? (task-docker-command infer-task) "bash")
        (check-equal? (execution-plan-node-ids tf-plan)
                      '((node tensorflow-demo 0 docker train-mnist)
                        (node tensorflow-demo 1 docker infer-mnist)))))
    (yuanxu-test-case "stage 15 error handling recovers local throw and adapter failure"
      (let* ((runner (make-runner (make-local-eager-strategy)
                                  (make-request-only-adapter)))
             (flow (throw-string-flow 'throw-demo
                                      "Nothing has been done"
                                      'unit
                                      'unit))
             (result (runner-run-value-or-recover
                      runner
                      flow
                      #!void
                      (lambda (failure)
                        (if (execution-failure? failure)
                          (list 'caught
                                (execution-failure-owner failure)
                                (execution-failure-code failure)
                                (execution-failure-message failure))
                          '(unexpected recovery target))))))
        (check-equal? result
                      '(caught flow thrown-string "Nothing has been done")))
      (let* ((command
              (lambda (envelope)
                (list (cons 'schema +runtime-response-schema+)
                      (cons 'request-id (cdr (assoc 'request-id envelope)))
                      (cons 'status 'failed)
                      (cons 'value #f)
                      (cons 'artifact-handle '(artifact error-handling))
                      (cons 'error '((code . bad-image)))
                      (cons 'metadata '((tutorial . error-handling))))))
             (config (make-rust-run-config
                      (list (cons 'runtime-command command))))
             (flow (external-flow 'bad-docker
                                  'submit
                                  '((image . "badImageName"))
                                  'unit
                                  'artifact))
             (result (runner-run-value-or-recover
                      (run-config->runner config)
                      flow
                      #!void
                      (lambda (failure-or-receipt)
                        (if (receipt-failed? failure-or-receipt)
                          (list 'failed
                                (receipt-task failure-or-receipt)
                                (receipt-kind failure-or-receipt)
                                (execution-failure-code
                                 (receipt-error failure-or-receipt)))
                          '(unexpected recovery target))))))
        (check-equal? result '(failed bad-docker external adapter-failure)))
      (let* ((command
              (lambda (envelope)
                (list (cons 'schema +runtime-response-schema+)
                      (cons 'request-id (cdr (assoc 'request-id envelope)))
                      (cons 'status 'failed)
                      (cons 'value #f)
                      (cons 'artifact-handle '(artifact error-handling-try))
                      (cons 'error '((code . bad-image)
                                     (image . "badImageName")))
                      (cons 'metadata '((tutorial . error-handling))))))
             (config (make-rust-run-config
                      (list (cons 'runtime-command command))))
             (flow (external-flow 'bad-docker-try
                                  'submit
                                  '((image . "badImageName")
                                    (command . "badCommand"))
                                  'unit
                                  'artifact))
             (result (runner-run-either (run-config->runner config)
                                        flow
                                        #!void))
             (visible (if (try-left? result)
                        "The task failed"
                        "The task succeeded"))
             (failure (try-result-value result)))
        (check-equal? visible "The task failed")
        (check-equal? (execution-failure-code failure) 'adapter-failure)
        (check-equal? (cdr (assoc 'error (execution-failure-detail failure)))
                      '((code . bad-image)
                        (image . "badImageName")))))
    (yuanxu-test-case "stage 16 makefile tool workflow descriptor is public"
      (let* ((workflow (make-makefile-tool-workflow 'makefile-tool-demo))
             (plan (runner-plan
                    (run-config->runner (make-rust-run-config))
                    workflow))
             (parse-task (car (flow-steps workflow)))
             (run-task (cadr (flow-steps workflow))))
        (check-equal? (execution-plan-node-ids plan)
                      '((node makefile-tool-demo 0 external makefile-tool-parse)
                        (node makefile-tool-demo 1 external makefile-tool-run)))
        (check-equal? (task-request-operation parse-task)
                      'makefile-tool-parse)
        (check-equal? (task-request-operation run-task)
                      'makefile-tool-run)
        (check-equal? (task-request-payload parse-task)
                      '((makefile . "Makefile")
                        (working-directory . "funflow-examples/makefile-tool/test")
                        (sources . ("main.cpp" "hello.cpp" "factorial.cpp"))))
        (check-equal? (task-request-payload run-task)
                      '((target . "hello")
                        (binary . "./hello")
                        (expected-output . process-output)))))
    (yuanxu-test-case "authors extension-owned workflows with Gerbil macros"
      (let* ((custom-task (car (flow-steps macro-custom-repeat)))
             (docker-task (car (flow-steps macro-docker-compile)))
             (store-task (car (flow-steps macro-store-put)))
             (store-plan (runner-plan
                          (run-config->runner (make-docker-store-run-config))
                          macro-ccompilation-store))
             (tensorflow-plan (runner-plan
                               (run-config->runner (make-docker-store-run-config))
                               macro-tensorflow))
             (makefile-plan (runner-plan
                             (run-config->runner (make-rust-run-config))
                             macro-makefile-tool)))
        (check-equal? (configured-run (make-custom-run-config)
                                      macro-custom-repeat
                                      "Kangaroo goes ")
                      "Kangaroo goes woop!woop!woop!woop!woop!woop!woop!")
        (check-equal? (task-custom-repeat? custom-task) #t)
        (check-equal? (task-docker-image docker-task) "gcc:9.3.0")
        (check-equal? (task-docker-command docker-task) "gcc")
        (check-equal? (task-request-operation store-task) 'put)
        (check-equal? (execution-plan-node-ids store-plan)
                      '((node macro-ccompilation-store 0 docker compile-c)
                        (node macro-ccompilation-store 1 store store-c-binary)))
        (check-equal? (execution-plan-node-ids tensorflow-plan)
                      '((node macro-tensorflow 0 docker train-mnist)
                        (node macro-tensorflow 1 docker infer-mnist)))
        (check-equal? (execution-plan-node-ids makefile-plan)
                      '((node macro-makefile-tool 0 external makefile-tool-parse)
                        (node macro-makefile-tool 1 external makefile-tool-run)))))))
