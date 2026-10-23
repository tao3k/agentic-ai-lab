;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile validation is the policy gate between inherited
;;; profile objects and runtime sandbox execution.
;;; Invariant: profile validation must reject unsafe partial profiles before a
;;; backend can materialize filesystem or resource isolation.

(import :gerbil/core
        (only-in :clan/poo/object object? .slot? .ref object<-alist)
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-capability
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-validation
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-profile-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax
        (only-in :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
                 agentic-ai-lab-durable-policy?
                 agentic-ai-lab-durable-policy-diagnostic->alist
                 agentic-ai-lab-durable-policy-diagnostics
                 agentic-ai-lab-durable-policy->receipt
                 agentic-ai-lab-durable-policy-name
                 agentic-ai-lab-durable-policy-receipt->alist)
        (only-in :agentic-ai-lab/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics))

(export agentic-ai-lab-sandbox-profile-policy-diagnostic
        agentic-ai-lab-sandbox-profile-policy-diagnostic?
        agentic-ai-lab-sandbox-profile-policy-diagnostics
        agentic-ai-lab-sandbox-profile-policy-validation
        agentic-ai-lab-sandbox-profile-policy-validation-valid?
        agentic-ai-lab-sandbox-profile-policy-validation-diagnostics
        agentic-ai-lab-sandbox-profile-policy-validation-diagnostic-count
        agentic-ai-lab-sandbox-profile-policy-projection-validation
        agentic-ai-lab-sandbox-profile-policy-projection-valid?
        agentic-ai-lab-sandbox-profile-policy-projection-diagnostics
        agentic-ai-lab-sandbox-profile-policy-projection)

;; agentic-ai-lab-sandbox-profile-policy-diagnostic-entry
;;   : PooSandboxProfilePolicyDiagnosticStruct
;;   | contract: fixed diagnostic fields for sandbox profile policy checks
;;   | result: struct value consumed by the explicit diagnostic ->alist projector
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-diagnostic?
;;        (agentic-ai-lab-sandbox-profile-policy-diagnostic
;;         'missing-resource 'resource-policy 'error '()))
;;       ;; => #t
;;       ```
;;     %
;;; Profile validation diagnostics keep sandbox resource and durable checks explicit.
;;; - Keep filesystem capability failures visible before runtime profile projection.
(defstruct agentic-ai-lab-sandbox-profile-policy-diagnostic-entry
  (kind schema code phase severity payload))

;; agentic-ai-lab-sandbox-profile-policy-diagnostic->alist
;;   : (-> PooSandboxProfilePolicyDiagnostic Alist)
;;   | contract: project one fixed profile policy diagnostic to receipt rows
;;   | result: ordered alist preserving payload rows after fixed diagnostic keys
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-diagnostic->alist diagnostic)
;;       ;; => ((kind . "agentic-ai-lab.sandbox.profile-policy.diagnostic.v1") ...)
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-diagnostic->alist diagnostic)
  (agentic-ai-lab-sandbox-profile-field-rows/tail
   (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-payload diagnostic)
   (kind
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-kind diagnostic))
   (schema
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-schema diagnostic))
   (code
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-code diagnostic))
   (phase
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-phase diagnostic))
   (severity
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-severity diagnostic))
   (payload
    (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry-payload diagnostic))))

;; agentic-ai-lab-sandbox-profile-policy-diagnostic
;;   : (-> Symbol Symbol Symbol Alist PooSandboxProfilePolicyDiagnostic)
;;   | contract: construct an inert sandbox profile diagnostic struct
;;   | result: fixed diagnostic value; callers project with ->alist at boundary
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-diagnostic
;;        'missing-resource 'resource-policy 'error '())
;;       ;; => sandbox profile policy diagnostic struct
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-diagnostic code
                                                 phase
                                                 severity
                                                 payload)
  (make-agentic-ai-lab-sandbox-profile-policy-diagnostic-entry
   agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
   agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
   code
   phase
   severity
   payload))

;; agentic-ai-lab-sandbox-profile-policy-diagnostic?
;;   : (-> Datum Boolean)
;;   | contract: recognize fixed sandbox profile diagnostic structs
;;   | result: #t only for sandbox profile policy diagnostic struct values
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-diagnostic? '())
;;       ;; => #f
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-diagnostic? value)
  (agentic-ai-lab-sandbox-profile-policy-diagnostic-entry? value))

;; : (-> Symbol Symbol Alist Alist)
(def (agentic-ai-lab-sandbox-profile-policy-filesystem-capability? capability)
  (cond
   ((symbol? capability)
    (or (eq? capability 'filesystem)
        (eq? capability 'filesystem-read)
        (eq? capability 'filesystem-write)))
   ((pair? capability)
    (agentic-ai-lab-sandbox-profile-policy-filesystem-capability? (car capability)))
   (else #f)))

;; : (-> [Capability] Boolean)
(def (agentic-ai-lab-sandbox-profile-policy-capabilities-have-filesystem?
      capabilities)
  (cond
   ((null? capabilities) #f)
   ((not (pair? capabilities)) #f)
   ((agentic-ai-lab-sandbox-profile-policy-filesystem-capability?
     (car capabilities))
    #t)
   (else
    (agentic-ai-lab-sandbox-profile-policy-capabilities-have-filesystem?
     (cdr capabilities)))))

;; : (-> ResourcePolicy Boolean)
(def (agentic-ai-lab-sandbox-profile-policy-resource-policy-has-filesystem?
      resource-policy)
  (cond
   ((null? resource-policy) #f)
   ((not (pair? resource-policy)) #f)
   ((agent-sandbox-profile-resource-policy-filesystem-entry?
     (car resource-policy))
    #t)
   (else
    (agentic-ai-lab-sandbox-profile-policy-resource-policy-has-filesystem?
     (cdr resource-policy)))))

;; agentic-ai-lab-sandbox-profile-policy-alist-ref
;;   : (-> Alist Symbol Value Value)
;;   | contract: read one profile row with a default value
;;   | result: row value when present, otherwise default value
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-alist-ref
;;        '((network-policy . deny)) 'network-policy 'allow)
;;       ;; => deny
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;; agentic-ai-lab-sandbox-profile-policy-resource-diagnostic
;;   : (-> Symbol Symbol Alist PooSandboxProfilePolicyDiagnostic)
;;   | contract: construct one resource-policy diagnostic for a profile/backend pair
;;   | result: fixed profile policy diagnostic struct
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic
;;        'profile 'backend '())
;;       ;; => sandbox profile policy diagnostic struct
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic profile-name
                                                          backend-kind
                                                          diagnostic)
  (agentic-ai-lab-sandbox-profile-policy-diagnostic
   (agentic-ai-lab-sandbox-profile-policy-alist-ref
    diagnostic
    'code
    'invalid-resource-policy)
   'resource
   'error
   (agentic-ai-lab-sandbox-profile-field-rows
    (profile profile-name)
    (backend-kind backend-kind)
    (slot
     (agentic-ai-lab-sandbox-profile-policy-alist-ref
      diagnostic
      'field
      'resource-policy))
    (detail diagnostic)
    (recoverable? #t))))

;; agentic-ai-lab-sandbox-profile-policy-resource-diagnostics
;;   : (-> Symbol Symbol [Symbol] ResourcePolicy [PooSandboxProfilePolicyDiagnostic])
;;   | contract: validate resource policy rows for required capabilities
;;   | result: profile policy diagnostic structs for invalid resource coverage
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-resource-diagnostics
;;        'profile 'backend '() '())
;;       ;; => ()
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-resource-diagnostics profile-name
                                                           backend-kind
                                                           capabilities
                                                           resource-policy)
  (let ((has-filesystem-capability?
         (agentic-ai-lab-sandbox-profile-policy-capabilities-have-filesystem?
          capabilities))
        (has-filesystem-resource?
         (agentic-ai-lab-sandbox-profile-policy-resource-policy-has-filesystem?
          resource-policy)))
    (agentic-ai-lab-sandbox-profile-rows/tail
     (if (and (not (null? resource-policy))
              (not has-filesystem-capability?))
       (list
        (agentic-ai-lab-sandbox-profile-policy-diagnostic
         'missing-filesystem-sandbox-capability
         'resource
         'error
         (agentic-ai-lab-sandbox-profile-field-rows
          (profile profile-name)
          (backend-kind backend-kind)
          (slot 'capabilities)
          (requires 'resource-policy)
          (resource-policy resource-policy)
          (recoverable? #t))))
       '())
     (agentic-ai-lab-sandbox-profile-rows/tail
      (if (and has-filesystem-capability?
               (not has-filesystem-resource?))
        (list
         (agentic-ai-lab-sandbox-profile-policy-diagnostic
          'missing-filesystem-sandbox-resource
          'resource
          'error
          (agentic-ai-lab-sandbox-profile-field-rows
           (profile profile-name)
           (backend-kind backend-kind)
           (slot 'resource-policy)
           (requires 'filesystem)
           (resource-policy resource-policy)
           (recoverable? #t))))
        '())
      (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows
       profile-name
       backend-kind
       (agent-sandbox-profile-resource-policy-filesystem-diagnostics
        resource-policy))))))

;; agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows/rev
;;   : (-> Symbol Symbol [Alist] [Alist] [Alist])
;;   | contract: accumulate resource diagnostic rows for a profile/backend pair
;;   | result: diagnostic rows prepended to the reversed row accumulator
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows/rev
;;        'profile 'backend '() '())
;;       ;; => ()
;;       ```
;;     %
;; : (-> Symbol Symbol [Alist] [Alist] [Alist])
(def (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows/rev profile-name
                                                                    backend-kind
                                                                    diagnostics
                                                                    rows-rev)
  (if (null? diagnostics)
    rows-rev
    (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows/rev
     profile-name
     backend-kind
     (cdr diagnostics)
     (cons (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic
            profile-name
            backend-kind
            (car diagnostics))
           rows-rev))))

;; agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows
;;   : (-> Symbol Symbol [Alist] [Alist])
;;   | contract: project resource policy diagnostic payloads into ordered rows
;;   | result: ordered resource diagnostic rows for validation receipts
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows
;;        'profile 'backend '())
;;       ;; => ()
;;       ```
;;     %
;; : (-> Symbol Symbol [Alist] [Alist])
(def (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows profile-name
                                                               backend-kind
                                                               diagnostics)
  (reverse
   (agentic-ai-lab-sandbox-profile-policy-resource-diagnostic-rows/rev
    profile-name
    backend-kind
    diagnostics
    '())))

;; agentic-ai-lab-sandbox-profile-policy-durable-summary
;;   : (-> PooSandboxProfilePolicy Symbol Symbol Symbol Alist)
;;   | contract: project durable policy slots into a report-only summary row
;;   | result: alist summary used by profile policy validation receipts
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-durable-summary
;;        policy 'profile 'backend 'ref)
;;       ;; => ((profile . profile) ...)
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-durable-summary profile-policy
                                                      profile-name
                                                      backend-kind
                                                      backend-ref)
  (let (durable-policy
        (agentic-ai-lab-sandbox-profile-policy-durable-policy profile-policy))
    (if (agentic-ai-lab-durable-policy? durable-policy)
      (let (receipt
            (agentic-ai-lab-durable-policy->receipt
             durable-policy
             (list (cons 'session-id profile-name)
                   (cons 'loop-run-id backend-ref))))
        (let (receipt-alist
              (agentic-ai-lab-durable-policy-receipt->alist receipt))
          (list
           (cons 'policy-id
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'policy-id
                  #f))
           (cons 'backend-kind backend-kind)
           (cons 'backend-ref backend-ref)
           (cons 'sandbox-handle-class
                 (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
                  profile-policy))
           (cons 'journal-owner
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'journal-owner
                  #f))
           (cons 'checkpoint-store
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'checkpoint-store
                  #f))
           (cons 'repair-mode
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'repair-mode
                  #f))
           (cons 'action-classes
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'action-classes
                  '()))
           (cons 'runtime-owner
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'runtime-owner
                  #f))
           (cons 'valid?
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'valid?
                  #f))
           (cons 'diagnostic-count
                 (agentic-ai-lab-sandbox-profile-policy-alist-ref
                  receipt-alist
                  'diagnostic-count
                  0))
           (cons 'runtime-executed #f))))
      (list
       (cons 'policy-id #f)
       (cons 'backend-kind backend-kind)
       (cons 'backend-ref backend-ref)
       (cons 'sandbox-handle-class
             (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
              profile-policy))
       (cons 'valid? #f)
       (cons 'diagnostic-count 1)
       (cons 'runtime-executed #f)))))

;; agentic-ai-lab-sandbox-profile-policy-durable-diagnostics
;;   : (-> Symbol Symbol PooSandboxProfilePolicy [PooSandboxProfilePolicyDiagnostic])
;;   | contract: validate durable policy ownership and handoff rows
;;   | result: profile policy diagnostic structs for durable-policy failures
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-durable-diagnostics
;;        'profile 'backend policy)
;;       ;; => ()
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-durable-diagnostics profile-name
                                                          backend-kind
                                                          profile-policy)
  (let (durable-policy
        (agentic-ai-lab-sandbox-profile-policy-durable-policy profile-policy))
    (cond
     ((not durable-policy)
      (list
       (agentic-ai-lab-sandbox-profile-policy-diagnostic
        'missing-durable-placement-policy
        'durable
        'error
        (list
         (cons 'profile profile-name)
         (cons 'backend-kind backend-kind)
         (cons 'slot 'durable-policy)
         (cons 'requires 'sandbox-durable-placement)
         (cons 'recoverable? #t)))))
     ((not (agentic-ai-lab-durable-policy? durable-policy))
      (list
       (agentic-ai-lab-sandbox-profile-policy-diagnostic
        'invalid-durable-placement-policy
        'durable
        'error
        (list
         (cons 'profile profile-name)
         (cons 'backend-kind backend-kind)
         (cons 'slot 'durable-policy)
         (cons 'value durable-policy)
         (cons 'expected 'agentic-ai-lab-durable-policy)
         (cons 'recoverable? #t)))))
     (else
      (let (durable-diagnostics
            (agentic-ai-lab-durable-policy-diagnostics durable-policy))
        (if (null? durable-diagnostics)
          '()
          (list
           (agentic-ai-lab-sandbox-profile-policy-diagnostic
            'invalid-durable-placement-policy
            'durable
            'error
            (list
             (cons 'profile profile-name)
             (cons 'backend-kind backend-kind)
             (cons 'slot 'durable-policy)
             (cons 'policy
                   (agentic-ai-lab-durable-policy-name durable-policy))
             (cons 'diagnostics
                   (map agentic-ai-lab-durable-policy-diagnostic->alist
                        durable-diagnostics))
             (cons 'recoverable? #t))))))))))

;; agentic-ai-lab-sandbox-profile-policy-diagnostics
;;   : (-> Symbol Symbol PooSandboxBackendCapability PooSandboxProfilePolicy [Symbol] [POOObject])
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profile-policy-diagnostics` compares effective
;;       profile capabilities with the selected backend's static POO capability
;;       object and returns POO diagnostic objects for unsupported capabilities
;;       and invalid resource policy.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-diagnostics
;;        'agent/gpu 'nono agentic-ai-lab-sandbox-backend-capability/nono
;;        (agentic-ai-lab-sandbox-profile-policy '(gpu-device)) '())
;;       ;; => POO diagnostic objects
;;       ```
(def (agentic-ai-lab-sandbox-profile-policy-diagnostics profile-name
                                                  backend-kind
                                                  backend-capability
                                                  profile-policy
                                                  profile-capabilities
                                                  .
                                                  maybe-resource-policy)
  (let* ((required
          (agentic-ai-lab-sandbox-profile-policy-effective-required
           profile-policy
           profile-capabilities))
         (resource-policy
          (if (null? maybe-resource-policy)
            (agentic-ai-lab-sandbox-profile-policy-resource-policy profile-policy)
            (car maybe-resource-policy))))
    (agentic-ai-lab-sandbox-profile-rows/tail
     (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics
      profile-name
      backend-kind
      backend-capability
      required)
     (agentic-ai-lab-sandbox-profile-rows/tail
      (agentic-ai-lab-sandbox-profile-policy-resource-diagnostics
       profile-name
       backend-kind
       profile-capabilities
       resource-policy)
      (agentic-ai-lab-sandbox-profile-policy-durable-diagnostics
       profile-name
       backend-kind
       profile-policy)))))

;; : (-> Symbol Symbol PooSandboxBackendCapability [Symbol] [Alist] [Alist])
(def (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics/rev
      profile-name
      backend-kind
      backend-capability
      required
      diagnostics-rev)
  (cond
   ((null? required) diagnostics-rev)
   ((agentic-ai-lab-sandbox-backend-capability-supports?
     backend-capability
     (car required))
    (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics/rev
     profile-name
     backend-kind
     backend-capability
     (cdr required)
     diagnostics-rev))
   (else
    (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics/rev
     profile-name
     backend-kind
     backend-capability
     (cdr required)
     (cons
      (agentic-ai-lab-sandbox-profile-policy-diagnostic
       'missing-backend-capability
       'capability
       'error
       (agentic-ai-lab-sandbox-profile-field-rows
        (profile profile-name)
        (backend-kind backend-kind)
        (slot 'capabilities)
        (required (car required))
        (supported
         (agentic-ai-lab-sandbox-backend-capability/capabilities
          backend-capability))
        (recoverable? #t)))
      diagnostics-rev)))))

;; : (-> Symbol Symbol PooSandboxBackendCapability [Symbol] [Alist])
(def (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics
      profile-name
      backend-kind
      backend-capability
      required)
  (reverse
   (agentic-ai-lab-sandbox-profile-policy-required-capability-diagnostics/rev
    profile-name
    backend-kind
    backend-capability
    required
    '())))

;;; Boundary: sandbox profile policy validation binds backend capabilities to
;;; inherited profile policy before runtime sandbox materialization.
;; : (-> Symbol Symbol Symbol PooSandboxBackendCapability PooSandboxProfilePolicy [Symbol] POOObject)
(def (agentic-ai-lab-sandbox-profile-policy-validation profile-name
                                                 backend-kind
                                                 backend-ref
                                                 backend-capability
                                                 profile-policy
                                                 profile-capabilities
                                                 .
                                                 maybe-resource-policy)
  (let* ((resource-policy
          (if (null? maybe-resource-policy)
            (agentic-ai-lab-sandbox-profile-policy-resource-policy profile-policy)
            (car maybe-resource-policy)))
         (diagnostics
          (agentic-ai-lab-sandbox-profile-policy-diagnostics
           profile-name
           backend-kind
           backend-capability
           profile-policy
           profile-capabilities
           resource-policy))
         (valid? (null? diagnostics)))
    (object<-alist
     (list
      (cons 'kind agentic-ai-lab-sandbox-profile-policy-validation-kind)
      (cons 'schema agentic-ai-lab-sandbox-profile-policy-validation-kind)
      (cons 'valid? valid?)
      (cons 'profile profile-name)
      (cons 'backend-kind backend-kind)
      (cons 'backend-ref backend-ref)
      (cons 'required-capabilities
            (agentic-ai-lab-sandbox-profile-policy-effective-required
             profile-policy
             profile-capabilities))
      (cons 'backend-capabilities
            (agentic-ai-lab-sandbox-backend-capability/capabilities
             backend-capability))
      (cons 'resource-policy resource-policy)
      (cons 'durable-policy-ref
            (agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
             profile-policy))
      (cons 'durable-policy-summary
            (agentic-ai-lab-sandbox-profile-policy-durable-summary
             profile-policy
             profile-name
             backend-kind
             backend-ref))
      (cons 'durable-valid?
            (and (agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
                  profile-policy)
                 (null? (agentic-ai-lab-sandbox-profile-policy-durable-diagnostics
                         profile-name
                         backend-kind
                         profile-policy))))
      (cons 'sandbox-handle-class
            (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
             profile-policy))
      (cons 'diagnostics
            (map agentic-ai-lab-sandbox-profile-policy-diagnostic->alist
                 diagnostics))
      (cons 'diagnostic-count (length diagnostics))
      (cons 'runtime-executed #f)))))

;; agentic-ai-lab-sandbox-profile-policy-validation-valid?
;;   : (-> PooSandboxProfilePolicyValidation Boolean)
;;   | contract: inspect a validation receipt object's valid? slot
;;   | result: #t only when the validation object explicitly records valid? #t
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-validation-valid? '())
;;       ;; => #f
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
  (and (object? validation)
       (.slot? validation 'valid?)
       (.ref validation 'valid?)))

;; : (-> PooSandboxProfilePolicyValidation [PooSandboxProfilePolicyDiagnostic])
(def (agentic-ai-lab-sandbox-profile-policy-validation-diagnostics validation)
  (agentic-ai-lab-sandbox-profile-policy-object-slot/default
   validation
   'diagnostics
   '()))

;; : (-> PooSandboxProfilePolicyValidation Fixnum)
(def (agentic-ai-lab-sandbox-profile-policy-validation-diagnostic-count validation)
  (agentic-ai-lab-sandbox-profile-policy-object-slot/default
   validation
   'diagnostic-count
   0))

;; : (-> PooSandboxProfilePolicyProjection PooSandboxProfilePolicyValidation)
(def (agentic-ai-lab-sandbox-profile-policy-projection-validation projection)
  (agentic-ai-lab-sandbox-profile-policy-object-slot/default
   projection
   'validation
   #f))

;; : (-> PooSandboxProfilePolicyProjection BOOLEAN)
(def (agentic-ai-lab-sandbox-profile-policy-projection-valid? projection)
  (and (object? projection)
       (.slot? projection 'valid?)
       (.ref projection 'valid?)))

;; : (-> PooSandboxProfilePolicyProjection [PooSandboxProfilePolicyDiagnostic])
(def (agentic-ai-lab-sandbox-profile-policy-projection-diagnostics projection)
  (let (validation
        (agentic-ai-lab-sandbox-profile-policy-projection-validation projection))
    (if validation
      (agentic-ai-lab-sandbox-profile-policy-validation-diagnostics validation)
      '())))

;; : (-> Symbol Symbol Symbol PooSandboxBackendCapability PooSandboxProfilePolicy [Symbol] POOObject)
(def (agentic-ai-lab-sandbox-profile-policy-projection profile-name
                                                 backend-kind
                                                 backend-ref
                                                 backend-capability
                                                 profile-policy
                                                 profile-capabilities
                                                 .
                                                 maybe-resource-policy)
  (let (validation
        (agentic-ai-lab-sandbox-profile-policy-validation
         profile-name
         backend-kind
         backend-ref
         backend-capability
         profile-policy
         profile-capabilities
         (if (null? maybe-resource-policy)
           (agentic-ai-lab-sandbox-profile-policy-resource-policy profile-policy)
           (car maybe-resource-policy))))
    (object<-alist
     (list
      (cons 'kind agentic-ai-lab-sandbox-profile-policy-projection-kind)
      (cons 'schema agentic-ai-lab-sandbox-profile-policy-projection-kind)
      (cons 'profile profile-name)
      (cons 'backend-kind backend-kind)
      (cons 'backend-ref backend-ref)
      (cons 'validation validation)
      (cons 'valid?
            (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation))
      (cons 'durable-policy-ref
            (agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
             profile-policy))
      (cons 'durable-policy-summary
            (agentic-ai-lab-sandbox-profile-policy-durable-summary
             profile-policy
             profile-name
             backend-kind
             backend-ref))
      (cons 'durable-valid?
            (agentic-ai-lab-sandbox-profile-policy-object-slot/default
             validation
             'durable-valid?
             #f))
      (cons 'sandbox-handle-class
            (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
             profile-policy))
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f)))))
