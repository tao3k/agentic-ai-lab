;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session transform objects.
;;; Invariant: transforms derive session values and handoff receipts; they never
;;; execute providers, tools, memory stores, selectors, or sandbox runtimes.

(import (only-in :gerbil/core fx+)
        (only-in :clan/poo/object .o .ref object? object<-alist)
        :agentic-ai-lab/modules/session/objects)


(export agentic-ai-lab-session-transform
        agentic-ai-lab-session-transform?
        agentic-ai-lab-session-transform-name
        agentic-ai-lab-session-transform-intent
        agentic-ai-lab-session-transform-description
        agentic-ai-lab-session-transform-capabilities
        agentic-ai-lab-session-transform-runtime-owner
        agentic-ai-lab-session-transform-metadata
        agentic-ai-lab-session-transform-memory-intents
        agentic-ai-lab-session-memory-intent
        agentic-ai-lab-session-memory-intent?
        agentic-ai-lab-session-memory-intent-name
        agentic-ai-lab-session-memory-intent-store-ref
        agentic-ai-lab-session-memory-intent-scope
        agentic-ai-lab-session-memory-intent-recall
        agentic-ai-lab-session-memory-intent-commit-policy
        agentic-ai-lab-session-memory-intent-runtime-owner
        agentic-ai-lab-session-memory-intent-metadata
        agentic-ai-lab-session-transform-apply
        agentic-ai-lab-session-transform-receipt?
        agentic-ai-lab-session-transform-receipt-derived-session
        agentic-ai-lab-session-transform-receipt-handoff-intent
        agentic-ai-lab-session-transform-receipt-memory-receipts
        agentic-ai-lab-session-memory-receipt-ref
        agentic-ai-lab-session-memory-receipt?
        agentic-ai-lab-session-memory-receipt-name)

(import :agentic-ai-lab/modules/session/transform-support/memory-intent)

(defstruct agentic-ai-lab-session-memory-receipt-record
  (kind
   schema
   intent-name
   store-ref
   scope
   recall
   commit-policy
   transform-name
   source-session-id
   derived-session-id
   runtime-owner
   handoff-required
   descriptor-realized?
   runtime-executed
   metadata)
  transparent: #t)

;; : (-> PooSessionMemoryReceipt Symbol Datum)
(def (agentic-ai-lab-session-memory-receipt-ref receipt key)
  (if (agentic-ai-lab-session-memory-receipt-record? receipt)
    (case key
      ((kind) (agentic-ai-lab-session-memory-receipt-record-kind receipt))
      ((schema) (agentic-ai-lab-session-memory-receipt-record-schema receipt))
      ((intent-name)
       (agentic-ai-lab-session-memory-receipt-record-intent-name receipt))
      ((store-ref) (agentic-ai-lab-session-memory-receipt-record-store-ref receipt))
      ((scope) (agentic-ai-lab-session-memory-receipt-record-scope receipt))
      ((recall) (agentic-ai-lab-session-memory-receipt-record-recall receipt))
      ((commit-policy)
       (agentic-ai-lab-session-memory-receipt-record-commit-policy receipt))
      ((transform-name)
       (agentic-ai-lab-session-memory-receipt-record-transform-name receipt))
      ((source-session-id)
       (agentic-ai-lab-session-memory-receipt-record-source-session-id receipt))
      ((derived-session-id)
       (agentic-ai-lab-session-memory-receipt-record-derived-session-id receipt))
      ((runtime-owner)
       (agentic-ai-lab-session-memory-receipt-record-runtime-owner receipt))
      ((handoff-required)
       (agentic-ai-lab-session-memory-receipt-record-handoff-required receipt))
      ((descriptor-realized?)
       (agentic-ai-lab-session-memory-receipt-record-descriptor-realized? receipt))
      ((runtime-executed)
       (agentic-ai-lab-session-memory-receipt-record-runtime-executed receipt))
      ((metadata) (agentic-ai-lab-session-memory-receipt-record-metadata receipt))
      (else #f))
    (.ref receipt key)))

;; : (-> SessionMemoryKeyCandidate Boolean)
;; | type SessionMemoryKeyCandidate = (U Symbol String)
(def (agentic-ai-lab-session-memory-key? value)
  (or (symbol? value) (string? value)))

;; : (-> Alist Alist Alist)
(def (agentic-ai-lab-session-transform-rows/tail rows tail)
  (foldr cons tail rows))

;;; Boundary: callers provide explicit field pairs and the runtime function
;;; prepends them to the existing transform tail in deterministic order.
;; : (-> Alist (List (Pair Symbol Object)) Alist)
(def (agentic-ai-lab-session-transform-field-rows/tail tail . rows)
  (agentic-ai-lab-session-transform-rows/tail rows tail))

;; : (-> Symbol Alist Alist)
(def (agentic-ai-lab-session-transform-declaration-metadata/tail declared-by tail)
  (agentic-ai-lab-session-transform-field-rows/tail
   tail
   (cons 'declared-by declared-by)
   (cons 'runtime-executed #f)))

;; : (-> Symbol Alist Alist)
(def (agentic-ai-lab-session-transform-lineage-metadata/tail transform-name tail)
  (agentic-ai-lab-session-transform-field-rows/tail
   tail
   (cons 'transform-name transform-name)))

;; : (-> Symbol Symbol Fixnum Alist Alist)
(def (agentic-ai-lab-session-transform-derived-metadata/tail transform-name
                                                        source-session-id
                                                        memory-intent-count
                                                        tail)
  (agentic-ai-lab-session-transform-field-rows/tail
   tail
   (cons 'derived-by 'agentic-ai-lab-session-transform)
   (cons 'transform-name transform-name)
   (cons 'source-session-id source-session-id)
   (cons 'memory-intent-count memory-intent-count)))

;;; A memory intent is a report-only request for a runtime memory backend. It is
;;; attached to session transforms but never recalls or commits data in Scheme.
;; : (-> Symbol Symbol Symbol [Symbol/String] Symbol [Alist] PooSessionMemoryIntent)
(def (agentic-ai-lab-session-memory-intent intent-name
                                     store-ref
                                     scope
                                     recall
                                     commit-policy
                                     . maybe-metadata)
  (agentic-ai-lab-session-require "session memory intent name must be a symbol"
                            (symbol? intent-name)
                            intent-name)
  (agentic-ai-lab-session-require "session memory store ref must be a symbol"
                            (symbol? store-ref)
                            store-ref)
  (agentic-ai-lab-session-require "session memory scope must be a symbol"
                            (symbol? scope)
                            scope)
  (agentic-ai-lab-session-require "session memory recall keys must be a list"
                            (list? recall)
                            recall)
  (agentic-ai-lab-session-require
   "session memory recall keys must be symbols or strings"
   (agentic-ai-lab-session-every? agentic-ai-lab-session-memory-key? recall)
   recall)
  (agentic-ai-lab-session-require "session memory commit policy must be a symbol"
                            (symbol? commit-policy)
                            commit-policy)
  (let ((metadata-value
         (agentic-ai-lab-session-transform-declaration-metadata/tail
          'agentic-ai-lab-session-memory-intent
          (if (null? maybe-metadata) '() (car maybe-metadata)))))
    (agentic-ai-lab-session-require "session memory metadata must be a list"
                              (list? metadata-value)
                              metadata-value)
    (list (cons 'kind 'agentic-ai-lab.session.memory-intent)
          (cons 'schema 'agentic-ai-lab.modules.session.memory-intent.v1)
          (cons 'intent-name intent-name)
          (cons 'store-ref store-ref)
          (cons 'scope scope)
          (cons 'recall recall)
          (cons 'commit-policy commit-policy)
          (cons 'runtime-owner "marlin-agent-core")
          (cons 'handoff-required #t)
          (cons 'descriptor-realized? #f)
          (cons 'runtime-executed #f)
          (cons 'metadata metadata-value))))

;;; Boundary: session memory intent ref is the policy-visible edge for policy
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> PooSessionMemoryIntent Symbol Value Value)
;; : (-> SessionMemoryIntentCandidate Boolean)
;; | type SessionMemoryIntentCandidate = (U PooSessionMemoryIntent Alist POOObject)
;; : (-> PooSessionMemoryIntent Symbol)
;; : (-> PooSessionMemoryIntent Symbol)
;; : (-> PooSessionMemoryIntent Symbol)
;; : (-> PooSessionMemoryIntent [Symbol/String])
;; : (-> PooSessionMemoryIntent Symbol)
;; : (-> PooSessionMemoryIntent String)
;; : (-> PooSessionMemoryIntent Alist)
;; : (-> PooSessionMemoryIntent Alist)
;; agentic-ai-lab-session-memory-intent-handoff-bundle
;;   : (-> [PooSessionMemoryIntent] (Cons [Alist] Fixnum))
;;   | doc m%
;;       Project memory intents into report-only handoff rows while returning
;;       the row count in the same public bundle protocol.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-session-memory-intent-handoff-bundle intents)
;;       ;; => (handoff-rows . count)
;;       ```
;;     %
;; : (-> [PooSessionMemoryIntent] [Alist] Fixnum (Cons [Alist] Fixnum))
;; : (-> [PooSessionMemoryIntent] (Cons [Alist] Fixnum))
;; agentic-ai-lab-session-memory-intent-count
;;   : (-> [PooSessionMemoryIntent] Fixnum)
;;   | doc m%
;;       Return the cardinality of memory intents when callers do not need to
;;       allocate handoff rows.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-session-memory-intent-count intents)
;;       ;; => count
;;       ```
;;     %
;; : (-> [PooSessionMemoryIntent] Fixnum)
;; : (-> [PooSessionTransformOption] (Cons Alist [PooSessionMemoryIntent]))
;; | type PooSessionTransformOption = (U Alist PooSessionMemoryIntent)
(def (agentic-ai-lab-session-transform-options options)
  (cond
   ((null? options)
    (cons '() '()))
   ((null? (cdr options))
    (let ((option (car options)))
      (if (and (list? option)
               (agentic-ai-lab-session-every? agentic-ai-lab-session-memory-intent?
                                         option))
          (cons '() option)
          (cons option '()))))
   ((null? (cddr options))
    (cons (car options) (cadr options)))
   (else
    (agentic-ai-lab-session-require
     "session transform accepts at most metadata and memory intents"
     #f
     options))))

;;; A transform is an agent-flow layer spec. It is intentionally inert: provider
;;; prompts and runtime calls become handoff intent, not Scheme execution.
;; : (-> Symbol Symbol String [Symbol] [Alist] PooSessionTransform)
(def (agentic-ai-lab-session-transform transform-name
                                 intent
                                 description
                                 capabilities
                                 . options)
  (agentic-ai-lab-session-require "session transform name must be a symbol"
                            (symbol? transform-name)
                            transform-name)
  (agentic-ai-lab-session-require "session transform intent must be a symbol"
                            (symbol? intent)
                            intent)
  (agentic-ai-lab-session-require "session transform description must be a string"
                            (string? description)
                            description)
  (agentic-ai-lab-session-require "session transform capabilities must be a list"
                            (list? capabilities)
                            capabilities)
  (agentic-ai-lab-session-require
   "session transform capabilities must contain only symbols"
   (agentic-ai-lab-session-every? symbol? capabilities)
   capabilities)
  (let* ((split-options (agentic-ai-lab-session-transform-options options))
         (transform-name-value transform-name)
         (intent-value intent)
         (description-value description)
         (capability-values capabilities)
         (metadata-value
          (agentic-ai-lab-session-transform-declaration-metadata/tail
           'agentic-ai-lab-session-transform
           (car split-options)))
         (memory-intents-value (cdr split-options)))
    (agentic-ai-lab-session-require "session transform metadata must be a list"
                              (list? metadata-value)
                              metadata-value)
    (agentic-ai-lab-session-require "session transform memory intents must be a list"
                              (list? memory-intents-value)
                              memory-intents-value)
    (agentic-ai-lab-session-require
     "session transform memory intents must contain only memory intents"
     (agentic-ai-lab-session-every? agentic-ai-lab-session-memory-intent?
                              memory-intents-value)
     memory-intents-value)
    (object<-alist
     (list
      (cons 'kind 'agentic-ai-lab.session.transform)
      (cons 'schema 'agentic-ai-lab.modules.session.transform.v1)
      (cons 'transform-name transform-name-value)
      (cons 'intent intent-value)
      (cons 'description description-value)
      (cons 'capabilities capability-values)
      (cons 'memory-intents memory-intents-value)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'handoff-required #t)
      (cons 'descriptor-realized? #f)
      (cons 'runtime-executed #f)
      (cons 'metadata metadata-value)))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-transform? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.transform)))

;; : (-> PooSessionTransform Symbol)
(def (agentic-ai-lab-session-transform-name transform)
  (.ref transform 'transform-name))

;; : (-> PooSessionTransform Symbol)
(def (agentic-ai-lab-session-transform-intent transform)
  (.ref transform 'intent))

;; : (-> PooSessionTransform String)
(def (agentic-ai-lab-session-transform-description transform)
  (.ref transform 'description))

;; : (-> PooSessionTransform [Symbol])
(def (agentic-ai-lab-session-transform-capabilities transform)
  (.ref transform 'capabilities))

;; : (-> PooSessionTransform String)
(def (agentic-ai-lab-session-transform-runtime-owner transform)
  (.ref transform 'runtime-owner))

;; : (-> PooSessionTransform Alist)
(def (agentic-ai-lab-session-transform-metadata transform)
  (.ref transform 'metadata))

;; : (-> PooSessionTransform [PooSessionMemoryIntent])
(def (agentic-ai-lab-session-transform-memory-intents transform)
  (.ref transform 'memory-intents))

;;; Handoff intent is the runtime-facing summary. It is plain data so Marlin can
;;; consume it without traversing nested POO objects.
;; : (-> PooSessionTransform PooSession PooSession Alist)
(def (agentic-ai-lab-session-transform-handoff-intent transform
                                                source-session
                                                derived-session)
  (let* ((memory-intents-value
          (agentic-ai-lab-session-transform-memory-intents transform))
         (memory-handoff-bundle
          (agentic-ai-lab-session-memory-intent-handoff-bundle
           memory-intents-value))
         (derived-placement-value
          (agentic-ai-lab-session-value-placement derived-session)))
    (list
     (cons 'kind 'agentic-ai-lab.session.transform.handoff-intent)
     (cons 'schema 'agentic-ai-lab.modules.session.transform.handoff-intent.v1)
     (cons 'transform-name (agentic-ai-lab-session-transform-name transform))
     (cons 'intent (agentic-ai-lab-session-transform-intent transform))
     (cons 'source-session-id (agentic-ai-lab-session-id source-session))
     (cons 'derived-session-id (agentic-ai-lab-session-id derived-session))
     (cons 'capabilities (agentic-ai-lab-session-transform-capabilities transform))
     (cons 'memory-intents (car memory-handoff-bundle))
     (cons 'memory-intent-count (cdr memory-handoff-bundle))
     (cons 'placement-profile-ref
           (agentic-ai-lab-session-placement-profile-ref
            derived-placement-value))
     (cons 'placement-resolved?
           (agentic-ai-lab-session-placement-resolved?
            derived-placement-value))
     (cons 'runtime-owner (agentic-ai-lab-session-transform-runtime-owner transform))
     (cons 'handoff-required #t)
     (cons 'descriptor-realized? #f)
     (cons 'runtime-executed #f))))

;;; Runtime memory effects stay behind the handoff. The receipt records what
;;; would be recalled or committed by the runtime owner.
;; : (-> PooSessionMemoryIntent PooSessionTransform PooSession PooSession PooSessionMemoryReceipt)
(def (agentic-ai-lab-session-memory-receipt-row memory-intent
                                          transform
                                          source-session
                                          derived-session)
  (list
   (cons 'kind 'agentic-ai-lab.session.memory.receipt)
   (cons 'schema 'agentic-ai-lab.modules.session.memory.receipt.v1)
   (cons 'intent-name (agentic-ai-lab-session-memory-intent-name memory-intent))
   (cons 'store-ref (agentic-ai-lab-session-memory-intent-store-ref memory-intent))
   (cons 'scope (agentic-ai-lab-session-memory-intent-scope memory-intent))
   (cons 'recall (agentic-ai-lab-session-memory-intent-recall memory-intent))
   (cons 'commit-policy (agentic-ai-lab-session-memory-intent-commit-policy
                         memory-intent))
   (cons 'transform-name (agentic-ai-lab-session-transform-name transform))
   (cons 'source-session-id (agentic-ai-lab-session-id source-session))
   (cons 'derived-session-id (agentic-ai-lab-session-id derived-session))
   (cons 'runtime-owner (agentic-ai-lab-session-memory-intent-runtime-owner
                         memory-intent))
   (cons 'handoff-required #t)
   (cons 'descriptor-realized? #f)
   (cons 'runtime-executed #f)
   (cons 'metadata (agentic-ai-lab-session-memory-intent-metadata memory-intent))))

;; agentic-ai-lab-session-memory-receipt-row-bundle
;;   : (-> [PooSessionMemoryIntent] PooSessionTransform PooSession PooSession (Cons [Alist] Fixnum))
;;   | doc m%
;;       Project memory intents into receipt rows for a derived session and
;;       return the row count with the same bundle protocol.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-session-memory-receipt-row-bundle intents transform source derived)
;;       ;; => (receipt-rows . count)
;;       ```
;;     %
;; : (-> [PooSessionMemoryIntent] PooSessionTransform PooSession PooSession [Alist] Fixnum (Cons [Alist] Fixnum))
(def (agentic-ai-lab-session-memory-receipt-row-bundle/rev memory-intents
                                                        transform
                                                        source-session
                                                        derived-session
                                                        rows-rev
                                                        count)
  (if (null? memory-intents)
    (cons rows-rev count)
    (agentic-ai-lab-session-memory-receipt-row-bundle/rev
     (cdr memory-intents)
     transform
     source-session
     derived-session
     (cons (agentic-ai-lab-session-memory-receipt-row
            (car memory-intents)
            transform
            source-session
            derived-session)
           rows-rev)
     (fx+ count 1))))

;; : (-> [PooSessionMemoryIntent] PooSessionTransform PooSession PooSession (Cons [Alist] Fixnum))
(def (agentic-ai-lab-session-memory-receipt-row-bundle memory-intents
                                                 transform
                                                 source-session
                                                 derived-session)
  (let (bundle
        (agentic-ai-lab-session-memory-receipt-row-bundle/rev
         memory-intents
         transform
         source-session
         derived-session
         '()
         0))
    (cons (reverse (car bundle)) (cdr bundle))))

;; : (-> Alist PooSessionMemoryReceipt)
(def (agentic-ai-lab-session-memory-receipt-row->object row)
  (make-agentic-ai-lab-session-memory-receipt-record
   (agentic-ai-lab-session-alist-ref row 'kind #f)
   (agentic-ai-lab-session-alist-ref row 'schema #f)
   (agentic-ai-lab-session-alist-ref row 'intent-name #f)
   (agentic-ai-lab-session-alist-ref row 'store-ref #f)
   (agentic-ai-lab-session-alist-ref row 'scope #f)
   (agentic-ai-lab-session-alist-ref row 'recall '())
   (agentic-ai-lab-session-alist-ref row 'commit-policy #f)
   (agentic-ai-lab-session-alist-ref row 'transform-name #f)
   (agentic-ai-lab-session-alist-ref row 'source-session-id #f)
   (agentic-ai-lab-session-alist-ref row 'derived-session-id #f)
   (agentic-ai-lab-session-alist-ref row 'runtime-owner "marlin-agent-core")
   (agentic-ai-lab-session-alist-ref row 'handoff-required #t)
   (agentic-ai-lab-session-alist-ref row 'descriptor-realized? #f)
   (agentic-ai-lab-session-alist-ref row 'runtime-executed #f)
   (agentic-ai-lab-session-alist-ref row 'metadata '())))

;; : (-> PooSessionMemoryIntent PooSessionTransform PooSession PooSession PooSessionMemoryReceipt)
(def (agentic-ai-lab-session-memory-receipt memory-intent
                                      transform
                                      source-session
                                      derived-session)
  (agentic-ai-lab-session-memory-receipt-row->object
   (agentic-ai-lab-session-memory-receipt-row
    memory-intent
    transform
    source-session
    derived-session)))

;; : (-> [Alist] [PooSessionMemoryReceipt])
(def (agentic-ai-lab-session-memory-receipt-rows->objects rows)
  (cond
   ((null? rows) '())
   (else
    (cons (agentic-ai-lab-session-memory-receipt-row->object (car rows))
          (agentic-ai-lab-session-memory-receipt-rows->objects (cdr rows))))))

;;; Apply a transform in the control plane. The output is a receipt object with
;;; an inspectable derived session; runtime providers still receive only the
;;; handoff intent.
;; : (-> PooSessionTransform PooSession Symbol [PooSessionChunk] [Alist] PooSessionTransformReceipt)
(def (agentic-ai-lab-session-transform-apply transform
                                       source-session
                                       derived-session-id
                                       chunks
                                       . maybe-metadata)
  (agentic-ai-lab-session-require "session transform apply requires a transform"
                            (agentic-ai-lab-session-transform? transform)
                            transform)
  (agentic-ai-lab-session-require "session transform apply requires a session"
                            (agentic-ai-lab-session? source-session)
                            source-session)
  (agentic-ai-lab-session-require "derived session id must be a symbol"
                            (symbol? derived-session-id)
                            derived-session-id)
  (agentic-ai-lab-session-require "derived session chunks must be a list"
                            (list? chunks)
                            chunks)
  (agentic-ai-lab-session-require
   "derived session chunks must contain only session chunks"
   (agentic-ai-lab-session-every? agentic-ai-lab-session-chunk? chunks)
   chunks)
  (let* ((metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata)))
         (source-session-id-value (agentic-ai-lab-session-id source-session))
         (derived-session-id-value derived-session-id)
         (memory-intents-value
          (agentic-ai-lab-session-transform-memory-intents transform))
         (memory-intent-count-value
          (agentic-ai-lab-session-memory-intent-count memory-intents-value))
         (transform-name-value
          (agentic-ai-lab-session-transform-name transform))
         (transform-intent-value
          (agentic-ai-lab-session-transform-intent transform))
         (transform-runtime-owner-value
          (agentic-ai-lab-session-transform-runtime-owner transform))
         (source-placement-value
          (agentic-ai-lab-session-value-placement source-session))
         (source-chunk-count-value
          (length (agentic-ai-lab-session-chunks source-session)))
         (derived-chunk-count-value
          (length chunks))
         (derived-session-value
          (agentic-ai-lab-session-value
           derived-session-id-value
           chunks
           (agentic-ai-lab-session-lineage
            derived-session-id-value
            (list source-session-id-value)
            'transform
            (agentic-ai-lab-session-transform-lineage-metadata/tail
             transform-name-value
             metadata-value))
           source-placement-value
           (agentic-ai-lab-session-transform-derived-metadata/tail
            transform-name-value
            source-session-id-value
            memory-intent-count-value
            metadata-value)))
         (handoff-intent-value
          (agentic-ai-lab-session-transform-handoff-intent
           transform
           source-session
           derived-session-value))
         (derived-placement-value
          (agentic-ai-lab-session-value-placement derived-session-value))
         (memory-receipt-bundle
          (agentic-ai-lab-session-memory-receipt-row-bundle
           memory-intents-value
           transform
           source-session
           derived-session-value))
         (memory-receipts-value (car memory-receipt-bundle))
         (memory-receipt-count-value (cdr memory-receipt-bundle)))
    (object<-alist
     (list
      (cons 'kind 'agentic-ai-lab.session.transform.receipt)
      (cons 'schema 'agentic-ai-lab.modules.session.transform.receipt.v1)
      (cons 'transform-name transform-name-value)
      (cons 'transform-intent transform-intent-value)
      (cons 'source-session-id source-session-id-value)
      (cons 'derived-session-id derived-session-id-value)
      (cons 'parent-session-ids (list source-session-id-value))
      (cons 'derived-session-chunks chunks)
      (cons 'derived-session-metadata
            (agentic-ai-lab-session-metadata derived-session-value))
      (cons 'derived-session-branch-kind 'transform)
      (cons 'placement-profile-ref
            (agentic-ai-lab-session-placement-profile-ref
             derived-placement-value))
      (cons 'placement-resolved?
            (agentic-ai-lab-session-placement-resolved?
             derived-placement-value))
      (cons 'placement-diagnostics
            (agentic-ai-lab-session-placement-diagnostics
             derived-placement-value))
      (cons 'placement-runtime-summary
            (agentic-ai-lab-session-placement-runtime-summary
             derived-placement-value))
      (cons 'placement-handoff-summary
            (agentic-ai-lab-session-placement-handoff-summary
             derived-placement-value))
      (cons 'placement-metadata
            (.ref derived-placement-value 'placement-metadata))
      (cons 'source-chunk-count source-chunk-count-value)
      (cons 'derived-chunk-count derived-chunk-count-value)
      (cons 'handoff-intent handoff-intent-value)
      (cons 'memory-receipts memory-receipts-value)
      (cons 'memory-receipt-count memory-receipt-count-value)
      (cons 'runtime-owner transform-runtime-owner-value)
      (cons 'handoff-required #t)
      (cons 'descriptor-realized? #f)
      (cons 'runtime-executed #f)
      (cons 'metadata metadata-value)))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-transform-receipt? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.transform.receipt)))

;; : (-> PooSessionTransformReceipt PooSession)
(def (agentic-ai-lab-session-transform-receipt-derived-session receipt)
  (let ((derived-session-id (.ref receipt 'derived-session-id))
        (parent-session-ids (.ref receipt 'parent-session-ids)))
    (agentic-ai-lab-session-value
     derived-session-id
     (.ref receipt 'derived-session-chunks)
     (agentic-ai-lab-session-lineage
      derived-session-id
      parent-session-ids
      (.ref receipt 'derived-session-branch-kind))
     (.o placement-kind: 'agentic-ai-lab.session.placement
         placement-schema: 'agentic-ai-lab.modules.session.placement.v1
         placement-profile-ref: (.ref receipt 'placement-profile-ref)
         placement-resolved?: (.ref receipt 'placement-resolved?)
         placement-diagnostics: (.ref receipt 'placement-diagnostics)
         placement-runtime-summary: (.ref receipt 'placement-runtime-summary)
         placement-handoff-summary: (.ref receipt 'placement-handoff-summary)
         placement-metadata: (.ref receipt 'placement-metadata)
         placement-runtime-executed: #f)
     (.ref receipt 'derived-session-metadata))))

;; : (-> PooSessionTransformReceipt Alist)
(def (agentic-ai-lab-session-transform-receipt-handoff-intent receipt)
  (.ref receipt 'handoff-intent))

;; agentic-ai-lab-session-transform-receipt-memory-receipts
;;   : (-> PooSessionTransformReceipt [PooSessionMemoryReceipt])
;;   | doc m%
;;       Materialize receipt rows from an inert transform receipt as POO memory
;;       receipt objects for downstream inspection.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-session-transform-receipt-memory-receipts receipt)
;;       ;; => memory-receipt-objects
;;       ```
;;     %
;; : (-> PooSessionTransformReceipt [PooSessionMemoryReceipt])
(def (agentic-ai-lab-session-transform-receipt-memory-receipts receipt)
  (agentic-ai-lab-session-memory-receipt-rows->objects
   (.ref receipt 'memory-receipts)))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-memory-receipt? value)
  (or (agentic-ai-lab-session-memory-receipt-record? value)
      (and (object? value)
           (eq? (.ref value 'kind) 'agentic-ai-lab.session.memory.receipt))))

;; : (-> PooSessionMemoryReceipt Symbol)
(def (agentic-ai-lab-session-memory-receipt-name receipt)
  (agentic-ai-lab-session-memory-receipt-ref receipt 'intent-name))
