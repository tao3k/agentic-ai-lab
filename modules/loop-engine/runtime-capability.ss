;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine capability receipt projection and registry lookup.
;;; Invariant: capability receipts are inert handoff facts; this owner never
;;; probes, opens, validates, or executes a runtime backend.

(import (only-in :agentic-ai-lab/modules/sandbox-core/profile-support/policy
                 agentic-ai-lab-sandbox-backend-capability?
                 agentic-ai-lab-sandbox-backend-capability/backend-kind
                 agentic-ai-lab-sandbox-backend-capability/capabilities
                 agentic-ai-lab-sandbox-backend-capability-registry-entries)
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        "core.ss"
        "runtime-base.ss"
        :yuanxu/utilities/runtime-receipt-syntax
        :yuanxu/utilities/functional)

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
        agentic-ai-lab-user-loop-engine-capability-entry-backend
        agentic-ai-lab-user-loop-engine-capability-supported-backends/add
        agentic-ai-lab-user-loop-engine-capability-supported-backends
        agentic-ai-lab-user-loop-engine-capability-registry-capability
        agentic-ai-lab-user-loop-engine-capability-diagnostics
        agentic-ai-lab-user-loop-engine-capability-receipt-ref
        agentic-ai-lab-user-loop-engine-capability-receipt->alist
        agentic-ai-lab-user-loop-engine-intent-capability-receipt)

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
;; agentic-ai-lab-user-loop-engine-capability-entry-backend
;; : (-> Pair Symbol)
;; | doc m%
;;   Resolve one registry entry to its declared backend symbol.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-user-loop-engine-capability-entry-backend entry)
;;   ;; => backend symbol
;;   ```
(def (agentic-ai-lab-user-loop-engine-capability-entry-backend entry)
  (if (and (pair? entry)
           (agentic-ai-lab-sandbox-backend-capability? (cdr entry)))
    (agentic-ai-lab-sandbox-backend-capability/backend-kind (cdr entry))
    (and (pair? entry) (car entry))))

;; : (-> [Pair] [Symbol] [Symbol])
(def (agentic-ai-lab-user-loop-engine-capability-supported-backends/add entries
                                                                   result)
  (append result
          (filter-map
           agentic-ai-lab-user-loop-engine-capability-entry-backend
           entries)))

;; agentic-ai-lab-user-loop-engine-capability-supported-backends
;; : (-> PooSandboxBackendCapabilityRegistry [Symbol])
;; | doc m%
;;   List supported backend symbols from the static capability registry.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-user-loop-engine-capability-supported-backends registry)
;;   ;; => backend symbols
;;   ```
(def (agentic-ai-lab-user-loop-engine-capability-supported-backends registry)
  (agentic-ai-lab-user-loop-engine-capability-supported-backends/add
   (agentic-ai-lab-sandbox-backend-capability-registry-entries registry)
   '()))

;; : (-> PooSandboxBackendCapabilityRegistry Symbol MaybePooSandboxBackendCapability)
(def (agentic-ai-lab-user-loop-engine-capability-registry-capability registry backend)
  (let (entry (assoc backend
                     (agentic-ai-lab-sandbox-backend-capability-registry-entries
                      registry)))
    (and entry (cdr entry))))

;;; Diagnostics are payload rows for users and ABI consumers. An empty result
;;; means the policy vocabulary is valid, not that a backend probe succeeded.
;; : (-> Symbol PooSandboxBackendCapabilityRegistry [Alist])
(def (agentic-ai-lab-user-loop-engine-capability-diagnostics backend registry)
  (if (or (not backend)
          (agentic-ai-lab-user-loop-engine-capability-registry-capability
           registry
           backend))
    '()
    (list
     (list
      (cons 'field 'backend)
      (cons 'code 'unsupported-capability-backend)
      (cons 'value backend)
      (cons 'supported
            (agentic-ai-lab-user-loop-engine-capability-supported-backends
             registry))))))

;;; Generated capability receipts use fixed struct access internally and only
;;; serialize once at manifest, snapshot, or Marlin handoff boundaries.
;; : (-> LoopEngineCapabilityReceipt Symbol Object Object)
(def (agentic-ai-lab-user-loop-engine-capability-receipt-ref receipt
                                                       slot
                                                       default-value)
  (if (loop-engine-capability-receipt? receipt)
    (case slot
      ((kind) 'capability-receipt)
      ((contract) 'agentic-ai-lab.loop-engine.capability-receipt.v1)
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
    ('contract 'agentic-ai-lab.loop-engine.capability-receipt.v1)
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
(def (agentic-ai-lab-user-loop-engine-capability-receipt->alist receipt)
  (if (loop-engine-capability-receipt? receipt)
    (loop-engine-capability-receipt->alist receipt)
    (error "loop-engine capability receipt must be a generated struct"
           receipt)))

;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-user-loop-engine-capability-policy-field capability-policy
                                                       slot
                                                       default-value)
  (agentic-ai-lab-user-loop-engine-intent-ref capability-policy slot default-value))

;;; Capability receipt is fixed generated Scheme state inside the control
;;; plane. Runtime ABI boundaries serialize it explicitly when handing data to
;;; Marlin or writing bounded summaries.
;; : (-> Alist LoopEngineCapabilityReceipt)
(def (agentic-ai-lab-user-loop-engine-intent-capability-receipt intent
                                                          .
                                                          maybe-registry)
  (if (and (null? maybe-registry) (assoc 'capability-receipt intent))
    (cdr (assoc 'capability-receipt intent))
    (let* ((use-case-name
            (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
           (capability-policy
            (agentic-ai-lab-user-loop-engine-intent-ref intent
                                                  'capability-policy
                                                  '()))
           (registry
            (if (null? maybe-registry)
              (agentic-ai-lab-user-config-sandbox-backend-capability-registry '())
              (car maybe-registry)))
           (backend
            (agentic-ai-lab-user-loop-engine-capability-policy-field
             capability-policy 'backend #f))
           (backend-capability
            (and backend
                 (agentic-ai-lab-user-loop-engine-capability-registry-capability
                  registry
                  backend)))
           (diagnostics
            (agentic-ai-lab-user-loop-engine-capability-diagnostics backend
                                                              registry)))
      (let* ((backend-kind
              (and backend-capability
                   (agentic-ai-lab-sandbox-backend-capability/backend-kind
                    backend-capability)))
             (backend-capabilities
              (if backend-capability
                (agentic-ai-lab-sandbox-backend-capability/capabilities
                 backend-capability)
                '()))
             (supported-backends
              (agentic-ai-lab-user-loop-engine-capability-supported-backends
               registry))
           (isolation
            (agentic-ai-lab-user-loop-engine-capability-policy-field
             capability-policy 'isolation #f))
           (required
            (agentic-ai-lab-user-loop-engine-capability-policy-field
             capability-policy 'required '()))
           (optional
            (agentic-ai-lab-user-loop-engine-capability-policy-field
             capability-policy 'optional '()))
           (unsupported-behavior
            (agentic-ai-lab-user-loop-engine-capability-policy-field
             capability-policy 'unsupported-behavior 'handoff-diagnostic))
             (sandbox-ref
              (agentic-ai-lab-user-loop-engine-intent-primary-sandbox-profile
               intent))
             (session-ref
              (agentic-ai-lab-user-loop-engine-runtime-id use-case-name
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
