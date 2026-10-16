;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: nono-sandbox C binding descriptor contract projection lives here.
;;; Boundary: this module emits ABI descriptor data only.
;;; Runtime contract: Marlin or another C runtime owns dlopen/FFI execution.
;;; Source contract: symbols mirror the package-owned bindings/nono-c/nono.h.
;;; Policy evidence: binding tests assert descriptor override and manifest gates.

(import (only-in :clan/poo/object .ref object?)
        (only-in :poo-flow/modules/workflow/control-plane/roles execution-policy-role)
        (only-in :poo-flow/modules/workflow/control-plane/failure raise-control-plane-failure)
        :core/object-family/role-syntax
        :poo-flow/modules/agent-sandbox/alist
        :poo-flow/modules/agent-sandbox/profile)

(export +nono-c-binding-schema+
        +nono-c-binding-access-modes+
        +nono-c-binding-network-modes+
        +nono-c-binding-types+
        +nono-c-binding-functions+
        nono-c-binding-descriptor-prototype
        make-nono-c-binding-descriptor
        nono-c-binding-descriptor?
        nono-c-binding-descriptor-name
        nono-c-binding-descriptor-abi
        nono-c-binding-descriptor-package
        nono-c-binding-descriptor-library
        nono-c-binding-descriptor-adapter-header
        nono-c-binding-descriptor-adapter-include-ref
        nono-c-binding-descriptor-header
        nono-c-binding-descriptor-include-ref
        nono-c-binding-descriptor-crate-ref
        nono-c-binding-descriptor-probe-ref
        nono-c-binding-descriptor-types
        nono-c-binding-descriptor-functions
        nono-c-binding-descriptor-access-modes
        nono-c-binding-descriptor-network-modes
        nono-c-binding-descriptor->contract
        nono-c-binding-descriptor-validation-errors
        nono-c-binding-validate-descriptor
        nono-c-binding-access-mode-info
        nono-c-binding-network-mode-info)

;;; Binding manifest schema versioning is separate from the neutral runtime
;;; manifest so nono-sandbox ABI changes can evolve without changing bridge envelopes.
;; : Symbol
(def +nono-c-binding-schema+ 'poo-flow.sandbox.nono-sandbox.c-binding.v1)

;;; Access modes pin Scheme mount policy to the integer constants used by the
;;; C capability API, so validation and projection cannot drift separately.
;; : [AccessModeContract]
(def +nono-c-binding-access-modes+
  '(((scheme . read)
     (constant . NONO_ACCESS_MODE_READ)
     (value . 0))
    ((scheme . write)
     (constant . NONO_ACCESS_MODE_WRITE)
     (value . 1))
    ((scheme . read-write)
     (constant . NONO_ACCESS_MODE_READ_WRITE)
     (value . 2))))

;;; Network modes follow the generated C header exactly. Adding a mode here
;;; requires matching validation and capability-plan projection.
;; : [NetworkModeContract]
(def +nono-c-binding-network-modes+
  '(((scheme . blocked)
     (constant . NONO_NETWORK_MODE_BLOCKED)
     (value . 0))
    ((scheme . allow-all)
     (constant . NONO_NETWORK_MODE_ALLOW_ALL)
     (value . 1))
    ((scheme . proxy-only)
     (constant . NONO_NETWORK_MODE_PROXY_ONLY)
     (value . 2))))

;;; Type names are contract data for a Rust/C bridge; Scheme records the native
;;; ABI inventory but never allocates or owns those C objects.
;; : [Symbol]
(def +nono-c-binding-types+
  '(NonoErrorCode
    NonoDiagnosticCode
    NonoCapabilitySourceTag
    NonoQueryStatus
    NonoQueryReason
    NonoQueryResult
    NonoSupportInfo
    NonoCapabilitySet
    NonoQueryContext
    NonoSandboxState))

;;; Function inventory ownership:
;;; - This list is the allowlist of native entry points a backend may bind.
;;; - Descriptor validation depends on lifecycle and apply symbols being present.
;;; - Runtime bridges can compare this list to `nono.h` during ABI refresh work.
;; : [Symbol]
(def +nono-c-binding-functions+
  '(nono_last_error
    nono_clear_error
    nono_string_free
    nono_version
    nono_last_diagnostic_code
    nono_last_remediation_json
    nono_session_diagnostic_report_to_json
    nono_merge_diagnostic_report_json
    nono_capability_set_new
    nono_capability_set_free
    nono_capability_set_allow_path
    nono_capability_set_allow_file
    nono_capability_set_set_network_blocked
    nono_capability_set_set_network_mode
    nono_capability_set_network_mode
    nono_capability_set_set_proxy_port
    nono_capability_set_proxy_port
    nono_capability_set_allow_command
    nono_capability_set_block_command
    nono_capability_set_add_platform_rule
    nono_capability_set_deduplicate
    nono_capability_set_path_covered
    nono_capability_set_is_network_blocked
    nono_capability_set_summary
    nono_capability_set_fs_count
    nono_capability_set_fs_original
    nono_capability_set_fs_resolved
    nono_capability_set_fs_access
    nono_capability_set_fs_is_file
    nono_capability_set_fs_source_tag
    nono_capability_set_fs_source_group_name
    nono_query_context_new
    nono_query_context_free
    nono_query_context_query_path
    nono_query_context_query_network
    nono_sandbox_apply
    nono_sandbox_is_supported
    nono_sandbox_support_info
    nono_sandbox_state_from_caps
    nono_sandbox_state_free
    nono_sandbox_state_to_json
    nono_sandbox_state_from_json
    nono_sandbox_state_to_caps))

;;; Validator slot delegates through the public descriptor gate so overrides
;;; and direct validation calls report identical typed failures.
;; : (-> NonoCBindingDescriptor NonoCBindingDescriptor)
(def (nono-c-binding-descriptor-validator descriptor)
  (nono-c-binding-validate-descriptor descriptor))

;;; Schema validation pins the binding manifest to this ABI contract version.
;; : (-> NonoCBindingSchemaCandidate Boolean)
(def (nono-c-binding-schema? value)
  (eq? value +nono-c-binding-schema+))

;;; Presence accepts any non-false descriptor field value because artifact refs
;;; may be strings, symbols, or generated backend payloads.
;; : (-> NonoCBindingRequiredFieldCandidate Boolean)
(def (nono-c-binding-present? value)
  (and value #t))

;;; The current binding owner exposes only the C ABI; Rust-side wrappers remain
;;; outside this Scheme contract.
;; : (-> NonoCBindingAbiCandidate Boolean)
(def (nono-c-binding-abi? value)
  (eq? value 'c))

;;; Function validation checks for the minimal allocation/apply pair required
;;; by every runtime capability plan.
;; : (-> NonoCBindingFunctionInventoryCandidate Boolean)
(def (nono-c-binding-functions? value)
  (and (list? value)
       (memq 'nono_capability_set_new value)
       (memq 'nono_sandbox_apply value)))

;;; Binding descriptors are POO objects so backend users can override the ABI
;;; artifact names or header path without changing runtime manifest projection.
;; : NonoCBindingDescriptorPrototype
(def nono-c-binding-descriptor-prototype
  (poo-core-role-object
   (slots ((schema +nono-c-binding-schema+)
           (name 'nono-c-binding)
           (abi 'c)
           (package "nono-ffi")
           (library "nono_ffi")
           (adapter-header "poo_flow_nono_binding.h")
           (adapter-include-ref
            "bindings/nono-c/poo_flow_nono_binding.h")
           (header "nono.h")
           (include-ref "bindings/nono-c/nono.h")
           (crate-ref "bindings/nono-c")
           (probe-ref
            "bindings/nono-c/poo_flow_nono_binding_probe.c")
           (types +nono-c-binding-types+)
           (functions +nono-c-binding-functions+)
           (access-modes +nono-c-binding-access-modes+)
           (network-modes +nono-c-binding-network-modes+)
           (validator
            nono-c-binding-descriptor-validator)))
   (supers execution-policy-role)))

;;; Descriptor construction is the POO override point for local builds that
;;; rename the native library while keeping the same nono ABI contract.
;; : (-> [Alist] NonoCBindingDescriptor)
(def (make-nono-c-binding-descriptor . maybe-overrides)
  (poo-core-role-object
   (slot-rows (if (null? maybe-overrides) '() (car maybe-overrides)))
   (supers nono-c-binding-descriptor-prototype)))

;; : (-> NonoCBindingDescriptorCandidate Boolean)
(def (nono-c-binding-descriptor? descriptor)
  (object? descriptor))

;;; Descriptor access deliberately stays dynamic because the POO object carries
;;; policy defaults and per-call overrides through the same `.ref` path.
;; : (-> NonoCBindingDescriptor Symbol Value Value)
(def (nono-c-binding-descriptor-slot descriptor slot default)
  (if (nono-c-binding-descriptor? descriptor)
    (.ref descriptor slot)
    default))

;; : (-> NonoCBindingDescriptor Symbol)
(def (nono-c-binding-descriptor-name descriptor)
  (nono-c-binding-descriptor-slot descriptor 'name #f))

;; : (-> NonoCBindingDescriptor Symbol)
(def (nono-c-binding-descriptor-abi descriptor)
  (nono-c-binding-descriptor-slot descriptor 'abi #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-package descriptor)
  (nono-c-binding-descriptor-slot descriptor 'package #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-library descriptor)
  (nono-c-binding-descriptor-slot descriptor 'library #f))

;;; Adapter header accessors name the POO Flow-owned C language surface, not the
;;; upstream nono header generated by cbindgen.
;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-adapter-header descriptor)
  (nono-c-binding-descriptor-slot descriptor 'adapter-header #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-adapter-include-ref descriptor)
  (nono-c-binding-descriptor-slot descriptor 'adapter-include-ref #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-header descriptor)
  (nono-c-binding-descriptor-slot descriptor 'header #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-include-ref descriptor)
  (nono-c-binding-descriptor-slot descriptor 'include-ref #f))

;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-crate-ref descriptor)
  (nono-c-binding-descriptor-slot descriptor 'crate-ref #f))

;;; Probe references make compile success auditable from the Scheme contract
;;; without forcing Scheme to execute or link the native nono library.
;; : (-> NonoCBindingDescriptor String)
(def (nono-c-binding-descriptor-probe-ref descriptor)
  (nono-c-binding-descriptor-slot descriptor 'probe-ref #f))

;; : (-> NonoCBindingDescriptor [Symbol])
(def (nono-c-binding-descriptor-types descriptor)
  (nono-c-binding-descriptor-slot descriptor 'types '()))

;; : (-> NonoCBindingDescriptor [Symbol])
(def (nono-c-binding-descriptor-functions descriptor)
  (nono-c-binding-descriptor-slot descriptor 'functions '()))

;; : (-> NonoCBindingDescriptor [AccessModeContract])
(def (nono-c-binding-descriptor-access-modes descriptor)
  (nono-c-binding-descriptor-slot descriptor 'access-modes '()))

;; : (-> NonoCBindingDescriptor [NetworkModeContract])
(def (nono-c-binding-descriptor-network-modes descriptor)
  (nono-c-binding-descriptor-slot descriptor 'network-modes '()))

;;; Descriptor contracts are the stable serializable ABI surface. Runtime
;;; bridges should consume this alist instead of depending on Gerbil POO object
;;; internals or slot precedence rules.
;; : (-> NonoCBindingDescriptor Alist)
(def (nono-c-binding-descriptor->contract descriptor)
  (let (valid-descriptor (nono-c-binding-validate-descriptor descriptor))
    (list (cons 'schema +nono-c-binding-schema+)
          (cons 'name (nono-c-binding-descriptor-name valid-descriptor))
          (cons 'abi (nono-c-binding-descriptor-abi valid-descriptor))
          (cons 'package (nono-c-binding-descriptor-package valid-descriptor))
          (cons 'library (nono-c-binding-descriptor-library valid-descriptor))
          (cons 'adapter-header
                (nono-c-binding-descriptor-adapter-header valid-descriptor))
          (cons 'adapter-include-ref
                (nono-c-binding-descriptor-adapter-include-ref
                 valid-descriptor))
          (cons 'header (nono-c-binding-descriptor-header valid-descriptor))
          (cons 'include-ref
                (nono-c-binding-descriptor-include-ref valid-descriptor))
          (cons 'crate-ref
                (nono-c-binding-descriptor-crate-ref valid-descriptor))
          (cons 'probe-ref
                (nono-c-binding-descriptor-probe-ref valid-descriptor))
          (cons 'types (nono-c-binding-descriptor-types valid-descriptor))
          (cons 'functions
                (nono-c-binding-descriptor-functions valid-descriptor))
          (cons 'access-modes
                (nono-c-binding-descriptor-access-modes valid-descriptor))
          (cons 'network-modes
                (nono-c-binding-descriptor-network-modes valid-descriptor)))))

;;; Descriptor validation protects the generated ABI surface from accidental
;;; Scheme-side drift: users may override artifact names, but the descriptor
;;; must still identify a C binding with the core nono lifecycle/apply symbols.
;; : (-> NonoCBindingDescriptor [ValidationError])
(def (nono-c-binding-descriptor-validation-errors descriptor)
  (if (nono-c-binding-descriptor? descriptor)
    (agent-sandbox-required-field-errors
     (list (cons 'schema
                 (nono-c-binding-descriptor-slot descriptor 'schema #f))
           (cons 'name (nono-c-binding-descriptor-name descriptor))
           (cons 'abi (nono-c-binding-descriptor-abi descriptor))
           (cons 'package (nono-c-binding-descriptor-package descriptor))
           (cons 'library (nono-c-binding-descriptor-library descriptor))
           (cons 'adapter-header
                 (nono-c-binding-descriptor-adapter-header descriptor))
           (cons 'adapter-include-ref
                 (nono-c-binding-descriptor-adapter-include-ref descriptor))
           (cons 'header (nono-c-binding-descriptor-header descriptor))
           (cons 'probe-ref (nono-c-binding-descriptor-probe-ref descriptor))
           (cons 'functions (nono-c-binding-descriptor-functions descriptor)))
     (list (cons 'schema
                 nono-c-binding-schema?)
           (cons 'name nono-c-binding-present?)
           (cons 'abi nono-c-binding-abi?)
           (cons 'package string?)
           (cons 'library string?)
           (cons 'adapter-header string?)
           (cons 'adapter-include-ref string?)
           (cons 'header string?)
           (cons 'probe-ref string?)
           (cons 'functions
                 nono-c-binding-functions?)))
    (list '((field . descriptor) (code . not-poo-object)))))

;;; Validation raises the same typed failure shape as other extension gates so
;;; callers can recover by code without parsing native binding error strings.
;; : (-> NonoCBindingDescriptor NonoCBindingDescriptor)
(def (nono-c-binding-validate-descriptor descriptor)
  (let (errors (nono-c-binding-descriptor-validation-errors descriptor))
    (if (null? errors)
      descriptor
      (raise-control-plane-failure
       'nono-sandbox
       'invalid-nono-c-binding-descriptor
       "invalid nono C binding descriptor"
       (list (cons 'errors errors))))))

;;; Mode lookup is descriptor-scoped so tests and runtime bridges can override
;;; constants for a regenerated header while sharing projection code.
;; : (-> [ModeContract] Symbol MaybeAlist)
(def (nono-c-binding-mode-info modes scheme-name)
  (if (null? modes)
    #f
    (let (mode (car modes))
      (if (eq? (agent-sandbox-alist-ref mode 'scheme #f) scheme-name)
        mode
        (nono-c-binding-mode-info (cdr modes) scheme-name)))))

;;; Public access-mode lookup defaults through the descriptor constructor and
;;; returns the exact C constant/value pair projected for filesystem policy.
;; : (-> Symbol [NonoCBindingDescriptor] MaybeAlist)
(def (nono-c-binding-access-mode-info scheme-name . maybe-descriptor)
  (let (descriptor (if (null? maybe-descriptor)
                    (make-nono-c-binding-descriptor)
                    (car maybe-descriptor)))
    (nono-c-binding-mode-info
     (nono-c-binding-descriptor-access-modes descriptor)
     scheme-name)))

;;; Public network-mode lookup mirrors access lookup and keeps validation tied
;;; to the same descriptor that will be serialized for the runtime.
;; : (-> Symbol [NonoCBindingDescriptor] MaybeAlist)
(def (nono-c-binding-network-mode-info scheme-name . maybe-descriptor)
  (let (descriptor (if (null? maybe-descriptor)
                    (make-nono-c-binding-descriptor)
                    (car maybe-descriptor)))
    (nono-c-binding-mode-info
     (nono-c-binding-descriptor-network-modes descriptor)
     scheme-name)))
