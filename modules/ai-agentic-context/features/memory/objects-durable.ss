;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable memory job validation and receipts.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-catalog
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-validation)

(export agentic-ai-lab-memory-durable-job-kind?
        agentic-ai-lab-memory-durable-job-state?
        agentic-ai-lab-memory-durable-job-diagnostic
        agentic-ai-lab-memory-durable-job-diagnostic-prepend
        agentic-ai-lab-memory-required-symbol-diagnostics/tail
        agentic-ai-lab-memory-required-symbol-diagnostics
        agentic-ai-lab-memory-durable-policy-ref-from-options
        agentic-ai-lab-memory-durable-store-diagnostics
        agentic-ai-lab-memory-durable-intent-diagnostics
        agentic-ai-lab-memory-durable-job-diagnostics
        agentic-ai-lab-memory-durable-job-receipt
        make-agentic-ai-lab-memory-durable-job-receipt
        agentic-ai-lab-memory-durable-job-receipt?
        agentic-ai-lab-memory-durable-job-receipt-job-id
        agentic-ai-lab-memory-durable-job-receipt-job-kind
        agentic-ai-lab-memory-durable-job-receipt-job-state
        agentic-ai-lab-memory-durable-job-receipt-project-id
        agentic-ai-lab-memory-durable-job-receipt-root-session-id
        agentic-ai-lab-memory-durable-job-receipt-session-id
        agentic-ai-lab-memory-durable-job-receipt-agent-id
        agentic-ai-lab-memory-durable-job-receipt-store-ref
        agentic-ai-lab-memory-durable-job-receipt-durable-policy-ref
        agentic-ai-lab-memory-durable-job-receipt-job-store-ref
        agentic-ai-lab-memory-durable-job-receipt-checkpoint-store-ref
        agentic-ai-lab-memory-durable-job-receipt-source-ref
        agentic-ai-lab-memory-durable-job-receipt-source-watermark
        agentic-ai-lab-memory-durable-job-receipt-target-watermark
        agentic-ai-lab-memory-durable-job-receipt-stale-source?
        agentic-ai-lab-memory-durable-job-receipt-retry-policy
        agentic-ai-lab-memory-durable-job-receipt-retention-policy
        agentic-ai-lab-memory-durable-job-receipt-usage-counter
        agentic-ai-lab-memory-durable-job-receipt-scope
        agentic-ai-lab-memory-durable-job-receipt-recall
        agentic-ai-lab-memory-durable-job-receipt-commit-policy
        agentic-ai-lab-memory-durable-job-receipt-valid?
        agentic-ai-lab-memory-durable-job-receipt-diagnostics
        agentic-ai-lab-memory-durable-job-receipt-metadata
        agentic-ai-lab-memory-durable-job-receipt-from-intent
        agentic-ai-lab-memory-recall-job-receipt
        agentic-ai-lab-memory-write-job-receipt
        agentic-ai-lab-memory-consolidation-job-receipt
        agentic-ai-lab-memory-stale-source-job-receipt
        agentic-ai-lab-memory-repair-job-receipt
        agentic-ai-lab-memory-durable-job-receipt->alist
        agentic-ai-lab-memory-durable-job-receipts->alists)

(def (agentic-ai-lab-memory-durable-job-kind? value)
  (and (symbol? value)
       (if (member value +agentic-ai-lab-memory-durable-job-kinds+) #t #f)))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-memory-durable-job-state? value)
  (and (symbol? value)
       (if (member value +agentic-ai-lab-memory-durable-job-states+) #t #f)))

;; : (-> Symbol Symbol Value Alist)
(def (agentic-ai-lab-memory-durable-job-diagnostic code slot value)
  (list (cons 'kind 'agentic-ai-lab.memory-core.durable-job.diagnostic)
        (cons 'schema 'agentic-ai-lab.modules.memory-core.durable-job.diagnostic.v1)
        (cons 'code code)
        (cons 'phase 'memory-durable-job)
        (cons 'slot slot)
        (cons 'value value)
        (cons 'severity 'error)
        (cons 'recoverable? #t)
        (cons 'runtime-executed #f)))

(def (agentic-ai-lab-memory-durable-job-diagnostic-prepend tail ok? code slot value)
  (if ok?
    tail
    (cons (agentic-ai-lab-memory-durable-job-diagnostic code slot value)
          tail)))

;; : (-> Symbol Symbol Value [Alist])
(def (agentic-ai-lab-memory-required-symbol-diagnostics/tail code slot value tail)
  (if (symbol? value)
    tail
    (cons (agentic-ai-lab-memory-durable-job-diagnostic code slot value)
          tail)))

;; : (-> Symbol Symbol Value [Alist])
(def (agentic-ai-lab-memory-required-symbol-diagnostics code slot value)
  (agentic-ai-lab-memory-required-symbol-diagnostics/tail code slot value '()))

;; : (-> Symbol [Alist] MaybeSymbol)
(def (agentic-ai-lab-memory-durable-policy-ref-from-options options)
  (let (durable-policy (agentic-ai-lab-memory-option options 'durable-policy #f))
    (cond
     ((agentic-ai-lab-durable-policy? durable-policy)
      (agentic-ai-lab-durable-policy-receipt-policy-id
       (agentic-ai-lab-durable-policy->receipt durable-policy)))
     (else
      (agentic-ai-lab-memory-option options 'durable-policy-ref #f)))))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist])
(def (agentic-ai-lab-memory-durable-store-diagnostics spec intent)
  (agentic-ai-lab-memory-store-intent-diagnostics/tail
   spec
   intent
   (if (agentic-ai-lab-memory-slot spec 'durable? #f)
     '()
     (list (agentic-ai-lab-memory-diagnostic 'memory-store-not-durable
                                       intent)))))

;; : (-> PooMemoryCatalog PooSessionMemoryIntent [Alist])
(def (agentic-ai-lab-memory-durable-intent-diagnostics catalog intent)
  (let (spec
        (agentic-ai-lab-memory-catalog-find
         catalog
         (agentic-ai-lab-session-memory-intent-store-ref intent)))
    (if spec
      (agentic-ai-lab-memory-durable-store-diagnostics spec intent)
      (list (agentic-ai-lab-memory-diagnostic 'memory-store-not-in-catalog
                                        intent)))))

;;; Boundary: durable job diagnostics validate session memory intent and catalog
;;; evidence before any durable store operation is scheduled.
;; : (-> Symbol Symbol Symbol Symbol Symbol MaybeSymbol PooMemoryCatalog PooSessionMemoryIntent Alist [Alist])
(def (agentic-ai-lab-memory-durable-job-diagnostics job-kind
                                              job-state
                                              project-id
                                              root-session-id
                                              session-id
                                              agent-id
                                              catalog
                                              intent
                                              options)
  (let ((durable-policy-ref
         (agentic-ai-lab-memory-durable-policy-ref-from-options options))
        (job-store-ref
         (agentic-ai-lab-memory-option options 'job-store-ref 'runtime/job-store))
        (checkpoint-store-ref
         (agentic-ai-lab-memory-option options
                                 'checkpoint-store-ref
                                 'runtime/checkpoint-store))
        (usage-counter
         (agentic-ai-lab-memory-option options 'usage-counter 0)))
    (let* ((intent-tail
            (agentic-ai-lab-memory-durable-intent-diagnostics catalog intent))
           (usage-tail
            (agentic-ai-lab-memory-durable-job-diagnostic-prepend
             intent-tail
             (and (integer? usage-counter) (>= usage-counter 0))
             'invalid-usage-counter
             'usage-counter
             usage-counter))
           (checkpoint-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-checkpoint-store-ref
             'checkpoint-store-ref
             checkpoint-store-ref
             usage-tail))
           (job-store-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-job-store-ref
             'job-store-ref
             job-store-ref
             checkpoint-tail))
           (durable-policy-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-durable-policy-ref
             'durable-policy-ref
             durable-policy-ref
             job-store-tail))
           (agent-tail
            (agentic-ai-lab-memory-durable-job-diagnostic-prepend
             durable-policy-tail
             (or (symbol? agent-id) (not agent-id))
             'invalid-agent-id
             'agent-id
             agent-id))
           (session-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-session-id
             'session-id
             session-id
             agent-tail))
           (root-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-root-session-id
             'root-session-id
             root-session-id
             session-tail))
           (project-tail
            (agentic-ai-lab-memory-required-symbol-diagnostics/tail
             'missing-project-id
             'project-id
             project-id
             root-tail))
           (job-state-tail
            (agentic-ai-lab-memory-durable-job-diagnostic-prepend
             project-tail
             (agentic-ai-lab-memory-durable-job-state? job-state)
             'unsupported-memory-job-state
             'job-state
             job-state)))
      (agentic-ai-lab-memory-durable-job-diagnostic-prepend
       job-state-tail
       (agentic-ai-lab-memory-durable-job-kind? job-kind)
       'unsupported-memory-job-kind
       'job-kind
       job-kind))))

;; : PooMemoryDurableJobReceipt
(defstruct agentic-ai-lab-memory-durable-job-receipt
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
(def (agentic-ai-lab-memory-durable-job-receipt-from-intent job-id
                                                       job-kind
                                                       project-id
                                                       root-session-id
                                                       session-id
                                                       agent-id
                                                       catalog
                                                       intent
                                                       . maybe-options)
  (agentic-ai-lab-session-require "memory durable job id must be a symbol"
                            (symbol? job-id)
                            job-id)
  (agentic-ai-lab-session-require "memory durable job requires a catalog"
                            (agentic-ai-lab-memory-catalog? catalog)
                            catalog)
  (agentic-ai-lab-session-require "memory durable job requires a memory intent"
                            (agentic-ai-lab-session-memory-intent? intent)
                            intent)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (job-state (agentic-ai-lab-memory-option options 'job-state 'planned))
         (durable-policy-ref
          (agentic-ai-lab-memory-durable-policy-ref-from-options options))
         (job-store-ref
          (agentic-ai-lab-memory-option options 'job-store-ref 'runtime/job-store))
         (checkpoint-store-ref
          (agentic-ai-lab-memory-option options
                                  'checkpoint-store-ref
                                  'runtime/checkpoint-store))
         (source-ref
          (agentic-ai-lab-memory-option
           options
           'source-ref
           (agentic-ai-lab-session-memory-intent-name intent)))
         (source-watermark
          (agentic-ai-lab-memory-option options 'source-watermark #f))
         (target-watermark
          (agentic-ai-lab-memory-option options 'target-watermark #f))
         (stale-source?
          (agentic-ai-lab-memory-option options 'stale-source? #f))
         (retry-policy
          (agentic-ai-lab-memory-option options 'retry-policy 'retry/bounded))
         (retention-policy
          (agentic-ai-lab-memory-option options 'retention-policy 'retain/project))
         (usage-counter
          (agentic-ai-lab-memory-option options 'usage-counter 0))
         (metadata
          (agentic-ai-lab-memory-option options 'metadata '()))
         (diagnostics
          (agentic-ai-lab-memory-durable-job-diagnostics
           job-kind
           job-state
           project-id
           root-session-id
           session-id
           agent-id
           catalog
           intent
           options)))
    (make-agentic-ai-lab-memory-durable-job-receipt
     job-id
     job-kind
     job-state
     project-id
     root-session-id
     session-id
     agent-id
     (agentic-ai-lab-session-memory-intent-store-ref intent)
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
     (agentic-ai-lab-session-memory-intent-scope intent)
     (agentic-ai-lab-session-memory-intent-recall intent)
     (agentic-ai-lab-session-memory-intent-commit-policy intent)
     (null? diagnostics)
     diagnostics
     metadata
     "marlin-agent-core"
     #t
     #f)))

;; : (-> Symbol Symbol Symbol Symbol MaybeSymbol PooMemoryCatalog PooSessionMemoryIntent [Alist] PooMemoryDurableJobReceipt)
(def (agentic-ai-lab-memory-recall-job-receipt job-id
                                         project-id
                                         root-session-id
                                         session-id
                                         agent-id
                                         catalog
                                         intent
                                         . maybe-options)
  (apply agentic-ai-lab-memory-durable-job-receipt-from-intent
         job-id
         'recall
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (agentic-ai-lab-memory-write-job-receipt job-id
                                        project-id
                                        root-session-id
                                        session-id
                                        agent-id
                                        catalog
                                        intent
                                        . maybe-options)
  (apply agentic-ai-lab-memory-durable-job-receipt-from-intent
         job-id
         'write
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (agentic-ai-lab-memory-consolidation-job-receipt job-id
                                                project-id
                                                root-session-id
                                                session-id
                                                agent-id
                                                catalog
                                                intent
                                                . maybe-options)
  (apply agentic-ai-lab-memory-durable-job-receipt-from-intent
         job-id
         'consolidation
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (agentic-ai-lab-memory-stale-source-job-receipt job-id
                                               project-id
                                               root-session-id
                                               session-id
                                               agent-id
                                               catalog
                                               intent
                                               . maybe-options)
  (apply agentic-ai-lab-memory-durable-job-receipt-from-intent
         job-id
         'stale-source
         project-id
         root-session-id
         session-id
         agent-id
         catalog
         intent
         maybe-options))

(def (agentic-ai-lab-memory-repair-job-receipt job-id
                                         project-id
                                         root-session-id
                                         session-id
                                         agent-id
                                         catalog
                                         intent
                                         . maybe-options)
  (apply agentic-ai-lab-memory-durable-job-receipt-from-intent
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
  agentic-ai-lab-memory-durable-job-receipt->alist (receipt)
  (bindings ((checked-receipt
              (agentic-ai-lab-session-require
               "memory durable job projection requires a durable job receipt"
               (agentic-ai-lab-memory-durable-job-receipt? receipt)
               receipt))
             (diagnostics
              (agentic-ai-lab-memory-durable-job-receipt-diagnostics
               checked-receipt))))
  (fields ((kind +agentic-ai-lab-ai-agentic-context-memory-durable-job-receipt-kind+)
           (schema 'agentic-ai-lab.modules.memory-core.durable-job-receipt.v1)
           (job-id
            (agentic-ai-lab-memory-durable-job-receipt-job-id checked-receipt))
           (job-kind
            (agentic-ai-lab-memory-durable-job-receipt-job-kind checked-receipt))
           (job-state
            (agentic-ai-lab-memory-durable-job-receipt-job-state checked-receipt))
           (project-id
            (agentic-ai-lab-memory-durable-job-receipt-project-id checked-receipt))
           (root-session-id
            (agentic-ai-lab-memory-durable-job-receipt-root-session-id
             checked-receipt))
           (session-id
            (agentic-ai-lab-memory-durable-job-receipt-session-id checked-receipt))
           (agent-id
            (agentic-ai-lab-memory-durable-job-receipt-agent-id checked-receipt))
           (store-ref
            (agentic-ai-lab-memory-durable-job-receipt-store-ref checked-receipt))
           (durable-policy-ref
            (agentic-ai-lab-memory-durable-job-receipt-durable-policy-ref
             checked-receipt))
           (job-store-ref
            (agentic-ai-lab-memory-durable-job-receipt-job-store-ref
             checked-receipt))
           (checkpoint-store-ref
            (agentic-ai-lab-memory-durable-job-receipt-checkpoint-store-ref
             checked-receipt))
           (source-ref
            (agentic-ai-lab-memory-durable-job-receipt-source-ref checked-receipt))
           (source-watermark
            (agentic-ai-lab-memory-durable-job-receipt-source-watermark
             checked-receipt))
           (target-watermark
            (agentic-ai-lab-memory-durable-job-receipt-target-watermark
             checked-receipt))
           (stale-source?
            (agentic-ai-lab-memory-durable-job-receipt-stale-source?
             checked-receipt))
           (retry-policy
            (agentic-ai-lab-memory-durable-job-receipt-retry-policy
             checked-receipt))
           (retention-policy
            (agentic-ai-lab-memory-durable-job-receipt-retention-policy
             checked-receipt))
           (usage-counter
            (agentic-ai-lab-memory-durable-job-receipt-usage-counter
             checked-receipt))
           (scope
            (agentic-ai-lab-memory-durable-job-receipt-scope checked-receipt))
           (recall
            (agentic-ai-lab-memory-durable-job-receipt-recall checked-receipt))
           (commit-policy
            (agentic-ai-lab-memory-durable-job-receipt-commit-policy
             checked-receipt))
           (valid?
            (agentic-ai-lab-memory-durable-job-receipt-valid? checked-receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (agentic-ai-lab-memory-durable-job-receipt-metadata checked-receipt))
           (runtime-owner
            (agentic-ai-lab-memory-durable-job-receipt-runtime-owner
             checked-receipt))
           (handoff-required
            (agentic-ai-lab-memory-durable-job-receipt-handoff-required
             checked-receipt))
           (runtime-executed
            (agentic-ai-lab-memory-durable-job-receipt-runtime-executed
             checked-receipt)))))

;; : (-> [PooMemoryDurableJobReceipt] [Alist])
(defpoo-final-projection-batch
  agentic-ai-lab-memory-durable-job-receipts->alists (receipts)
  (projector agentic-ai-lab-memory-durable-job-receipt->alist)
  (error-message "memory durable job receipt serialization requires a list"))
