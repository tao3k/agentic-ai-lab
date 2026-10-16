;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: Marlin-facing agent sandbox backend dispatch lives here.
;;; Boundary: this module selects backend interface manifests, not runtimes.
;;; Runtime contract: Marlin owns all native/Cube API execution after handoff.
;;; Policy evidence: dispatcher tests assert nono/Cube routing and failure gates.

(import (only-in :poo-flow/modules/workflow/control-plane/failure raise-control-plane-failure)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-protocol +runtime-request-schema+)
        :poo-flow/modules/agent-sandbox/alist
        :poo-flow/modules/agent-sandbox/projection-syntax
        :poo-flow/modules/agent-sandbox/profile
        :poo-flow/modules/agent-sandbox/bridge
        :poo-flow/modules/nono-sandbox/c-binding
        :poo-flow/modules/agent-sandbox/cube-interface)

(export +agent-sandbox-marlin-interface-schema+
        +agent-sandbox-marlin-admission-schema+
        +agent-sandbox-marlin-supported-backends+
        agent-sandbox-marlin-supported-backend?
        agent-sandbox-marlin-runtime-manifest-validation-errors
        agent-sandbox-marlin-validate-runtime-manifest
        agent-sandbox-marlin-admission-envelope-validation-errors
        agent-sandbox-marlin-validate-admission-envelope
        agent-sandbox-runtime-manifest->marlin-interface-manifest
        agent-sandbox-request->marlin-interface-manifest
        agent-sandbox-execution-request->marlin-interface-manifest
        agent-sandbox-execution-request->marlin-admission-envelope)

;; : (-> Symbol Symbol ValidationError)
(def (agent-sandbox-marlin-validation-error field code)
  (agent-sandbox-field-rows
   (field field)
   (code code)))

;; : (-> Symbol ValidationError)
(def (agent-sandbox-marlin-unsupported-backend-error backend-kind)
  (agent-sandbox-field-rows
   (field 'backend-kind)
   (value backend-kind)
   (code 'unsupported-marlin-backend)))

;;; Marlin interface schema is the stable envelope Marlin consumes before it
;;; delegates to backend-specific nono or Cube runners.
;; : (-> Unit MarlinInterfaceSchema)
(def +agent-sandbox-marlin-interface-schema+
  'poo-flow.agent-sandbox-marlin-interface.v1)

;;; Admission envelopes are the Marlin runtime entry contract. They keep the
;;; core runtime request identity beside the selected backend handoff manifest.
;; : (-> Unit MarlinAdmissionSchema)
(def +agent-sandbox-marlin-admission-schema+
  'poo-flow.agent-sandbox-marlin-admission.v1)

;;; Supported backends are explicit so adding a new backend requires a dispatch
;;; branch and tests instead of silently passing through unknown manifests.
;; : (-> Unit [Symbol])
(def +agent-sandbox-marlin-supported-backends+
  '(nono cube))

;; : (-> Symbol Boolean)
(def (agent-sandbox-marlin-supported-backend? backend-kind)
  (and (memq backend-kind +agent-sandbox-marlin-supported-backends+) #t))

;; : (-> RuntimeManifest (U Symbol #f))
(def (agent-sandbox-marlin-runtime-backend-kind runtime-manifest)
  (agent-sandbox-alist-ref
   (agent-sandbox-alist-ref runtime-manifest 'backend '())
   'kind
   #f))

;;; Validation specs are first-class so runtime and admission validation share
;;; the same predicate contract shape instead of repeating anonymous lambdas.
;; : (-> RequiredManifestField Boolean)
(def (agent-sandbox-marlin-present? value)
  (and value #t))

;;; Boundary: schema predicates keep manifest version checks declarative.
;;; Each field spec can carry the expected symbol without closing over runtime IO.
;; : (-> Symbol Predicate)
(def (agent-sandbox-marlin-schema? expected)
  (lambda (value)
    (eq? value expected)))

;; : (-> Symbol Predicate FieldSpec)
(def (agent-sandbox-marlin-field-spec field predicate)
  (cons field predicate))

;;; Marlin dispatch validation checks only the shared handoff envelope. Backend
;;; leaves still validate nono C ABI policy and Cube lifecycle policy.
;; : (-> RuntimeManifest [ValidationError])
(def (agent-sandbox-marlin-runtime-manifest-validation-errors runtime-manifest)
  (if (list? runtime-manifest)
    (let (backend-kind
          (agent-sandbox-marlin-runtime-backend-kind runtime-manifest))
      (let* ((errors-rev
              (agent-sandbox-rows-into/rev
               (agent-sandbox-required-field-errors
                runtime-manifest
                (list (agent-sandbox-marlin-field-spec
                       'schema
                       (agent-sandbox-marlin-schema?
                        +agent-sandbox-runtime-manifest-schema+))))
               '()))
             (errors-rev
              (if (agent-sandbox-marlin-supported-backend? backend-kind)
                errors-rev
                (cons (agent-sandbox-marlin-unsupported-backend-error
                       backend-kind)
                      errors-rev))))
        (reverse errors-rev)))
    (list (agent-sandbox-marlin-validation-error 'runtime-manifest
                                                 'not-alist))))

;;; Validation preserves the manifest in typed failures so callers can decide
;;; whether to repair backend selection or task policy before invoking Marlin.
;; : (-> RuntimeManifest AgentSandboxRuntimeManifest)
(def (agent-sandbox-marlin-validate-runtime-manifest runtime-manifest)
  (let (errors
        (agent-sandbox-marlin-runtime-manifest-validation-errors
         runtime-manifest))
    (if (null? errors)
      runtime-manifest
      (raise-control-plane-failure
       'agent-sandbox-marlin
       'invalid-agent-sandbox-marlin-interface-manifest
       "invalid agent sandbox Marlin interface manifest"
       (agent-sandbox-field-rows
        (errors errors)
        (runtime-manifest runtime-manifest))))))

;;; Backend projection is the only dispatch branch in Scheme. It routes to the
;;; leaf contract owners while keeping runtime execution out of this module.
;; : (-> AgentSandboxRuntimeManifest Alist)
(def (agent-sandbox-marlin-backend-manifest runtime-manifest)
  (let (backend-kind
        (agent-sandbox-marlin-runtime-backend-kind runtime-manifest))
    (cond
     ((eq? backend-kind 'nono)
      (nono-c-binding-runtime-manifest->manifest runtime-manifest))
     ((eq? backend-kind 'cube)
      (cube-interface-runtime-manifest->manifest runtime-manifest))
     (else
      (raise-control-plane-failure
       'agent-sandbox-marlin
       'unsupported-agent-sandbox-marlin-backend
       "unsupported agent sandbox backend for Marlin"
       (agent-sandbox-field-rows
        (backend-kind backend-kind)
        (runtime-manifest runtime-manifest)))))))

;;; Boundary: agent sandbox marlin handoff kind is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Symbol)
(def (agent-sandbox-marlin-handoff-kind backend-kind)
  (cond
   ((eq? backend-kind 'nono) 'nono-c-binding)
   ((eq? backend-kind 'cube) 'cube-interface)
   (else 'unknown)))

;; : (-> Symbol Boolean)
(def (agent-sandbox-marlin-supported-handoff-kind? handoff-kind)
  (and (memq handoff-kind '(nono-c-binding cube-interface)) #t))

;;; Handoff manifests must be non-empty alists; an empty list would validate the
;;; envelope while giving Marlin no backend contract to execute.
;; : (-> MarlinHandoffManifestCandidate Boolean)
(def (agent-sandbox-marlin-handoff-manifest? value)
  (and (pair? value) (list? value)))

;;; Final Marlin handoff wraps the backend-owned manifest with uniform routing
;;; fields. Marlin can inspect `handoff-kind` before delegating to a native or
;;; remote runner, while tests can assert one shape across backends.
;; : (-> AgentSandboxRuntimeManifest MarlinInterfaceManifest)
(def (agent-sandbox-runtime-manifest->marlin-interface-manifest
      runtime-manifest)
  (let* ((valid-manifest
          (agent-sandbox-marlin-validate-runtime-manifest runtime-manifest))
         (backend-kind
          (agent-sandbox-marlin-runtime-backend-kind valid-manifest))
         (backend-manifest
          (agent-sandbox-marlin-backend-manifest valid-manifest)))
    (agent-sandbox-field-rows
     (schema +agent-sandbox-marlin-interface-schema+)
     (runtime-schema
      (agent-sandbox-alist-ref valid-manifest 'schema #f))
     (backend-kind backend-kind)
     (backend
      (agent-sandbox-alist-ref valid-manifest 'backend '()))
     (handoff-kind
      (agent-sandbox-marlin-handoff-kind backend-kind))
     (handoff-schema
      (agent-sandbox-alist-ref backend-manifest 'schema #f))
     (handoff backend-manifest)
     (metadata
      (agent-sandbox-alist-ref valid-manifest 'metadata '())))))

;;; Request projection gives Scheme callers the same Marlin envelope that
;;; execution-request projection will hand to runtime adapters.
;; : (-> AgentSandboxRequest MarlinInterfaceManifest)
(def (agent-sandbox-request->marlin-interface-manifest request)
  (agent-sandbox-runtime-manifest->marlin-interface-manifest
   (agent-sandbox-request->runtime-manifest request)))

;;; Execution-request projection reuses bridge projection so Marlin envelopes
;;; and runtime command envelopes cannot drift.
;; : (-> ExecutionRequest MarlinInterfaceManifest)
(def (agent-sandbox-execution-request->marlin-interface-manifest request)
  (let (runtime-manifest
        (agent-sandbox-alist-ref
         (make-agent-sandbox-bridge-envelope request)
         'runtime-manifest
         #f))
    (agent-sandbox-runtime-manifest->marlin-interface-manifest
     runtime-manifest)))

;;; Boundary: admission validation checks only Marlin's common routing contract.
;;; Backend-specific shape checks stay with the leaf handoff manifests.
;;; Invariant: this function returns validation data and never invokes Marlin.
;; : (-> Alist [ValidationError])
(def (agent-sandbox-marlin-admission-envelope-validation-errors envelope)
  (if (list? envelope)
    (agent-sandbox-required-field-errors
     envelope
     (list (agent-sandbox-marlin-field-spec
            'schema
            (agent-sandbox-marlin-schema?
             +agent-sandbox-marlin-admission-schema+))
           (agent-sandbox-marlin-field-spec
            'runtime-request-schema
            (agent-sandbox-marlin-schema? +runtime-request-schema+))
           (agent-sandbox-marlin-field-spec
            'bridge-schema
            (agent-sandbox-marlin-schema? +agent-sandbox-bridge-schema+))
           (agent-sandbox-marlin-field-spec
            'marlin-interface-schema
            (agent-sandbox-marlin-schema?
             +agent-sandbox-marlin-interface-schema+))
           (agent-sandbox-marlin-field-spec
            'operation
            agent-sandbox-marlin-present?)
           (agent-sandbox-marlin-field-spec
            'request-id
            agent-sandbox-marlin-present?)
           (agent-sandbox-marlin-field-spec
            'artifact-handle
            agent-sandbox-marlin-present?)
           (agent-sandbox-marlin-field-spec
            'backend-kind
            agent-sandbox-marlin-supported-backend?)
           (agent-sandbox-marlin-field-spec
            'handoff-kind
            agent-sandbox-marlin-supported-handoff-kind?)
           (agent-sandbox-marlin-field-spec
            'handoff
            agent-sandbox-marlin-handoff-manifest?)))
    (list (agent-sandbox-marlin-validation-error 'admission-envelope
                                                 'not-alist))))

;;; Boundary: agent sandbox marlin validate admission envelope is the policy-
;;; visible edge for sandbox behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> Alist MarlinAdmissionEnvelope)
(def (agent-sandbox-marlin-validate-admission-envelope envelope)
  (let (errors
        (agent-sandbox-marlin-admission-envelope-validation-errors envelope))
    (if (null? errors)
      envelope
      (raise-control-plane-failure
       'agent-sandbox-marlin
       'invalid-agent-sandbox-marlin-admission-envelope
       "invalid agent sandbox Marlin admission envelope"
       (agent-sandbox-field-rows
        (errors errors)
        (admission-envelope envelope))))))

;;; This is the handoff Marlin should consume from runtime commands: it keeps
;;; Rust request identity and policy data together with the backend contract.
;; : (-> ExecutionRequest [Symbol] MarlinAdmissionEnvelope)
(def (agent-sandbox-execution-request->marlin-admission-envelope
      request
      . maybe-operation)
  (let* ((operation (if (null? maybe-operation) 'submit (car maybe-operation)))
         (bridge-envelope
          (make-agent-sandbox-bridge-envelope request operation))
         (runtime-manifest
          (agent-sandbox-alist-ref bridge-envelope 'runtime-manifest #f))
         (marlin-interface
          (agent-sandbox-runtime-manifest->marlin-interface-manifest
           runtime-manifest))
         (handoff
         (agent-sandbox-alist-ref marlin-interface 'handoff '())))
    (agent-sandbox-marlin-validate-admission-envelope
     (agent-sandbox-field-rows
      (schema +agent-sandbox-marlin-admission-schema+)
      (runtime-request-schema
       (agent-sandbox-alist-ref bridge-envelope 'schema #f))
      (bridge-schema
       (agent-sandbox-alist-ref bridge-envelope 'extension-schema #f))
      (marlin-interface-schema
       (agent-sandbox-alist-ref marlin-interface 'schema #f))
      (operation operation)
      (request-id
       (agent-sandbox-alist-ref bridge-envelope 'request-id #f))
      (artifact-handle
       (agent-sandbox-alist-ref bridge-envelope 'artifact-handle #f))
      (policy
       (agent-sandbox-alist-ref bridge-envelope 'policy '()))
      (plan-id
       (agent-sandbox-alist-ref bridge-envelope 'plan-id #f))
      (node-id
       (agent-sandbox-alist-ref bridge-envelope 'node-id #f))
      (frontier
       (agent-sandbox-alist-ref bridge-envelope 'frontier '()))
      (request-schema
       (agent-sandbox-alist-ref bridge-envelope 'request-schema #f))
      (backend-kind
       (agent-sandbox-alist-ref marlin-interface 'backend-kind #f))
      (backend-ref
       (agent-sandbox-alist-ref bridge-envelope 'backend-ref #f))
      (backend
       (agent-sandbox-alist-ref marlin-interface 'backend '()))
      (command
       (agent-sandbox-alist-ref bridge-envelope 'command #f))
      (handoff-kind
       (agent-sandbox-alist-ref marlin-interface 'handoff-kind #f))
      (handoff-schema
       (agent-sandbox-alist-ref marlin-interface 'handoff-schema #f))
      (handoff handoff)
      (runtime-manifest runtime-manifest)
      (marlin-interface marlin-interface)
      (sandbox
       (agent-sandbox-alist-ref bridge-envelope 'sandbox '()))
      (metadata
       (agent-sandbox-alist-ref marlin-interface 'metadata '()))))))
