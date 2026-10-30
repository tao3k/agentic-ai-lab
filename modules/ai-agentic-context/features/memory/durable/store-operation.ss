;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime store operation receipts for Marlin handoff.
;;; Invariant: Scheme projects operation intent only; Rust/Marlin owns append,
;;; fsync, checkpoint IO, index rebuild, leases, and repair side effects.

(import (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend)

(export +agentic-ai-lab-durable-runtime-store-operation-receipt-kind+
        +agentic-ai-lab-durable-runtime-store-operation-receipt-schema+
        +agentic-ai-lab-durable-runtime-store-operation-handoff-schema+
        +agentic-ai-lab-durable-runtime-store-operation-specs+
        make-agentic-ai-lab-durable-runtime-store-operation-receipt
        agentic-ai-lab-durable-runtime-store-operation-receipt?
        agentic-ai-lab-durable-runtime-store-operation-receipt-valid?
        agentic-ai-lab-durable-runtime-store-operation-receipt-diagnostics
        agentic-ai-lab-durable-runtime-store-operation
        agentic-ai-lab-durable-runtime-store-operation-receipts
        agentic-ai-lab-durable-runtime-store-operation-receipt->alist
        agentic-ai-lab-durable-runtime-store-operation-receipts->alists
        agentic-ai-lab-durable-runtime-store-operations->marlin-handoff)

;; : Symbol
(def +agentic-ai-lab-durable-runtime-store-operation-receipt-kind+
  'agentic-ai-lab.durable.runtime-store-operation-receipt)

;; : Symbol
(def +agentic-ai-lab-durable-runtime-store-operation-receipt-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-operation.receipt.v1)

;; : Symbol
(def +agentic-ai-lab-durable-runtime-store-operation-handoff-schema+
  'agentic-ai-lab.module-system.durable-runtime-store-operation.marlin-handoff.v1)

;; OperationSpec = (Kind LedgerKind CapabilityFlag TargetSlot)
;; : [DurableRuntimeStoreOperationSpec]
(def +agentic-ai-lab-durable-runtime-store-operation-specs+
  '((append-fact fact-log append-fact fact-log-ref)
    (write-checkpoint checkpoint write-checkpoint checkpoint-store-ref)
    (rebuild-index derived-index rebuild-index derived-index-ref)
    (claim-job-lease job claim-job-lease job-store-ref)
    (append-repair-event repair append-repair-event repair-journal-ref)
    (retain-artifact artifact retain-artifact artifact-store-ref)
    (append-communication-event
     communication append-communication-event communication-ledger-ref)
    (attach-sandbox-handle sandbox attach-sandbox-handle sandbox-ledger-ref)))

;; : (forall (a) (-> Alist Symbol a a))
(def (durable-runtime-store-ref row key default)
  (if (list? row)
    (let (entry (assoc key row))
      (if entry (cdr entry) default))
    default))

;; : (-> Symbol (U #f Alist))
(def (durable-runtime-store-operation-spec operation-kind)
  (find (lambda (spec) (eq? (car spec) operation-kind))
        +agentic-ai-lab-durable-runtime-store-operation-specs+))

;; : (-> Symbol Symbol Value Alist)
(def (durable-runtime-store-operation-diagnostic code slot value)
  (list (cons 'kind 'agentic-ai-lab.durable.runtime-store-operation.diagnostic)
        (cons 'schema
              'agentic-ai-lab.module-system.durable-runtime-store-operation.diagnostic.v1)
        (cons 'code code)
        (cons 'phase 'durable-runtime-store-operation)
        (cons 'slot slot)
        (cons 'value value)
        (cons 'severity 'error)
        (cons 'recoverable? #t)
        (cons 'runtime-executed #f)))

;; : (-> Boolean Symbol Symbol Value [Alist])
(def (durable-runtime-store-operation-diagnostic-unless ok? code slot value)
  (if ok?
    '()
    (list (durable-runtime-store-operation-diagnostic code slot value))))

;; : (-> Datum Boolean)
(def (durable-runtime-store-symbol-list? value)
  (and (list? value)
       (not (find (lambda (item) (not (symbol? item))) value))))

;;; Runtime store operation receipts are fixed structs; handoff helpers project
;;; them into alists only at the Marlin boundary.
;; : PooDurableRuntimeStoreOperationReceipt
(defstruct agentic-ai-lab-durable-runtime-store-operation-receipt
  (operation-id
   operation-kind
   store-id
   backend-id
   project-id
   root-session-id
   session-id
   ledger-kind
   capability-flag
   target-ref
   payload-summary
   causal-refs
   watermark
   negotiation
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   runtime-executed)
  transparent: #t)

;; : (-> Symbol Symbol Alist Alist Symbol [Alist])
(def (durable-runtime-store-operation-diagnostics operation-id
                                                  operation-kind
                                                  spec
                                                  negotiation
                                                  target-ref
                                                  causal-refs)
  (append
   (durable-runtime-store-operation-diagnostic-unless
    (symbol? operation-id)
    'missing-operation-id
    'operation-id
    operation-id)
   (durable-runtime-store-operation-diagnostic-unless
    spec
    'unsupported-operation-kind
    'operation-kind
    operation-kind)
   (durable-runtime-store-operation-diagnostic-unless
    (eq? (durable-runtime-store-ref negotiation 'handoff-ready? #f) #t)
    'runtime-store-handoff-not-ready
    'negotiation
    negotiation)
   (durable-runtime-store-operation-diagnostic-unless
    (or (not spec)
        (member operation-kind
                (durable-runtime-store-ref negotiation 'operation-kinds '())))
    'operation-kind-not-supported-by-backend
    'operation-kind
    operation-kind)
   (durable-runtime-store-operation-diagnostic-unless
    (symbol? target-ref)
    'missing-target-ref
    'target-ref
    target-ref)
   (durable-runtime-store-operation-diagnostic-unless
    (durable-runtime-store-symbol-list? causal-refs)
    'invalid-causal-refs
    'causal-refs
    causal-refs)))

;; : (-> Symbol Symbol PooDurableRuntimeStoreNegotiationReceipt Datum [Alist] PooDurableRuntimeStoreOperationReceipt)
(def (agentic-ai-lab-durable-runtime-store-operation operation-id
                                               operation-kind
                                               negotiation
                                               payload-summary
                                               . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (negotiation-row
          (if (agentic-ai-lab-durable-runtime-store-negotiation-receipt? negotiation)
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
             negotiation)
            negotiation))
         (contract-row
          (durable-runtime-store-ref negotiation-row 'contract-row '()))
         (spec
          (durable-runtime-store-operation-spec operation-kind))
         (target-slot (and spec (cadddr spec)))
         (target-ref
          (durable-runtime-store-ref
           options
           'target-ref
           (durable-runtime-store-ref contract-row target-slot #f)))
         (causal-refs
          (durable-runtime-store-ref options 'causal-refs '()))
         (watermark
          (durable-runtime-store-ref options 'watermark #f))
         (metadata
          (durable-runtime-store-ref options 'metadata '()))
         (diagnostics
          (durable-runtime-store-operation-diagnostics
           operation-id
           operation-kind
           spec
           negotiation-row
           target-ref
           causal-refs)))
    (make-agentic-ai-lab-durable-runtime-store-operation-receipt
     operation-id
     operation-kind
     (durable-runtime-store-ref negotiation-row 'store-id #f)
     (durable-runtime-store-ref negotiation-row 'backend-id #f)
     (durable-runtime-store-ref contract-row 'project-id #f)
     (durable-runtime-store-ref contract-row 'root-session-id #f)
     (durable-runtime-store-ref contract-row 'session-id #f)
     (and spec (cadr spec))
     (and spec (caddr spec))
     target-ref
     payload-summary
     causal-refs
     watermark
     negotiation-row
     (null? diagnostics)
     diagnostics
     metadata
     (durable-runtime-store-ref negotiation-row
                                'runtime-owner
                                "marlin-agent-core")
     #t
     #f)))

;; : (forall (k v) (-> PooDurableRuntimeStoreNegotiationReceipt [(Pair k v)] [PooDurableRuntimeStoreOperationReceipt]))
;; : (-> PooDurableRuntimeStoreNegotiationReceipt [Alist] [PooDurableRuntimeStoreOperationReceipt])
(def (agentic-ai-lab-durable-runtime-store-operation-receipts negotiation
                                                         . maybe-options)
  (let ((options (if (null? maybe-options) '() (car maybe-options))))
    (map (lambda (spec)
           (agentic-ai-lab-durable-runtime-store-operation
            (car spec)
            (car spec)
            negotiation
            (durable-runtime-store-ref
             options
             'payload-summary
             (list (cons 'operation-kind (car spec))))
            options))
         +agentic-ai-lab-durable-runtime-store-operation-specs+)))

;; : (-> PooDurableRuntimeStoreOperationReceipt Alist)
(defpoo-final-projection
  agentic-ai-lab-durable-runtime-store-operation-receipt->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-runtime-store-operation-receipt-diagnostics
               receipt))))
  (fields ((kind +agentic-ai-lab-durable-runtime-store-operation-receipt-kind+)
           (schema +agentic-ai-lab-durable-runtime-store-operation-receipt-schema+)
           (operation-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-operation-id
             receipt))
           (operation-kind
            (agentic-ai-lab-durable-runtime-store-operation-receipt-operation-kind
             receipt))
           (store-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-store-id receipt))
           (backend-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-backend-id
             receipt))
           (project-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-project-id
             receipt))
           (root-session-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-root-session-id
             receipt))
           (session-id
            (agentic-ai-lab-durable-runtime-store-operation-receipt-session-id
             receipt))
           (ledger-kind
            (agentic-ai-lab-durable-runtime-store-operation-receipt-ledger-kind
             receipt))
           (capability-flag
            (agentic-ai-lab-durable-runtime-store-operation-receipt-capability-flag
             receipt))
           (target-ref
            (agentic-ai-lab-durable-runtime-store-operation-receipt-target-ref
             receipt))
           (payload-summary
            (agentic-ai-lab-durable-runtime-store-operation-receipt-payload-summary
             receipt))
           (causal-refs
            (agentic-ai-lab-durable-runtime-store-operation-receipt-causal-refs
             receipt))
           (watermark
            (agentic-ai-lab-durable-runtime-store-operation-receipt-watermark
             receipt))
           (valid?
            (agentic-ai-lab-durable-runtime-store-operation-receipt-valid? receipt))
           (diagnostics diagnostics)
           (metadata
            (agentic-ai-lab-durable-runtime-store-operation-receipt-metadata receipt))
           (runtime-owner
            (agentic-ai-lab-durable-runtime-store-operation-receipt-runtime-owner
             receipt))
           (handoff-required
            (agentic-ai-lab-durable-runtime-store-operation-receipt-handoff-required
             receipt))
           (runtime-executed
            (agentic-ai-lab-durable-runtime-store-operation-receipt-runtime-executed
             receipt))
           (diagnostic-count (length diagnostics)))))

;; : (-> [Alist] Boolean)
(def (durable-runtime-store-operation-rows-valid? rows)
  (not (find (lambda (row)
               (not (eq? (durable-runtime-store-ref row 'valid? #f) #t)))
             rows)))

;; : (-> [PooDurableRuntimeStoreOperationReceipt] [Alist])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-runtime-store-operation-receipts->alists (receipts)
  (projector agentic-ai-lab-durable-runtime-store-operation-receipt->alist)
  (error-message
   "durable runtime store operation receipt serialization requires a list"))

;; : (-> PooDurableRuntimeStoreNegotiationReceipt [PooDurableRuntimeStoreOperationReceipt] Alist)
(def (agentic-ai-lab-durable-runtime-store-operations->marlin-handoff negotiation
                                                                  receipts
                                                                  . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (negotiation-row
          (if (agentic-ai-lab-durable-runtime-store-negotiation-receipt? negotiation)
            (agentic-ai-lab-durable-runtime-store-negotiation-receipt->alist
             negotiation)
            negotiation))
         (backend-row
          (durable-runtime-store-ref negotiation-row 'backend-row '()))
         (operation-rows
          (agentic-ai-lab-durable-runtime-store-operation-receipts->alists receipts))
         (operation
          (durable-runtime-store-ref options
                                     'manifest-operation
                                     'durable-runtime-store-operations))
         (command-executable
          (durable-runtime-store-ref backend-row
                                     'executable
                                     "marlin-runtime-store"))
         (command-arguments
          (durable-runtime-store-ref options
                                     'arguments
                                     '("durable-runtime-store" "operations")))
         (command-protocol
          (durable-runtime-store-ref backend-row
                                     'protocol
                                     'stdout-s-expression))
         (command-metadata
          (list (cons 'source 'agentic-ai-lab.durable.runtime-store.operation)
                (cons 'operation-count (length operation-rows))
                (cons 'runtime-executed #f)))
         (envelope
          (list (cons 'schema +runtime-request-schema+)
                (cons 'runtime 'marlin)
                (cons 'operation operation)
                (cons 'request-id
                      (list 'agentic-ai-lab.durable.runtime-store.operations
                            (durable-runtime-store-ref negotiation-row
                                                       'store-id
                                                       #f)))
                (cons 'artifact-handle #f)
                (cons 'request
                      (list (cons 'negotiation negotiation-row)
                            (cons 'operation-rows operation-rows)))
                (cons 'policy
                      (list (cons 'runtime-owner
                                  (durable-runtime-store-ref
                                   negotiation-row
                                   'runtime-owner
                                   "marlin-agent-core"))
                            (cons 'handoff-required #t)
                            (cons 'runtime-executed #f)))
                (cons 'plan-id #f)
                (cons 'node-id
                      (durable-runtime-store-ref negotiation-row
                                                 'store-id
                                                 #f))
                (cons 'frontier '())))
         (manifest
          (runtime-command-fields->manifest
           operation
           command-executable
           command-arguments
           command-protocol
           command-metadata
           envelope)))
    (list
     (cons 'kind 'agentic-ai-lab.durable.runtime-store.operation-handoff)
     (cons 'schema +agentic-ai-lab-durable-runtime-store-operation-handoff-schema+)
     (cons 'request-schema +runtime-request-schema+)
     (cons 'operation operation)
     (cons 'request-id (durable-runtime-store-ref manifest 'request-id #f))
     (cons 'runtime-owner
           (durable-runtime-store-ref negotiation-row
                                      'runtime-owner
                                      "marlin-agent-core"))
     (cons 'handoff-ready?
           (and (eq? (durable-runtime-store-ref negotiation-row
                                                'handoff-ready?
                                                #f)
                     #t)
                (durable-runtime-store-operation-rows-valid? operation-rows)))
     (cons 'operation-count (length operation-rows))
     (cons 'negotiation negotiation-row)
     (cons 'operation-rows operation-rows)
     (cons 'runtime-command-manifest manifest)
     (cons 'runtime-executed #f)
     (cons 'runtime-parses-scheme-source #f)
     (cons 'scheme-manufactures-runtime-handlers #f))))
