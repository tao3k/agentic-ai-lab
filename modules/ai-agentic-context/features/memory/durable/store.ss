;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store contract receipts for Rust/Marlin handoff.
;;; Invariant: Scheme validates and projects store contracts only; the runtime
;;; owns storage, locking, leases, fsync, backfill, replay, and side effects.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :yuanxu/utilities/final-projection-syntax)

(export +agentic-ai-lab-durable-runtime-store-contract-kind+
        +agentic-ai-lab-durable-runtime-store-contract-schema+
        +agentic-ai-lab-durable-runtime-store-contract-receipt-schema+
        +agentic-ai-lab-durable-runtime-store-diagnostic-schema+
        +agentic-ai-lab-durable-runtime-store-ledger-kinds+
        +agentic-ai-lab-durable-runtime-store-capability-flags+
        make-agentic-ai-lab-durable-runtime-store-contract-receipt
        agentic-ai-lab-durable-runtime-store-contract-receipt?
        agentic-ai-lab-durable-runtime-store-contract-receipt-store-id
        agentic-ai-lab-durable-runtime-store-contract-receipt-store-owner
        agentic-ai-lab-durable-runtime-store-contract-receipt-durable-policy-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-project-id
        agentic-ai-lab-durable-runtime-store-contract-receipt-root-session-id
        agentic-ai-lab-durable-runtime-store-contract-receipt-session-id
        agentic-ai-lab-durable-runtime-store-contract-receipt-runtime-owner
        agentic-ai-lab-durable-runtime-store-contract-receipt-schema-version
        agentic-ai-lab-durable-runtime-store-contract-receipt-fact-log-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-checkpoint-store-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-derived-index-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-job-store-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-repair-journal-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-artifact-store-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-communication-ledger-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-sandbox-ledger-ref
        agentic-ai-lab-durable-runtime-store-contract-receipt-ledger-kinds
        agentic-ai-lab-durable-runtime-store-contract-receipt-capability-flags
        agentic-ai-lab-durable-runtime-store-contract-receipt-valid?
        agentic-ai-lab-durable-runtime-store-contract-receipt-diagnostics
        agentic-ai-lab-durable-runtime-store-contract-receipt-metadata
        agentic-ai-lab-durable-runtime-store-contract
        agentic-ai-lab-durable-runtime-store-contract/default
        agentic-ai-lab-durable-runtime-store-contract?
        agentic-ai-lab-durable-runtime-store-contract-name
        agentic-ai-lab-durable-runtime-store-contract-diagnostics
        agentic-ai-lab-durable-runtime-store-contract-valid?
        agentic-ai-lab-durable-runtime-store-contract->receipt
        agentic-ai-lab-durable-runtime-store-contract-receipt->alist
        agentic-ai-lab-durable-runtime-store-contracts->receipts
        agentic-ai-lab-durable-runtime-store-contract-receipts->alists)

;; : AgenticAILabDurableRuntimeStoreContractKind
(def +agentic-ai-lab-durable-runtime-store-contract-kind+
  'agentic-ai-lab.durable.runtime-store-contract)

;; : AgenticAILabDurableRuntimeStoreContractSchemaId
(def +agentic-ai-lab-durable-runtime-store-contract-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-contract.v1)

;; : AgenticAILabDurableRuntimeStoreContractReceiptSchemaId
(def +agentic-ai-lab-durable-runtime-store-contract-receipt-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-contract.receipt.v1)

;; : AgenticAILabDurableRuntimeStoreDiagnosticSchemaId
(def +agentic-ai-lab-durable-runtime-store-diagnostic-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-contract.diagnostic.v1)

;; : [AgenticAILabDurableRuntimeStoreLedgerKind]
(def +agentic-ai-lab-durable-runtime-store-ledger-kinds+
  '(fact-log checkpoint derived-index job repair artifact communication sandbox))

;; : [AgenticAILabDurableRuntimeStoreCapabilityFlag]
(def +agentic-ai-lab-durable-runtime-store-capability-flags+
  '(append-fact
    write-checkpoint
    rebuild-index
    claim-job-lease
    append-repair-event
    retain-artifact
    append-communication-event
    attach-sandbox-handle))

;; : (forall (a) (-> PooDurableRuntimeStoreOptionRows PooDurableRuntimeStoreOptionKey a a))
(def (agentic-ai-lab-durable-runtime-store-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (forall (a) (-> PooDurableRuntimeStoreSourceObject PooDurableRuntimeStoreSlotKey a a))
(def (agentic-ai-lab-durable-runtime-store-slot object key default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))

;; : (forall (a) (-> PooDurableRuntimeStoreIdentityRows PooDurableRuntimeStoreIdentityKey a a))
(def (agentic-ai-lab-durable-runtime-store-identity-ref identity key default-value)
  (let (entry (assoc key identity))
    (if entry (cdr entry) default-value)))

;; : (-> PooDurableRuntimeStorePredicate PooDurableRuntimeStoreValueList Bool)
(def (agentic-ai-lab-durable-runtime-store-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (agentic-ai-lab-durable-runtime-store-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> a (List a) Bool))
(def (agentic-ai-lab-durable-runtime-store-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Bool)
(def (agentic-ai-lab-durable-runtime-store-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-durable-runtime-store-every? symbol? values)))

;; : (-> PooDurableRuntimeStoreDiagnosticCode PooDurableRuntimeStoreDiagnosticSlot PooDurableRuntimeStoreDiagnosticSeverity PooDurableRuntimeStoreDiagnosticPayload PooDurableRuntimeStoreDiagnosticRow)
(def (agentic-ai-lab-durable-runtime-store-diagnostic code slot severity payload)
  (list
   (cons 'kind +agentic-ai-lab-durable-runtime-store-diagnostic-schema+)
   (cons 'schema +agentic-ai-lab-durable-runtime-store-diagnostic-schema+)
   (cons 'code code)
   (cons 'phase 'durable-runtime-store-contract)
   (cons 'slot slot)
   (cons 'severity severity)
   (cons 'payload payload)
   (cons 'recoverable?
         (agentic-ai-lab-durable-runtime-store-option
          payload
          'recoverable?
          #t))))

;; : (-> PooDurableRuntimeStoreDiagnosticCode PooDurableRuntimeStoreDiagnosticSlot PooDurableRuntimeStoreDiagnosticValue PooDurableRuntimeStoreDiagnosticRow)
(def (agentic-ai-lab-durable-runtime-store-value-diagnostic code slot value)
  (agentic-ai-lab-durable-runtime-store-diagnostic
   code
   slot
   'error
   (list (cons 'value value)
         (cons 'recoverable? #t))))

;;; Runtime store contract construction centralizes ledger and capability
;;; defaults before backend negotiation while keeping validation and receipt
;;; projection as separate cheap stages.
;; : (-> PooDurableRuntimeStoreId PooDurableRuntimeOwner PooDurablePolicy [PooDurableRuntimeStoreOptionRow] PooDurableRuntimeStoreContract)
(def (agentic-ai-lab-durable-runtime-store-contract store-id
                                              store-owner
                                              durable-policy
                                              . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (schema-version
          (agentic-ai-lab-durable-runtime-store-option options 'schema-version 1))
         (fact-log-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'fact-log-ref
                                                'runtime/fact-log))
         (checkpoint-store-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'checkpoint-store-ref
                                                'runtime/checkpoint-store))
         (derived-index-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'derived-index-ref
                                                'runtime/derived-index))
         (job-store-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'job-store-ref
                                                'runtime/job-store))
         (repair-journal-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'repair-journal-ref
                                                'runtime/repair-journal))
         (artifact-store-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'artifact-store-ref
                                                'runtime/artifact-store))
         (communication-ledger-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'communication-ledger-ref
                                                'runtime/communication-ledger))
         (sandbox-ledger-ref
          (agentic-ai-lab-durable-runtime-store-option options
                                                'sandbox-ledger-ref
                                                'runtime/sandbox-ledger))
         (ledger-kinds
          (agentic-ai-lab-durable-runtime-store-option
           options
           'ledger-kinds
           +agentic-ai-lab-durable-runtime-store-ledger-kinds+))
         (capability-flags
          (agentic-ai-lab-durable-runtime-store-option
           options
           'capability-flags
           +agentic-ai-lab-durable-runtime-store-capability-flags+))
         (metadata
          (agentic-ai-lab-durable-runtime-store-option options 'metadata '())))
    (object<-alist
     (list
      (cons 'durable-runtime-store-kind
            +agentic-ai-lab-durable-runtime-store-contract-kind+)
      (cons 'durable-runtime-store-schema
            +agentic-ai-lab-durable-runtime-store-contract-schema+)
      (cons 'runtime-store-id store-id)
      (cons 'runtime-store-owner store-owner)
      (cons 'runtime-store-durable-policy durable-policy)
      (cons 'runtime-store-schema-version schema-version)
      (cons 'runtime-store-fact-log-ref fact-log-ref)
      (cons 'runtime-store-checkpoint-store-ref checkpoint-store-ref)
      (cons 'runtime-store-derived-index-ref derived-index-ref)
      (cons 'runtime-store-job-store-ref job-store-ref)
      (cons 'runtime-store-repair-journal-ref repair-journal-ref)
      (cons 'runtime-store-artifact-store-ref artifact-store-ref)
      (cons 'runtime-store-communication-ledger-ref communication-ledger-ref)
      (cons 'runtime-store-sandbox-ledger-ref sandbox-ledger-ref)
      (cons 'runtime-store-ledger-kinds ledger-kinds)
      (cons 'runtime-store-capability-flags capability-flags)
      (cons 'runtime-store-metadata metadata)
      (cons 'runtime-executed #f)))))

;; : PooDurableRuntimeStoreContract
(def agentic-ai-lab-durable-runtime-store-contract/default
  (agentic-ai-lab-durable-runtime-store-contract
   'runtime-store/default
   'marlin-runtime-store
   agentic-ai-lab-durable-policy/default
   '((metadata . ((scope . shared)
                  (runtime-executed . #f))))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-runtime-store-contract? value)
  (and (object? value)
       (.slot? value 'durable-runtime-store-kind)
       (eq? (.ref value 'durable-runtime-store-kind)
            +agentic-ai-lab-durable-runtime-store-contract-kind+)))

;; : (-> PooDurableRuntimeStoreContract PooDurableRuntimeStoreContractName)
(def (agentic-ai-lab-durable-runtime-store-contract-name contract)
  (agentic-ai-lab-durable-runtime-store-slot contract 'runtime-store-id #f))

;; : (-> PooDurableRuntimeStoreContract PooDurableRuntimeStoreRequiredSlot PooDurableRuntimeStoreRequiredValue [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics contract
                                                                  slot
                                                                  code
                                                                  value)
  (cond
   ((symbol? value) '())
   (else
    (list
     (agentic-ai-lab-durable-runtime-store-diagnostic
      code
      slot
      'error
      (list (cons 'store-id
                  (agentic-ai-lab-durable-runtime-store-contract-name contract))
            (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t)))))))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-ledger-kind-diagnostics contract)
  (let (ledger-kinds
        (agentic-ai-lab-durable-runtime-store-slot
         contract
         'runtime-store-ledger-kinds
         #f))
    (cond
     ((not (agentic-ai-lab-durable-runtime-store-symbol-list? ledger-kinds))
      (list
       (agentic-ai-lab-durable-runtime-store-value-diagnostic
        'invalid-ledger-kinds
        'ledger-kinds
        ledger-kinds)))
     ((agentic-ai-lab-durable-runtime-store-every?
       (lambda (ledger-kind)
         (agentic-ai-lab-durable-runtime-store-member?
          ledger-kind
          +agentic-ai-lab-durable-runtime-store-ledger-kinds+))
       ledger-kinds)
      '())
     (else
      (list
       (agentic-ai-lab-durable-runtime-store-diagnostic
        'unsupported-ledger-kind
        'ledger-kinds
        'error
        (list (cons 'store-id
                    (agentic-ai-lab-durable-runtime-store-contract-name contract))
              (cons 'value ledger-kinds)
              (cons 'allowed +agentic-ai-lab-durable-runtime-store-ledger-kinds+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-capability-diagnostics contract)
  (let (capability-flags
        (agentic-ai-lab-durable-runtime-store-slot
         contract
         'runtime-store-capability-flags
         #f))
    (cond
     ((not (agentic-ai-lab-durable-runtime-store-symbol-list? capability-flags))
      (list
       (agentic-ai-lab-durable-runtime-store-value-diagnostic
        'invalid-capability-flags
        'capability-flags
        capability-flags)))
     ((agentic-ai-lab-durable-runtime-store-every?
       (lambda (capability-flag)
         (agentic-ai-lab-durable-runtime-store-member?
          capability-flag
          +agentic-ai-lab-durable-runtime-store-capability-flags+))
       capability-flags)
      '())
     (else
      (list
       (agentic-ai-lab-durable-runtime-store-diagnostic
        'unsupported-capability-flag
        'capability-flags
        'error
        (list (cons 'store-id
                    (agentic-ai-lab-durable-runtime-store-contract-name contract))
              (cons 'value capability-flags)
              (cons 'allowed
                    +agentic-ai-lab-durable-runtime-store-capability-flags+)
              (cons 'recoverable? #t))))))))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-required-contract-diagnostics contract)
  (append
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'runtime-store-id
    'missing-store-id
    (agentic-ai-lab-durable-runtime-store-slot contract 'runtime-store-id #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'runtime-store-owner
    'missing-store-owner
    (agentic-ai-lab-durable-runtime-store-slot contract 'runtime-store-owner #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'fact-log-ref
    'missing-fact-log-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-fact-log-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'checkpoint-store-ref
    'missing-checkpoint-store-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-checkpoint-store-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'derived-index-ref
    'missing-derived-index-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-derived-index-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'job-store-ref
    'missing-job-store-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-job-store-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'repair-journal-ref
    'missing-repair-journal-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-repair-journal-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'artifact-store-ref
    'missing-artifact-store-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-artifact-store-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'communication-ledger-ref
    'missing-communication-ledger-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-communication-ledger-ref
     #f))
   (agentic-ai-lab-durable-runtime-store-required-symbol-diagnostics
    contract
    'sandbox-ledger-ref
    'missing-sandbox-ledger-ref
    (agentic-ai-lab-durable-runtime-store-slot
     contract
     'runtime-store-sandbox-ledger-ref
     #f))))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-schema-version-diagnostics contract)
  (let (schema-version
        (agentic-ai-lab-durable-runtime-store-slot
         contract
         'runtime-store-schema-version
         #f))
    (if (integer? schema-version)
      '()
      (list
       (agentic-ai-lab-durable-runtime-store-value-diagnostic
        'invalid-schema-version
        'schema-version
        schema-version)))))

;; : (-> PooDurableRuntimeStoreContract PooDurablePolicyValue [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-policy-diagnostics contract durable-policy)
  (append
   (if (agentic-ai-lab-durable-policy? durable-policy)
     '()
     (list
      (agentic-ai-lab-durable-runtime-store-value-diagnostic
       'invalid-durable-policy
       'durable-policy
       durable-policy)))
   (if (and (agentic-ai-lab-durable-policy? durable-policy)
            (agentic-ai-lab-durable-policy-valid? durable-policy))
     '()
     (list
      (agentic-ai-lab-durable-runtime-store-diagnostic
       'invalid-durable-policy-receipt
       'durable-policy
       'error
       (list (cons 'store-id
                   (agentic-ai-lab-durable-runtime-store-contract-name
                    contract))
             (cons 'recoverable? #t)))))))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreDiagnosticRow])
(def (agentic-ai-lab-durable-runtime-store-contract-diagnostics contract)
  (if (agentic-ai-lab-durable-runtime-store-contract? contract)
    (let ((durable-policy
           (agentic-ai-lab-durable-runtime-store-slot
            contract
            'runtime-store-durable-policy
            #f)))
      (append
       (agentic-ai-lab-durable-runtime-store-required-contract-diagnostics contract)
       (agentic-ai-lab-durable-runtime-store-schema-version-diagnostics contract)
       (agentic-ai-lab-durable-runtime-store-policy-diagnostics contract
                                                          durable-policy)
       (agentic-ai-lab-durable-runtime-store-ledger-kind-diagnostics contract)
       (agentic-ai-lab-durable-runtime-store-capability-diagnostics contract)))
    (list
     (agentic-ai-lab-durable-runtime-store-value-diagnostic
      'invalid-runtime-store-contract
      'runtime-store-contract
      contract))))

;; : (-> PooDurableRuntimeStoreContract Bool)
(def (agentic-ai-lab-durable-runtime-store-contract-valid? contract)
  (null? (agentic-ai-lab-durable-runtime-store-contract-diagnostics contract)))

;; agentic-ai-lab-durable-runtime-store-contract-receipt
;;   : PooDurableRuntimeStoreContractReceiptStruct
;;   | doc m%
;;       Runtime store contract receipts stay fixed structs; projection helpers
;;       own the ABI alist shape.
;;     %
(defstruct agentic-ai-lab-durable-runtime-store-contract-receipt
  (store-id
   store-owner
   durable-policy-ref
   project-id
   root-session-id
   session-id
   runtime-owner
   schema-version
   fact-log-ref
   checkpoint-store-ref
   derived-index-ref
   job-store-ref
   repair-journal-ref
   artifact-store-ref
   communication-ledger-ref
   sandbox-ledger-ref
   ledger-kinds
   capability-flags
   valid?
   diagnostics
   metadata)
  transparent: #t)

;; : (forall (a) (-> a PooDurableRuntimeStoreIdentityRows (U #f PooDurablePolicyReceipt)))
(def (agentic-ai-lab-durable-runtime-store-policy->receipt durable-policy identity)
  (and (agentic-ai-lab-durable-policy? durable-policy)
       (agentic-ai-lab-durable-policy->receipt durable-policy identity)))

;; : (-> (U #f PooDurablePolicyReceipt) (U #f PooDurablePolicyId))
(def (agentic-ai-lab-durable-runtime-store-policy-receipt-policy-id receipt)
  (and receipt
       (agentic-ai-lab-durable-policy-receipt-policy-id receipt)))

;; : (-> (U #f PooDurablePolicyReceipt) (U #f PooDurableRuntimeOwner))
(def (agentic-ai-lab-durable-runtime-store-policy-receipt-runtime-owner receipt)
  (and receipt
       (agentic-ai-lab-durable-policy-receipt-runtime-owner receipt)))

;; : (-> PooDurableRuntimeStoreContract [PooDurableRuntimeStoreIdentityRow] PooDurableRuntimeStoreContractReceipt)
(def (agentic-ai-lab-durable-runtime-store-contract->receipt contract
                                                        . maybe-identity)
  (let* ((identity (if (null? maybe-identity) '() (car maybe-identity)))
         (durable-policy
          (agentic-ai-lab-durable-runtime-store-slot
           contract
           'runtime-store-durable-policy
           #f))
         (durable-policy-receipt
          (agentic-ai-lab-durable-runtime-store-policy->receipt durable-policy
                                                          identity))
         (diagnostics
          (agentic-ai-lab-durable-runtime-store-contract-diagnostics contract))
         (valid? (null? diagnostics)))
    (make-agentic-ai-lab-durable-runtime-store-contract-receipt
     (agentic-ai-lab-durable-runtime-store-slot contract 'runtime-store-id #f)
     (agentic-ai-lab-durable-runtime-store-slot contract 'runtime-store-owner #f)
     (agentic-ai-lab-durable-runtime-store-policy-receipt-policy-id
      durable-policy-receipt)
     (agentic-ai-lab-durable-runtime-store-identity-ref identity 'project-id #f)
     (agentic-ai-lab-durable-runtime-store-identity-ref identity
                                                 'root-session-id
                                                 #f)
     (agentic-ai-lab-durable-runtime-store-identity-ref identity 'session-id #f)
     (agentic-ai-lab-durable-runtime-store-policy-receipt-runtime-owner
      durable-policy-receipt)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-schema-version
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-fact-log-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-checkpoint-store-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-derived-index-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-job-store-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-repair-journal-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-artifact-store-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot contract
                                         'runtime-store-communication-ledger-ref
                                         #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-sandbox-ledger-ref
      #f)
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-ledger-kinds
      '())
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-capability-flags
      '())
     valid?
     diagnostics
     (agentic-ai-lab-durable-runtime-store-slot
      contract
      'runtime-store-metadata
      '()))))

;; : (-> PooDurableRuntimeStoreContractReceipt PooDurableRuntimeStoreContractReceiptRow)
(defpoo-final-projection
  agentic-ai-lab-durable-runtime-store-contract-receipt->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-runtime-store-contract-receipt-diagnostics
               receipt))))
  (fields ((kind 'agentic-ai-lab.durable.runtime-store-contract-receipt)
           (schema +agentic-ai-lab-durable-runtime-store-contract-receipt-schema+)
           (store-id
            (agentic-ai-lab-durable-runtime-store-contract-receipt-store-id receipt))
           (store-owner
            (agentic-ai-lab-durable-runtime-store-contract-receipt-store-owner
             receipt))
           (durable-policy-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-durable-policy-ref
             receipt))
           (project-id
            (agentic-ai-lab-durable-runtime-store-contract-receipt-project-id receipt))
           (root-session-id
            (agentic-ai-lab-durable-runtime-store-contract-receipt-root-session-id
             receipt))
           (session-id
            (agentic-ai-lab-durable-runtime-store-contract-receipt-session-id
             receipt))
           (runtime-owner
            (agentic-ai-lab-durable-runtime-store-contract-receipt-runtime-owner
             receipt))
           (schema-version
            (agentic-ai-lab-durable-runtime-store-contract-receipt-schema-version
             receipt))
           (fact-log-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-fact-log-ref
             receipt))
           (checkpoint-store-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-checkpoint-store-ref
             receipt))
           (derived-index-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-derived-index-ref
             receipt))
           (job-store-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-job-store-ref
             receipt))
           (repair-journal-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-repair-journal-ref
             receipt))
           (artifact-store-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-artifact-store-ref
             receipt))
           (communication-ledger-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-communication-ledger-ref
             receipt))
           (sandbox-ledger-ref
            (agentic-ai-lab-durable-runtime-store-contract-receipt-sandbox-ledger-ref
             receipt))
           (ledger-kinds
            (agentic-ai-lab-durable-runtime-store-contract-receipt-ledger-kinds
             receipt))
           (capability-flags
            (agentic-ai-lab-durable-runtime-store-contract-receipt-capability-flags
             receipt))
           (valid?
            (agentic-ai-lab-durable-runtime-store-contract-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (agentic-ai-lab-durable-runtime-store-contract-receipt-metadata receipt))
           (runtime-executed #f))))

;; : (-> [PooDurableRuntimeStoreContract] [PooDurableRuntimeStoreContractReceipt])
(def (agentic-ai-lab-durable-runtime-store-contracts->receipts contracts)
  (cond
   ((null? contracts) '())
   ((pair? contracts)
    (cons (agentic-ai-lab-durable-runtime-store-contract->receipt (car contracts))
          (agentic-ai-lab-durable-runtime-store-contracts->receipts
           (cdr contracts))))
   (else
    (error "durable runtime store contract batch projection requires a list"
           contracts))))

;; : (-> [PooDurableRuntimeStoreContractReceipt] [PooDurableRuntimeStoreContractReceiptRow])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-runtime-store-contract-receipts->alists (receipts)
  (projector agentic-ai-lab-durable-runtime-store-contract-receipt->alist)
  (error-message
   "durable runtime store contract receipt serialization requires a list"))
