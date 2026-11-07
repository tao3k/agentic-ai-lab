;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store backend negotiation and Marlin handoff ABI.
;;; Invariant: Scheme selects and projects backend contracts only; the runtime
;;; owns append, fsync, leases, checkpoint IO, index rebuild, and repair jobs.

(import (only-in :clan/poo/object .ref .slot? object? object<-alist)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store)

(export +agentic-ai-lab-durable-runtime-store-backend-kind+
        +agentic-ai-lab-durable-runtime-store-backend-schema+
        +agentic-ai-lab-durable-runtime-store-backend-receipt-schema+
        +agentic-ai-lab-durable-runtime-store-backend-diagnostic-schema+
        +agentic-ai-lab-durable-runtime-store-negotiation-schema+
        +agentic-ai-lab-durable-runtime-store-handoff-schema+
        +agentic-ai-lab-durable-runtime-store-backend-protocols+
        +agentic-ai-lab-durable-runtime-store-handoff-required-fields+
        make-agentic-ai-lab-durable-runtime-store-backend-receipt
        agentic-ai-lab-durable-runtime-store-backend-receipt?
        agentic-ai-lab-durable-runtime-store-backend-receipt-backend-id
        agentic-ai-lab-durable-runtime-store-backend-receipt-backend-kind
        agentic-ai-lab-durable-runtime-store-backend-receipt-runtime-owner
        agentic-ai-lab-durable-runtime-store-backend-receipt-executable
        agentic-ai-lab-durable-runtime-store-backend-receipt-protocol
        agentic-ai-lab-durable-runtime-store-backend-receipt-supported-ledger-kinds
        agentic-ai-lab-durable-runtime-store-backend-receipt-supported-capability-flags
        agentic-ai-lab-durable-runtime-store-backend-receipt-operation-kinds
        agentic-ai-lab-durable-runtime-store-backend-receipt-valid?
        agentic-ai-lab-durable-runtime-store-backend-receipt-diagnostics
        agentic-ai-lab-durable-runtime-store-backend-receipt-metadata
        make-agentic-ai-lab-durable-runtime-store-negotiation-receipt
        agentic-ai-lab-durable-runtime-store-negotiation-receipt?
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-store-id
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-id
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-kind
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-selected?
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-handoff-ready?
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-contract-row
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-row
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-required-ledger-kinds
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-supported-ledger-kinds
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-missing-ledger-kinds
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-required-capability-flags
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-supported-capability-flags
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-missing-capability-flags
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-operation-kinds
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-unsupported-operation-kinds
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-manifest-operation
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-valid?
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-diagnostics
        agentic-ai-lab-durable-runtime-store-negotiation-receipt-metadata
 agentic-ai-lab-durable-runtime-store-backend
 agentic-ai-lab-durable-runtime-store-backend/default
 +agentic-ai-lab-turso-durable-runtime-store-capability-flags+
 agentic-ai-lab-durable-runtime-store-backend/turso
 agentic-ai-lab-durable-runtime-store-backend?
        agentic-ai-lab-durable-runtime-store-backend->receipt
        agentic-ai-lab-durable-runtime-store-backend-receipt->alist
        agentic-ai-lab-durable-runtime-store-backend-negotiation
        agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
        agentic-ai-lab-durable-runtime-store-negotiation->marlin-handoff
        agentic-ai-lab-durable-runtime-store-negotiations->alists)

(def +agentic-ai-lab-durable-runtime-store-backend-kind+
  'agentic-ai-lab.durable.runtime-store-backend)

(def +agentic-ai-lab-durable-runtime-store-backend-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-backend.v1)

(def +agentic-ai-lab-durable-runtime-store-backend-receipt-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-backend.receipt.v1)

(def +agentic-ai-lab-durable-runtime-store-backend-diagnostic-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-backend.diagnostic.v1)

(def +agentic-ai-lab-durable-runtime-store-negotiation-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-negotiation.v1)

(def +agentic-ai-lab-durable-runtime-store-handoff-schema+
  'agentic-ai-lab.module-system.durable-runtime-store.marlin-handoff.v1)

(def +agentic-ai-lab-durable-runtime-store-backend-protocols+
  '(stdout-s-expression marlin-runtime-command marlin-service ffi))

(def +agentic-ai-lab-durable-runtime-store-handoff-required-fields+
  '(schema
    operation
    request-id
    request
    policy
    runtime-owner
    runtime-command-manifest
    negotiation
    runtime-executed))

;; : (forall (a) (-> Alist Symbol a a))
(def (agentic-ai-lab-durable-runtime-backend-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (forall (a) (-> POOObject Symbol a a))
(def (agentic-ai-lab-durable-runtime-backend-slot object key default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))

;; : (forall (a) (-> Alist Symbol a a))
(def (agentic-ai-lab-durable-runtime-backend-alist-ref row key default-value)
  (if (list? row)
    (let (entry (assoc key row))
      (if entry (cdr entry) default-value))
    default-value))

;; : (-> Procedure List Boolean)
(def (agentic-ai-lab-durable-runtime-backend-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (agentic-ai-lab-durable-runtime-backend-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> a (List a) Boolean))
(def (agentic-ai-lab-durable-runtime-backend-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-runtime-backend-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-durable-runtime-backend-every? symbol? values)))

;; : (-> Symbol Symbol Symbol Alist Alist)
(def (agentic-ai-lab-durable-runtime-backend-diagnostic code slot severity payload)
  (list
   (cons 'kind +agentic-ai-lab-durable-runtime-store-backend-diagnostic-schema+)
   (cons 'schema +agentic-ai-lab-durable-runtime-store-backend-diagnostic-schema+)
   (cons 'code code)
   (cons 'phase 'durable-runtime-store-backend)
   (cons 'slot slot)
   (cons 'severity severity)
   (cons 'payload payload)
   (cons 'recoverable?
         (agentic-ai-lab-durable-runtime-backend-option
          payload
          'recoverable?
          #t))
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol Datum [Alist])
(def (agentic-ai-lab-durable-runtime-backend-required-symbol-diagnostics code slot value)
  (if (symbol? value)
    '()
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t))))))

;; : (-> Symbol Symbol Datum [Alist])
(def (agentic-ai-lab-durable-runtime-backend-required-string-diagnostics code slot value)
  (if (string? value)
    '()
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'value value)
            (cons 'expected 'string)
            (cons 'recoverable? #t))))))

;; : (-> Symbol [Symbol] [Symbol] Symbol Symbol [Alist])
(def (agentic-ai-lab-durable-runtime-backend-symbol-list-diagnostics code
                                                               values
                                                               allowed
                                                               slot
                                                               owner)
  (cond
   ((not (agentic-ai-lab-durable-runtime-backend-symbol-list? values))
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'owner owner)
            (cons 'value values)
            (cons 'expected 'symbol-list)
            (cons 'allowed allowed)
            (cons 'recoverable? #t)))))
   ((agentic-ai-lab-durable-runtime-backend-every?
     (lambda (value)
       (agentic-ai-lab-durable-runtime-backend-member? value allowed))
     values)
    '())
   (else
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'owner owner)
            (cons 'value values)
            (cons 'allowed allowed)
            (cons 'recoverable? #t)))))))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-durable-runtime-backend-missing-symbols required supported)
  (cond
   ((null? required) '())
   ((agentic-ai-lab-durable-runtime-backend-member? (car required) supported)
    (agentic-ai-lab-durable-runtime-backend-missing-symbols (cdr required)
                                                      supported))
   (else
    (cons (car required)
          (agentic-ai-lab-durable-runtime-backend-missing-symbols (cdr required)
                                                            supported)))))

;; : (-> Symbol Symbol String Symbol [Symbol] [Symbol] [Symbol] [Alist] POOObject)
(def (agentic-ai-lab-durable-runtime-store-backend backend-id
                                             backend-kind
                                             executable
                                             protocol
                                             supported-ledger-kinds
                                             supported-capability-flags
                                             operation-kinds
                                             . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (runtime-owner
          (agentic-ai-lab-durable-runtime-backend-option
           options
           'runtime-owner
           "marlin-agent-core"))
         (metadata
          (agentic-ai-lab-durable-runtime-backend-option options 'metadata '())))
    (object<-alist
     (list
      (cons 'durable-runtime-store-backend-kind
            +agentic-ai-lab-durable-runtime-store-backend-kind+)
      (cons 'durable-runtime-store-backend-schema
            +agentic-ai-lab-durable-runtime-store-backend-schema+)
      (cons 'backend-id backend-id)
      (cons 'backend-kind backend-kind)
      (cons 'executable executable)
      (cons 'protocol protocol)
      (cons 'supported-ledger-kinds supported-ledger-kinds)
      (cons 'supported-capability-flags supported-capability-flags)
      (cons 'operation-kinds operation-kinds)
      (cons 'runtime-owner runtime-owner)
      (cons 'backend-metadata metadata)
      (cons 'runtime-executed #f)))))

(def agentic-ai-lab-durable-runtime-store-backend/default
  (agentic-ai-lab-durable-runtime-store-backend
   'runtime-backend/marlin-store
   'marlin-runtime-store
   "marlin-runtime-store"
   'stdout-s-expression
   +agentic-ai-lab-durable-runtime-store-ledger-kinds+
   +agentic-ai-lab-durable-runtime-store-capability-flags+
   +agentic-ai-lab-durable-runtime-store-capability-flags+
   '((metadata . ((scope . shared)
                  (runtime-executed . #f))))))

(def +agentic-ai-lab-turso-durable-runtime-store-capability-flags+
  (append +agentic-ai-lab-durable-runtime-store-capability-flags+
          '(concurrent-writes
            local-first-push-pull
            ai-vector-search
            libsql-vector-index
            vector-top-k)))

(def agentic-ai-lab-durable-runtime-store-backend/turso
  (agentic-ai-lab-durable-runtime-store-backend
   'runtime-backend/turso
   'turso-runtime-store
   "turso-runtime-store"
   'python-pyturso
   +agentic-ai-lab-durable-runtime-store-ledger-kinds+
   +agentic-ai-lab-turso-durable-runtime-store-capability-flags+
   +agentic-ai-lab-durable-runtime-store-capability-flags+
   '((metadata . ((driver . turso)
                  (driver-package . pyturso)
                  (connection-module . turso)
                  (concurrent-writes . #t)
                  (sync-model . local-first-push-pull)
                  (ai-vector-search . #t)
                  (vector-index . libsql_vector_idx)
                  (vector-query . vector_top_k)
                  (runtime-executed . #f))))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-runtime-store-backend? value)
  (and (object? value)
       (.slot? value 'durable-runtime-store-backend-kind)
       (eq? (.ref value 'durable-runtime-store-backend-kind)
            +agentic-ai-lab-durable-runtime-store-backend-kind+)))

;; : (-> PooDurableRuntimeStoreBackend [Alist])
(def (agentic-ai-lab-durable-runtime-store-backend-diagnostics backend)
  (let ((backend-id
         (agentic-ai-lab-durable-runtime-backend-slot backend 'backend-id #f))
        (backend-kind
         (agentic-ai-lab-durable-runtime-backend-slot backend 'backend-kind #f))
        (executable
         (agentic-ai-lab-durable-runtime-backend-slot backend 'executable #f))
        (protocol
         (agentic-ai-lab-durable-runtime-backend-slot backend 'protocol #f))
        (runtime-owner
         (agentic-ai-lab-durable-runtime-backend-slot backend 'runtime-owner #f))
        (ledger-kinds
         (agentic-ai-lab-durable-runtime-backend-slot
          backend
          'supported-ledger-kinds
          #f))
        (capability-flags
         (agentic-ai-lab-durable-runtime-backend-slot
          backend
          'supported-capability-flags
          #f))
        (operation-kinds
         (agentic-ai-lab-durable-runtime-backend-slot backend 'operation-kinds #f)))
    (if (agentic-ai-lab-durable-runtime-store-backend? backend)
      (append
       (agentic-ai-lab-durable-runtime-backend-required-symbol-diagnostics
        'missing-backend-id
        'backend-id
        backend-id)
       (agentic-ai-lab-durable-runtime-backend-required-symbol-diagnostics
        'missing-backend-kind
        'backend-kind
        backend-kind)
       (agentic-ai-lab-durable-runtime-backend-required-string-diagnostics
        'missing-executable
        'executable
        executable)
       (agentic-ai-lab-durable-runtime-backend-required-symbol-diagnostics
        'missing-protocol
        'protocol
        protocol)
       (if (agentic-ai-lab-durable-runtime-backend-member?
            protocol
            +agentic-ai-lab-durable-runtime-store-backend-protocols+)
         '()
         (list
          (agentic-ai-lab-durable-runtime-backend-diagnostic
           'unsupported-backend-protocol
           'protocol
           'error
           (list (cons 'backend-id backend-id)
                 (cons 'value protocol)
                 (cons 'allowed
                       +agentic-ai-lab-durable-runtime-store-backend-protocols+)
                 (cons 'recoverable? #t)))))
       (if (string? runtime-owner)
         '()
         (list
          (agentic-ai-lab-durable-runtime-backend-diagnostic
           'invalid-runtime-owner
           'runtime-owner
           'error
           (list (cons 'backend-id backend-id)
                 (cons 'value runtime-owner)
                 (cons 'expected 'string)
                 (cons 'recoverable? #t)))))
       (agentic-ai-lab-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-ledger-kind
        ledger-kinds
        +agentic-ai-lab-durable-runtime-store-ledger-kinds+
        'supported-ledger-kinds
        backend-id)
       (agentic-ai-lab-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-capability-flag
        capability-flags
        +agentic-ai-lab-durable-runtime-store-capability-flags+
        'supported-capability-flags
        backend-id)
       (agentic-ai-lab-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-operation-kind
        operation-kinds
        +agentic-ai-lab-durable-runtime-store-capability-flags+
        'operation-kinds
        backend-id))
      (list
       (agentic-ai-lab-durable-runtime-backend-diagnostic
        'invalid-runtime-store-backend
        'backend
        'error
        (list (cons 'value backend)
              (cons 'recoverable? #t)))))))

;;; Runtime store backend receipts stay fixed structs before alist projection.
(defstruct agentic-ai-lab-durable-runtime-store-backend-receipt
  (backend-id
   backend-kind
   runtime-owner
   executable
   protocol
   supported-ledger-kinds
   supported-capability-flags
   operation-kinds
   valid?
   diagnostics
   metadata)
  transparent: #t)

;; : (-> PooDurableRuntimeStoreBackend PooDurableRuntimeStoreBackendReceipt)
(def (agentic-ai-lab-durable-runtime-store-backend->receipt backend)
  (let* ((diagnostics
          (agentic-ai-lab-durable-runtime-store-backend-diagnostics backend))
         (valid? (null? diagnostics)))
    (make-agentic-ai-lab-durable-runtime-store-backend-receipt
     (agentic-ai-lab-durable-runtime-backend-slot backend 'backend-id #f)
     (agentic-ai-lab-durable-runtime-backend-slot backend 'backend-kind #f)
     (agentic-ai-lab-durable-runtime-backend-slot backend 'runtime-owner #f)
     (agentic-ai-lab-durable-runtime-backend-slot backend 'executable #f)
     (agentic-ai-lab-durable-runtime-backend-slot backend 'protocol #f)
     (agentic-ai-lab-durable-runtime-backend-slot backend
                                            'supported-ledger-kinds
                                            '())
     (agentic-ai-lab-durable-runtime-backend-slot backend
                                            'supported-capability-flags
                                            '())
     (agentic-ai-lab-durable-runtime-backend-slot backend 'operation-kinds '())
     valid?
     diagnostics
     (agentic-ai-lab-durable-runtime-backend-slot backend
                                            'backend-metadata
                                            '()))))

;; : (-> PooDurableRuntimeStoreBackendReceipt Alist)
(defpoo-final-projection
  agentic-ai-lab-durable-runtime-store-backend-receipt->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-runtime-store-backend-receipt-diagnostics
               receipt))))
  (fields ((kind 'agentic-ai-lab.durable.runtime-store-backend-receipt)
           (schema +agentic-ai-lab-durable-runtime-store-backend-receipt-schema+)
           (backend-id
            (agentic-ai-lab-durable-runtime-store-backend-receipt-backend-id receipt))
           (backend-kind
            (agentic-ai-lab-durable-runtime-store-backend-receipt-backend-kind
             receipt))
           (runtime-owner
            (agentic-ai-lab-durable-runtime-store-backend-receipt-runtime-owner
             receipt))
           (executable
            (agentic-ai-lab-durable-runtime-store-backend-receipt-executable
             receipt))
           (protocol
            (agentic-ai-lab-durable-runtime-store-backend-receipt-protocol receipt))
           (supported-ledger-kinds
            (agentic-ai-lab-durable-runtime-store-backend-receipt-supported-ledger-kinds
             receipt))
           (supported-capability-flags
            (agentic-ai-lab-durable-runtime-store-backend-receipt-supported-capability-flags
             receipt))
           (operation-kinds
            (agentic-ai-lab-durable-runtime-store-backend-receipt-operation-kinds
             receipt))
           (valid?
            (agentic-ai-lab-durable-runtime-store-backend-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (agentic-ai-lab-durable-runtime-store-backend-receipt-metadata receipt))
           (runtime-executed #f))))

;; : (-> Datum Alist)
(def (agentic-ai-lab-durable-runtime-store-contract-receipt-row receipt)
  (cond
   ((agentic-ai-lab-durable-runtime-store-contract-receipt? receipt)
    (agentic-ai-lab-durable-runtime-store-contract-receipt->alist receipt))
   ((list? receipt) receipt)
   (else receipt)))

;; : (-> Datum Alist)
(def (agentic-ai-lab-durable-runtime-store-backend-receipt-row receipt)
  (cond
   ((agentic-ai-lab-durable-runtime-store-backend-receipt? receipt)
    (agentic-ai-lab-durable-runtime-store-backend-receipt->alist receipt))
   ((list? receipt) receipt)
   (else receipt)))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-durable-runtime-store-contract-row-diagnostics row)
  (cond
   ((not (list? row))
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      'invalid-runtime-store-contract-receipt
      'contract-row
      'error
      (list (cons 'value row)
            (cons 'recoverable? #t)))))
   ((not (eq? (agentic-ai-lab-durable-runtime-backend-alist-ref row 'valid? #f)
              #t))
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      'runtime-store-contract-not-ready
      'contract-row
      'error
      (list (cons 'store-id
                  (agentic-ai-lab-durable-runtime-backend-alist-ref row
                                                              'store-id
                                                              #f))
            (cons 'diagnostics
                  (agentic-ai-lab-durable-runtime-backend-alist-ref row
                                                              'diagnostics
                                                              '()))
            (cons 'recoverable? #t)))))
   (else '())))

;; : (-> Alist [Alist])
(def (agentic-ai-lab-durable-runtime-store-backend-row-diagnostics row)
  (cond
   ((not (list? row))
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      'invalid-runtime-store-backend-receipt
      'backend-row
      'error
      (list (cons 'value row)
            (cons 'recoverable? #t)))))
   ((not (eq? (agentic-ai-lab-durable-runtime-backend-alist-ref row 'valid? #f)
              #t))
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      'runtime-store-backend-not-ready
      'backend-row
      'error
      (list (cons 'backend-id
                  (agentic-ai-lab-durable-runtime-backend-alist-ref row
                                                              'backend-id
                                                              #f))
            (cons 'diagnostics
                  (agentic-ai-lab-durable-runtime-backend-alist-ref row
                                                              'diagnostics
                                                              '()))
            (cons 'recoverable? #t)))))
   (else '())))

;; : (-> Symbol [Symbol] Symbol [Alist])
(def (agentic-ai-lab-durable-runtime-store-missing-diagnostics code values slot)
  (if (null? values)
    '()
    (list
     (agentic-ai-lab-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'missing values)
            (cons 'recoverable? #t))))))

;; : PooDurableRuntimeStoreNegotiationReceipt
(defstruct agentic-ai-lab-durable-runtime-store-negotiation-receipt
  (store-id
   backend-id
   backend-kind
   selected?
   handoff-ready?
   contract-row
   backend-row
   required-ledger-kinds
   supported-ledger-kinds
   missing-ledger-kinds
   required-capability-flags
   supported-capability-flags
   missing-capability-flags
   operation-kinds
   unsupported-operation-kinds
   manifest-operation
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   runtime-executed)
  transparent: #t)

;; : (-> PooDurableRuntimeStoreContractReceipt PooDurableRuntimeStoreBackendReceipt [Alist] PooDurableRuntimeStoreNegotiationReceipt)
(def (agentic-ai-lab-durable-runtime-store-backend-negotiation contract-receipt
                                                          backend-receipt
                                                          . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (contract-row
          (agentic-ai-lab-durable-runtime-store-contract-receipt-row
           contract-receipt))
         (backend-row
          (agentic-ai-lab-durable-runtime-store-backend-receipt-row backend-receipt))
         (required-ledger-kinds
          (agentic-ai-lab-durable-runtime-backend-alist-ref
           contract-row
           'ledger-kinds
           '()))
         (supported-ledger-kinds
          (agentic-ai-lab-durable-runtime-backend-alist-ref
           backend-row
           'supported-ledger-kinds
           '()))
         (missing-ledger-kinds
          (agentic-ai-lab-durable-runtime-backend-missing-symbols
           required-ledger-kinds
           supported-ledger-kinds))
         (required-capability-flags
          (agentic-ai-lab-durable-runtime-backend-alist-ref
           contract-row
           'capability-flags
           '()))
         (supported-capability-flags
          (agentic-ai-lab-durable-runtime-backend-alist-ref
           backend-row
           'supported-capability-flags
           '()))
         (missing-capability-flags
          (agentic-ai-lab-durable-runtime-backend-missing-symbols
           required-capability-flags
           supported-capability-flags))
         (operation-kinds
          (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row
                                                      'operation-kinds
                                                      '()))
         (unsupported-operation-kinds
          (agentic-ai-lab-durable-runtime-backend-missing-symbols
           required-capability-flags
           operation-kinds))
         (manifest-operation
          (agentic-ai-lab-durable-runtime-backend-option
           options
           'manifest-operation
           'durable-runtime-store-negotiate))
         (metadata
          (agentic-ai-lab-durable-runtime-backend-option options 'metadata '()))
         (diagnostics
          (append
           (agentic-ai-lab-durable-runtime-store-contract-row-diagnostics
            contract-row)
           (agentic-ai-lab-durable-runtime-store-backend-row-diagnostics
            backend-row)
           (agentic-ai-lab-durable-runtime-store-missing-diagnostics
            'missing-ledger-kinds
            missing-ledger-kinds
            'supported-ledger-kinds)
           (agentic-ai-lab-durable-runtime-store-missing-diagnostics
            'missing-capability-flags
            missing-capability-flags
            'supported-capability-flags)
           (agentic-ai-lab-durable-runtime-store-missing-diagnostics
            'unsupported-operation-kinds
            unsupported-operation-kinds
            'operation-kinds)))
         (valid? (null? diagnostics)))
    (make-agentic-ai-lab-durable-runtime-store-negotiation-receipt
     (agentic-ai-lab-durable-runtime-backend-alist-ref contract-row 'store-id #f)
     (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row 'backend-id #f)
     (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row
                                                 'backend-kind
                                                 #f)
     valid?
     valid?
     contract-row
     backend-row
     required-ledger-kinds
     supported-ledger-kinds
     missing-ledger-kinds
     required-capability-flags
     supported-capability-flags
     missing-capability-flags
     operation-kinds
     unsupported-operation-kinds
     manifest-operation
     valid?
     diagnostics
     metadata
     (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row
                                                 'runtime-owner
                                                 "marlin-agent-core")
     #t
     #f)))

;; : (-> PooDurableRuntimeStoreNegotiationReceipt Alist)
(defpoo-final-projection
  agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-runtime-store-negotiation-receipt-diagnostics
               receipt))))
  (fields ((kind 'agentic-ai-lab.durable.runtime-store-negotiation-receipt)
           (schema +agentic-ai-lab-durable-runtime-store-negotiation-schema+)
           (store-id
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-store-id
             receipt))
           (backend-id
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-id
             receipt))
           (backend-kind
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-kind
             receipt))
           (selected?
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-selected?
             receipt))
           (handoff-ready?
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-handoff-ready?
             receipt))
           (contract-row
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-contract-row
             receipt))
           (backend-row
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-row
             receipt))
           (required-ledger-kinds
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-required-ledger-kinds
             receipt))
           (supported-ledger-kinds
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-supported-ledger-kinds
             receipt))
           (missing-ledger-kinds
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-missing-ledger-kinds
             receipt))
           (required-capability-flags
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-required-capability-flags
             receipt))
           (supported-capability-flags
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-supported-capability-flags
             receipt))
           (missing-capability-flags
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-missing-capability-flags
             receipt))
           (operation-kinds
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-operation-kinds
             receipt))
           (unsupported-operation-kinds
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-unsupported-operation-kinds
             receipt))
           (manifest-operation
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-manifest-operation
             receipt))
           (valid?
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-valid?
             receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-metadata
             receipt))
           (runtime-owner
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-runtime-owner
             receipt))
           (handoff-required
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-handoff-required
             receipt))
           (runtime-executed
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-runtime-executed
             receipt)))))

;; : (-> PooDurableRuntimeStoreNegotiationReceipt Alist)
(def (agentic-ai-lab-durable-runtime-store-negotiation->marlin-handoff receipt
                                                                 . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (row (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
               receipt))
         (backend-row
          (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-row
           receipt))
         (operation
          (agentic-ai-lab-durable-runtime-store-negotiation-receipt-manifest-operation
           receipt))
         (executable
          (agentic-ai-lab-durable-runtime-backend-option
           options
           'executable
           (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row
                                                       'executable
                                                       "marlin-runtime-store")))
         (arguments
          (agentic-ai-lab-durable-runtime-backend-option
           options
           'arguments
           '("durable-runtime-store" "negotiate")))
         (protocol
          (agentic-ai-lab-durable-runtime-backend-alist-ref backend-row
                                                      'protocol
                                                      'stdout-s-expression))
         (metadata
          (list (cons 'source 'agentic-ai-lab.durable.runtime-store)
                (cons 'backend-id
                      (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-id
                       receipt))
                (cons 'store-id
                      (agentic-ai-lab-durable-runtime-store-negotiation-receipt-store-id
                       receipt))
                (cons 'runtime-executed #f)))
         (envelope
          (list (cons 'schema +runtime-request-schema+)
                (cons 'runtime 'marlin)
                (cons 'operation operation)
                (cons 'request-id
                      (list 'agentic-ai-lab.durable.runtime-store
                            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-store-id
                             receipt)
                            (agentic-ai-lab-durable-runtime-store-negotiation-receipt-backend-id
                             receipt)))
                (cons 'artifact-handle #f)
                (cons 'request row)
                (cons 'policy
                      (list
                       (cons 'runtime-owner
                             (agentic-ai-lab-durable-runtime-store-negotiation-receipt-runtime-owner
                              receipt))
                       (cons 'handoff-required #t)
                       (cons 'runtime-executed #f)))
                (cons 'plan-id #f)
                (cons 'node-id
                      (agentic-ai-lab-durable-runtime-store-negotiation-receipt-store-id
                       receipt))
                (cons 'frontier '())))
         (runtime-command-manifest
          (runtime-command-fields->manifest
           operation
           executable
           arguments
           protocol
           metadata
           envelope)))
    (list
     (cons 'kind 'agentic-ai-lab.durable.runtime-store.marlin-handoff)
     (cons 'schema +agentic-ai-lab-durable-runtime-store-handoff-schema+)
     (cons 'request-schema +runtime-request-schema+)
     (cons 'operation operation)
     (cons 'request-id
           (agentic-ai-lab-durable-runtime-backend-alist-ref
            runtime-command-manifest
            'request-id
            #f))
     (cons 'runtime-owner
           (agentic-ai-lab-durable-runtime-store-negotiation-receipt-runtime-owner
            receipt))
     (cons 'handoff-ready?
           (agentic-ai-lab-durable-runtime-store-negotiation-receipt-handoff-ready?
            receipt))
     (cons 'required-fields
           +agentic-ai-lab-durable-runtime-store-handoff-required-fields+)
     (cons 'negotiation row)
     (cons 'runtime-command-manifest runtime-command-manifest)
     (cons 'runtime-executed #f)
     (cons 'runtime-parses-scheme-source #f)
     (cons 'scheme-manufactures-runtime-handlers #f))))

;; : (-> [PooDurableRuntimeStoreNegotiationReceipt] [Alist])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-runtime-store-negotiations->alists (receipts)
  (projector agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist)
  (error-message "durable runtime store negotiation serialization requires a list"))
