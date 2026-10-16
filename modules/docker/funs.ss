;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: Docker tutorial alignment lives in this module.
;;; Boundary: core provides descriptor, strategy, runner, and adapter protocols.
;;; Import contract: users opt in through the module config/interface exports.
;;; Runtime contract: this module emits request data only.
;;; Runtime contract: image pulls and mounts stay behind runtime commands.
;;; Runtime contract: process control and CAS writes stay out of Scheme.
;;; Dependency: generic sandbox resources live in =:poo-flow/modules/agent-sandbox/resource=.
;;; Policy evidence: tests should trust the installed module registry.

(import (only-in :poo-flow/modules/workflow/control-plane/task
                 make-task-family-descriptor task-family-registry-extend
                 default-task-family-registry make-task task? task-kind
                 task-request)
        (only-in :poo-flow/modules/workflow/control-plane/failure raise-control-plane-failure)
        (only-in :poo-flow/modules/workflow/control-plane/strategy
                 make-strategy strategy-name strategy-capabilities
                 strategy-cache-policy strategy-failure-policy strategy-planner
                 make-local-eager-strategy)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-adapter
                 make-runtime-adapter runtime-adapter-name
                 runtime-adapter-capabilities runtime-adapter-submitter
                 runtime-adapter-fetcher runtime-adapter-store-putter
                 runtime-adapter-store-getter make-rust-adapter)
        (only-in :poo-flow/modules/workflow/control-plane/config make-run-config)
        (only-in :poo-flow/modules/workflow/control-plane/flow
                 default-flow-declaration-registry task-flow flow-name flow-steps)
        (only-in :poo-flow/modules/agent-sandbox/resource
                 sandbox-volume-bindings->request
                 sandbox-volume-bindings-merge))

(export docker-task-family-descriptor
        +docker-task-input-receipt-schema+
        make-docker-task-family-registry
        docker-enable-strategy
        make-docker-enabled-strategy
        make-docker-enabled-adapter
        make-docker-run-config
        make-docker-task-input
        docker-task-input?
        docker-task-input-input-bindings
        docker-task-input-args-vals
        make-empty-docker-task-input
        docker-task-input-merge
        docker-task-input->request
        make-docker-task
        task-docker-config
        task-docker-image
        task-docker-command
        task-docker-args
        task-docker-volumes
        task-docker-output-policy
        docker-flow
        docker-task-flow
        make-docker-task-input-receipt
        docker-task-input-receipt?
        docker-task-input-receipt-schema
        docker-task-input-receipt-flow
        docker-task-input-receipt-image
        docker-task-input-receipt-command
        docker-task-input-receipt-args
        docker-task-input-receipt-input-bindings
        docker-task-input-receipt-args-vals
        docker-task-input-receipt-output-policy
        docker-task-input-receipt-runtime-executed
        docker-flow->task-input-receipt)

;; : (forall (a) (-> [a] [a] [a]))
(def (docker-values/tail values tail)
  (foldr cons tail values))

;;; Boundary: DockerTaskInput receipts use an explicit schema symbol so Marlin
;;; can discover report-only handoff data without guessing task entrypoints.
;; : (-> Unit Symbol)
(def +docker-task-input-receipt-schema+
  'poo-flow.extensions.docker-task-input-receipt.v1)

;;; Docker task input mirrors Funflow's DockerTaskInput: inputBindings plus
;;; placeholder argument values. It is input data to the flow, not task config.
;; : (-> [SandboxVolumeBinding] Alist DockerTaskInput)
(defstruct docker-task-input
  (input-bindings
   args-vals)
  transparent: #t)

;;; Report-only evidence for the Docker input/config boundary. It does not mean
;;; a container ran, an image was pulled, or a CAS output was written.
;; : (-> Symbol Symbol Image Command [Arg] [VolumeBinding] Alist OutputPolicy Boolean DockerTaskInputReceipt)
(defstruct docker-task-input-receipt
  (schema
   flow
   image
   command
   args
   input-bindings
   args-vals
   output-policy
   runtime-executed)
  transparent: #t)

;; : (-> Unit TaskFamilyDescriptor)
(def docker-task-family-descriptor
  (make-task-family-descriptor 'docker 'docker 'adapter 'rust-or-external-runtime 'submit))

;;; Boundary: make docker task family registry is the policy-visible edge for
;;; policy behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [TaskFamilyRegistry] TaskFamilyRegistry)
(def (make-docker-task-family-registry . maybe-registry)
  (task-family-registry-extend (if (null? maybe-registry)
                                 default-task-family-registry
                                 (car maybe-registry))
                               docker-task-family-descriptor))

;;; Docker-aware strategies are opt-in wrappers over core strategy policy. Core
;;; stays unaware of Docker while extension users still get normal validation.
;; : (-> Strategy Strategy)
(def (docker-enable-strategy strategy)
  (make-strategy (strategy-name strategy)
                 (docker-values/tail
                  (strategy-capabilities strategy)
                  '(docker))
                 (strategy-cache-policy strategy)
                 (strategy-failure-policy strategy)
                 (strategy-planner strategy)))

;;; The default constructor starts from local eager policy; composition helpers
;;; can reuse docker-enable-strategy when Docker is only one workflow capability.
;; : (-> Unit Strategy)
(def (make-docker-enabled-strategy)
  (docker-enable-strategy (make-local-eager-strategy)))

;;; Adapter extension is structural: it preserves submit/fetch/store handlers and
;;; only advertises Docker capability to strategy validation.
;; : (-> RuntimeAdapter RuntimeAdapter)
(def (make-docker-enabled-adapter adapter)
  (make-runtime-adapter (runtime-adapter-name adapter)
                        (docker-values/tail
                         (runtime-adapter-capabilities adapter)
                         '(docker))
                        (runtime-adapter-submitter adapter)
                        (runtime-adapter-fetcher adapter)
                        (runtime-adapter-store-putter adapter)
                        (runtime-adapter-store-getter adapter)))

;;; Option lookup is intentionally local to the extension so Docker defaults do
;;; not leak into core run-config construction.
;; : (-> Alist Symbol Value Value)
(def (docker-option options key default)
  (let (entry (assoc key options))
    (if entry
      (cdr entry)
      default)))

;;; Boundary: empty Docker inputs are the monoidal zero for composition tests
;;; and config-only tasks before a runtime supplies CAS mounts.
;; : (-> Unit DockerTaskInput)
(def (make-empty-docker-task-input)
  (make-docker-task-input '() '()))

;;; Boundary: request projection is local to Docker options. Shared sandbox
;;; resource projection lives in =:extensions/sandbox-resource=.
;; : (-> Alist Symbol Value Value)
(def (docker-alist-ref alist key default)
  (let (entry (assoc key alist))
    (if entry
      (cdr entry)
      default)))

;;; Boundary: docker arg key seen predicate is the policy-visible edge for
;;; policy behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Alist Boolean)
(def (docker-arg-key-seen? key args)
  (if (assoc key args) #t #f))

;; : (-> Pair Symbol)
(def (docker-arg-key entry)
  (car entry))

;;; Boundary: docker args vals append left biased is the policy-visible edge
;;; for policy behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Alist Alist Alist)
(def (docker-args-vals-copy-left/rev remaining result-rev)
  (if (null? remaining)
    result-rev
    (docker-args-vals-copy-left/rev
     (cdr remaining)
     (cons (car remaining) result-rev))))

;; : (-> Alist Alist Alist)
(def (docker-args-vals-append-left-biased/rev remaining result-rev)
  (cond
   ((null? remaining)
    (reverse result-rev))
   ((docker-arg-key-seen? (docker-arg-key (car remaining)) result-rev)
    (docker-args-vals-append-left-biased/rev
     (cdr remaining)
     result-rev))
   (else
    (docker-args-vals-append-left-biased/rev
     (cdr remaining)
     (cons (car remaining) result-rev)))))

;; : (-> Alist Alist Alist)
(def (docker-args-vals-append-left-biased left right)
  (docker-args-vals-append-left-biased/rev
   right
   (docker-args-vals-copy-left/rev left '())))

;;; Boundary: Funflow's DockerTaskInput semigroup is left-biased for duplicate
;;; mounts and placeholder values, so earlier composition layers keep priority.
;; : (-> DockerTaskInput DockerTaskInput DockerTaskInput)
(def (docker-task-input-merge left right)
  (make-docker-task-input
   (sandbox-volume-bindings-merge
    (docker-task-input-input-bindings left)
    (docker-task-input-input-bindings right))
   (docker-args-vals-append-left-biased
    (docker-task-input-args-vals left)
    (docker-task-input-args-vals right))))

;;; Boundary: runtime request shape is data-only; Rust/Marlin chooses Docker
;;; flags, resolves store items, and writes CAS outputs.
;; : (-> DockerTaskInput Alist)
(def (docker-task-input->request input)
  (list
   (cons 'input-bindings
         (sandbox-volume-bindings->request
          (docker-task-input-input-bindings input)))
   (cons 'args-vals (docker-task-input-args-vals input))))

;;; The configured Docker run entrypoint installs the extension task registry
;;; and adapter capability while preserving core run-config behavior.
;; : (-> [Alist] RunConfig)
(def (make-docker-run-config . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (command (docker-option options 'runtime-command #f)))
    (make-run-config 'docker-runtime
                     (make-docker-enabled-strategy)
                     (make-docker-enabled-adapter (make-rust-adapter command))
                     (append '((runtime . rust)
                               (extension . docker))
                             options)
                     (make-docker-task-family-registry)
                     default-flow-declaration-registry)))

;;; Docker tasks are first-class extension request data for the runtime
;;; boundary. Rust owns image pulls, mounts, process control, and CAS output.
;; : (-> Symbol Image Command [Arg] [SandboxVolumeBinding] OutputPolicy Contract Contract Task)
(def (make-docker-task name image command args volumes output-policy input-contract output-contract)
  (make-task name
             'docker
             (list 'docker
                   (list (cons 'image image)
                         (cons 'command command)
                         (cons 'args args)
                         (cons 'volumes volumes)
                         (cons 'output-policy output-policy)))
             input-contract
             output-contract
             #f))

;;; Task config extraction refuses non-Docker tasks instead of assuming the
;;; request payload shape belongs to this extension.
;; : (-> Task (U DockerConfig #f))
(def (task-docker-config task)
  (if (eq? (task-kind task) 'docker)
    (cadr (task-request task))
    #f))

;;; Boundary: task docker config ref is the policy-visible edge for policy
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Task Symbol Value Value)
(def (task-docker-config-ref task key default)
  (let ((config (task-docker-config task)))
    (if config
      (let (entry (assoc key config))
        (if entry
          (cdr entry)
          default))
      default)))

;; : (-> Task (U Image #f))
(def (task-docker-image task)
  (task-docker-config-ref task 'image #f))

;; : (-> Task (U Command #f))
(def (task-docker-command task)
  (task-docker-config-ref task 'command #f))

;; : (-> Task [Arg])
(def (task-docker-args task)
  (task-docker-config-ref task 'args '()))

;; : (-> Task [SandboxVolumeBinding])
(def (task-docker-volumes task)
  (task-docker-config-ref task 'volumes '()))

;; : (-> Task (U OutputPolicy #f))
(def (task-docker-output-policy task)
  (task-docker-config-ref task 'output-policy #f))

;; : (-> Symbol Image Command [Arg] [SandboxVolumeBinding] OutputPolicy Contract Contract Flow)
(def (docker-flow name image command args volumes output-policy input-contract output-contract)
  (task-flow name
             (make-docker-task name
                               image
                               command
                               args
                               volumes
                               output-policy
                               input-contract
                               output-contract)))

;;; Funflow's dockerFlow takes DockerTaskConfig and returns a flow from
;;; DockerTaskInput to a CAS item. This constructor preserves that boundary.
;; : (-> Symbol Image Command [Arg] Flow)
(def (docker-task-flow name image command args)
  (docker-flow name
               image
               command
               args
               '()
               'cas-item
               'docker-task-input
               'cas-item))

;;; Boundary: receipt helpers validate that the flow is backed by a Docker task
;;; before projecting report-only handoff data.
;; : (-> Flow Task)
(def (docker-flow-primary-task flow)
  (let (steps (flow-steps flow))
    (if (and (pair? steps)
             (task? (car steps))
             (eq? (task-kind (car steps)) 'docker))
      (car steps)
      (raise-control-plane-failure
       'docker-extension
       'expected-docker-flow
       "expected a flow whose first step is a docker task"
       (list (cons 'flow (flow-name flow)))))))

;;; Project the Funflow DockerTaskConfig + DockerTaskInput boundary into a
;;; receipt that Marlin/Rust can consume before any container execution exists.
;; : (-> Flow DockerTaskInput DockerTaskInputReceipt)
(def (docker-flow->task-input-receipt flow input)
  (let (task (docker-flow-primary-task flow))
    (make-docker-task-input-receipt
     +docker-task-input-receipt-schema+
     (flow-name flow)
     (task-docker-image task)
     (task-docker-command task)
     (task-docker-args task)
     (sandbox-volume-bindings->request
      (docker-task-input-input-bindings input))
     (docker-task-input-args-vals input)
     (task-docker-output-policy task)
     #f)))
