(import (only-in :yuanxu/modules/funflow/check-types +yuanxu-durable-action-classes+))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared durable policy POO capability objects.
;;; Invariant: this layer validates and projects durable intent only; Rust or
;;; Marlin owns fact logs, checkpoints, indexes, leases, replay, and repair.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        :yuanxu/utilities/final-projection-syntax)

(export +agentic-ai-lab-durable-policy-kind+
        +agentic-ai-lab-durable-policy-schema+
        +agentic-ai-lab-durable-policy-diagnostic-schema+
        +agentic-ai-lab-durable-policy-receipt-schema+
        +yuanxu-durable-action-classes+
        +agentic-ai-lab-durable-repair-modes+
        make-agentic-ai-lab-durable-policy-receipt
        agentic-ai-lab-durable-policy-receipt?
        agentic-ai-lab-durable-policy-receipt-policy-id
        agentic-ai-lab-durable-policy-receipt-project-id
        agentic-ai-lab-durable-policy-receipt-root-session-id
        agentic-ai-lab-durable-policy-receipt-session-id
        agentic-ai-lab-durable-policy-receipt-parent-session-id
        agentic-ai-lab-durable-policy-receipt-loop-run-id
        agentic-ai-lab-durable-policy-receipt-checkpoint-policy-ref
        agentic-ai-lab-durable-policy-receipt-journal-policy-ref
        agentic-ai-lab-durable-policy-receipt-index-policy-ref
        agentic-ai-lab-durable-policy-receipt-resume-policy-ref
        agentic-ai-lab-durable-policy-receipt-repair-policy-ref
        agentic-ai-lab-durable-policy-receipt-journal-owner
        agentic-ai-lab-durable-policy-receipt-checkpoint-store
        agentic-ai-lab-durable-policy-receipt-resume-identity
        agentic-ai-lab-durable-policy-receipt-repair-mode
        agentic-ai-lab-durable-policy-receipt-action-classes
        agentic-ai-lab-durable-policy-receipt-runtime-owner
        agentic-ai-lab-durable-policy-receipt-valid?
        agentic-ai-lab-durable-policy-receipt-diagnostics
        agentic-ai-lab-durable-policy-receipt-metadata
        agentic-ai-lab-durable-policy
        agentic-ai-lab-durable-policy/default
        agentic-ai-lab-durable-policy?
        agentic-ai-lab-durable-policy-name
        agentic-ai-lab-durable-policy-scope-ref
        agentic-ai-lab-durable-policy-diagnostic
        agentic-ai-lab-durable-policy-diagnostic?
        agentic-ai-lab-durable-policy-diagnostic->alist
        agentic-ai-lab-durable-policy-diagnostics
        agentic-ai-lab-durable-policy-valid?
        agentic-ai-lab-durable-policy->receipt
        agentic-ai-lab-durable-policies->receipts
        agentic-ai-lab-durable-policy-receipt->alist
        agentic-ai-lab-durable-policy-receipts->alists)

;; : PooDurablePolicyKind
(def +agentic-ai-lab-durable-policy-kind+
  'agentic-ai-lab.durable.policy)

;; : PooDurablePolicySchemaId
(def +agentic-ai-lab-durable-policy-schema+
  'agentic-ai-lab.module-system.durable-policy.v1)

;; : PooDurablePolicyDiagnosticSchemaId
(def +agentic-ai-lab-durable-policy-diagnostic-schema+
  'agentic-ai-lab.module-system.durable-policy.diagnostic.v1)

;; : PooDurablePolicyReceiptSchemaId
(def +agentic-ai-lab-durable-policy-receipt-schema+
  'agentic-ai-lab.module-system.durable-policy.receipt.v1)

;; : [PooDurableActionClass]


;; : [PooDurableRepairMode]
(def +agentic-ai-lab-durable-repair-modes+
  '(fail-closed retry rebuild compensate quarantine manual))

;; agentic-ai-lab-durable-policy-diagnostic-record
;;   : PooDurablePolicyDiagnosticRecordStruct
;;   | doc m%
;;       Durable policy diagnostics use fixed records internally and alists at
;;       the public receipt boundary.
;;     %
(defstruct agentic-ai-lab-durable-policy-diagnostic-record
  (kind schema code phase slot severity payload recoverable?)
  transparent: #t)

;; : (forall (a) (-> PooDurableOptionRows PooDurableOptionKey a a))
(def (agentic-ai-lab-durable-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (forall (a) (-> (List a) (List a) (List a)))
(def (agentic-ai-lab-durable-reverse-onto values tail)
  (if (null? values)
    tail
    (agentic-ai-lab-durable-reverse-onto
     (cdr values)
     (cons (car values) tail))))

;; : (forall (a) (-> PooDurableRequireMessage Bool a a))
(def (agentic-ai-lab-durable-require message condition value)
  (if condition
    value
    (error message value)))

;; : (-> PooDurablePredicate PooDurableValueList Bool)
(def (agentic-ai-lab-durable-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (agentic-ai-lab-durable-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> a (List a) Bool))
(def (agentic-ai-lab-durable-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Bool)
(def (agentic-ai-lab-durable-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-durable-every? symbol? values)))

;; : (forall (a) (-> PooDurableSourceObject PooDurableSlotKey a a))
(def (agentic-ai-lab-durable-slot object key default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))

;; : (forall (a) (-> PooDurableIdentityRows PooDurableIdentityKey a a))
(def (agentic-ai-lab-durable-identity-ref identity key default-value)
  (let (entry (assoc key identity))
    (if entry (cdr entry) default-value)))

;; agentic-ai-lab-durable-policy-diagnostic
;;   : (-> PooDurableDiagnosticCode PooDurableDiagnosticSlot PooDurableDiagnosticSeverity PooDurableDiagnosticPayload PooDurablePolicyDiagnostic)
;;   | doc m%
;;       Diagnostics are fixed internal records; callers use
;;       `agentic-ai-lab-durable-policy-diagnostic->alist` at the ABI boundary.
;;     %
(def (agentic-ai-lab-durable-policy-diagnostic code slot severity payload)
  (make-agentic-ai-lab-durable-policy-diagnostic-record
   +agentic-ai-lab-durable-policy-diagnostic-schema+
   +agentic-ai-lab-durable-policy-diagnostic-schema+
   code
   'durable-policy
   slot
   severity
   payload
   (agentic-ai-lab-durable-identity-ref payload 'recoverable? #t)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-policy-diagnostic? value)
  (agentic-ai-lab-durable-policy-diagnostic-record? value))

;; : (-> PooDurablePolicyDiagnostic PooDurablePolicyDiagnosticRow)
(def (agentic-ai-lab-durable-policy-diagnostic->alist diagnostic)
  (list (cons 'kind
              (agentic-ai-lab-durable-policy-diagnostic-record-kind diagnostic))
        (cons 'schema
              (agentic-ai-lab-durable-policy-diagnostic-record-schema diagnostic))
        (cons 'code
              (agentic-ai-lab-durable-policy-diagnostic-record-code diagnostic))
        (cons 'phase
              (agentic-ai-lab-durable-policy-diagnostic-record-phase diagnostic))
        (cons 'slot
              (agentic-ai-lab-durable-policy-diagnostic-record-slot diagnostic))
        (cons 'severity
              (agentic-ai-lab-durable-policy-diagnostic-record-severity diagnostic))
        (cons 'payload
              (agentic-ai-lab-durable-policy-diagnostic-record-payload diagnostic))
        (cons 'recoverable?
              (agentic-ai-lab-durable-policy-diagnostic-record-recoverable?
               diagnostic))))

;; : (-> [PooDurablePolicyDiagnostic] [PooDurablePolicyDiagnosticRow])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-policy-diagnostic-alists (diagnostics)
  (projector agentic-ai-lab-durable-policy-diagnostic->alist)
  (error-message "durable policy diagnostic projection requires a list"))

;; agentic-ai-lab-durable-policy
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
;;       (agentic-ai-lab-durable-policy 'durable/ci 'session/build
;;         '((repair-mode . retry)))
;;       ;; => POO durable policy object
;;       ```
;;     %
(def (agentic-ai-lab-durable-policy policy-name scope-ref . maybe-options)
  (agentic-ai-lab-durable-require "durable policy name must be a symbol"
                            (symbol? policy-name)
                            policy-name)
  (agentic-ai-lab-durable-require "durable policy scope ref must be a symbol"
                            (symbol? scope-ref)
                            scope-ref)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (policy-name-value policy-name)
         (scope-ref-value scope-ref)
         (checkpoint-policy-ref-value
          (agentic-ai-lab-durable-option options
                                   'checkpoint-policy-ref
                                   'checkpoint/default))
         (journal-policy-ref-value
          (agentic-ai-lab-durable-option options
                                   'journal-policy-ref
                                   'journal/default))
         (index-policy-ref-value
          (agentic-ai-lab-durable-option options
                                   'index-policy-ref
                                   'index/default))
         (resume-policy-ref-value
          (agentic-ai-lab-durable-option options
                                   'resume-policy-ref
                                   'resume/default))
         (repair-policy-ref-value
          (agentic-ai-lab-durable-option options
                                   'repair-policy-ref
                                   'repair/fail-closed))
         (journal-owner-value
          (agentic-ai-lab-durable-option options 'journal-owner 'runtime/fact-log))
         (checkpoint-store-value
          (agentic-ai-lab-durable-option options
                                   'checkpoint-store
                                   'runtime/checkpoint-store))
         (resume-identity-value
          (agentic-ai-lab-durable-option options 'resume-identity 'session-id))
         (repair-mode-value
          (agentic-ai-lab-durable-option options 'repair-mode 'fail-closed))
         (action-classes-value
          (agentic-ai-lab-durable-option options
                                   'action-classes
                                   +yuanxu-durable-action-classes+))
         (runtime-owner-value
          (agentic-ai-lab-durable-option options
                                   'runtime-owner
                                   "marlin-agent-core"))
         (metadata-value
          (agentic-ai-lab-durable-option options 'metadata '())))
    (object<-alist
     (list
      (cons 'durable-kind +agentic-ai-lab-durable-policy-kind+)
      (cons 'durable-schema +agentic-ai-lab-durable-policy-schema+)
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
(def agentic-ai-lab-durable-policy/default
  (agentic-ai-lab-durable-policy
   'durable/default
   'objects.shared.durable
   '((metadata . ((scope . shared)
                  (runtime-executed . #f))))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-policy? value)
  (and (object? value)
       (.slot? value 'durable-kind)
       (eq? (.ref value 'durable-kind)
            +agentic-ai-lab-durable-policy-kind+)))

;; : (-> PooDurablePolicy PooDurablePolicyName)
(def (agentic-ai-lab-durable-policy-name policy)
  (agentic-ai-lab-durable-slot policy 'durable-policy-name #f))

;; : (-> PooDurablePolicy PooDurableScopeRef)
(def (agentic-ai-lab-durable-policy-scope-ref policy)
  (agentic-ai-lab-durable-slot policy 'durable-scope-ref #f))

;; : (-> PooDurablePolicy PooDurableRequiredSlot PooDurableRequiredSlotValue [PooDurablePolicyDiagnostic])
(def (agentic-ai-lab-durable-policy-required-symbol-diagnostics policy
                                                           slot
                                                           code
                                                           value)
  (cond
   ((not value)
    (list
     (agentic-ai-lab-durable-policy-diagnostic
      code
      slot
      'error
      (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
            (cons 'expected 'symbol)
            (cons 'recoverable? #t)))))
   ((symbol? value) '())
   (else
    (list
     (agentic-ai-lab-durable-policy-diagnostic
      code
      slot
      'error
      (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
            (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t)))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (agentic-ai-lab-durable-policy-action-class-diagnostics policy)
  (let (action-classes
        (agentic-ai-lab-durable-slot policy 'action-classes #f))
    (cond
     ((not (agentic-ai-lab-durable-symbol-list? action-classes))
      (list
       (agentic-ai-lab-durable-policy-diagnostic
        'invalid-action-classes
        'action-classes
        'error
        (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
              (cons 'value action-classes)
              (cons 'expected 'symbol-list)
              (cons 'allowed +yuanxu-durable-action-classes+)
              (cons 'recoverable? #t)))))
     ((agentic-ai-lab-durable-every?
       (lambda (action-class)
         (agentic-ai-lab-durable-member?
          action-class
          +yuanxu-durable-action-classes+))
       action-classes)
      '())
     (else
      (list
       (agentic-ai-lab-durable-policy-diagnostic
        'unsupported-action-class
        'action-classes
        'error
        (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
              (cons 'value action-classes)
              (cons 'allowed +yuanxu-durable-action-classes+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (agentic-ai-lab-durable-policy-repair-mode-diagnostics policy)
  (let (repair-mode (agentic-ai-lab-durable-slot policy 'repair-mode #f))
    (cond
     ((not repair-mode)
      (list
       (agentic-ai-lab-durable-policy-diagnostic
        'missing-repair-mode
        'repair-mode
        'error
        (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
              (cons 'allowed +agentic-ai-lab-durable-repair-modes+)
              (cons 'recoverable? #t)))))
     ((agentic-ai-lab-durable-member? repair-mode +agentic-ai-lab-durable-repair-modes+)
      '())
     (else
      (list
       (agentic-ai-lab-durable-policy-diagnostic
        'unsupported-repair-mode
        'repair-mode
        'error
        (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
              (cons 'value repair-mode)
              (cons 'allowed +agentic-ai-lab-durable-repair-modes+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (agentic-ai-lab-durable-policy-runtime-owner-diagnostics policy)
  (let (runtime-owner (agentic-ai-lab-durable-slot policy 'runtime-owner #f))
    (if (string? runtime-owner)
      '()
      (list
       (agentic-ai-lab-durable-policy-diagnostic
        'invalid-runtime-owner
        'runtime-owner
        'error
        (list (cons 'policy (agentic-ai-lab-durable-policy-name policy))
              (cons 'value runtime-owner)
              (cons 'expected 'string)
              (cons 'recoverable? #t)))))))

;;; Effective durable validation accumulates all diagnostics before projection
;;; so callers get a complete repair report instead of a fail-fast exception.
;; : (-> PooDurablePolicy [PooDurablePolicyDiagnostic])
(def (agentic-ai-lab-durable-policy-diagnostics policy)
  (if (agentic-ai-lab-durable-policy? policy)
    (let* ((diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-required-symbol-diagnostics
              policy
              'durable-policy-name
              'missing-durable-policy-name
              (agentic-ai-lab-durable-slot policy 'durable-policy-name #f))
             '()))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-required-symbol-diagnostics
              policy
              'durable-scope-ref
              'missing-durable-scope-ref
              (agentic-ai-lab-durable-slot policy 'durable-scope-ref #f))
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-required-symbol-diagnostics
              policy
              'journal-owner
              'missing-journal-owner
              (agentic-ai-lab-durable-slot policy 'journal-owner #f))
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-required-symbol-diagnostics
              policy
              'checkpoint-store
              'missing-checkpoint-store
              (agentic-ai-lab-durable-slot policy 'checkpoint-store #f))
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-required-symbol-diagnostics
              policy
              'resume-identity
              'missing-resume-identity
              (agentic-ai-lab-durable-slot policy 'resume-identity #f))
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-repair-mode-diagnostics policy)
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-action-class-diagnostics policy)
             diagnostics-rev))
           (diagnostics-rev
            (agentic-ai-lab-durable-reverse-onto
             (agentic-ai-lab-durable-policy-runtime-owner-diagnostics policy)
             diagnostics-rev)))
      (reverse diagnostics-rev))
    (list
     (agentic-ai-lab-durable-policy-diagnostic
      'invalid-durable-policy
      'durable-policy
      'error
      (list (cons 'value policy)
            (cons 'recoverable? #t))))))

;; : (-> PooDurablePolicy Bool)
(def (agentic-ai-lab-durable-policy-valid? policy)
  (null? (agentic-ai-lab-durable-policy-diagnostics policy)))

;;; Durable policy receipts are fixed records until projected at the external
;;; ABI boundary.
(defstruct agentic-ai-lab-durable-policy-receipt
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
(def (agentic-ai-lab-durable-policy->receipt policy . maybe-identity)
  (agentic-ai-lab-durable-require "durable policy receipt requires a durable policy"
                            (agentic-ai-lab-durable-policy? policy)
                            policy)
  (let* ((identity (if (null? maybe-identity) '() (car maybe-identity)))
         (diagnostics
          (agentic-ai-lab-durable-policy-diagnostics policy))
         (valid? (null? diagnostics)))
    (make-agentic-ai-lab-durable-policy-receipt
     (agentic-ai-lab-durable-policy-name policy)
     (agentic-ai-lab-durable-identity-ref identity 'project-id #f)
     (agentic-ai-lab-durable-identity-ref identity 'root-session-id #f)
     (agentic-ai-lab-durable-identity-ref identity 'session-id #f)
     (agentic-ai-lab-durable-identity-ref identity 'parent-session-id #f)
     (agentic-ai-lab-durable-identity-ref identity 'loop-run-id #f)
     (agentic-ai-lab-durable-slot policy 'checkpoint-policy-ref #f)
     (agentic-ai-lab-durable-slot policy 'journal-policy-ref #f)
     (agentic-ai-lab-durable-slot policy 'index-policy-ref #f)
     (agentic-ai-lab-durable-slot policy 'resume-policy-ref #f)
     (agentic-ai-lab-durable-slot policy 'repair-policy-ref #f)
     (agentic-ai-lab-durable-slot policy 'journal-owner #f)
     (agentic-ai-lab-durable-slot policy 'checkpoint-store #f)
     (agentic-ai-lab-durable-slot policy 'resume-identity #f)
     (agentic-ai-lab-durable-slot policy 'repair-mode #f)
     (agentic-ai-lab-durable-slot policy 'action-classes '())
     (agentic-ai-lab-durable-slot policy 'runtime-owner #f)
     valid?
     (agentic-ai-lab-durable-policy-diagnostic-alists diagnostics)
     (agentic-ai-lab-durable-slot policy 'durable-metadata '()))))

;; : (-> [PooDurablePolicy] [PooDurablePolicyReceipt])
(def (agentic-ai-lab-durable-policies->receipts policies)
  (if (list? policies)
    (map agentic-ai-lab-durable-policy->receipt policies)
    (error "durable policy batch projection requires a list" policies)))

;; : (-> PooDurablePolicyReceipt PooDurablePolicyReceiptRow)
(defpoo-final-projection
  agentic-ai-lab-durable-policy-receipt->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-policy-receipt-diagnostics receipt))))
  (fields ((kind 'agentic-ai-lab.durable.policy-receipt)
           (schema +agentic-ai-lab-durable-policy-receipt-schema+)
           (policy-id (agentic-ai-lab-durable-policy-receipt-policy-id receipt))
           (project-id (agentic-ai-lab-durable-policy-receipt-project-id receipt))
           (root-session-id
            (agentic-ai-lab-durable-policy-receipt-root-session-id receipt))
           (session-id (agentic-ai-lab-durable-policy-receipt-session-id receipt))
           (parent-session-id
            (agentic-ai-lab-durable-policy-receipt-parent-session-id receipt))
           (loop-run-id (agentic-ai-lab-durable-policy-receipt-loop-run-id receipt))
           (checkpoint-policy-ref
            (agentic-ai-lab-durable-policy-receipt-checkpoint-policy-ref receipt))
           (journal-policy-ref
            (agentic-ai-lab-durable-policy-receipt-journal-policy-ref receipt))
           (index-policy-ref
            (agentic-ai-lab-durable-policy-receipt-index-policy-ref receipt))
           (resume-policy-ref
            (agentic-ai-lab-durable-policy-receipt-resume-policy-ref receipt))
           (repair-policy-ref
            (agentic-ai-lab-durable-policy-receipt-repair-policy-ref receipt))
           (journal-owner
            (agentic-ai-lab-durable-policy-receipt-journal-owner receipt))
           (checkpoint-store
            (agentic-ai-lab-durable-policy-receipt-checkpoint-store receipt))
           (resume-identity
            (agentic-ai-lab-durable-policy-receipt-resume-identity receipt))
           (repair-mode
            (agentic-ai-lab-durable-policy-receipt-repair-mode receipt))
           (action-classes
            (agentic-ai-lab-durable-policy-receipt-action-classes receipt))
           (runtime-owner
            (agentic-ai-lab-durable-policy-receipt-runtime-owner receipt))
           (valid? (agentic-ai-lab-durable-policy-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata (agentic-ai-lab-durable-policy-receipt-metadata receipt))
           (runtime-executed #f))))

;; : (-> [PooDurablePolicyReceipt] [PooDurablePolicyReceiptRow])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-policy-receipts->alists (receipts)
  (projector agentic-ai-lab-durable-policy-receipt->alist)
  (error-message "durable policy receipt serialization requires a list"))
