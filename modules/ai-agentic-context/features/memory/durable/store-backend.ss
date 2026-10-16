;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store backend negotiation and Marlin handoff ABI.
;;; Invariant: Scheme selects and projects backend contracts only; the runtime
;;; owns append, fsync, leases, checkpoint IO, index rebuild, and repair jobs.

(import (only-in :clan/poo/object .ref .slot? object? object<-alist)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/ai-agentic-context/features/memory/durable/store)

(export +poo-flow-durable-runtime-store-backend-kind+
        +poo-flow-durable-runtime-store-backend-schema+
        +poo-flow-durable-runtime-store-backend-receipt-schema+
        +poo-flow-durable-runtime-store-backend-diagnostic-schema+
        +poo-flow-durable-runtime-store-negotiation-schema+
        +poo-flow-durable-runtime-store-handoff-schema+
        +poo-flow-durable-runtime-store-backend-protocols+
        +poo-flow-durable-runtime-store-handoff-required-fields+
        make-poo-flow-durable-runtime-store-backend-receipt
        poo-flow-durable-runtime-store-backend-receipt?
        poo-flow-durable-runtime-store-backend-receipt-backend-id
        poo-flow-durable-runtime-store-backend-receipt-backend-kind
        poo-flow-durable-runtime-store-backend-receipt-runtime-owner
        poo-flow-durable-runtime-store-backend-receipt-executable
        poo-flow-durable-runtime-store-backend-receipt-protocol
        poo-flow-durable-runtime-store-backend-receipt-supported-ledger-kinds
        poo-flow-durable-runtime-store-backend-receipt-supported-capability-flags
        poo-flow-durable-runtime-store-backend-receipt-operation-kinds
        poo-flow-durable-runtime-store-backend-receipt-valid?
        poo-flow-durable-runtime-store-backend-receipt-diagnostics
        poo-flow-durable-runtime-store-backend-receipt-metadata
        make-poo-flow-durable-runtime-store-negotiation-receipt
        poo-flow-durable-runtime-store-negotiation-receipt?
        poo-flow-durable-runtime-store-negotiation-receipt-store-id
        poo-flow-durable-runtime-store-negotiation-receipt-backend-id
        poo-flow-durable-runtime-store-negotiation-receipt-backend-kind
        poo-flow-durable-runtime-store-negotiation-receipt-selected?
        poo-flow-durable-runtime-store-negotiation-receipt-handoff-ready?
        poo-flow-durable-runtime-store-negotiation-receipt-contract-row
        poo-flow-durable-runtime-store-negotiation-receipt-backend-row
        poo-flow-durable-runtime-store-negotiation-receipt-required-ledger-kinds
        poo-flow-durable-runtime-store-negotiation-receipt-supported-ledger-kinds
        poo-flow-durable-runtime-store-negotiation-receipt-missing-ledger-kinds
        poo-flow-durable-runtime-store-negotiation-receipt-required-capability-flags
        poo-flow-durable-runtime-store-negotiation-receipt-supported-capability-flags
        poo-flow-durable-runtime-store-negotiation-receipt-missing-capability-flags
        poo-flow-durable-runtime-store-negotiation-receipt-operation-kinds
        poo-flow-durable-runtime-store-negotiation-receipt-unsupported-operation-kinds
        poo-flow-durable-runtime-store-negotiation-receipt-manifest-operation
        poo-flow-durable-runtime-store-negotiation-receipt-valid?
        poo-flow-durable-runtime-store-negotiation-receipt-diagnostics
        poo-flow-durable-runtime-store-negotiation-receipt-metadata
 poo-flow-durable-runtime-store-backend
 poo-flow-durable-runtime-store-backend/default
 +poo-flow-turso-durable-runtime-store-capability-flags+
 poo-flow-durable-runtime-store-backend/turso
 poo-flow-durable-runtime-store-backend?
        poo-flow-durable-runtime-store-backend->receipt
        poo-flow-durable-runtime-store-backend-receipt->alist
        poo-flow-durable-runtime-store-backend-negotiation
        poo-flow-durable-runtime-store-negotiation-receipt->alist
        poo-flow-durable-runtime-store-negotiation->marlin-handoff
        poo-flow-durable-runtime-store-negotiations->alists)

(def +poo-flow-durable-runtime-store-backend-kind+
  'poo-flow.durable.runtime-store-backend)

(def +poo-flow-durable-runtime-store-backend-schema+
  'poo-flow.module-system.durable-runtime-store-backend.v1)

(def +poo-flow-durable-runtime-store-backend-receipt-schema+
  'poo-flow.module-system.durable-runtime-store-backend.receipt.v1)

(def +poo-flow-durable-runtime-store-backend-diagnostic-schema+
  'poo-flow.module-system.durable-runtime-store-backend.diagnostic.v1)

(def +poo-flow-durable-runtime-store-negotiation-schema+
  'poo-flow.module-system.durable-runtime-store-negotiation.v1)

(def +poo-flow-durable-runtime-store-handoff-schema+
  'poo-flow.module-system.durable-runtime-store.marlin-handoff.v1)

(def +poo-flow-durable-runtime-store-backend-protocols+
  '(stdout-s-expression marlin-runtime-command marlin-service ffi))

(def +poo-flow-durable-runtime-store-handoff-required-fields+
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
(def (poo-flow-durable-runtime-backend-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (forall (a) (-> POOObject Symbol a a))
(def (poo-flow-durable-runtime-backend-slot object key default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))

;; : (forall (a) (-> Alist Symbol a a))
(def (poo-flow-durable-runtime-backend-alist-ref row key default-value)
  (if (list? row)
    (let (entry (assoc key row))
      (if entry (cdr entry) default-value))
    default-value))

;; : (-> Procedure List Boolean)
(def (poo-flow-durable-runtime-backend-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (poo-flow-durable-runtime-backend-every? predicate (cdr values)))
   (else #f)))

;; : (forall (a) (-> a (List a) Boolean))
(def (poo-flow-durable-runtime-backend-member? value values)
  (if (member value values) #t #f))

;; : (-> Datum Boolean)
(def (poo-flow-durable-runtime-backend-symbol-list? values)
  (and (list? values)
       (poo-flow-durable-runtime-backend-every? symbol? values)))

;; : (-> Symbol Symbol Symbol Alist Alist)
(def (poo-flow-durable-runtime-backend-diagnostic code slot severity payload)
  (list
   (cons 'kind +poo-flow-durable-runtime-store-backend-diagnostic-schema+)
   (cons 'schema +poo-flow-durable-runtime-store-backend-diagnostic-schema+)
   (cons 'code code)
   (cons 'phase 'durable-runtime-store-backend)
   (cons 'slot slot)
   (cons 'severity severity)
   (cons 'payload payload)
   (cons 'recoverable?
         (poo-flow-durable-runtime-backend-option
          payload
          'recoverable?
          #t))
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol Datum [Alist])
(def (poo-flow-durable-runtime-backend-required-symbol-diagnostics code slot value)
  (if (symbol? value)
    '()
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'value value)
            (cons 'expected 'symbol)
            (cons 'recoverable? #t))))))

;; : (-> Symbol Symbol Datum [Alist])
(def (poo-flow-durable-runtime-backend-required-string-diagnostics code slot value)
  (if (string? value)
    '()
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'value value)
            (cons 'expected 'string)
            (cons 'recoverable? #t))))))

;; : (-> Symbol [Symbol] [Symbol] Symbol Symbol [Alist])
(def (poo-flow-durable-runtime-backend-symbol-list-diagnostics code
                                                               values
                                                               allowed
                                                               slot
                                                               owner)
  (cond
   ((not (poo-flow-durable-runtime-backend-symbol-list? values))
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'owner owner)
            (cons 'value values)
            (cons 'expected 'symbol-list)
            (cons 'allowed allowed)
            (cons 'recoverable? #t)))))
   ((poo-flow-durable-runtime-backend-every?
     (lambda (value)
       (poo-flow-durable-runtime-backend-member? value allowed))
     values)
    '())
   (else
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'owner owner)
            (cons 'value values)
            (cons 'allowed allowed)
            (cons 'recoverable? #t)))))))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (poo-flow-durable-runtime-backend-missing-symbols required supported)
  (cond
   ((null? required) '())
   ((poo-flow-durable-runtime-backend-member? (car required) supported)
    (poo-flow-durable-runtime-backend-missing-symbols (cdr required)
                                                      supported))
   (else
    (cons (car required)
          (poo-flow-durable-runtime-backend-missing-symbols (cdr required)
                                                            supported)))))

;; : (-> Symbol Symbol String Symbol [Symbol] [Symbol] [Symbol] [Alist] POOObject)
(def (poo-flow-durable-runtime-store-backend backend-id
                                             backend-kind
                                             executable
                                             protocol
                                             supported-ledger-kinds
                                             supported-capability-flags
                                             operation-kinds
                                             . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (runtime-owner
          (poo-flow-durable-runtime-backend-option
           options
           'runtime-owner
           "marlin-agent-core"))
         (metadata
          (poo-flow-durable-runtime-backend-option options 'metadata '())))
    (object<-alist
     (list
      (cons 'durable-runtime-store-backend-kind
            +poo-flow-durable-runtime-store-backend-kind+)
      (cons 'durable-runtime-store-backend-schema
            +poo-flow-durable-runtime-store-backend-schema+)
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

(def poo-flow-durable-runtime-store-backend/default
  (poo-flow-durable-runtime-store-backend
   'runtime-backend/marlin-store
   'marlin-runtime-store
   "marlin-runtime-store"
   'stdout-s-expression
   +poo-flow-durable-runtime-store-ledger-kinds+
   +poo-flow-durable-runtime-store-capability-flags+
   +poo-flow-durable-runtime-store-capability-flags+
   '((metadata . ((scope . shared)
                  (runtime-executed . #f))))))

(def +poo-flow-turso-durable-runtime-store-capability-flags+
  (append +poo-flow-durable-runtime-store-capability-flags+
          '(concurrent-writes
            local-first-push-pull
            ai-vector-search
            libsql-vector-index
            vector-top-k)))

(def poo-flow-durable-runtime-store-backend/turso
  (poo-flow-durable-runtime-store-backend
   'runtime-backend/turso
   'turso-runtime-store
   "turso-runtime-store"
   'python-pyturso
   +poo-flow-durable-runtime-store-ledger-kinds+
   +poo-flow-turso-durable-runtime-store-capability-flags+
   +poo-flow-durable-runtime-store-capability-flags+
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
(def (poo-flow-durable-runtime-store-backend? value)
  (and (object? value)
       (.slot? value 'durable-runtime-store-backend-kind)
       (eq? (.ref value 'durable-runtime-store-backend-kind)
            +poo-flow-durable-runtime-store-backend-kind+)))

;; : (-> PooDurableRuntimeStoreBackend [Alist])
(def (poo-flow-durable-runtime-store-backend-diagnostics backend)
  (let ((backend-id
         (poo-flow-durable-runtime-backend-slot backend 'backend-id #f))
        (backend-kind
         (poo-flow-durable-runtime-backend-slot backend 'backend-kind #f))
        (executable
         (poo-flow-durable-runtime-backend-slot backend 'executable #f))
        (protocol
         (poo-flow-durable-runtime-backend-slot backend 'protocol #f))
        (runtime-owner
         (poo-flow-durable-runtime-backend-slot backend 'runtime-owner #f))
        (ledger-kinds
         (poo-flow-durable-runtime-backend-slot
          backend
          'supported-ledger-kinds
          #f))
        (capability-flags
         (poo-flow-durable-runtime-backend-slot
          backend
          'supported-capability-flags
          #f))
        (operation-kinds
         (poo-flow-durable-runtime-backend-slot backend 'operation-kinds #f)))
    (if (poo-flow-durable-runtime-store-backend? backend)
      (append
       (poo-flow-durable-runtime-backend-required-symbol-diagnostics
        'missing-backend-id
        'backend-id
        backend-id)
       (poo-flow-durable-runtime-backend-required-symbol-diagnostics
        'missing-backend-kind
        'backend-kind
        backend-kind)
       (poo-flow-durable-runtime-backend-required-string-diagnostics
        'missing-executable
        'executable
        executable)
       (poo-flow-durable-runtime-backend-required-symbol-diagnostics
        'missing-protocol
        'protocol
        protocol)
       (if (poo-flow-durable-runtime-backend-member?
            protocol
            +poo-flow-durable-runtime-store-backend-protocols+)
         '()
         (list
          (poo-flow-durable-runtime-backend-diagnostic
           'unsupported-backend-protocol
           'protocol
           'error
           (list (cons 'backend-id backend-id)
                 (cons 'value protocol)
                 (cons 'allowed
                       +poo-flow-durable-runtime-store-backend-protocols+)
                 (cons 'recoverable? #t)))))
       (if (string? runtime-owner)
         '()
         (list
          (poo-flow-durable-runtime-backend-diagnostic
           'invalid-runtime-owner
           'runtime-owner
           'error
           (list (cons 'backend-id backend-id)
                 (cons 'value runtime-owner)
                 (cons 'expected 'string)
                 (cons 'recoverable? #t)))))
       (poo-flow-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-ledger-kind
        ledger-kinds
        +poo-flow-durable-runtime-store-ledger-kinds+
        'supported-ledger-kinds
        backend-id)
       (poo-flow-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-capability-flag
        capability-flags
        +poo-flow-durable-runtime-store-capability-flags+
        'supported-capability-flags
        backend-id)
       (poo-flow-durable-runtime-backend-symbol-list-diagnostics
        'unsupported-operation-kind
        operation-kinds
        +poo-flow-durable-runtime-store-capability-flags+
        'operation-kinds
        backend-id))
      (list
       (poo-flow-durable-runtime-backend-diagnostic
        'invalid-runtime-store-backend
        'backend
        'error
        (list (cons 'value backend)
              (cons 'recoverable? #t)))))))

;;; Runtime store backend receipts stay fixed structs before alist projection.
(defstruct poo-flow-durable-runtime-store-backend-receipt
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
(def (poo-flow-durable-runtime-store-backend->receipt backend)
  (let* ((diagnostics
          (poo-flow-durable-runtime-store-backend-diagnostics backend))
         (valid? (null? diagnostics)))
    (make-poo-flow-durable-runtime-store-backend-receipt
     (poo-flow-durable-runtime-backend-slot backend 'backend-id #f)
     (poo-flow-durable-runtime-backend-slot backend 'backend-kind #f)
     (poo-flow-durable-runtime-backend-slot backend 'runtime-owner #f)
     (poo-flow-durable-runtime-backend-slot backend 'executable #f)
     (poo-flow-durable-runtime-backend-slot backend 'protocol #f)
     (poo-flow-durable-runtime-backend-slot backend
                                            'supported-ledger-kinds
                                            '())
     (poo-flow-durable-runtime-backend-slot backend
                                            'supported-capability-flags
                                            '())
     (poo-flow-durable-runtime-backend-slot backend 'operation-kinds '())
     valid?
     diagnostics
     (poo-flow-durable-runtime-backend-slot backend
                                            'backend-metadata
                                            '()))))

;; : (-> PooDurableRuntimeStoreBackendReceipt Alist)
(defpoo-final-projection
  poo-flow-durable-runtime-store-backend-receipt->alist (receipt)
  (bindings ((diagnostics
              (poo-flow-durable-runtime-store-backend-receipt-diagnostics
               receipt))))
  (fields ((kind 'poo-flow.durable.runtime-store-backend-receipt)
           (schema +poo-flow-durable-runtime-store-backend-receipt-schema+)
           (backend-id
            (poo-flow-durable-runtime-store-backend-receipt-backend-id receipt))
           (backend-kind
            (poo-flow-durable-runtime-store-backend-receipt-backend-kind
             receipt))
           (runtime-owner
            (poo-flow-durable-runtime-store-backend-receipt-runtime-owner
             receipt))
           (executable
            (poo-flow-durable-runtime-store-backend-receipt-executable
             receipt))
           (protocol
            (poo-flow-durable-runtime-store-backend-receipt-protocol receipt))
           (supported-ledger-kinds
            (poo-flow-durable-runtime-store-backend-receipt-supported-ledger-kinds
             receipt))
           (supported-capability-flags
            (poo-flow-durable-runtime-store-backend-receipt-supported-capability-flags
             receipt))
           (operation-kinds
            (poo-flow-durable-runtime-store-backend-receipt-operation-kinds
             receipt))
           (valid?
            (poo-flow-durable-runtime-store-backend-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (poo-flow-durable-runtime-store-backend-receipt-metadata receipt))
           (runtime-executed #f))))

;; : (-> Datum Alist)
(def (poo-flow-durable-runtime-store-contract-receipt-row receipt)
  (cond
   ((poo-flow-durable-runtime-store-contract-receipt? receipt)
    (poo-flow-durable-runtime-store-contract-receipt->alist receipt))
   ((list? receipt) receipt)
   (else receipt)))

;; : (-> Datum Alist)
(def (poo-flow-durable-runtime-store-backend-receipt-row receipt)
  (cond
   ((poo-flow-durable-runtime-store-backend-receipt? receipt)
    (poo-flow-durable-runtime-store-backend-receipt->alist receipt))
   ((list? receipt) receipt)
   (else receipt)))

;; : (-> Alist [Alist])
(def (poo-flow-durable-runtime-store-contract-row-diagnostics row)
  (cond
   ((not (list? row))
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      'invalid-runtime-store-contract-receipt
      'contract-row
      'error
      (list (cons 'value row)
            (cons 'recoverable? #t)))))
   ((not (eq? (poo-flow-durable-runtime-backend-alist-ref row 'valid? #f)
              #t))
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      'runtime-store-contract-not-ready
      'contract-row
      'error
      (list (cons 'store-id
                  (poo-flow-durable-runtime-backend-alist-ref row
                                                              'store-id
                                                              #f))
            (cons 'diagnostics
                  (poo-flow-durable-runtime-backend-alist-ref row
                                                              'diagnostics
                                                              '()))
            (cons 'recoverable? #t)))))
   (else '())))

;; : (-> Alist [Alist])
(def (poo-flow-durable-runtime-store-backend-row-diagnostics row)
  (cond
   ((not (list? row))
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      'invalid-runtime-store-backend-receipt
      'backend-row
      'error
      (list (cons 'value row)
            (cons 'recoverable? #t)))))
   ((not (eq? (poo-flow-durable-runtime-backend-alist-ref row 'valid? #f)
              #t))
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      'runtime-store-backend-not-ready
      'backend-row
      'error
      (list (cons 'backend-id
                  (poo-flow-durable-runtime-backend-alist-ref row
                                                              'backend-id
                                                              #f))
            (cons 'diagnostics
                  (poo-flow-durable-runtime-backend-alist-ref row
                                                              'diagnostics
                                                              '()))
            (cons 'recoverable? #t)))))
   (else '())))

;; : (-> Symbol [Symbol] Symbol [Alist])
(def (poo-flow-durable-runtime-store-missing-diagnostics code values slot)
  (if (null? values)
    '()
    (list
     (poo-flow-durable-runtime-backend-diagnostic
      code
      slot
      'error
      (list (cons 'missing values)
            (cons 'recoverable? #t))))))

;; : PooDurableRuntimeStoreNegotiationReceipt
(defstruct poo-flow-durable-runtime-store-negotiation-receipt
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
(def (poo-flow-durable-runtime-store-backend-negotiation contract-receipt
                                                          backend-receipt
                                                          . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (contract-row
          (poo-flow-durable-runtime-store-contract-receipt-row
           contract-receipt))
         (backend-row
          (poo-flow-durable-runtime-store-backend-receipt-row backend-receipt))
         (required-ledger-kinds
          (poo-flow-durable-runtime-backend-alist-ref
           contract-row
           'ledger-kinds
           '()))
         (supported-ledger-kinds
          (poo-flow-durable-runtime-backend-alist-ref
           backend-row
           'supported-ledger-kinds
           '()))
         (missing-ledger-kinds
          (poo-flow-durable-runtime-backend-missing-symbols
           required-ledger-kinds
           supported-ledger-kinds))
         (required-capability-flags
          (poo-flow-durable-runtime-backend-alist-ref
           contract-row
           'capability-flags
           '()))
         (supported-capability-flags
          (poo-flow-durable-runtime-backend-alist-ref
           backend-row
           'supported-capability-flags
           '()))
         (missing-capability-flags
          (poo-flow-durable-runtime-backend-missing-symbols
           required-capability-flags
           supported-capability-flags))
         (operation-kinds
          (poo-flow-durable-runtime-backend-alist-ref backend-row
                                                      'operation-kinds
                                                      '()))
         (unsupported-operation-kinds
          (poo-flow-durable-runtime-backend-missing-symbols
           required-capability-flags
           operation-kinds))
         (manifest-operation
          (poo-flow-durable-runtime-backend-option
           options
           'manifest-operation
           'durable-runtime-store-negotiate))
         (metadata
          (poo-flow-durable-runtime-backend-option options 'metadata '()))
         (diagnostics
          (append
           (poo-flow-durable-runtime-store-contract-row-diagnostics
            contract-row)
           (poo-flow-durable-runtime-store-backend-row-diagnostics
            backend-row)
           (poo-flow-durable-runtime-store-missing-diagnostics
            'missing-ledger-kinds
            missing-ledger-kinds
            'supported-ledger-kinds)
           (poo-flow-durable-runtime-store-missing-diagnostics
            'missing-capability-flags
            missing-capability-flags
            'supported-capability-flags)
           (poo-flow-durable-runtime-store-missing-diagnostics
            'unsupported-operation-kinds
            unsupported-operation-kinds
            'operation-kinds)))
         (valid? (null? diagnostics)))
    (make-poo-flow-durable-runtime-store-negotiation-receipt
     (poo-flow-durable-runtime-backend-alist-ref contract-row 'store-id #f)
     (poo-flow-durable-runtime-backend-alist-ref backend-row 'backend-id #f)
     (poo-flow-durable-runtime-backend-alist-ref backend-row
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
     (poo-flow-durable-runtime-backend-alist-ref backend-row
                                                 'runtime-owner
                                                 "marlin-agent-core")
     #t
     #f)))

;; : (-> PooDurableRuntimeStoreNegotiationReceipt Alist)
(defpoo-final-projection
  poo-flow-durable-runtime-store-negotiation-receipt->alist (receipt)
  (bindings ((diagnostics
              (poo-flow-durable-runtime-store-negotiation-receipt-diagnostics
               receipt))))
  (fields ((kind 'poo-flow.durable.runtime-store-negotiation-receipt)
           (schema +poo-flow-durable-runtime-store-negotiation-schema+)
           (store-id
            (poo-flow-durable-runtime-store-negotiation-receipt-store-id
             receipt))
           (backend-id
            (poo-flow-durable-runtime-store-negotiation-receipt-backend-id
             receipt))
           (backend-kind
            (poo-flow-durable-runtime-store-negotiation-receipt-backend-kind
             receipt))
           (selected?
            (poo-flow-durable-runtime-store-negotiation-receipt-selected?
             receipt))
           (handoff-ready?
            (poo-flow-durable-runtime-store-negotiation-receipt-handoff-ready?
             receipt))
           (contract-row
            (poo-flow-durable-runtime-store-negotiation-receipt-contract-row
             receipt))
           (backend-row
            (poo-flow-durable-runtime-store-negotiation-receipt-backend-row
             receipt))
           (required-ledger-kinds
            (poo-flow-durable-runtime-store-negotiation-receipt-required-ledger-kinds
             receipt))
           (supported-ledger-kinds
            (poo-flow-durable-runtime-store-negotiation-receipt-supported-ledger-kinds
             receipt))
           (missing-ledger-kinds
            (poo-flow-durable-runtime-store-negotiation-receipt-missing-ledger-kinds
             receipt))
           (required-capability-flags
            (poo-flow-durable-runtime-store-negotiation-receipt-required-capability-flags
             receipt))
           (supported-capability-flags
            (poo-flow-durable-runtime-store-negotiation-receipt-supported-capability-flags
             receipt))
           (missing-capability-flags
            (poo-flow-durable-runtime-store-negotiation-receipt-missing-capability-flags
             receipt))
           (operation-kinds
            (poo-flow-durable-runtime-store-negotiation-receipt-operation-kinds
             receipt))
           (unsupported-operation-kinds
            (poo-flow-durable-runtime-store-negotiation-receipt-unsupported-operation-kinds
             receipt))
           (manifest-operation
            (poo-flow-durable-runtime-store-negotiation-receipt-manifest-operation
             receipt))
           (valid?
            (poo-flow-durable-runtime-store-negotiation-receipt-valid?
             receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (poo-flow-durable-runtime-store-negotiation-receipt-metadata
             receipt))
           (runtime-owner
            (poo-flow-durable-runtime-store-negotiation-receipt-runtime-owner
             receipt))
           (handoff-required
            (poo-flow-durable-runtime-store-negotiation-receipt-handoff-required
             receipt))
           (runtime-executed
            (poo-flow-durable-runtime-store-negotiation-receipt-runtime-executed
             receipt)))))

;; : (-> PooDurableRuntimeStoreNegotiationReceipt Alist)
(def (poo-flow-durable-runtime-store-negotiation->marlin-handoff receipt
                                                                 . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (row (poo-flow-durable-runtime-store-negotiation-receipt->alist
               receipt))
         (backend-row
          (poo-flow-durable-runtime-store-negotiation-receipt-backend-row
           receipt))
         (operation
          (poo-flow-durable-runtime-store-negotiation-receipt-manifest-operation
           receipt))
         (executable
          (poo-flow-durable-runtime-backend-option
           options
           'executable
           (poo-flow-durable-runtime-backend-alist-ref backend-row
                                                       'executable
                                                       "marlin-runtime-store")))
         (arguments
          (poo-flow-durable-runtime-backend-option
           options
           'arguments
           '("durable-runtime-store" "negotiate")))
         (protocol
          (poo-flow-durable-runtime-backend-alist-ref backend-row
                                                      'protocol
                                                      'stdout-s-expression))
         (metadata
          (list (cons 'source 'poo-flow.durable.runtime-store)
                (cons 'backend-id
                      (poo-flow-durable-runtime-store-negotiation-receipt-backend-id
                       receipt))
                (cons 'store-id
                      (poo-flow-durable-runtime-store-negotiation-receipt-store-id
                       receipt))
                (cons 'runtime-executed #f)))
         (envelope
          (list (cons 'schema +runtime-request-schema+)
                (cons 'runtime 'marlin)
                (cons 'operation operation)
                (cons 'request-id
                      (list 'poo-flow.durable.runtime-store
                            (poo-flow-durable-runtime-store-negotiation-receipt-store-id
                             receipt)
                            (poo-flow-durable-runtime-store-negotiation-receipt-backend-id
                             receipt)))
                (cons 'artifact-handle #f)
                (cons 'request row)
                (cons 'policy
                      (list
                       (cons 'runtime-owner
                             (poo-flow-durable-runtime-store-negotiation-receipt-runtime-owner
                              receipt))
                       (cons 'handoff-required #t)
                       (cons 'runtime-executed #f)))
                (cons 'plan-id #f)
                (cons 'node-id
                      (poo-flow-durable-runtime-store-negotiation-receipt-store-id
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
     (cons 'kind 'poo-flow.durable.runtime-store.marlin-handoff)
     (cons 'schema +poo-flow-durable-runtime-store-handoff-schema+)
     (cons 'request-schema +runtime-request-schema+)
     (cons 'operation operation)
     (cons 'request-id
           (poo-flow-durable-runtime-backend-alist-ref
            runtime-command-manifest
            'request-id
            #f))
     (cons 'runtime-owner
           (poo-flow-durable-runtime-store-negotiation-receipt-runtime-owner
            receipt))
     (cons 'handoff-ready?
           (poo-flow-durable-runtime-store-negotiation-receipt-handoff-ready?
            receipt))
     (cons 'required-fields
           +poo-flow-durable-runtime-store-handoff-required-fields+)
     (cons 'negotiation row)
     (cons 'runtime-command-manifest runtime-command-manifest)
     (cons 'runtime-executed #f)
     (cons 'runtime-parses-scheme-source #f)
     (cons 'scheme-manufactures-runtime-handlers #f))))

;; : (-> [PooDurableRuntimeStoreNegotiationReceipt] [Alist])
(defpoo-final-projection-batch
  poo-flow-durable-runtime-store-negotiations->alists (receipts)
  (projector poo-flow-durable-runtime-store-negotiation-receipt->alist)
  (error-message "durable runtime store negotiation serialization requires a list"))
