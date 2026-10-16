;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: composed workflow builders for Docker, Store, Tensorflow, and makefile examples.
;;; Invariant: builders produce descriptors and runtime command manifests only.

(import (only-in :poo-flow/modules/workflow/control-plane/task
                 execution-request-request execution-request-plan-id)
        (only-in :poo-flow/modules/workflow/control-plane/strategy make-local-eager-strategy)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-adapter make-rust-adapter)
        (only-in :poo-flow/modules/workflow/control-plane/config make-run-config)
        (only-in :poo-flow/modules/workflow/control-plane/flow
                 default-flow-declaration-registry external-flow flow-then)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
                 make-stdout-runtime-command-descriptor)
        :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/docker/funs
        :poo-flow/modules/workflow/store)

(export make-docker-store-run-config
        make-ccompilation-flow
        make-ccompilation-store-workflow
        make-tensorflow-train-flow
        make-tensorflow-inference-flow
        make-tensorflow-workflow
        make-makefile-tool-parse-flow
        make-makefile-tool-run-flow
        make-makefile-tool-workflow
        make-makefile-tool-runtime-arguments
        make-makefile-tool-runtime-command-descriptor)

;;; Workflow options stay alist-shaped so this composition layer can pass
;;; caller metadata through without owning Docker or Store schema validation.
;; : (-> Alist Symbol Value Value)
(def (workflow-option options key default)
  (let (entry (workflow-option-entry options key))
    (if entry
      (workflow-option-entry-value entry)
      default)))

;; : (-> Alist Symbol Pair)
(def (workflow-option-entry options key)
  (assoc key options))

;; : (-> Pair Value)
(def (workflow-option-entry-value entry)
  (cdr entry))

;;; Boundary:
;;; - Option filtering keeps control callbacks out of exported descriptor metadata.
;;; - Metadata remains inert data for runtime manifests.
;; : (-> Alist Symbol Alist Alist)
(def (workflow-options-without/rev options key result-rev)
  (cond
   ((null? options) result-rev)
   ((workflow-option-entry-key? (car options) key)
    (workflow-options-without/rev (cdr options) key result-rev))
   (else
    (workflow-options-without/rev
     (cdr options)
     key
     (cons (car options) result-rev)))))

;; : (-> Alist Symbol Alist)
(def (workflow-options-without options key)
  (reverse (workflow-options-without/rev options key '())))

;; : (-> List List List)
(def (workflow-values/tail values tail)
  (foldr cons tail values))

;; : (-> Pair Symbol Boolean)
(def (workflow-option-entry-key? entry key)
  (eq? (car entry) key))

;;; Boundary:
;;; - Runtime manifests are argv-shaped, so every projected value becomes text.
;;; - Symbols stay readable while structured values use s-expression spelling.
;; : (-> RuntimeValue CliArgument)
(def (workflow-cli-string value)
  (cond
   ((not value) "")
   ((string? value) value)
   ((symbol? value) (symbol->string value))
   (else (object->string value))))

;;; The Docker+Store config composes capabilities and task registries while
;;; keeping both backend contracts behind the same runtime command boundary.
;; : (-> [Alist] RunConfig)
(def (make-docker-store-run-config . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (command (workflow-option options 'runtime-command #f)))
    (make-run-config
     'docker-store-runtime
     (store-enable-strategy
      (docker-enable-strategy (make-local-eager-strategy)))
     (make-store-enabled-adapter
      (make-docker-enabled-adapter (make-rust-adapter command)))
     (poo-flow-product-field-rows/tail
      options
      (runtime 'rust)
      (extensions '(docker store)))
     (make-store-task-family-registry
      (make-docker-task-family-registry))
     default-flow-declaration-registry)))

;;; CCompilation's public Scheme result is a descriptor-shaped Docker flow.
;;; The runtime command owns image pulls, volume realization, compilation, and
;;; process handles; this constructor owns the tutorial's stable request shape.
;; : (-> Symbol Flow)
(def (make-ccompilation-flow name)
  (docker-flow name
               "gcc:9.3.0"
               "gcc"
               '("/example/double.c"
                 "/example/square.c"
                 "/example/main.c"
                 "-o"
                 "/output/main")
               '(((store-item . ccompilation-src)
                  (mount-path . "/example"))
                 ((store-item . ccompilation-output)
                  (mount-path . "/output")))
               'process-handle
               'integer
               'process-handle))

;;; The store handoff mirrors the tutorial's post-compile artifact boundary:
;;; Docker produces a process/artifact result, Store records a durable manifest.
;; : (-> Symbol Flow)
(def (make-ccompilation-store-workflow name)
  (flow-then name
             (make-ccompilation-flow 'compile-c)
             (store-flow 'store-c-binary
                         'put
                         '((store-item . c-binary)
                           (path . "/output/main"))
                         'process-handle
                         'artifact-manifest)))

;; : (-> Symbol Flow)
(def (make-tensorflow-train-flow name)
  (docker-flow name
               "tensorflow/tensorflow:2.3.0"
               "bash"
               '("-c"
                 "pip install -r /tensorflow-example/requirements.txt && python /tensorflow-example/train_mnist.py --n_epochs 10 ./model")
               '(((store-item . tensorflow-example)
                  (mount-path . "/tensorflow-example"))
                 ((store-item . trained-model-output)
                  (mount-path . "/model-output")))
               'trained-model
               'unit
               'trained-model))

;; : (-> Symbol Flow)
(def (make-tensorflow-inference-flow name)
  (docker-flow name
               "tensorflow/tensorflow:2.3.0"
               "bash"
               '("-c"
                 "pip install -r /tensorflow-example/requirements.txt && python /tensorflow-example/inference_mnist.py /trained/model /tensorflow-example/demo-images ./summary.png")
               '(((store-item . tensorflow-example)
                  (mount-path . "/tensorflow-example"))
                 ((store-item . trained-model)
                  (mount-path . "/trained"))
                 ((store-item . tensorflow-summary-output)
                  (mount-path . "/summary-output")))
               'summary-image
               'trained-model
               'summary-image))

;;; TensorflowDocker is represented as a two-step external workflow. It keeps
;;; the visible training/inference milestones inspectable while leaving model
;;; training, image rendering, and filesystem writes to the runtime owner.
;; : (-> Symbol Flow)
(def (make-tensorflow-workflow name)
  (flow-then name
             (make-tensorflow-train-flow 'train-mnist)
             (make-tensorflow-inference-flow 'infer-mnist)))

;;; Boundary:
;;; - makefile-tool parsing is a runtime-owned external task.
;;; - Scheme owns only the tutorial-visible project descriptor.
;; : (-> Symbol Flow)
(def (make-makefile-tool-parse-flow name)
  (external-flow name
                 'makefile-tool-parse
                 '((makefile . "Makefile")
                   (working-directory . "funflow-examples/makefile-tool/test")
                   (sources . ("main.cpp" "hello.cpp" "factorial.cpp")))
                 'makefile-project
                 'makefile-plan))

;;; Boundary:
;;; - makefile-tool execution is a runtime-owned external task.
;;; - The output contract models the notebook's process-output result.
;; : (-> Symbol Flow)
(def (make-makefile-tool-run-flow name)
  (external-flow name
                 'makefile-tool-run
                 '((target . "hello")
                   (binary . "./hello")
                   (expected-output . process-output))
                 'makefile-plan
                 'process-output))

;;; Boundary:
;;; - This workflow preserves the tutorial's parse-then-run milestone shape.
;;; - Rust or another adapter owns Makefile execution and filesystem effects.
;; : (-> Symbol Flow)
(def (make-makefile-tool-workflow name)
  (flow-then name
             (make-makefile-tool-parse-flow 'makefile-tool-parse)
             (make-makefile-tool-run-flow 'makefile-tool-run)))

;;; Boundary:
;;; - This argument builder is the Rust CLI handoff for makefile-tool requests.
;;; - It serializes request metadata without running Makefile or process work.
;; | RuntimeArgumentBuilder = (-> RuntimeEnvelope [String])
;; : (-> [Alist] RuntimeArgumentBuilder)
;; : (forall (o) (-> [o] RuntimeArgumentBuilder))
;; make-makefile-tool-runtime-arguments
;;   : (-> [Alist] RuntimeArgumentBuilder)
;;   | contract: options produce an envelope serializer, not runtime execution
;;   | doc m%
;;   | # Examples
;;   | ```scheme
;;   | ((make-makefile-tool-runtime-arguments '((runtime-name . "makefile-tool")))
;;   |  runtime-envelope)
;;   | ```
;;   | result: CLI argv list for the Marlin-owned runtime command.
(def (make-makefile-tool-runtime-arguments . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (runtime-name (workflow-option options
                                        'runtime-name
                                        "makefile-tool")))
    (lambda (envelope)
      (let* ((request (workflow-envelope-ref envelope 'request #f))
             (operation (cadr (execution-request-request request)))
             (payload (caddr (execution-request-request request)))
             (base (list runtime-name
                         "--request-id"
                         (workflow-cli-string
                          (workflow-envelope-ref envelope 'request-id #f))
                         "--plan-id"
                         (workflow-cli-string (execution-request-plan-id request))
                         "--operation"
                         (workflow-cli-string operation))))
        (workflow-values/tail
         base
         (cond
          ((eq? operation 'makefile-tool-parse)
           (list "--working-directory"
                 (workflow-cli-string
                  (workflow-option payload 'working-directory "."))
                 "--makefile"
                 (workflow-cli-string
                  (workflow-option payload 'makefile "Makefile"))
                 "--sources"
                 (workflow-cli-string
                  (workflow-option payload 'sources '()))))
          ((eq? operation 'makefile-tool-run)
           (list "--target"
                 (workflow-cli-string
                  (workflow-option payload 'target ""))
                 "--binary"
                 (workflow-cli-string
                  (workflow-option payload 'binary ""))
                 "--expected-output"
                 (workflow-cli-string
                  (workflow-option payload 'expected-output 'process-output))))
          (else
           (list "--payload" (workflow-cli-string payload)))))))))

;;; Boundary: workflow envelope ref is the policy-visible edge for workflow
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Alist Symbol Value Value)
(def (workflow-envelope-ref envelope key default)
  (let (entry (workflow-option-entry envelope key))
    (if entry
      (workflow-option-entry-value entry)
      default)))

;;; Boundary:
;;; - The descriptor is inert until materialized by runtime-adapter code.
;;; - Tests may override =arguments= to emulate a runtime response through /bin/echo.
;; : (-> Symbol String [Alist] RuntimeCommandDescriptorValue)
(def (make-makefile-tool-runtime-command-descriptor name executable . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (arguments (workflow-option
                     options
                     'arguments
                     (make-makefile-tool-runtime-arguments options)))
         (metadata (poo-flow-product-field-rows/tail
                    (workflow-options-without options 'arguments)
                    (workflow 'makefile-tool)
                    (runtime 'rust-cli-compatible))))
    (make-stdout-runtime-command-descriptor name
                                            executable
                                            arguments
                                            metadata)))
