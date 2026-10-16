;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared durable policy POO capability objects.
;;; Invariant: this layer validates and projects durable intent only; Rust or
;;; Marlin owns fact logs, checkpoints, indexes, leases, replay, and repair.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        :core/utilities/final-projection-syntax)

(export +poo-flow-durable-policy-kind+
        +poo-flow-durable-policy-schema+
        +poo-flow-durable-policy-diagnostic-schema+
        +poo-flow-durable-policy-receipt-schema+
        +poo-flow-durable-action-classes+
        +poo-flow-durable-repair-modes+
        make-poo-flow-durable-policy-receipt
        poo-flow-durable-policy-receipt?
        poo-flow-durable-policy-receipt-policy-id
        poo-flow-durable-policy-receipt-project-id
        poo-flow-durable-policy-receipt-root-session-id
        poo-flow-durable-policy-receipt-session-id
        poo-flow-durable-policy-receipt-parent-session-id
        poo-flow-durable-policy-receipt-loop-run-id
        poo-flow-durable-policy-receipt-checkpoint-policy-ref
        poo-flow-durable-policy-receipt-journal-policy-ref
        poo-flow-durable-policy-receipt-index-policy-ref
        poo-flow-durable-policy-receipt-resume-policy-ref
        poo-flow-durable-policy-receipt-repair-policy-ref
        poo-flow-durable-policy-receipt-journal-owner
        poo-flow-durable-policy-receipt-checkpoint-store
        poo-flow-durable-policy-receipt-resume-identity
        poo-flow-durable-policy-receipt-repair-mode
        poo-flow-durable-policy-receipt-action-classes
        poo-flow-durable-policy-receipt-runtime-owner
        poo-flow-durable-policy-receipt-valid?
        poo-flow-durable-policy-receipt-diagnostics
        poo-flow-durable-policy-receipt-metadata
        poo-flow-durable-policy
        poo-flow-durable-policy/default
        poo-flow-durable-policy?
        poo-flow-durable-policy-name
        poo-flow-durable-policy-scope-ref
        poo-flow-durable-policy-diagnostic
        poo-flow-durable-policy-diagnostic?
        poo-flow-durable-policy-diagnostic->alist
        poo-flow-durable-policy-diagnostics
        poo-flow-durable-policy-valid?
        poo-flow-durable-policy->receipt
        poo-flow-durable-policies->receipts
        poo-flow-durable-policy-receipt->alist
        poo-flow-durable-policy-receipts->alists)

;; : PooDurablePolicyKind
(def +poo-flow-durable-policy-kind+
  'poo-flow.durable.policy)

;; : PooDurablePolicySchemaId
(def +poo-flow-durable-policy-schema+
  'poo-flow.module-system.durable-policy.v1)

;; : PooDurablePolicyDiagnosticSchemaId
(def +poo-flow-durable-policy-diagnostic-schema+
  'poo-flow.module-system.durable-policy.diagnostic.v1)

;; : PooDurablePolicyReceiptSchemaId
(def +poo-flow-durable-policy-receipt-schema+
  'poo-flow.module-system.durable-policy.receipt.v1)

;; : [PooDurableActionClass]
(def +poo-flow-durable-action-classes+
  '(replayable idempotent compensatable terminal manual))

;; : [PooDurableRepairMode]
(def +poo-flow-durable-repair-modes+
  '(fail-closed retry rebuild compensate quarantine manual))

;; poo-flow-durable-policy-diagnostic-record
;;   : PooDurablePolicyDiagnosticRecordStruct
;;   | doc m%
;;       Durable policy diagnostics use fixed records internally and alists at
;;       the public receipt boundary.
;;     %
(defstruct poo-flow-durable-policy-diagnostic-record
  (kind schema code phase slot severity payload recoverable?)
  transparent: #t)

;; : (forall (a) (-> PooDurableOptionRows PooDurableOptionKey a a))
(def (poo-flow-durable-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (forall (a) (-> (List a) (List a) (List a)))
(def (poo-flow-durable-reverse-onto values tail)
  (if (null? values)
    tail
    (poo-flow-durable-reverse-onto
     (cdr values)
     (cons (car values) tail))))

;; : (forall (a) (-> PooDurableRequireMessage Bool a a))
(def (poo-flow-durable-require message condition value)
  (if condition
    value
    (error message value)))

;; : (-> PooDurablePredicate PooDurableValueList Bool)
(def (poo-flow-durable-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (poo-flow-durable-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> a (List a) Bool))
(def (poo-flow-durable-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Bool)
(def (poo-flow-durable-symbol-list? values)
  (and (list? values)
       (poo-flow-durable-every? symbol? values)))

;; : (forall (a) (-> PooDurableSourceObject PooDurableSlotKey a a))
(def (poo-flow-durable-slot object key default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))

;; : (forall (a) (-> PooDurableIdentityRows PooDurableIdentityKey a a))
(def (poo-flow-durable-identity-ref identity key default-value)
  (let (entry (assoc key identity))
    (if entry (cdr entry) default-value)))

;; poo-flow-durable-policy-diagnostic
;;   : (-> PooDurableDiagnosticCode PooDurableDiagnosticSlot PooDurableDiagnosticSeverity PooDurableDiagnosticPayload PooDurablePolicyDiagnostic)
;;   | doc m%
;;       Diagnostics are fixed internal records; callers use
;;       `poo-flow-durable-policy-diagnostic->alist` at the ABI boundary.
;;     %
(def (poo-flow-durable-policy-diagnostic code slot severity payload)
  (make-poo-flow-durable-policy-diagnostic-record
   +poo-flow-durable-policy-diagnostic-schema+
   +poo-flow-durable-policy-diagnostic-schema+
   code
   'durable-policy
   slot
   severity
   payload
   (poo-flow-durable-identity-ref payload 'recoverable? #t)))

;; : (-> Datum Boolean)
(def (poo-flow-durable-policy-diagnostic? value)
  (poo-flow-durable-policy-diagnostic-record? value))

;; : (-> PooDurablePolicyDiagnostic PooDurablePolicyDiagnosticRow)
(def (poo-flow-durable-policy-diagnostic->alist diagnostic)
  (list (cons 'kind
              (poo-flow-durable-policy-diagnostic-record-kind diagnostic))
        (cons 'schema
              (poo-flow-durable-policy-diagnostic-record-schema diagnostic))
        (cons 'code
              (poo-flow-durable-policy-diagnostic-record-code diagnostic))
        (cons 'phase
              (poo-flow-durable-policy-diagnostic-record-phase diagnostic))
        (cons 'slot
              (poo-flow-durable-policy-diagnostic-record-slot diagnostic))
        (cons 'severity
              (poo-flow-durable-policy-diagnostic-record-severity diagnostic))
        (cons 'payload
              (poo-flow-durable-policy-diagnostic-record-payload diagnostic))
        (cons 'recoverable?
              (poo-flow-durable-policy-diagnostic-record-recoverable?
               diagnostic))))

;; : (-> [PooDurablePolicyDiagnostic] [PooDurablePolicyDiagnosticRow])
(defpoo-final-projection-batch
  poo-flow-durable-policy-diagnostic-alists (diagnostics)
  (projector poo-flow-durable-policy-diagnostic->alist)
  (error-message "durable policy diagnostic projection requires a list"))

;; poo-flow-durable-policy
;;   : (-> PooDurablePolicyName PooDurableScopeRef [PooDurablePolicyOptionRow] PooDurablePolicy)
;;   | doc m%
;;       Durable policy construction is the single normalization point for
;;       policy identity, handoff refs, repair defaults, and runtime ownership.
;;       The returned value remains a native POO object until the explicit
;;       receipt projection boundary.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-durable-policy 'durable/ci 'session/build
;;         '((repair-mode . retry)))
;;       ;; => POO durable policy object
;;       ```
;;     %
(def (poo-flow-durable-policy policy-name scope-ref . maybe-options)
  (poo-flow-durable-require "durable policy name must be a symbol"
                            (symbol? policy-name)
                            policy-name)
  (poo-flow-durable-require "durable policy scope ref must be a symbol"
                            (symbol? scope-ref)
                            scope-ref)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (policy-name-value policy-name)
         (scope-ref-value scope-ref)
         (checkpoint-policy-ref-value
          (poo-flow-durable-option options
                                   'checkpoint-policy-ref
                                   'checkpoint/default))
         (journal-policy-ref-value
          (poo-flow-durable-option options
                                   'journal-policy-ref
                                   'journal/default))
         (index-policy-ref-value
          (poo-flow-durable-option options
                                   'index-policy-ref
                                   'index/default))
         (resume-policy-ref-value
          (poo-flow-durable-option options
                                   'resume-policy-ref
                                   'resume/default))
         (repair-policy-ref-value
          (poo-flow-durable-option options
                                   'repair-policy-ref
                                   'repair/fail-closed))
         (journal-owner-value
          (poo-flow-durable-option options 'journal-owner 'runtime/fact-log))
         (checkpoint-store-value
          (poo-flow-durable-option options
                                   'checkpoint-store
                                   'runtime/checkpoint-store))
         (resume-identity-value
          (poo-flow-durable-option options 'resume-identity 'session-id))
         (repair-mode-value
          (poo-flow-durable-option options 'repair-mode 'fail-closed))
         (action-classes-value
          (poo-flow-durable-option options
                                   'action-classes
                                   +poo-flow-durable-action-classes+))
         (runtime-owner-value
          (poo-flow-durable-option options
                                   'runtime-owner
                                   "marlin-agent-core"))
         (metadata-value
          (poo-flow-durable-option options 'metadata '())))
    (object<-alist
     (list
      (cons 'durable-kind +poo-flow-durable-policy-kind+)
      (cons 'durable-schema +poo-flow-durable-policy-schema+)
      (cons 'durable-policy-name policy-name-value)
      (cons 'durable-scope-ref scope-ref-value)
      (cons 'checkpoint-policy-ref checkpoint-policy-ref-value)
      (cons 'journal-policy-ref journal-policy-ref-value)
      (cons 'index-policy-ref index-policy-ref-value)
      (cons 'resume-policy-ref resume-policy-ref-value)
      (cons 'repair-policy-ref repair-policy-ref-value)
      (cons 'journal-owner journal-owner-value)
      (cons 'checkpoint-store checkpoint-store-value)
      (cons 'resume-identity resume-identity-value)
      (cons 'repair-mode repair-mode-value)
      (cons 'action-classes action-classes-value)
      (cons 'runtime-owner runtime-owner-value)
      (cons 'durable-metadata metadata-value)
      (cons 'durable-runtime-executed #f)))))

;; : PooDurablePolicy
(def poo-flow-durable-policy/default
  (poo-flow-durable-policy
   'durable/default
   'objects.shared.durable
   '((metadata . ((scope . shared)
                  (runtime-executed . #f))))))

;; : (-> Datum Boolean)
(def (poo-flow-durable-policy? value)
  (and (object? value)
       (.slot? value 'durable-kind)
       (eq? (.ref value 'durable-kind)
            +poo-flow-durable-policy-kind+)))

;; : (-> PooDurablePolicy PooDurablePolicyName)
(def (poo-flow-durable-policy-name policy)
  (poo-flow-durable-slot policy 'durable-policy-name #f))

;; : (-> PooDurablePolicy PooDurableScopeRef)
(def (poo-flow-durable-policy-scope-ref policy)
  (poo-flow-durable-slot policy 'durable-scope-ref #f))

;; : (-> PooDurablePolicy PooDurableRequiredSlot PooDurableRequiredSlotValue [PooDurablePolicyDiagnostic])
(def (poo-flow-durable-policy-required-symbol-diagnostics policy
                                                           slot
                                                           code
                                                           value)
  (cond
   ((not value)
    (list
     (poo-flow-durable-policy-diagnostic
      code
      slot
      'error
      (list (cons 'policy (poo-flow-durable-policy-name policy))
            (cons 'expected 'symbol)
            (cons 'recoverable? #t)))))
   ((symbol? value) '())
   (else
    (list
     (poo-flow-durable-policy-diagnostic
      code
      slot
      'error
      (list (cons 'policy (poo-flow-durable-policy-name policy))
            (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t)))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (poo-flow-durable-policy-action-class-diagnostics policy)
  (let (action-classes
        (poo-flow-durable-slot policy 'action-classes #f))
    (cond
     ((not (poo-flow-durable-symbol-list? action-classes))
      (list
       (poo-flow-durable-policy-diagnostic
        'invalid-action-classes
        'action-classes
        'error
        (list (cons 'policy (poo-flow-durable-policy-name policy))
              (cons 'value action-classes)
              (cons 'expected 'symbol-list)
              (cons 'allowed +poo-flow-durable-action-classes+)
              (cons 'recoverable? #t)))))
     ((poo-flow-durable-every?
       (lambda (action-class)
         (poo-flow-durable-member?
          action-class
          +poo-flow-durable-action-classes+))
       action-classes)
      '())
     (else
      (list
       (poo-flow-durable-policy-diagnostic
        'unsupported-action-class
        'action-classes
        'error
        (list (cons 'policy (poo-flow-durable-policy-name policy))
              (cons 'value action-classes)
              (cons 'allowed +poo-flow-durable-action-classes+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (poo-flow-durable-policy-repair-mode-diagnostics policy)
  (let (repair-mode (poo-flow-durable-slot policy 'repair-mode #f))
    (cond
     ((not repair-mode)
      (list
       (poo-flow-durable-policy-diagnostic
        'missing-repair-mode
        'repair-mode
        'error
        (list (cons 'policy (poo-flow-durable-policy-name policy))
              (cons 'allowed +poo-flow-durable-repair-modes+)
              (cons 'recoverable? #t)))))
     ((poo-flow-durable-member? repair-mode +poo-flow-durable-repair-modes+)
      '())
     (else
      (list
       (poo-flow-durable-policy-diagnostic
        'unsupported-repair-mode
        'repair-mode
        'error
        (list (cons 'policy (poo-flow-durable-policy-name policy))
              (cons 'value repair-mode)
              (cons 'allowed +poo-flow-durable-repair-modes+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (poo-flow-durable-policy-runtime-owner-diagnostics policy)
  (let (runtime-owner (poo-flow-durable-slot policy 'runtime-owner #f))
    (if (string? runtime-owner)
      '()
      (list
       (poo-flow-durable-policy-diagnostic
        'invalid-runtime-owner
        'runtime-owner
        'error
        (list (cons 'policy (poo-flow-durable-policy-name policy))
              (cons 'value runtime-owner)
              (cons 'expected 'string)
              (cons 'recoverable? #t)))))))

;;; Effective durable validation accumulates all diagnostics before projection
;;; so callers get a complete repair report instead of a fail-fast exception.
;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (poo-flow-durable-policy-diagnostics policy)
  (if (poo-flow-durable-policy? policy)
    (let* ((diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-required-symbol-diagnostics
              policy
              'durable-policy-name
              'missing-durable-policy-name
              (poo-flow-durable-slot policy 'durable-policy-name #f))
             '()))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-required-symbol-diagnostics
              policy
              'durable-scope-ref
              'missing-durable-scope-ref
              (poo-flow-durable-slot policy 'durable-scope-ref #f))
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-required-symbol-diagnostics
              policy
              'journal-owner
              'missing-journal-owner
              (poo-flow-durable-slot policy 'journal-owner #f))
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-required-symbol-diagnostics
              policy
              'checkpoint-store
              'missing-checkpoint-store
              (poo-flow-durable-slot policy 'checkpoint-store #f))
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-required-symbol-diagnostics
              policy
              'resume-identity
              'missing-resume-identity
              (poo-flow-durable-slot policy 'resume-identity #f))
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-repair-mode-diagnostics policy)
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-action-class-diagnostics policy)
             diagnostics-rev))
           (diagnostics-rev
            (poo-flow-durable-reverse-onto
             (poo-flow-durable-policy-runtime-owner-diagnostics policy)
             diagnostics-rev)))
      (reverse diagnostics-rev))
    (list
     (poo-flow-durable-policy-diagnostic
      'invalid-durable-policy
      'durable-policy
      'error
      (list (cons 'value policy)
            (cons 'recoverable? #t))))))

;; : (-> PooDurablePolicy Bool)
(def (poo-flow-durable-policy-valid? policy)
  (null? (poo-flow-durable-policy-diagnostics policy)))

;;; Durable policy receipts are fixed records until projected at the external
;;; ABI boundary.
(defstruct poo-flow-durable-policy-receipt
  (policy-id
   project-id
   root-session-id
   session-id
   parent-session-id
   loop-run-id
   checkpoint-policy-ref
   journal-policy-ref
   index-policy-ref
   resume-policy-ref
   repair-policy-ref
   journal-owner
   checkpoint-store
   resume-identity
   repair-mode
   action-classes
   runtime-owner
   valid?
   diagnostics
   metadata)
  transparent: #t)

;; : (-> PooDurablePolicy [PooDurableIdentityRow] PooDurablePolicyReceipt)
(def (poo-flow-durable-policy->receipt policy . maybe-identity)
  (poo-flow-durable-require "durable policy receipt requires a durable policy"
                            (poo-flow-durable-policy? policy)
                            policy)
  (let* ((identity (if (null? maybe-identity) '() (car maybe-identity)))
         (diagnostics
          (poo-flow-durable-policy-diagnostics policy))
         (valid? (null? diagnostics)))
    (make-poo-flow-durable-policy-receipt
     (poo-flow-durable-policy-name policy)
     (poo-flow-durable-identity-ref identity 'project-id #f)
     (poo-flow-durable-identity-ref identity 'root-session-id #f)
     (poo-flow-durable-identity-ref identity 'session-id #f)
     (poo-flow-durable-identity-ref identity 'parent-session-id #f)
     (poo-flow-durable-identity-ref identity 'loop-run-id #f)
     (poo-flow-durable-slot policy 'checkpoint-policy-ref #f)
     (poo-flow-durable-slot policy 'journal-policy-ref #f)
     (poo-flow-durable-slot policy 'index-policy-ref #f)
     (poo-flow-durable-slot policy 'resume-policy-ref #f)
     (poo-flow-durable-slot policy 'repair-policy-ref #f)
     (poo-flow-durable-slot policy 'journal-owner #f)
     (poo-flow-durable-slot policy 'checkpoint-store #f)
     (poo-flow-durable-slot policy 'resume-identity #f)
     (poo-flow-durable-slot policy 'repair-mode #f)
     (poo-flow-durable-slot policy 'action-classes '())
     (poo-flow-durable-slot policy 'runtime-owner #f)
     valid?
     (poo-flow-durable-policy-diagnostic-alists diagnostics)
     (poo-flow-durable-slot policy 'durable-metadata '()))))

;; : (-> [PooDurablePolicy] [PooDurablePolicyReceipt])
(def (poo-flow-durable-policies->receipts policies)
  (if (list? policies)
    (map poo-flow-durable-policy->receipt policies)
    (error "durable policy batch projection requires a list" policies)))

;; : (-> PooDurablePolicyReceipt PooDurablePolicyReceiptRow)
(defpoo-final-projection
  poo-flow-durable-policy-receipt->alist (receipt)
  (bindings ((diagnostics
              (poo-flow-durable-policy-receipt-diagnostics receipt))))
  (fields ((kind 'poo-flow.durable.policy-receipt)
           (schema +poo-flow-durable-policy-receipt-schema+)
           (policy-id (poo-flow-durable-policy-receipt-policy-id receipt))
           (project-id (poo-flow-durable-policy-receipt-project-id receipt))
           (root-session-id
            (poo-flow-durable-policy-receipt-root-session-id receipt))
           (session-id (poo-flow-durable-policy-receipt-session-id receipt))
           (parent-session-id
            (poo-flow-durable-policy-receipt-parent-session-id receipt))
           (loop-run-id (poo-flow-durable-policy-receipt-loop-run-id receipt))
           (checkpoint-policy-ref
            (poo-flow-durable-policy-receipt-checkpoint-policy-ref receipt))
           (journal-policy-ref
            (poo-flow-durable-policy-receipt-journal-policy-ref receipt))
           (index-policy-ref
            (poo-flow-durable-policy-receipt-index-policy-ref receipt))
           (resume-policy-ref
            (poo-flow-durable-policy-receipt-resume-policy-ref receipt))
           (repair-policy-ref
            (poo-flow-durable-policy-receipt-repair-policy-ref receipt))
           (journal-owner
            (poo-flow-durable-policy-receipt-journal-owner receipt))
           (checkpoint-store
            (poo-flow-durable-policy-receipt-checkpoint-store receipt))
           (resume-identity
            (poo-flow-durable-policy-receipt-resume-identity receipt))
           (repair-mode
            (poo-flow-durable-policy-receipt-repair-mode receipt))
           (action-classes
            (poo-flow-durable-policy-receipt-action-classes receipt))
           (runtime-owner
            (poo-flow-durable-policy-receipt-runtime-owner receipt))
           (valid? (poo-flow-durable-policy-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata (poo-flow-durable-policy-receipt-metadata receipt))
           (runtime-executed #f))))

;; : (-> [PooDurablePolicyReceipt] [PooDurablePolicyReceiptRow])
(defpoo-final-projection-batch
  poo-flow-durable-policy-receipts->alists (receipts)
  (projector poo-flow-durable-policy-receipt->alist)
  (error-message "durable policy receipt serialization requires a list"))
