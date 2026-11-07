;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: backend validation keeps sandbox provider checks separate from
;;; profile authoring syntax and runtime execution.
;;; Invariant: validation receipts must be deterministic policy evidence for
;;; every sandbox backend object.

(import :gerbil/core
        (only-in :clan/poo/object object<-alist object? .slot? .ref)
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-capability
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax)

(export agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
        agentic-ai-lab-sandbox-backend-capability-registry-diagnostic?
        agentic-ai-lab-sandbox-backend-capability-registry-validation
        agentic-ai-lab-sandbox-backend-capability-registries-validation
        agentic-ai-lab-sandbox-backend-capability-registry-validation?
        agentic-ai-lab-sandbox-backend-capability-registry-validation-valid?
        agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics
        agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count)

;;; Backend registry diagnostics are fixed internal structs until validation
;;; projects them to alists at the receipt boundary.
;; agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry
;;   : PooSandboxBackendCapabilityRegistryDiagnosticStruct
;;   | contract: fixed diagnostic fields for backend capability registry checks
;;   | result: struct value consumed by the explicit diagnostic ->alist projector
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic?
;;        (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
;;         'missing-entry 'capabilities 'error '()))
;;       ;; => #t
;;       ```
;;     %
;;; Registry diagnostics are internal receipts for backend capability policy validation.
;;; - Keep duplicate entry and alias reports bounded before projecting validation rows.
(defstruct agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry
  (kind schema code phase slot severity payload))

;; agentic-ai-lab-sandbox-backend-capability-registry-diagnostic->alist
;;   : (-> PooSandboxBackendCapabilityRegistryDiagnostic Alist)
;;   | contract: project one fixed backend registry diagnostic to receipt rows
;;   | result: ordered alist preserving payload rows after fixed diagnostic keys
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic->alist diagnostic)
;;       ;; => ((kind . "agentic-ai-lab.sandbox.backend-capability-registry.diagnostic.v1") ...)
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic->alist diagnostic)
  (agentic-ai-lab-sandbox-profile-field-rows/tail
   (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-payload
    diagnostic)
   (kind
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-kind
     diagnostic))
   (schema
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-schema
     diagnostic))
   (code
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-code
     diagnostic))
   (phase
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-phase
     diagnostic))
   (slot
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-slot
     diagnostic))
   (severity
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-severity
     diagnostic))
   (payload
    (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry-payload
     diagnostic))))

;; agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
;;   : (-> Symbol Symbol Symbol Alist PooSandboxBackendCapabilityRegistryDiagnostic)
;;   | contract: construct an inert backend registry diagnostic struct
;;   | result: fixed diagnostic value; callers project with ->alist at boundary
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
;;        'missing-entry 'capabilities 'error '())
;;       ;; => backend capability registry diagnostic struct
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic code
                                                              slot
                                                              severity
                                                              payload)
  (make-agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry
   agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
   agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
   code
   'backend-capability-registry
   slot
   severity
   payload))

;; agentic-ai-lab-sandbox-backend-capability-registry-diagnostic?
;;   : (-> Datum Boolean)
;;   | contract: recognize fixed backend capability diagnostic structs
;;   | result: #t only for backend capability registry diagnostic struct values
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic? '())
;;       ;; => #f
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic? value)
  (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-entry? value))

;; agentic-ai-lab-sandbox-backend-capability-registry-invalid-diagnostics
;;   : (-> SandboxBackendCapabilityRegistryCandidate Fixnum [PooSandboxBackendCapabilityRegistryDiagnostic])
;;   | contract: emit invalid-registry diagnostics for non-registry candidates
;;   | result: empty list for valid registries, otherwise one diagnostic struct
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-invalid-diagnostics '() 0)
;;       ;; => (backend capability registry diagnostic struct)
;;       ```
;;     %
;; : (-> SandboxBackendCapabilityRegistryCandidate Fixnum [PooSandboxBackendCapabilityRegistryDiagnostic])
(def (agentic-ai-lab-sandbox-backend-capability-registry-invalid-diagnostics registry
                                                                       index)
  (if (agentic-ai-lab-sandbox-backend-capability-registry? registry)
    '()
    (list
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'invalid-backend-capability-registry
      'registry
      'error
      (agentic-ai-lab-sandbox-profile-field-rows
       (registry-index index)
       (recoverable? #t))))))

;; agentic-ai-lab-sandbox-backend-capability-registries-invalid-diagnostics
;;   : (-> [SandboxBackendCapabilityRegistryCandidate] Fixnum [PooSandboxBackendCapabilityRegistryDiagnostic])
;;   | contract: scan registry candidates and collect invalid-registry diagnostics
;;   | result: diagnostic structs in traversal order
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registries-invalid-diagnostics '() 0)
;;       ;; => ()
;;       ```
;;     %
;; : (-> [SandboxBackendCapabilityRegistryCandidate] Fixnum [PooSandboxBackendCapabilityRegistryDiagnostic])
(def (agentic-ai-lab-sandbox-backend-capability-registries-invalid-diagnostics
      registries
      index)
  (cond
   ((null? registries) '())
   (else
    (agentic-ai-lab-sandbox-profile-rows/tail
     (agentic-ai-lab-sandbox-backend-capability-registry-invalid-diagnostics
      (car registries)
      index)
     (agentic-ai-lab-sandbox-backend-capability-registries-invalid-diagnostics
      (cdr registries)
      (+ index 1))))))

;; : (-> [PooSandboxBackendCapabilityRegistry] [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registries-entries registries)
  (agentic-ai-lab-sandbox-backend-capability-registries-entries/add
   registries
   '()))

;; : (-> [PooSandboxBackendCapabilityRegistry] [Alist] [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registries-entries/add registries
                                                                 entries)
  (cond
   ((null? registries) (reverse entries))
   ((agentic-ai-lab-sandbox-backend-capability-registry? (car registries))
    (agentic-ai-lab-sandbox-backend-capability-registries-entries/add
     (cdr registries)
     (agentic-ai-lab-sandbox-backend-capability-registry-prepend
      (agentic-ai-lab-sandbox-backend-capability-registry-entries (car registries))
      entries)))
   (else
    (agentic-ai-lab-sandbox-backend-capability-registries-entries/add
     (cdr registries)
     entries))))

;; : (-> [Alist] [Alist] [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registry-prepend values result)
  (cond
   ((null? values) result)
   (else
    (agentic-ai-lab-sandbox-backend-capability-registry-prepend
     (cdr values)
     (cons (car values) result)))))

;; : (-> [PooSandboxBackendCapabilityRegistry] [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registries-aliases registries)
  (agentic-ai-lab-sandbox-backend-capability-registries-aliases/add
   registries
   '()))

;; : (-> [PooSandboxBackendCapabilityRegistry] [Alist] [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registries-aliases/add registries
                                                                 aliases)
  (cond
   ((null? registries) (reverse aliases))
   ((agentic-ai-lab-sandbox-backend-capability-registry? (car registries))
    (agentic-ai-lab-sandbox-backend-capability-registries-aliases/add
     (cdr registries)
     (agentic-ai-lab-sandbox-backend-capability-registry-prepend
      (agentic-ai-lab-sandbox-backend-capability-registry-aliases (car registries))
      aliases)))
   (else
    (agentic-ai-lab-sandbox-backend-capability-registries-aliases/add
     (cdr registries)
     aliases))))

;; agentic-ai-lab-sandbox-backend-capability-registry-member?
;;   : (-> SandboxPolicySlotValue [SandboxPolicySlotValue] Boolean)
;;   | contract: test value membership in a registry validation collection
;;   | result: #t when the value is present, otherwise #f
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-member? 'read '(read))
;;       ;; => #t
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-backend-capability-registry-member? value values)
  (and (member value values) #t))

;; agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
;;   : (-> [Alist] SandboxPolicyIndex SandboxPolicyIndex [Symbol] [Symbol])
;;   | contract: update duplicate tracking indexes while preserving duplicate keys
;;   | result: duplicate key list accumulated in reverse traversal order
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
;;        '() (make-hash-table) (make-hash-table) '())
;;       ;; => ()
;;       ```
;;     %
;; : (-> [Alist] SandboxPolicyIndex SandboxPolicyIndex [Symbol] [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add entries
                                                                       seen
                                                                       duplicate-index
                                                                       result)
  (cond
   ((null? entries) result)
   ((not (pair? (car entries)))
    (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
     (cdr entries)
     seen
     duplicate-index
     result))
   ((hash-get seen (caar entries))
    (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
     (cdr entries)
     seen
     duplicate-index
     (if (hash-get duplicate-index (caar entries))
       result
       (begin
         (hash-put! duplicate-index (caar entries) #t)
         (cons (caar entries) result)))))
   (else
    (hash-put! seen (caar entries) #t)
    (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
     (cdr entries)
     seen
     duplicate-index
     result))))

;; : (-> [Alist] [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys entries)
  (reverse
   (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys/add
    entries
    (make-hash-table)
    (make-hash-table)
    '())))

;; : (-> Symbol Symbol [Symbol] [POOObject])
(def (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-diagnostics code
                                                                         slot
                                                                         keys)
  (cond
   ((null? keys) '())
   (else
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      code
      slot
      'error
      (agentic-ai-lab-sandbox-profile-field-rows
       (key (car keys))
       (recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-diagnostics
      code
      slot
      (cdr keys))))))

;; : (-> [Alist] [POOObject])
(def (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics entries)
  (cond
   ((null? entries) '())
   ((not (pair? (car entries)))
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'invalid-backend-capability-entry
      'entries
      'error
      (agentic-ai-lab-sandbox-profile-field-rows
       (entry (car entries))
       (recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics
      (cdr entries))))
   ((not (agentic-ai-lab-sandbox-backend-capability? (cdar entries)))
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'invalid-backend-capability-entry
      'entries
      'error
      (agentic-ai-lab-sandbox-profile-field-rows
       (backend-kind (caar entries))
       (recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics
      (cdr entries))))
   ((not (equal? (caar entries)
                 (agentic-ai-lab-sandbox-backend-capability/backend-kind
                  (cdar entries))))
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'backend-capability-entry-key-mismatch
      'entries
      'error
      (list
       (cons 'entry-key (caar entries))
       (cons 'backend-kind
             (agentic-ai-lab-sandbox-backend-capability/backend-kind
              (cdar entries)))
       (cons 'recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics
      (cdr entries))))
   (else
    (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics
     (cdr entries)))))

;; : (-> [Alist] [Symbol] [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys/rev entries
                                                                 keys-rev)
  (cond
   ((null? entries) keys-rev)
   ((pair? (car entries))
    (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys/rev
     (cdr entries)
     (cons (caar entries) keys-rev)))
   (else
    (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys/rev
     (cdr entries)
     keys-rev))))

;; : (-> [Alist] [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys entries)
  (reverse
   (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys/rev
    entries
    '())))

;; agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
;;   : (-> [Alist] [Symbol] [PooSandboxBackendCapabilityRegistryDiagnostic])
;;   | contract: validate alias rows against the backend capability entry index
;;   | result: backend capability registry diagnostic structs
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
;;        '() '())
;;       ;; => ()
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics aliases
                                                                      entry-index)
  (cond
   ((null? aliases) '())
   ((not (and (pair? (car aliases))
              (symbol? (caar aliases))
              (symbol? (cdar aliases))))
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'invalid-backend-capability-alias
      'aliases
      'error
      (agentic-ai-lab-sandbox-profile-field-rows
       (alias (car aliases))
       (recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
      (cdr aliases)
      entry-index)))
   ((not (hash-get entry-index (cdar aliases)))
    (cons
     (agentic-ai-lab-sandbox-backend-capability-registry-diagnostic
      'backend-capability-alias-target-missing
      'aliases
      'error
       (agentic-ai-lab-sandbox-profile-field-rows
        (alias (caar aliases))
        (target (cdar aliases))
        (recoverable? #t)))
     (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
      (cdr aliases)
      entry-index)))
   (else
    (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
     (cdr aliases)
     entry-index))))

;; : (-> PooSandboxBackendCapabilityRegistry PooSandboxBackendCapabilityRegistryValidation)
(def (agentic-ai-lab-sandbox-backend-capability-registry-validation registry)
  (agentic-ai-lab-sandbox-backend-capability-registries-validation (list registry)))

;; : (-> [PooSandboxBackendCapabilityRegistry] PooSandboxBackendCapabilityRegistryValidation)
(def (agentic-ai-lab-sandbox-backend-capability-registries-validation registries)
  (let* ((entries
          (agentic-ai-lab-sandbox-backend-capability-registries-entries registries))
         (aliases
          (agentic-ai-lab-sandbox-backend-capability-registries-aliases registries))
         (entry-keys
          (agentic-ai-lab-sandbox-backend-capability-registry-entry-keys entries))
         (entry-index
          (agentic-ai-lab-sandbox-policy-value-index entry-keys))
         (diagnostics
          (agentic-ai-lab-sandbox-profile-rows/tail
           (agentic-ai-lab-sandbox-backend-capability-registries-invalid-diagnostics
            registries
            0)
           (agentic-ai-lab-sandbox-profile-rows/tail
            (agentic-ai-lab-sandbox-backend-capability-registry-entry-diagnostics
             entries)
            (agentic-ai-lab-sandbox-profile-rows/tail
             (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-diagnostics
              'duplicate-backend-capability-id
              'entries
              (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys
               entries))
             (agentic-ai-lab-sandbox-profile-rows/tail
              (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-diagnostics
               'duplicate-backend-capability-alias
               'aliases
               (agentic-ai-lab-sandbox-backend-capability-registry-duplicate-keys
                aliases))
              (agentic-ai-lab-sandbox-backend-capability-registry-alias-diagnostics
               aliases
               entry-index)))))))
    (object<-alist
     (agentic-ai-lab-sandbox-profile-field-rows
      (kind agentic-ai-lab-sandbox-backend-capability-registry-validation-kind)
      (schema agentic-ai-lab-sandbox-backend-capability-registry-validation-kind)
      (valid? (null? diagnostics))
      (registry-count (length registries))
      (entry-count (length entries))
      (alias-count (length aliases))
      (diagnostics
       (map agentic-ai-lab-sandbox-backend-capability-registry-diagnostic->alist
            diagnostics))
      (diagnostic-count (length diagnostics))
      (runtime-executed #f)))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-sandbox-backend-capability-registry-validation? value)
  (agentic-ai-lab-sandbox-policy-object-kind?
   value
   agentic-ai-lab-sandbox-backend-capability-registry-validation-kind))

;; : (-> PooSandboxBackendCapabilityRegistryValidation Boolean)
(def (agentic-ai-lab-sandbox-backend-capability-registry-validation-valid? validation)
  (and (object? validation)
       (.slot? validation 'valid?)
       (.ref validation 'valid?)))

;; : (-> PooSandboxBackendCapabilityRegistryValidation [PooSandboxBackendCapabilityRegistryDiagnostic])
(def (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics
      validation)
  (agentic-ai-lab-sandbox-profile-policy-object-slot/default
   validation
   'diagnostics
   '()))

;; : (-> PooSandboxBackendCapabilityRegistryValidation Fixnum)
(def (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count
      validation)
  (agentic-ai-lab-sandbox-profile-policy-object-slot/default
   validation
   'diagnostic-count
   0))
