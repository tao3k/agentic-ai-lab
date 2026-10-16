;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine capability receipt projection and registry lookup.
;;; Invariant: capability receipts are inert handoff facts; this owner never
;;; probes, opens, validates, or executes a runtime backend.

(import (only-in :poo-flow/modules/sandbox-core/profile-support/policy
                 poo-flow-sandbox-backend-capability?
                 poo-flow-sandbox-backend-capability/backend-kind
                 poo-flow-sandbox-backend-capability/capabilities
                 poo-flow-sandbox-backend-capability-registry-entries)
        :poo-flow/modules/sandbox-core/backend-capability-catalog
        "core.ss"
        "runtime-base.ss"
        :core/utilities/runtime-receipt-syntax
        :core/utilities/functional)

(export make-loop-engine-capability-receipt
        loop-engine-capability-receipt?
        loop-engine-capability-receipt-backend
        loop-engine-capability-receipt-backend-kind
        loop-engine-capability-receipt-backend-capabilities
        loop-engine-capability-receipt-supported-backends
        loop-engine-capability-receipt-valid?
        loop-engine-capability-receipt-diagnostics
        loop-engine-capability-receipt-isolation
        loop-engine-capability-receipt-required
        loop-engine-capability-receipt-optional
        loop-engine-capability-receipt-unsupported-behavior
        loop-engine-capability-receipt-sandbox-ref
        loop-engine-capability-receipt-session-ref
        loop-engine-capability-receipt->alist
        loop-engine-capability-receipt-diagnostic-count
        poo-flow-user-loop-engine-capability-entry-backend
        poo-flow-user-loop-engine-capability-supported-backends/add
        poo-flow-user-loop-engine-capability-supported-backends
        poo-flow-user-loop-engine-capability-registry-capability
        poo-flow-user-loop-engine-capability-diagnostics
        poo-flow-user-loop-engine-capability-receipt-ref
        poo-flow-user-loop-engine-capability-receipt->alist
        poo-flow-user-loop-engine-intent-capability-receipt)

;;; Capability receipts are generated runtime state, not user-authored POO
;;; declarations. Keep the hot construction path as a fixed Gerbil struct and
;;; project to alists only at manifest, snapshot, test-summary, and Marlin
;;; handoff boundaries.
;; loop-engine-capability-receipt
;; : GerbilStruct
;; | doc m%
;;   Fixed runtime capability receipt storage for Marlin handoff projections.
;;   # Examples
;;   ```scheme
;;   (loop-engine-capability-receipt? receipt)
;;   ;; => #t when receipt has the generated struct shape
;;   ```
(defstruct loop-engine-capability-receipt
  (backend
   backend-kind
   backend-capabilities
   supported-backends
   valid?
   diagnostics
   isolation
   required
   optional
   unsupported-behavior
   sandbox-ref
   session-ref)
  transparent: #t)

;; loop-engine-capability-receipt-diagnostic-count
;; : (-> LoopEngineCapabilityReceipt Integer)
;; | doc m%
;;   Count generated capability receipt diagnostics without serializing it.
;;   # Examples
;;   ```scheme
;;   (loop-engine-capability-receipt-diagnostic-count receipt)
;;   ;; => diagnostic count
;;   ```
(def (loop-engine-capability-receipt-diagnostic-count receipt)
  (length (loop-engine-capability-receipt-diagnostics receipt)))

;;; Capability receipts are OpenRath-inspired backend expectation facts. They
;;; read the static module-system capability registry and never probe, open, or
;;; validate a live backend.
;; poo-flow-user-loop-engine-capability-entry-backend
;; : (-> Pair Symbol)
;; | doc m%
;;   Resolve one registry entry to its declared backend symbol.
;;   # Examples
;;   ```scheme
;;   (poo-flow-user-loop-engine-capability-entry-backend entry)
;;   ;; => backend symbol
;;   ```
(def (poo-flow-user-loop-engine-capability-entry-backend entry)
  (if (and (pair? entry)
           (poo-flow-sandbox-backend-capability? (cdr entry)))
    (poo-flow-sandbox-backend-capability/backend-kind (cdr entry))
    (and (pair? entry) (car entry))))

;; : (-> [Pair] [Symbol] [Symbol])
(def (poo-flow-user-loop-engine-capability-supported-backends/add entries
                                                                   result)
  (append result
          (filter-map
           poo-flow-user-loop-engine-capability-entry-backend
           entries)))

;; poo-flow-user-loop-engine-capability-supported-backends
;; : (-> PooSandboxBackendCapabilityRegistry [Symbol])
;; | doc m%
;;   List supported backend symbols from the static capability registry.
;;   # Examples
;;   ```scheme
;;   (poo-flow-user-loop-engine-capability-supported-backends registry)
;;   ;; => backend symbols
;;   ```
(def (poo-flow-user-loop-engine-capability-supported-backends registry)
  (poo-flow-user-loop-engine-capability-supported-backends/add
   (poo-flow-sandbox-backend-capability-registry-entries registry)
   '()))

;; : (-> PooSandboxBackendCapabilityRegistry Symbol MaybePooSandboxBackendCapability)
(def (poo-flow-user-loop-engine-capability-registry-capability registry backend)
  (let (entry (assoc backend
                     (poo-flow-sandbox-backend-capability-registry-entries
                      registry)))
    (and entry (cdr entry))))

;;; Diagnostics are payload rows for users and ABI consumers. An empty result
;;; means the policy vocabulary is valid, not that a backend probe succeeded.
;; : (-> Symbol PooSandboxBackendCapabilityRegistry [Alist])
(def (poo-flow-user-loop-engine-capability-diagnostics backend registry)
  (if (or (not backend)
          (poo-flow-user-loop-engine-capability-registry-capability
           registry
           backend))
    '()
    (list
     (list
      (cons 'field 'backend)
      (cons 'code 'unsupported-capability-backend)
      (cons 'value backend)
      (cons 'supported
            (poo-flow-user-loop-engine-capability-supported-backends
             registry))))))

;;; Generated capability receipts use fixed struct access internally and only
;;; serialize once at manifest, snapshot, or Marlin handoff boundaries.
;; : (-> LoopEngineCapabilityReceipt Symbol Object Object)
(def (poo-flow-user-loop-engine-capability-receipt-ref receipt
                                                       slot
                                                       default-value)
  (if (loop-engine-capability-receipt? receipt)
    (case slot
      ((kind) 'capability-receipt)
      ((contract) 'poo-flow.loop-engine.capability-receipt.v1)
      ((backend)
       (loop-engine-capability-receipt-backend receipt))
      ((backend-kind)
       (loop-engine-capability-receipt-backend-kind receipt))
      ((backend-capabilities)
       (loop-engine-capability-receipt-backend-capabilities receipt))
      ((supported-backends)
       (loop-engine-capability-receipt-supported-backends receipt))
      ((valid?)
       (loop-engine-capability-receipt-valid? receipt))
      ((diagnostic-count)
       (loop-engine-capability-receipt-diagnostic-count receipt))
      ((diagnostics)
       (loop-engine-capability-receipt-diagnostics receipt))
      ((isolation)
       (loop-engine-capability-receipt-isolation receipt))
      ((required)
       (loop-engine-capability-receipt-required receipt))
      ((optional)
       (loop-engine-capability-receipt-optional receipt))
      ((unsupported-behavior)
       (loop-engine-capability-receipt-unsupported-behavior receipt))
      ((sandbox-ref)
       (loop-engine-capability-receipt-sandbox-ref receipt))
      ((session-ref)
       (loop-engine-capability-receipt-session-ref receipt))
      ((runtime-owner) "marlin-agent-core")
      ((runtime-executed) #f)
      (else default-value))
    default-value))

;; : (-> LoopEngineCapabilityReceipt Alist)
(defpoo-runtime-receipt-projection
  loop-engine-capability-receipt->alist
  (receipt)
  (bindings ())
  (fields
   (('kind 'capability-receipt)
    ('contract 'poo-flow.loop-engine.capability-receipt.v1)
    ('backend (loop-engine-capability-receipt-backend receipt))
    ('backend-kind (loop-engine-capability-receipt-backend-kind receipt))
    ('backend-capabilities
     (loop-engine-capability-receipt-backend-capabilities receipt))
    ('supported-backends
     (loop-engine-capability-receipt-supported-backends receipt))
    ('valid? (loop-engine-capability-receipt-valid? receipt))
    ('diagnostic-count
     (loop-engine-capability-receipt-diagnostic-count receipt))
    ('diagnostics (loop-engine-capability-receipt-diagnostics receipt))
    ('isolation (loop-engine-capability-receipt-isolation receipt))
    ('required (loop-engine-capability-receipt-required receipt))
    ('optional (loop-engine-capability-receipt-optional receipt))
    ('unsupported-behavior
     (loop-engine-capability-receipt-unsupported-behavior receipt))
    ('sandbox-ref (loop-engine-capability-receipt-sandbox-ref receipt))
    ('session-ref (loop-engine-capability-receipt-session-ref receipt))
    ('runtime-owner "marlin-agent-core")
    ('runtime-executed #f))))

;; : (-> Object Alist)
(def (poo-flow-user-loop-engine-capability-receipt->alist receipt)
  (if (loop-engine-capability-receipt? receipt)
    (loop-engine-capability-receipt->alist receipt)
    (error "loop-engine capability receipt must be a generated struct"
           receipt)))

;; : (-> Alist Symbol Object Object)
(def (poo-flow-user-loop-engine-capability-policy-field capability-policy
                                                       slot
                                                       default-value)
  (poo-flow-user-loop-engine-intent-ref capability-policy slot default-value))

;;; Capability receipt is fixed generated Scheme state inside the control
;;; plane. Runtime ABI boundaries serialize it explicitly when handing data to
;;; Marlin or writing bounded summaries.
;; : (-> Alist LoopEngineCapabilityReceipt)
(def (poo-flow-user-loop-engine-intent-capability-receipt intent
                                                          .
                                                          maybe-registry)
  (if (and (null? maybe-registry) (assoc 'capability-receipt intent))
    (cdr (assoc 'capability-receipt intent))
    (let* ((use-case-name
            (poo-flow-user-loop-engine-intent-use-case-name intent))
           (capability-policy
            (poo-flow-user-loop-engine-intent-ref intent
                                                  'capability-policy
                                                  '()))
           (registry
            (if (null? maybe-registry)
              (poo-flow-user-config-sandbox-backend-capability-registry '())
              (car maybe-registry)))
           (backend
            (poo-flow-user-loop-engine-capability-policy-field
             capability-policy 'backend #f))
           (backend-capability
            (and backend
                 (poo-flow-user-loop-engine-capability-registry-capability
                  registry
                  backend)))
           (diagnostics
            (poo-flow-user-loop-engine-capability-diagnostics backend
                                                              registry)))
      (let* ((backend-kind
              (and backend-capability
                   (poo-flow-sandbox-backend-capability/backend-kind
                    backend-capability)))
             (backend-capabilities
              (if backend-capability
                (poo-flow-sandbox-backend-capability/capabilities
                 backend-capability)
                '()))
             (supported-backends
              (poo-flow-user-loop-engine-capability-supported-backends
               registry))
           (isolation
            (poo-flow-user-loop-engine-capability-policy-field
             capability-policy 'isolation #f))
           (required
            (poo-flow-user-loop-engine-capability-policy-field
             capability-policy 'required '()))
           (optional
            (poo-flow-user-loop-engine-capability-policy-field
             capability-policy 'optional '()))
           (unsupported-behavior
            (poo-flow-user-loop-engine-capability-policy-field
             capability-policy 'unsupported-behavior 'handoff-diagnostic))
             (sandbox-ref
              (poo-flow-user-loop-engine-intent-primary-sandbox-profile
               intent))
             (session-ref
              (poo-flow-user-loop-engine-runtime-id use-case-name
                                                   "session")))
        (make-loop-engine-capability-receipt
         backend
         backend-kind
         backend-capabilities
         supported-backends
         (null? diagnostics)
         diagnostics
         isolation
         required
         optional
         unsupported-behavior
         sandbox-ref
         session-ref)))))
