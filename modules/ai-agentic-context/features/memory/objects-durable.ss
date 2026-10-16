;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable memory job validation and receipts.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform
        :poo-flow/modules/ai-agentic-context/features/memory/objects-core
        :poo-flow/modules/ai-agentic-context/features/memory/objects-catalog
        :poo-flow/modules/ai-agentic-context/features/memory/objects-validation)

(export poo-flow-memory-durable-job-kind?
        poo-flow-memory-durable-job-state?
        poo-flow-memory-durable-job-diagnostic
        poo-flow-memory-durable-job-diagnostic-prepend
        poo-flow-memory-required-symbol-diagnostics/tail
        poo-flow-memory-required-symbol-diagnostics
        poo-flow-memory-durable-policy-ref-from-options
        poo-flow-memory-durable-store-diagnostics
        poo-flow-memory-durable-intent-diagnostics
        poo-flow-memory-durable-job-diagnostics
        poo-flow-memory-durable-job-receipt
        make-poo-flow-memory-durable-job-receipt
        poo-flow-memory-durable-job-receipt?
        poo-flow-memory-durable-job-receipt-job-id
        poo-flow-memory-durable-job-receipt-job-kind
        poo-flow-memory-durable-job-receipt-job-state
        poo-flow-memory-durable-job-receipt-project-id
        poo-flow-memory-durable-job-receipt-root-session-id
        poo-flow-memory-durable-job-receipt-session-id
        poo-flow-memory-durable-job-receipt-agent-id
        poo-flow-memory-durable-job-receipt-store-ref
        poo-flow-memory-durable-job-receipt-durable-policy-ref
        poo-flow-memory-durable-job-receipt-job-store-ref
        poo-flow-memory-durable-job-receipt-checkpoint-store-ref
        poo-flow-memory-durable-job-receipt-source-ref
        poo-flow-memory-durable-job-receipt-source-watermark
        poo-flow-memory-durable-job-receipt-target-watermark
        poo-flow-memory-durable-job-receipt-stale-source?
        poo-flow-memory-durable-job-receipt-retry-policy
        poo-flow-memory-durable-job-receipt-retention-policy
        poo-flow-memory-durable-job-receipt-usage-counter
        poo-flow-memory-durable-job-receipt-scope
        poo-flow-memory-durable-job-receipt-recall
        poo-flow-memory-durable-job-receipt-commit-policy
        poo-flow-memory-durable-job-receipt-valid?
        poo-flow-memory-durable-job-receipt-diagnostics
        poo-flow-memory-durable-job-receipt-metadata
        poo-flow-memory-durable-job-receipt-from-intent
        poo-flow-memory-recall-job-receipt
        poo-flow-memory-write-job-receipt
        poo-flow-memory-consolidation-job-receipt
        poo-flow-memory-stale-source-job-receipt
        poo-flow-memory-repair-job-receipt
        poo-flow-memory-durable-job-receipt->alist
        poo-flow-memory-durable-job-receipts->alists)

(def (poo-flow-memory-durable-job-kind? value)
  (and (symbol? value)
       (if (member value +poo-flow-memory-durable-job-kinds+) #t #f)))

;; : (-> Symbol Boolean)
(def (poo-flow-memory-durable-job-state? value)
  (and (symbol? value)
       (if (member value +poo-flow-memory-durable-job-states+) #t #f)))

;; : (-> Symbol Symbol Value Alist)
(def (poo-flow-memory-durable-job-diagnostic code slot value)
  (list (cons 'kind 'poo-flow.memory-core.durable-job.diagnostic)
        (cons 'schema 'poo-flow.modules.memory-core.durable-job.diagnostic.v1)
        (cons 'code code)
        (cons 'phase 'memory-durable-job)
        (cons 'slot slot)
        (cons 'value value)
        (cons 'severity 'error)
        (cons 'recoverable? #t)
        (cons 'runtime-executed #f)))

(def (poo-flow-memory-durable-job-diagnostic-prepend tail ok? code slot value)
  (if ok?
    tail
    (cons (poo-flow-memory-durable-job-diagnostic code slot value)
          tail)))

;; : (-> Symbol Symbol Value [Alist])
(def (poo-flow-memory-required-symbol-diagnostics/tail code slot value tail)
  (if (symbol? value)
    tail
    (cons (poo-flow-memory-durable-job-diagnostic code slot value)
          tail)))

;; : (-> Symbol Symbol Value [Alist])
(def (poo-flow-memory-required-symbol-diagnostics code slot value)
  (poo-flow-memory-required-symbol-diagnostics/tail code slot value '()))

;; : (-> Symbol [Alist] MaybeSymbol)
(def (poo-flow-memory-durable-policy-ref-from-options options)
  (let (durable-policy (poo-flow-memory-option options 'durable-policy #f))
    (cond
     ((poo-flow-durable-policy? durable-policy)
      (poo-flow-durable-policy-receipt-policy-id
       (poo-flow-durable-policy->receipt durable-policy)))
     (else
      (poo-flow-memory-option options 'durable-policy-ref #f)))))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist])
(def (poo-flow-memory-durable-store-diagnostics spec intent)
  (poo-flow-memory-store-intent-diagnostics/tail
   spec
   intent
   (if (poo-flow-memory-slot spec 'durable? #f)
     '()
     (list (poo-flow-memory-diagnostic 'memory-store-not-durable
                                       intent)))))

;; : (-> PooMemoryCatalog PooSessionMemoryIntent [Alist])
(def (poo-flow-memory-durable-intent-diagnostics catalog intent)
  (let (spec
        (poo-flow-memory-catalog-find
         catalog
         (poo-flow-session-memory-intent-store-ref intent)))
    (if spec
      (poo-flow-memory-durable-store-diagnostics spec intent)
      (list (poo-flow-memory-diagnostic 'memory-store-not-in-catalog
                                        intent)))))

;;; Boundary: durable job diagnostics validate session memory intent and catalog
;;; evidence before any durable store operation is scheduled.
;; : (-> Symbol Symbol Symbol Symbol Symbol MaybeSymbol PooMemoryCatalog PooSessionMemoryIntent Alist [Alist])
(def (poo-flow-memory-durable-job-diagnostics job-kind
                                              job-state
                                              project-id
                                              root-session-id
                                              session-id
                                              agent-id
                                              catalog
                                              intent
                                              options)
  (let ((durable-policy-ref
         (poo-flow-memory-durable-policy-ref-from-options options))
        (job-store-ref
         (poo-flow-memory-option options 'job-store-ref 'runtime/job-store))
        (checkpoint-store-ref
         (poo-flow-memory-option options
                                 'checkpoint-store-ref
                                 'runtime/checkpoint-store))
        (usage-counter
         (poo-flow-memory-option options 'usage-counter 0)))
    (let* ((intent-tail
            (poo-flow-memory-durable-intent-diagnostics catalog intent))
           (usage-tail
            (poo-flow-memory-durable-job-diagnostic-prepend
             intent-tail
             (and (integer? usage-counter) (>= usage-counter 0))
             'invalid-usage-counter
             'usage-counter
             usage-counter))
           (checkpoint-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-checkpoint-store-ref
             'checkpoint-store-ref
             checkpoint-store-ref
             usage-tail))
           (job-store-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-job-store-ref
             'job-store-ref
             job-store-ref
             checkpoint-tail))
           (durable-policy-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-durable-policy-ref
             'durable-policy-ref
             durable-policy-ref
             job-store-tail))
           (agent-tail
            (poo-flow-memory-durable-job-diagnostic-prepend
             durable-policy-tail
             (or (symbol? agent-id) (not agent-id))
             'invalid-agent-id
             'agent-id
             agent-id))
           (session-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-session-id
             'session-id
             session-id
             agent-tail))
           (root-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-root-session-id
             'root-session-id
             root-session-id
             session-tail))
           (project-tail
            (poo-flow-memory-required-symbol-diagnostics/tail
             'missing-project-id
             'project-id
             project-id
             root-tail))
           (job-state-tail
            (poo-flow-memory-durable-job-diagnostic-prepend
             project-tail
             (poo-flow-memory-durable-job-state? job-state)
             'unsupported-memory-job-state
             'job-state
             job-state)))
      (poo-flow-memory-durable-job-diagnostic-prepend
       job-state-tail
       (poo-flow-memory-durable-job-kind? job-kind)
       'unsupported-memory-job-kind
       'job-kind
       job-kind))))

;; : PooMemoryDurableJobReceipt
(defstruct poo-flow-memory-durable-job-receipt
  (job-id
   job-kind
   job-state
   project-id
   root-session-id
   session-id
   agent-id
   store-ref
   durable-policy-ref
   job-store-ref
   checkpoint-store-ref
   source-ref
   source-watermark
   target-watermark
   stale-source?
   retry-policy
   retention-policy
   usage-counter
   scope
   recall
   commit-policy
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   runtime-executed)
  transparent: #t)

;;; Boundary: durable job receipts materialize memory checkpoint intent as a
;;; policy-visible value without executing provider storage.
;; : (-> Symbol Symbol Symbol Symbol Symbol MaybeSymbol PooMemoryCatalog PooSessionMemoryIntent [Alist] PooMemoryDurableJobReceipt)
(def (poo-flow-memory-durable-job-receipt-from-intent job-id
                                                       job-kind
                                                       project-id
                                                       root-session-id
                                                       session-id
                                                       agent-id
                                                       catalog
                                                       intent
                                                       . maybe-options)
  (poo-flow-session-require "memory durable job id must be a symbol"
                            (symbol? job-id)
                            job-id)
  (poo-flow-session-require "memory durable job requires a catalog"
                            (poo-flow-memory-catalog? catalog)
                            catalog)
  (poo-flow-session-require "memory durable job requires a memory intent"
                            (poo-flow-session-memory-intent? intent)
                            intent)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (job-state (poo-flow-memory-option options 'job-state 'planned))
         (durable-policy-ref
          (poo-flow-memory-durable-policy-ref-from-options options))
         (job-store-ref
          (poo-flow-memory-option options 'job-store-ref 'runtime/job-store))
         (checkpoint-store-ref
          (poo-flow-memory-option options
                                  'checkpoint-store-ref
                                  'runtime/checkpoint-store))
         (source-ref
          (poo-flow-memory-option
           options
           'source-ref
           (poo-flow-session-memory-intent-name intent)))
         (source-watermark
          (poo-flow-memory-option options 'source-watermark #f))
         (target-watermark
          (poo-flow-memory-option options 'target-watermark #f))
         (stale-source?
          (poo-flow-memory-option options 'stale-source? #f))
         (retry-policy
          (poo-flow-memory-option options 'retry-policy 'retry/bounded))
         (retention-policy
          (poo-flow-memory-option options 'retention-policy 'retain/project))
         (usage-counter
          (poo-flow-memory-option options 'usage-counter 0))
         (metadata
          (poo-flow-memory-option options 'metadata '()))
         (diagnostics
          (poo-flow-memory-durable-job-diagnostics
           job-kind
           job-state
           project-id
           root-session-id
           session-id
           agent-id
           catalog
           intent
           options)))
    (make-poo-flow-memory-durable-job-receipt
     job-id
     job-kind
     job-state
     project-id
     root-session-id
     session-id
     agent-id
     (poo-flow-session-memory-intent-store-ref intent)
     durable-policy-ref
     job-store-ref
     checkpoint-store-ref
     source-ref
     source-watermark
     target-watermark
     stale-source?
     retry-policy
     retention-policy
     usage-counter
     (poo-flow-session-memory-intent-scope intent)
     (poo-flow-session-memory-intent-recall intent)
     (poo-flow-session-memory-intent-commit-policy intent)
     (null? diagnostics)
     diagnostics
     metadata
     "marlin-agent-core"
     #t
     #f)))

;; : (-> Symbol Symbol Symbol Symbol MaybeSymbol PooMemoryCatalog PooSessionMemoryIntent [Alist] PooMemoryDurableJobReceipt)
(def (poo-flow-memory-recall-job-receipt job-id
                                         project-id
                                         root-session-id
                                         session-id
                                         agent-id
                                         catalog
                                         intent
                                         . maybe-options)
  (apply poo-flow-memory-durable-job-receipt-from-intent
         job-id
         'recall
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (poo-flow-memory-write-job-receipt job-id
                                        project-id
                                        root-session-id
                                        session-id
                                        agent-id
                                        catalog
                                        intent
                                        . maybe-options)
  (apply poo-flow-memory-durable-job-receipt-from-intent
         job-id
         'write
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (poo-flow-memory-consolidation-job-receipt job-id
                                                project-id
                                                root-session-id
                                                session-id
                                                agent-id
                                                catalog
                                                intent
                                                . maybe-options)
  (apply poo-flow-memory-durable-job-receipt-from-intent
         job-id
         'consolidation
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (poo-flow-memory-stale-source-job-receipt job-id
                                               project-id
                                               root-session-id
                                               session-id
                                               agent-id
                                               catalog
                                               intent
                                               . maybe-options)
  (apply poo-flow-memory-durable-job-receipt-from-intent
         job-id
         'stale-source
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (poo-flow-memory-repair-job-receipt job-id
                                         project-id
                                         root-session-id
                                         session-id
                                         agent-id
                                         catalog
                                         intent
                                         . maybe-options)
  (apply poo-flow-memory-durable-job-receipt-from-intent
         job-id
         'repair
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

;; : (-> PooMemoryDurableJobReceipt Alist)
(defpoo-final-projection
  poo-flow-memory-durable-job-receipt->alist (receipt)
  (bindings ((checked-receipt
              (poo-flow-session-require
               "memory durable job projection requires a durable job receipt"
               (poo-flow-memory-durable-job-receipt? receipt)
               receipt))
             (diagnostics
              (poo-flow-memory-durable-job-receipt-diagnostics
               checked-receipt))))
  (fields ((kind +poo-flow-ai-agentic-context-memory-durable-job-receipt-kind+)
           (schema 'poo-flow.modules.memory-core.durable-job-receipt.v1)
           (job-id
            (poo-flow-memory-durable-job-receipt-job-id checked-receipt))
           (job-kind
            (poo-flow-memory-durable-job-receipt-job-kind checked-receipt))
           (job-state
            (poo-flow-memory-durable-job-receipt-job-state checked-receipt))
           (project-id
            (poo-flow-memory-durable-job-receipt-project-id checked-receipt))
           (root-session-id
            (poo-flow-memory-durable-job-receipt-root-session-id
             checked-receipt))
           (session-id
            (poo-flow-memory-durable-job-receipt-session-id checked-receipt))
           (agent-id
            (poo-flow-memory-durable-job-receipt-agent-id checked-receipt))
           (store-ref
            (poo-flow-memory-durable-job-receipt-store-ref checked-receipt))
           (durable-policy-ref
            (poo-flow-memory-durable-job-receipt-durable-policy-ref
             checked-receipt))
           (job-store-ref
            (poo-flow-memory-durable-job-receipt-job-store-ref
             checked-receipt))
           (checkpoint-store-ref
            (poo-flow-memory-durable-job-receipt-checkpoint-store-ref
             checked-receipt))
           (source-ref
            (poo-flow-memory-durable-job-receipt-source-ref checked-receipt))
           (source-watermark
            (poo-flow-memory-durable-job-receipt-source-watermark
             checked-receipt))
           (target-watermark
            (poo-flow-memory-durable-job-receipt-target-watermark
             checked-receipt))
           (stale-source?
            (poo-flow-memory-durable-job-receipt-stale-source?
             checked-receipt))
           (retry-policy
            (poo-flow-memory-durable-job-receipt-retry-policy
             checked-receipt))
           (retention-policy
            (poo-flow-memory-durable-job-receipt-retention-policy
             checked-receipt))
           (usage-counter
            (poo-flow-memory-durable-job-receipt-usage-counter
             checked-receipt))
           (scope
            (poo-flow-memory-durable-job-receipt-scope checked-receipt))
           (recall
            (poo-flow-memory-durable-job-receipt-recall checked-receipt))
           (commit-policy
            (poo-flow-memory-durable-job-receipt-commit-policy
             checked-receipt))
           (valid?
            (poo-flow-memory-durable-job-receipt-valid? checked-receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (poo-flow-memory-durable-job-receipt-metadata checked-receipt))
           (runtime-owner
            (poo-flow-memory-durable-job-receipt-runtime-owner
             checked-receipt))
           (handoff-required
            (poo-flow-memory-durable-job-receipt-handoff-required
             checked-receipt))
           (runtime-executed
            (poo-flow-memory-durable-job-receipt-runtime-executed
             checked-receipt)))))

;; : (-> [PooMemoryDurableJobReceipt] [Alist])
(defpoo-final-projection-batch
  poo-flow-memory-durable-job-receipts->alists (receipts)
  (projector poo-flow-memory-durable-job-receipt->alist)
  (error-message "memory durable job receipt serialization requires a list"))
