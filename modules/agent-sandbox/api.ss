;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: Agent sandbox facade and task/flow opt-in live here.
;;; Boundary: profile, request, and bridge contracts live in leaf modules.
;;; Import contract: users opt in through =:poo-flow/modules/agent-sandbox= exports.
;;; Runtime contract: Marlin or another runtime owns real sandbox execution.
;;; Runtime contract: LLM calls, API/R surfaces, and C bindings stay out of Scheme.
;;; Policy evidence: tests should validate this facade plus leaf contracts.

(import (only-in :poo-flow/modules/workflow/control-plane/task
                 make-task-family-descriptor task-family-registry-extend
                 default-task-family-registry make-task)
        (only-in :poo-flow/modules/workflow/control-plane/strategy
                 make-strategy strategy-name strategy-capabilities
                 strategy-cache-policy strategy-failure-policy strategy-planner
                 make-local-eager-strategy)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-adapter
                 make-runtime-adapter runtime-adapter-name
                 runtime-adapter-capabilities runtime-adapter-submitter
                 runtime-adapter-fetcher runtime-adapter-store-putter
                 runtime-adapter-store-getter make-rust-adapter adapter-submit)
        (only-in :poo-flow/modules/workflow/control-plane/config make-run-config)
        (only-in :poo-flow/modules/workflow/control-plane/flow
                 default-flow-declaration-registry task-flow)
        :poo-flow/modules/agent-sandbox/alist
        :poo-flow/modules/agent-sandbox/profile
        :poo-flow/modules/agent-sandbox/profile-candidate
        :poo-flow/modules/agent-sandbox/request
        :poo-flow/modules/agent-sandbox/request-macro
        :poo-flow/modules/agent-sandbox/bridge
        :poo-flow/modules/agent-sandbox/marlin-interface)

(export (import: :poo-flow/modules/agent-sandbox/alist)
        (import: :poo-flow/modules/agent-sandbox/profile)
        (import: :poo-flow/modules/agent-sandbox/profile-candidate)
        (import: :poo-flow/modules/agent-sandbox/request)
        (import: :poo-flow/modules/agent-sandbox/request-macro)
        (import: :poo-flow/modules/agent-sandbox/bridge)
        (import: :poo-flow/modules/agent-sandbox/marlin-interface)
        agent-sandbox-task-family-descriptor
        make-agent-sandbox-task-family-registry
        agent-sandbox-enable-strategy
        make-agent-sandbox-enabled-strategy
        make-agent-sandbox-enabled-adapter
        make-agent-sandbox-runtime-adapter
        make-agent-sandbox-run-config
        make-agent-sandbox-task
        make-profiled-agent-sandbox-task
        agent-sandbox-flow
        profiled-agent-sandbox-flow)

;;; The descriptor names the Scheme-visible contract only. Concrete backend
;;; selection remains adapter-owned so Marlin can choose API/R/C paths later.
;; : (-> Unit TaskFamilyDescriptor)
(def agent-sandbox-task-family-descriptor
  (make-task-family-descriptor 'agent-sandbox
                               'agent-sandbox
                               'adapter
                               'marlin-or-external-runtime
                               'submit))

;;; Registry installation is opt-in and composable with other extension
;;; registries. Default core task families are not mutated.
;; : (-> [TaskFamilyRegistry] TaskFamilyRegistry)
(def (make-agent-sandbox-task-family-registry . maybe-registry)
  (task-family-registry-extend
   (if (null? maybe-registry) default-task-family-registry (car maybe-registry))
   agent-sandbox-task-family-descriptor))

;;; Capability insertion is idempotent because extension wrappers may compose
;;; with future Docker-compatible or store-aware adapters.
;; : (forall (a) (-> [a] [a] [a]))
(def (agent-sandbox-values/tail values tail)
  (append values tail))

;; : (-> [Symbol] Symbol [Symbol])
(def (agent-sandbox-capabilities-with capability-set capability)
  (if (memq capability capability-set)
    capability-set
    (agent-sandbox-values/tail capability-set (list capability))))

;;; Strategy wrapping only advertises planning support. It does not select a
;;; concrete backend or change the core planner.
;; : (-> Strategy Strategy)
(def (agent-sandbox-enable-strategy strategy)
  (make-strategy
   (strategy-name strategy)
   (agent-sandbox-capabilities-with (strategy-capabilities strategy)
                                    'agent-sandbox)
   (strategy-cache-policy strategy)
   (strategy-failure-policy strategy)
   (strategy-planner strategy)))

;;; Agent-sandbox-aware strategies are opt-in wrappers over core strategy
;;; policy. Core stays unaware of backend-specific sandbox implementations.
;; : (-> Unit Strategy)
(def (make-agent-sandbox-enabled-strategy)
  (agent-sandbox-enable-strategy (make-local-eager-strategy)))

;;; Adapter wrapping is capability-only. The submit/fetch/store functions stay
;;; owned by the underlying adapter so Scheme never becomes the sandbox runtime.
;; : (-> RuntimeAdapter RuntimeAdapter)
(def (make-agent-sandbox-enabled-adapter adapter)
  (make-runtime-adapter
   (runtime-adapter-name adapter)
   (agent-sandbox-capabilities-with (runtime-adapter-capabilities adapter)
                                    'agent-sandbox)
   (runtime-adapter-submitter adapter)
   (runtime-adapter-fetcher adapter)
   (runtime-adapter-store-putter adapter)
   (runtime-adapter-store-getter adapter)))

;;; Agent-sandbox runtime adapters are Rust-compatible, but their submit slot
;;; gives Marlin an extension-aware envelope instead of a generic Rust request.
;; : (-> (U RuntimeCommand #f) RuntimeAdapter)
(def (make-agent-sandbox-runtime-adapter command)
  (let (base (make-rust-adapter))
    (make-agent-sandbox-enabled-adapter
     (if command
       (make-runtime-adapter
        (runtime-adapter-name base)
        (runtime-adapter-capabilities base)
        (lambda (request)
          (if (agent-sandbox-execution-request? request)
            (agent-sandbox-command-submit command request)
            (adapter-submit base request)))
        (runtime-adapter-fetcher base)
        (runtime-adapter-store-putter base)
        (runtime-adapter-store-getter base))
       base))))

;;; The configured entrypoint installs the extension task registry and adapter
;;; capability while leaving backend selection to Marlin or an external runtime.
;; : (-> [Alist] RunConfig)
(def (make-agent-sandbox-run-config . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (command (agent-sandbox-option options 'runtime-command #f)))
    (make-run-config
     'agent-sandbox-runtime
     (make-agent-sandbox-enabled-strategy)
     (make-agent-sandbox-runtime-adapter command)
     (append '((runtime . rust)
               (extension . agent-sandbox))
             options)
     (make-agent-sandbox-task-family-registry)
     default-flow-declaration-registry)))

;;; Compatibility constructor keeps the original flat sandbox API stable for
;;; callers while routing all backend default logic through the profiled path.
;;; Boundary: future backend policy belongs in profiles/options, not by growing
;;; this long signature with runtime-owned concerns.
;; : (-> Symbol Symbol BackendRef Command [Arg] Env Workdir Mounts NetworkPolicy Capabilities ResourcePolicy OutputPolicy Metadata Contract Contract Task)
(def (make-agent-sandbox-task name
                              backend-kind
                              backend-ref
                              command
                              args
                              env
                              workdir
                              mounts
                              network-policy
                              capabilities
                              resource-policy
                              output-policy
                              metadata
                              input-contract
                              output-contract)
  (make-profiled-agent-sandbox-task
   name
   (make-agent-sandbox-backend-profile backend-kind backend-ref '() '() '() '())
   command
   args
   env
   workdir
   mounts
   output-policy
   input-contract
   output-contract
   (list (cons 'network-policy network-policy)
         (cons 'capabilities capabilities)
         (cons 'resource-policy resource-policy)
         (cons 'metadata metadata))))

;;; Profiled tasks are the preferred bridge-facing constructor. The profile
;;; supplies backend defaults and options supply per-task overrides.
;; : (-> Symbol AgentSandboxProfile Command [Arg] Env Workdir Mounts OutputPolicy Contract Contract [Alist] Task)
(def (make-profiled-agent-sandbox-task name
                                       profile
                                       command
                                       args
                                       env
                                       workdir
                                       mounts
                                       output-policy
                                       input-contract
                                       output-contract
                                       . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (request (make-agent-sandbox-request-from-fields
                   profile
                   (list (cons 'command command)
                         (cons 'args args)
                         (cons 'env env)
                         (cons 'workdir workdir)
                         (cons 'mounts mounts)
                         (cons 'network-policy
                               (agent-sandbox-option options 'network-policy #f))
                         (cons 'capabilities
                               (agent-sandbox-option options 'capabilities #f))
                         (cons 'resource-policy
                               (agent-sandbox-option options 'resource-policy #f))
                         (cons 'output-policy output-policy)
                         (cons 'metadata
                               (agent-sandbox-option options 'metadata '()))))))
    (make-task name
               'agent-sandbox
               (list 'agent-sandbox request)
               input-contract
               output-contract
               #f)))

;;; The flow helper keeps user code declaration-shaped: every backend detail is
;;; still inert request data until a runtime adapter interprets it.
;; : (-> Symbol Symbol BackendRef Command [Arg] Env Workdir Mounts NetworkPolicy Capabilities ResourcePolicy OutputPolicy Metadata Contract Contract Flow)
(def (agent-sandbox-flow name
                         backend-kind
                         backend-ref
                         command
                         args
                         env
                         workdir
                         mounts
                         network-policy
                         capabilities
                         resource-policy
                         output-policy
                         metadata
                         input-contract
                         output-contract)
  (task-flow name
             (make-agent-sandbox-task name
                                      backend-kind
                                      backend-ref
                                      command
                                      args
                                      env
                                      workdir
                                      mounts
                                      network-policy
                                      capabilities
                                      resource-policy
                                      output-policy
                                      metadata
                                      input-contract
                                      output-contract)))

;;; Profiled flows keep reusable backend policy out of call sites while still
;;; producing the same normalized task request as direct constructors.
;; : (-> Symbol AgentSandboxProfile Command [Arg] Env Workdir Mounts OutputPolicy Contract Contract [Alist] Flow)
(def (profiled-agent-sandbox-flow name
                                  profile
                                  command
                                  args
                                  env
                                  workdir
                                  mounts
                                  output-policy
                                  input-contract
                                  output-contract
                                  . maybe-options)
  (task-flow
   name
   (make-profiled-agent-sandbox-task
    name
    profile
    command
    args
    env
    workdir
    mounts
    output-policy
    input-contract
    output-contract
    (if (null? maybe-options) '() (car maybe-options)))))
