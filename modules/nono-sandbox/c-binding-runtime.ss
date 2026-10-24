;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: nono-sandbox C binding runtime manifest projection lives here.
;;; Boundary: this module emits capability plans and backend handoff manifests.
;;; Runtime contract: Marlin or another C runtime owns dlopen/FFI execution.
;;; Source contract: symbols mirror the package-owned bindings/nono-c/nono.h.
;;; Policy evidence: binding tests assert descriptor override and manifest gates.

;;; Native nono C binding runtime manifest projection.
;;; - Keep sandbox manifests validated before runtime dry-run, smoke, or live receipts are emitted.
(import (only-in :yuanxu/modules/funflow/control-plane/failure raise-control-plane-failure)
        :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/profile
        :agentic-ai-lab/modules/agent-sandbox/bridge
        :agentic-ai-lab/modules/nono-sandbox/c-binding-build
        :agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor
        (only-in :std/misc/process run-process))

(export +nono-c-binding-dry-run-receipt-schema+
        +nono-c-binding-smoke-test-receipt-schema+
        +nono-c-binding-live-test-receipt-schema+
        nono-c-binding-compile-probe-command
        nono-c-binding-runtime-manifest-validation-errors
        nono-c-binding-validate-runtime-manifest
        nono-c-binding-dry-run
        nono-c-binding-smoke-test
        nono-c-binding-live-test
        nono-c-binding-runtime-manifest->manifest
        agent-sandbox-request->nono-c-binding-manifest
        agent-sandbox-execution-request->nono-c-binding-manifest)

;;; Runtime receipt rows are generated without touching sandbox execution.
;; nono-c-binding-runtime-field-rows
;; : (-> Syntax Syntax)
;; | contract: expands literal `(field value)` pairs into bounded runtime rows
;; | warning: keep dry-run, smoke, and live execution outside this macro
;; | doc m%
;;   Generates the C binding runtime manifest row list.
;;   # Examples
;;   ```scheme
;;   (nono-c-binding-runtime-field-rows (backend 'nono-c))
;;   ;; => ((backend . nono-c))
;;   ```
(defrules nono-c-binding-runtime-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;; : (-> List List List)
(def (nono-c-binding-runtime-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> List List List)
(def (nono-c-binding-runtime-rows-into/rev rows rows-rev)
  (if (null? rows)
    rows-rev
    (nono-c-binding-runtime-rows-into/rev
     (cdr rows)
     (cons (car rows) rows-rev))))

;;; Dry-run receipts are Scheme-side evidence only. They prove the nono C ABI
;;; manifest can be projected, but they do not load a native library or apply a sandbox.
;; : (-> Unit Symbol)
(def +nono-c-binding-dry-run-receipt-schema+
  'agentic-ai-lab.sandbox.nono-sandbox.c-binding.dry-run.v1)

;;; Smoke receipts add an opt-in process probe over the dry-run receipt while
;;; keeping irreversible nono sandbox application outside Scheme.
;; : (-> Unit Symbol)
(def +nono-c-binding-smoke-test-receipt-schema+
  'agentic-ai-lab.sandbox.nono-sandbox.c-binding.smoke-test.v1)

;;; Live receipts are PATH-gated. They run a harmless installed `nono` probe
;;; when available, and otherwise record a skip instead of failing package tests.
;; : (-> Unit Symbol)
(def +nono-c-binding-live-test-receipt-schema+
  'agentic-ai-lab.sandbox.nono-sandbox.c-binding.live-test.v1)

;;; Mount validation is deliberately stricter than the neutral request schema:
;;; the C ABI needs a UTF-8 path and one of the generated access constants.
;; : (-> Mount Integer [ValidationError])
(def (nono-c-binding-mount-validation-errors mount index)
  (if (list? mount)
    (let* ((path (agent-sandbox-alist-ref mount 'path #f))
           (kind (agent-sandbox-alist-ref mount 'kind #f))
           (mode (agent-sandbox-alist-ref mount 'mode #f)))
      (nono-c-binding-runtime-rows/tail
       (if (string? path)
         '()
         (list
          (nono-c-binding-runtime-field-rows
           (field 'mount-path)
           (index index)
           (code 'missing-or-invalid-path))))
       (nono-c-binding-runtime-rows/tail
        (if (memq kind '(file directory path))
          '()
          (list
           (nono-c-binding-runtime-field-rows
            (field 'mount-kind)
            (index index)
            (value kind)
            (code 'unsupported-mount-kind))))
        (if (nono-c-binding-access-mode-info mode)
          '()
          (list
           (nono-c-binding-runtime-field-rows
            (field 'mount-mode)
            (index index)
            (value mode)
            (code 'unsupported-access-mode)))))))
    (list
     (nono-c-binding-runtime-field-rows
      (field 'mount)
      (index index)
      (code 'not-alist)))))

;;; Mount validation preserves indices so runtime-manifest errors point back to
;;; the exact filesystem grant that cannot be represented by nono's C ABI.
;; : (-> [Mount] Integer [ValidationError])
(def (nono-c-binding-mounts-validation-errors/rev mounts index errors-rev)
  (if (null? mounts)
    errors-rev
    (nono-c-binding-mounts-validation-errors/rev
     (cdr mounts)
     (+ index 1)
     (nono-c-binding-runtime-rows-into/rev
      (nono-c-binding-mount-validation-errors (car mounts) index)
      errors-rev))))

;; : (-> [Mount] Integer [ValidationError])
(def (nono-c-binding-mounts-validation-errors mounts index)
  (reverse (nono-c-binding-mounts-validation-errors/rev mounts index '())))

;;; Network validation maps Scheme policy modes to nono's concrete constants
;;; before any runtime tries to set an unsupported mode through C.
;; : (-> NetworkPolicy [ValidationError])
(def (nono-c-binding-network-validation-errors network-policy)
  (let (mode (agent-sandbox-alist-ref network-policy 'mode 'blocked))
    (if (nono-c-binding-network-mode-info mode)
      '()
      (list
       (nono-c-binding-runtime-field-rows
        (field 'network-mode)
        (value mode)
        (code 'unsupported-network-mode))))))

;;; Runtime manifests must first satisfy the neutral sandbox bridge schema
;;; before this backend projects them into C ABI calls.
;; : (-> NonoCBindingRuntimeSchemaCandidate Boolean)
(def (nono-c-binding-runtime-schema? value)
  (eq? value +agent-sandbox-runtime-manifest-schema+))

;;; Backend validation keeps nono C projection from accepting Cube or generic
;;; sandbox manifests by accident.
;; : (-> NonoCBindingRuntimeBackendCandidate Boolean)
(def (nono-c-binding-runtime-backend? value)
  (eq? value 'nono))

;;; Runtime required fields accept any non-false process command payload; the
;;; C binding layer only checks presence before backend-owned command encoding.
;; : (-> NonoRuntimeRequiredFieldCandidate Boolean)
(def (nono-c-binding-runtime-present? value)
  (and value #t))

;;; Runtime manifest validation is the backend-specific gate missing from the
;;; neutral bridge layer: only nono manifests with C-representable processes,
;;; mounts, and network modes may become FFI call plans.
;; : (-> RuntimeManifest [ValidationError])
(def (nono-c-binding-runtime-manifest-validation-errors runtime-manifest)
  (if (list? runtime-manifest)
    (let* ((backend (agent-sandbox-alist-ref runtime-manifest 'backend '()))
           (process (agent-sandbox-alist-ref runtime-manifest 'process '()))
           (filesystem (agent-sandbox-alist-ref runtime-manifest 'filesystem '()))
           (mounts (agent-sandbox-alist-ref filesystem 'mounts '()))
           (network-policy
            (agent-sandbox-alist-ref runtime-manifest 'network-policy '())))
      (nono-c-binding-runtime-rows/tail
       (agent-sandbox-required-field-errors
        runtime-manifest
        (nono-c-binding-runtime-field-rows
         (schema nono-c-binding-runtime-schema?)))
       (nono-c-binding-runtime-rows/tail
        (agent-sandbox-required-field-errors
         backend
         (nono-c-binding-runtime-field-rows
          (kind nono-c-binding-runtime-backend?)))
        (nono-c-binding-runtime-rows/tail
         (agent-sandbox-required-field-errors
          process
          (nono-c-binding-runtime-field-rows
           (command nono-c-binding-runtime-present?)
           (argv list?)))
         (nono-c-binding-runtime-rows/tail
          (if (list? mounts)
            (nono-c-binding-mounts-validation-errors mounts 0)
            (list
             (nono-c-binding-runtime-field-rows
              (field 'mounts)
              (code 'not-list))))
          (nono-c-binding-network-validation-errors network-policy))))))
    (list
     (nono-c-binding-runtime-field-rows
      (field 'runtime-manifest)
      (code 'not-alist)))))

;;; This validator is the last Scheme-side boundary before a native runtime
;;; receives the manifest, so it preserves the original manifest in failures
;;; for bridge diagnostics and policy tests.
;; : (-> RuntimeManifest AgentSandboxRuntimeManifest)
(def (nono-c-binding-validate-runtime-manifest runtime-manifest)
  (let (errors
        (nono-c-binding-runtime-manifest-validation-errors runtime-manifest))
    (if (null? errors)
      runtime-manifest
      (raise-control-plane-failure
       'nono-sandbox
       'invalid-nono-c-binding-manifest
       "invalid nono C binding runtime manifest"
       (nono-c-binding-runtime-field-rows
        (errors errors)
        (runtime-manifest runtime-manifest))))))

;;; Mount manifests carry one canonical kind selected before C projection.
;; : (-> Mount Symbol)
(def (nono-c-binding-mount-kind mount)
  (agent-sandbox-alist-ref mount 'kind #f))

;;; Boundary: nono c binding mount function is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Mount Symbol)
(def (nono-c-binding-mount-function mount)
  (if (eq? (nono-c-binding-mount-kind mount) 'file)
    'nono_capability_set_allow_file
    'nono_capability_set_allow_path))

;;; Mount calls choose the exact nono function at projection time. File grants
;;; become `allow_file`, while directory/path grants use `allow_path`.
;; : (-> Mount Alist)
(def (nono-c-binding-mount-call mount)
  (let* ((mode (agent-sandbox-alist-ref mount 'mode #f))
         (mode-info (nono-c-binding-access-mode-info mode)))
    (list (cons 'stage 'filesystem)
          (cons 'function (nono-c-binding-mount-function mount))
          (cons 'path (agent-sandbox-alist-ref mount 'path #f))
          (cons 'kind (nono-c-binding-mount-kind mount))
          (cons 'access-mode mode)
          (cons 'access-constant
                (agent-sandbox-alist-ref mode-info 'constant #f))
          (cons 'access-value
                (agent-sandbox-alist-ref mode-info 'value #f)))))

;;; Mount call mapping is a pure sequence transform: every validated mount has
;;; enough path/kind/mode data for `nono-c-binding-mount-call`, so `map` keeps
;;; one output ABI call per input grant without hidden filtering or reordering.
;; : (-> [Mount] [Alist])
(def (nono-c-binding-mount-calls mounts)
  (map nono-c-binding-mount-call mounts))

;;; Network calls are split so proxy-only manifests can set both the mode and
;;; optional port while blocked/allow-all remain single-call plans.
;; : (-> NetworkPolicy [Alist])
(def (nono-c-binding-network-calls network-policy)
  (let* ((mode (agent-sandbox-alist-ref network-policy 'mode 'blocked))
         (mode-info (nono-c-binding-network-mode-info mode))
         (proxy-port (agent-sandbox-alist-ref network-policy 'proxy-port #f))
         (mode-call
          (list (cons 'stage 'network)
                (cons 'function 'nono_capability_set_set_network_mode)
                (cons 'mode mode)
                (cons 'network-constant
                      (agent-sandbox-alist-ref mode-info 'constant #f))
                (cons 'network-value
                      (agent-sandbox-alist-ref mode-info 'value #f)))))
    (if proxy-port
      (list mode-call
            (list (cons 'stage 'network-proxy)
                  (cons 'function 'nono_capability_set_set_proxy_port)
                  (cons 'port proxy-port)))
      (list mode-call))))

;;; Capability inputs accept scalar or list values; normalizing here keeps all
;;; plan builders list-shaped before they emit ABI function calls.
;; : (-> MaybeValue [Value])
(def (nono-c-binding-list-value value)
  (cond ((not value) '())
        ((list? value) value)
        (else (list value))))

;;; Command and platform-rule capability helpers keep optional nono-specific
;;; policy extensions out of the neutral request schema.
;; : (-> Symbol Symbol String Alist)
(def (nono-c-binding-string-call stage function-name value)
  (list (cons 'stage stage)
        (cons 'function function-name)
        (cons 'value value)))

;;; Mapper construction is intentionally first-class: capability plan assembly
;;; reuses the same stage/function specialization for allow, block, and
;;; platform-rule lists without repeating wrapper lambdas at each call site.
;; : (-> Symbol Symbol Procedure)
(def (nono-c-binding-string-call-mapper stage function-name)
  (lambda (value)
    (nono-c-binding-string-call stage function-name value)))

;;; Neutral sandbox capabilities may contain symbolic grants such as
;;; `filesystem-read`. Backend-specific command policies are pair-shaped
;;; extension entries; filter before using alist lookup so both forms coexist.
;; : (-> Capabilities Alist)
(def (nono-c-binding-capability-extension-entries capabilities)
  (cond
   ((null? capabilities) '())
   ((pair? (car capabilities))
    (cons (car capabilities)
          (nono-c-binding-capability-extension-entries (cdr capabilities))))
   (else
    (nono-c-binding-capability-extension-entries (cdr capabilities)))))

;;; String capability projection owns the optional extension keys that are not
;;; part of the neutral sandbox schema. Missing keys normalize to an empty list,
;;; so each caller receives a pure map over the backend-owned policy values.
;; : (-> Capabilities Symbol Symbol Symbol [Alist])
(def (nono-c-binding-string-calls capabilities key stage function-name)
  (let (extension-entries
        (nono-c-binding-capability-extension-entries capabilities))
    (map (nono-c-binding-string-call-mapper stage function-name)
         (nono-c-binding-list-value
          (agent-sandbox-alist-ref extension-entries key '())))))

;;; Capability plans are declarative C call sequences. They preserve ordering
;;; for a Rust/C runtime bridge while Scheme keeps ownership of validation and
;;; avoids applying the irreversible nono sandbox itself.
;; : (-> RuntimeManifest [Alist])
(def (nono-c-binding-capability-plan runtime-manifest)
  (let* ((filesystem (agent-sandbox-alist-ref runtime-manifest 'filesystem '()))
         (mounts (agent-sandbox-alist-ref filesystem 'mounts '()))
         (network-policy
          (agent-sandbox-alist-ref runtime-manifest 'network-policy '()))
         (capabilities
          (agent-sandbox-alist-ref runtime-manifest 'capabilities '())))
    (nono-c-binding-runtime-rows/tail
     (list
      (nono-c-binding-runtime-field-rows
       (stage 'create-capability-set)
       (function 'nono_capability_set_new)))
     (nono-c-binding-runtime-rows/tail
      (nono-c-binding-mount-calls mounts)
      (nono-c-binding-runtime-rows/tail
       (nono-c-binding-network-calls network-policy)
       (nono-c-binding-runtime-rows/tail
        (nono-c-binding-string-calls capabilities
                                     'allow-commands
                                     'allow-command
                                     'nono_capability_set_allow_command)
        (nono-c-binding-runtime-rows/tail
         (nono-c-binding-string-calls capabilities
                                      'block-commands
                                      'block-command
                                      'nono_capability_set_block_command)
         (nono-c-binding-runtime-rows/tail
          (nono-c-binding-string-calls capabilities
                                       'platform-rules
                                       'platform-rule
                                       'nono_capability_set_add_platform_rule)
          (list
           (nono-c-binding-runtime-field-rows
            (stage 'deduplicate)
            (function 'nono_capability_set_deduplicate)))))))))))

;;; The dry-run receipt is the nono C binding preflight surface: it validates
;;; the neutral runtime manifest, projects the ABI call plan, and reports the
;;; native apply entrypoint without calling it.
;; nono-c-binding-dry-run
;;   : (-> RuntimeManifest [NonoCBindingDescriptor] Alist)
;;   | contract: validates and projects only; native sandbox apply is never called
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (nono-c-binding-dry-run runtime-manifest)
;;       ;; => receipt
;;       ```
;;     %
(def (nono-c-binding-dry-run runtime-manifest . maybe-descriptor)
  (let* ((manifest
          (apply nono-c-binding-runtime-manifest->manifest
                 runtime-manifest
                 maybe-descriptor))
         (capability-plan
          (agent-sandbox-alist-ref manifest 'capability-plan '()))
         (apply-plan
          (agent-sandbox-alist-ref manifest 'apply-plan '())))
    (nono-c-binding-runtime-field-rows
     (schema +nono-c-binding-dry-run-receipt-schema+)
     (ok? #t)
     (runtime-executed #f)
     (would-apply? #f)
     (binding
      (agent-sandbox-alist-ref manifest 'binding '()))
     (backend
      (agent-sandbox-alist-ref manifest 'backend '()))
     (process
      (agent-sandbox-alist-ref manifest 'process '()))
     (capability-plan-count
      (length capability-plan))
     (apply-function
      (agent-sandbox-alist-ref apply-plan 'apply #f))
     (support-function
      (agent-sandbox-alist-ref apply-plan 'support #f)))))

;;; Smoke tests run a host probe command through Gerbil's standard process
;;; library after dry-run validation. The default probe is the direct C compile
;;; argv; callers may pass a safer or platform-specific command.
;; nono-c-binding-smoke-test
;;   : (forall (c) (-> RuntimeManifest [c] Alist))
;;   : (-> RuntimeManifest [Command] Alist)
;;   | contract: runs a host probe command only; native sandbox apply is never called
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (nono-c-binding-smoke-test runtime-manifest (nono-c-binding-compile-probe-command))
;;       ;; => receipt
;;       ```
;;     %
(def (nono-c-binding-smoke-test runtime-manifest . maybe-command)
  (let* ((dry-run (nono-c-binding-dry-run runtime-manifest))
         (command (if (null? maybe-command)
                    (nono-c-binding-compile-probe-command)
                    (car maybe-command)))
         (status 0)
         (output
          (run-process command
                       stderr-redirection: #t
                       check-status:
                       (lambda (exit-status _settings)
                         (set! status exit-status)))))
    (list (cons 'schema +nono-c-binding-smoke-test-receipt-schema+)
          (cons 'ok? (zero? status))
          (cons 'status status)
          (cons 'output output)
          (cons 'command command)
          (cons 'runtime-executed #f)
          (cons 'would-apply? #f)
          (cons 'dry-run dry-run))))

;;; Live probes are enabled by PATH discovery: if the command can be spawned,
;;; its exit status determines success; if it cannot be spawned, the receipt is
;;; an explicit skip. The default command is `nono --version`, not sandbox apply.
;; nono-c-binding-live-test
;;   : (forall (c) (-> RuntimeManifest [c] Alist))
;;   : (-> RuntimeManifest [Command] Alist)
;;   | contract: runs only an installed nono CLI probe; native sandbox apply is never called
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (nono-c-binding-live-test runtime-manifest)
;;       ;; => live receipt, either enabled or skipped
;;       ```
;;     %
(def (nono-c-binding-live-test runtime-manifest . maybe-command)
  (let* ((dry-run (nono-c-binding-dry-run runtime-manifest))
         (command (if (null? maybe-command)
                    '("nono" "--version")
                    (car maybe-command)))
         (status 0)
         (output-or-failure
          (with-catch
           (lambda (failure) failure)
           (lambda ()
             (run-process command
                          stderr-redirection: #t
                          check-status:
                          (lambda (exit-status _settings)
                            (set! status exit-status)))))))
    (if (string? output-or-failure)
      (list (cons 'schema +nono-c-binding-live-test-receipt-schema+)
            (cons 'ok? (zero? status))
            (cons 'enabled? #t)
            (cons 'skipped? #f)
            (cons 'status status)
            (cons 'output output-or-failure)
            (cons 'command command)
            (cons 'live-executed #t)
            (cons 'runtime-executed #f)
            (cons 'would-apply? #f)
            (cons 'dry-run dry-run))
      (list (cons 'schema +nono-c-binding-live-test-receipt-schema+)
            (cons 'ok? #t)
            (cons 'enabled? #f)
            (cons 'skipped? #t)
            (cons 'skip-reason 'nono-not-found-on-path)
            (cons 'command command)
            (cons 'live-executed #f)
            (cons 'runtime-executed #f)
            (cons 'would-apply? #f)
            (cons 'dry-run dry-run)))))

;;; Final projection packages the verified ABI contract, request policy, and
;;; query/apply/state entry points into one backend-owned manifest. Consumers
;;; can bind this data to C directly without reading Gerbil request internals
;;; or invoking native code from the Scheme layer.
;; : (-> AgentSandboxRuntimeManifest [NonoCBindingDescriptor] NonoCBindingManifest)
(def (nono-c-binding-runtime-manifest->manifest runtime-manifest
                                                . maybe-descriptor)
  (let* ((descriptor
          (nono-c-binding-validate-descriptor
           (if (null? maybe-descriptor)
             (make-nono-c-binding-descriptor)
             (car maybe-descriptor))))
         (valid-manifest
          (nono-c-binding-validate-runtime-manifest runtime-manifest))
         (backend (agent-sandbox-alist-ref valid-manifest 'backend '()))
         (process (agent-sandbox-alist-ref valid-manifest 'process '()))
         (filesystem (agent-sandbox-alist-ref valid-manifest 'filesystem '()))
         (network-policy
          (agent-sandbox-alist-ref valid-manifest 'network-policy '())))
    (list (cons 'schema +nono-c-binding-schema+)
          (cons 'binding
                (nono-c-binding-descriptor->contract descriptor))
          (cons 'runtime-schema
                (agent-sandbox-alist-ref valid-manifest 'schema #f))
          (cons 'backend backend)
          (cons 'process process)
          (cons 'filesystem filesystem)
          (cons 'network-policy network-policy)
          (cons 'capability-plan
                (nono-c-binding-capability-plan valid-manifest))
          (cons 'query-plan
                '((context-new . nono_query_context_new)
                  (context-free . nono_query_context_free)
                  (query-path . nono_query_context_query_path)
                  (query-network . nono_query_context_query_network)
                  (result-string-free . nono_string_free)))
          (cons 'diagnostic-plan
                '((last-code . nono_last_diagnostic_code)
                  (last-remediation-json . nono_last_remediation_json)
                  (session-report-json .
                   nono_session_diagnostic_report_to_json)
                  (merge-report-json . nono_merge_diagnostic_report_json)
                  (string-free . nono_string_free)))
          (cons 'apply-plan
                '((apply . nono_sandbox_apply)
                  (support . nono_sandbox_is_supported)
                  (support-info . nono_sandbox_support_info)))
          (cons 'state-plan
                '((from-caps . nono_sandbox_state_from_caps)
                  (state-free . nono_sandbox_state_free)
                  (to-json . nono_sandbox_state_to_json)
                  (from-json . nono_sandbox_state_from_json)
                  (to-caps . nono_sandbox_state_to_caps)))
          (cons 'resource-policy
                (agent-sandbox-alist-ref valid-manifest 'resource-policy '()))
          (cons 'output-policy
                (agent-sandbox-alist-ref valid-manifest 'output-policy #f))
          (cons 'metadata
                (agent-sandbox-alist-ref valid-manifest 'metadata '())))))

;;; Request projection lets Scheme callers ask for a nono C binding manifest
;;; directly while still passing through the neutral runtime manifest contract.
;; : (-> AgentSandboxRequest [NonoCBindingDescriptor] NonoCBindingManifest)
(def (agent-sandbox-request->nono-c-binding-manifest request
                                                     . maybe-descriptor)
  (apply nono-c-binding-runtime-manifest->manifest
         (agent-sandbox-request->runtime-manifest request)
         maybe-descriptor))

;;; Execution-request projection is the adapter-facing entry point: it reuses
;;; the bridge envelope so C binding manifests and Marlin envelopes cannot drift.
;; : (-> ExecutionRequest [NonoCBindingDescriptor] NonoCBindingManifest)
(def (agent-sandbox-execution-request->nono-c-binding-manifest request
                                                               . maybe-descriptor)
  (let (runtime-manifest
        (agent-sandbox-alist-ref
         (make-agent-sandbox-bridge-envelope request)
         'runtime-manifest
         #f))
    (apply nono-c-binding-runtime-manifest->manifest
           runtime-manifest
           maybe-descriptor)))
