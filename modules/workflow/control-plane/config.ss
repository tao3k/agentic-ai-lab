;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: configured entrypoints assemble strategies and runtime adapters.
;;; Invariant: config data selects components but never executes workflow tasks.

(import :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/runtime-adapter
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/runner
        :poo-flow/modules/workflow/control-plane/projection-syntax)

(export make-config-requirement
        config-requirement?
        config-requirement-source
        config-requirement-key
        config-requirement-secret
        config-requirement-secret?
        config-requirement->alist
        make-config-preflight
        config-preflight?
        config-preflight-requirements
        config-preflight-missing
        config-preflight-status
        config-preflight-ok?
        config-preflight->alist
        make-config-argument
        config-argument?
        config-argument-kind
        config-argument-value
        config-argument-secret
        config-argument-secret?
        config-argument->requirement
        config-arguments->requirements
        render-config-argument
        render-config-arguments
        make-run-config
        run-config?
        run-config-name
        run-config-strategy
        run-config-adapter
        run-config-options
        run-config-task-registry
        run-config-flow-registry
        run-config-registry-policy
        run-config-config-requirements
        run-config-config-source
        run-config-preflight
        run-config-validate-preflight
        run-config-validate-registries
        make-request-only-run-config
        make-rust-run-config
        run-config->runner
        run-config-runtime-owner
        run-flow-with-config)

;;; Config requirements describe what a runtime needs without loading or
;;; persisting the secret values themselves.
;; : (-> Symbol Symbol Boolean ConfigRequirement)
(defstruct config-requirement
  (source
   key
   secret)
  transparent: #t)

;; : (-> ConfigRequirement Boolean)
(def (config-requirement-secret? requirement)
  (config-requirement-secret requirement))

;; : (-> ConfigRequirement Alist)
(defpoo-core-receipt-projection
  config-requirement->alist (requirement)
  (bindings ())
  (fields ((source (config-requirement-source requirement))
           (key (config-requirement-key requirement))
           (secret (config-requirement-secret requirement)))))

;;; Preflight reports only requirement identity and missing keys; raw values
;;; remain in the runtime adapter or caller-owned config source.
;; : (-> [ConfigRequirement] [ConfigRequirement] ConfigPreflight)
(defstruct config-preflight
  (requirements
   missing)
  transparent: #t)

;;; Boundary: config preflight status is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ConfigPreflight Symbol)
(def (config-preflight-status preflight)
  (if (null? (config-preflight-missing preflight))
    'ok
    'missing))

;; : (-> ConfigPreflight Boolean)
(def (config-preflight-ok? preflight)
  (eq? (config-preflight-status preflight) 'ok))

;;; Boundary: config requirements to alist is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ConfigPreflight Alist)
(defpoo-core-receipt-projection
  config-preflight->alist (preflight)
  (bindings ((requirements
              (config-requirement-alists
               (config-preflight-requirements preflight)))
             (missing
              (config-requirement-alists
               (config-preflight-missing preflight)))))
  (fields ((status (config-preflight-status preflight))
           (requirements requirements)
           (missing missing))))

;;; Config arguments mirror Funflow's configurable arguments while keeping
;;; source loading and secret materialization outside the Scheme control plane.
;; : (-> Symbol Value Boolean ConfigArgument)
(defstruct config-argument
  (kind
   value
   secret)
  transparent: #t)

;; : (-> ConfigArgument Boolean)
(def (config-argument-secret? argument)
  (config-argument-secret argument))

;;; Only env/file arguments produce key requirements; literal and placeholder
;;; arguments are already representable without config source lookup.
;; : (-> ConfigArgument MaybeConfigRequirement)
(def (config-argument->requirement argument)
  (let ((kind (config-argument-kind argument))
        (value (config-argument-value argument)))
    (cond
     ((or (eq? kind 'env) (eq? kind 'file))
      (make-config-requirement kind value (config-argument-secret? argument)))
     (else #f))))

;;; Requirement derivation keeps env/file ordering stable while dropping
;;; literals and placeholders that do not require caller-supplied config keys.
;; : (-> [ConfigArgument] [ConfigRequirement])
(def (config-arguments->requirements arguments)
  (filter-map config-argument->requirement arguments))

;;; Rendering keeps placeholder arguments as symbolic runtime references.
;;; Secret source-backed arguments render as redacted references so receipts and
;;; request envelopes do not persist raw secret values.
;; : (-> Alist ConfigArgument Value)
(def (render-config-argument source argument)
  (let ((kind (config-argument-kind argument))
        (value (config-argument-value argument)))
    (cond
     ((eq? kind 'literal) value)
     ((eq? kind 'placeholder)
      (poo-flow-product-field-rows
       (placeholder value)))
     ((or (eq? kind 'env) (eq? kind 'file))
      (if (config-argument-secret? argument)
        (poo-flow-product-field-rows
         (source kind)
         (key value)
         (secret #t))
        (config-source-ref source kind value)))
     (else
      (raise-control-plane-failure
       'config
       'unsupported-config-argument
       "unsupported config argument kind"
       (poo-flow-product-field-rows
        (kind kind)
        (value value)))))))

;;; Boundary: render config arguments is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (forall (source argument value) (-> source [argument] [value]))
;; : (-> Alist List List)
;; : (-> Alist [ConfigArgument] [Value])
(def (render-config-arguments source arguments)
  (map (lambda (argument) (render-config-argument source argument))
       arguments))

;;; A run config is the inspectable data form of a Funflow-style configured
;;; execution entrypoint.
;; : (-> Symbol Strategy RuntimeAdapter Alist TaskFamilyRegistry FlowDeclarationRegistry RunConfigState)
(defstruct run-config-state
  (name
   strategy
   adapter
   options
   task-registry
   flow-registry)
  transparent: #t)

;;; Public config construction keeps existing callers on default POO registries
;;; while allowing extensions to install descriptor bundles at the run boundary.
;; : (-> Symbol Strategy RuntimeAdapter Alist [TaskFamilyRegistry] [FlowDeclarationRegistry] RunConfig)
(def (make-run-config name strategy adapter options . registries)
  (make-run-config-state name
                         strategy
                         adapter
                         options
                         (if (null? registries)
                           default-task-family-registry
                           (car registries))
                         (if (or (null? registries) (null? (cdr registries)))
                           default-flow-declaration-registry
                           (cadr registries))))

;; : (-> RunConfigCandidate Boolean)
(def (run-config? config)
  (run-config-state? config))

;; : (-> RunConfig Symbol)
(def (run-config-name config)
  (run-config-state-name config))

;; : (-> RunConfig Strategy)
(def (run-config-strategy config)
  (run-config-state-strategy config))

;; : (-> RunConfig RuntimeAdapter)
(def (run-config-adapter config)
  (run-config-state-adapter config))

;;; Boundary: run config option is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> RunConfig Alist)
(def (run-config-options config)
  (run-config-state-options config))

;; : (-> RunConfig TaskFamilyRegistry)
(def (run-config-task-registry config)
  (run-config-state-task-registry config))

;; : (-> RunConfig FlowDeclarationRegistry)
(def (run-config-flow-registry config)
  (run-config-state-flow-registry config))

;;; Registry policy is the configured handoff receipt for descriptor bundles.
;;; It is report-only data, so callers can inspect extension boundaries before
;;; creating runtime adapter requests.
;; : (-> RunConfig Alist)
(def (run-config-registry-policy config)
  (poo-flow-product-field-rows
   (task-registry
    (task-family-registry-name
     (run-config-task-registry config)))
   (flow-registry
    (flow-declaration-registry-name
     (run-config-flow-registry config)))))

;;; Boundary: run config option is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Alist Symbol Value Value)
(def (run-config-option options key default)
  (let (entry (assoc key options))
    (if entry
      (cdr entry)
      default)))

;; : (-> RunConfig [ConfigRequirement])
(def (run-config-config-requirements config)
  (run-config-option (run-config-options config) 'config-requirements '()))

;; : (-> RunConfig Alist)
(def (run-config-config-source config)
  (run-config-option (run-config-options config) 'config-source '()))

;;; Preflight keeps the Funflow-style missing-input check before execution.
;;; It checks caller-supplied source keys but does not read files or env vars.
;; : (-> RunConfig ConfigPreflight)
(def (run-config-preflight config)
  (let ((requirements (run-config-config-requirements config))
        (source (run-config-config-source config)))
    (make-config-preflight
     requirements
     (missing-config-requirements requirements source))))

;;; Boundary: run config validate preflight is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> RunConfig Boolean)
(def (run-config-validate-preflight config)
  (let (preflight (run-config-preflight config))
    (if (config-preflight-ok? preflight)
      #t
      (raise-control-plane-failure
       'config
       'missing-config-keys
       "missing config keys"
       (config-preflight->alist preflight)
       #t))))

;;; Registry validation lowers through the runner but stops before execution.
;;; Missing task-family or flow-declaration descriptors therefore fail while
;;; the system is still in the Scheme control plane.
;; : (-> RunConfig Flow Boolean)
(def (run-config-validate-registries config flow)
  (runner-validate (run-config->runner config) flow))

;;; The request-only config records adapter envelopes for tests without claiming
;;; to run store or external work.
;; : (-> Unit RunConfig)
(def (make-request-only-run-config)
  (make-run-config 'request-only
                   (make-local-eager-strategy)
                   (make-request-only-adapter)
                   '((runtime . request-only))))

;;; The Rust config selects the handoff adapter while Scheme keeps ownership of
;;; declaration, planning, and audit evidence.
;; : (-> [Alist] RunConfig)
(def (make-rust-run-config . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (command (run-config-option options 'runtime-command #f)))
    (make-run-config 'rust
                     (make-local-eager-strategy)
                     (make-rust-adapter command)
                     (poo-flow-product-field-rows/tail
                      options
                      (runtime 'rust)))))

;;; Lowering config through the existing runner keeps validation behavior
;;; identical for configured and direct execution.
;; : (-> RunConfig Runner)
(def (run-config->runner config)
  (make-runner (run-config-strategy config)
               (run-config-adapter config)
               (run-config-task-registry config)
               (run-config-flow-registry config)))

;;; Runtime ownership is derived from the selected adapter instead of copied
;;; into config options.
;; : (-> RunConfig Symbol)
(def (run-config-runtime-owner config)
  (runtime-adapter-name (run-config-adapter config)))

;;; The configured entrypoint mirrors Funflow's run-with-config shape while
;;; reusing the normal runner interpreter and receipt schema.
;; : (-> RunConfig Flow Input RunResult)
(def (run-flow-with-config config flow input)
  (run-config-validate-preflight config)
  (run-config-validate-registries config flow)
  (runner-run (run-config->runner config) flow input))

;;; Boundary: config requirement collection projection is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; config-requirement-alists
;;   : (forall (requirement row) (-> [requirement] [row]))
;;   : (-> List Alist)
;;   : (-> [ConfigRequirement] [Alist])
;;   | doc m%
;;       Project config requirement objects into ordered boundary alists.
;;
;;       # Examples
;;       ```scheme
;;       (config-requirement-alists '())
;;       ;; => ()
;;       ```
;;     %
(def (config-requirement-alists requirements)
  (map config-requirement->alist requirements))

;; : (-> [ConfigRequirement] Alist [ConfigRequirement])
(def (missing-config-requirements requirements source)
  (filter (lambda (requirement)
            (not (config-source-satisfies? source requirement)))
          requirements))

;;; Literal requirements are already satisfied; file/env requirements are
;;; satisfied only by key presence in their source bucket.
;; : (-> Alist ConfigRequirement Boolean)
(def (config-source-satisfies? source requirement)
  (let ((source-kind (config-requirement-source requirement))
        (key (config-requirement-key requirement)))
    (if (eq? source-kind 'literal)
      #t
      (let (bucket (config-source-bucket source source-kind))
        (and bucket
             (config-source-entry bucket key)
             #t)))))

;;; Boundary: config source ref is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Alist Symbol Symbol Value)
(def (config-source-ref source source-kind key)
  (let* ((bucket (config-source-bucket source source-kind))
         (entry (and bucket (config-source-entry bucket key))))
    (if entry
      (config-source-entry-value entry)
      (raise-missing-config-value source-kind key))))

;; : (-> Alist Symbol Pair)
(def (config-source-bucket source source-kind)
  (assoc source-kind source))

;; : (-> Pair Alist)
(def (config-source-bucket-entries bucket)
  (cdr bucket))

;; : (-> Pair Symbol Pair)
(def (config-source-entry bucket key)
  (assoc key (config-source-bucket-entries bucket)))

;; : (-> Pair Value)
(def (config-source-entry-value entry)
  (cdr entry))

;; : (-> Symbol Symbol Never)
(def (raise-missing-config-value source-kind key)
  (raise-control-plane-failure
   'config
   'missing-config-keys
   "missing config key"
   (poo-flow-product-field-rows
    (status 'missing)
    (missing
     (list (config-requirement->alist
            (make-config-requirement source-kind key #f)))))
   #t))
