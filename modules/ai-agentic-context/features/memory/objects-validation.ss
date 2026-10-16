;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory policy/catalog validation receipts.

(import (only-in :std/list/list fold)
        (only-in :clan/poo/object .o .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform
        :poo-flow/modules/ai-agentic-context/features/memory/objects-core
        :poo-flow/modules/ai-agentic-context/features/memory/objects-catalog)

(export poo-flow-memory-policy-validation-receipt-record
        make-poo-flow-memory-policy-validation-receipt-record
        poo-flow-memory-policy-validation-receipt-record?
        poo-flow-memory-diagnostic
        poo-flow-memory-store-intent-diagnostics/tail
        poo-flow-memory-store-intent-diagnostics
        poo-flow-memory-policy-catalog-validation-summary-finish
        poo-flow-memory-policy-catalog-intent-diagnostics
        poo-flow-memory-policy-catalog-seen-store-refs
        poo-flow-memory-policy-catalog-intent-store-refs/rev
        poo-flow-memory-policy-catalog-resolved-store-refs/rev
        poo-flow-memory-policy-catalog-unresolved-store-refs/rev
        poo-flow-memory-policy-catalog-validation-summary/rev
        poo-flow-memory-policy-catalog-validation-summary
        poo-flow-memory-policy-catalog-validation-receipt
        poo-flow-memory-policy-catalog-validation-receipt?
        poo-flow-memory-policy-catalog-validation-receipt-valid?
        poo-flow-memory-policy-catalog-validation-receipt-diagnostics
        poo-flow-memory-policy-catalog-validation-receipt->alist)

(defstruct poo-flow-memory-policy-validation-receipt-record
  (kind
   schema
   validation-id
   catalog-ref
   catalog-store-count
   catalog-store-refs
   intent-count
   intent-store-refs
   resolved-store-refs
   unresolved-store-refs
   valid?
   diagnostic-count
   diagnostics
   runtime-owner
   runtime-executed
   metadata)
  transparent: #t)
;; : (-> Symbol PooSessionMemoryIntent Alist)
(def (poo-flow-memory-diagnostic code intent)
  (poo-flow-memory-field-rows
   (kind 'poo-flow.memory-core.diagnostic)
   (schema 'poo-flow.modules.memory-core.diagnostic.v1)
   (code code)
   (intent-name (poo-flow-session-memory-intent-name intent))
   (store-ref (poo-flow-session-memory-intent-store-ref intent))
   (scope (poo-flow-session-memory-intent-scope intent))
   (commit-policy (poo-flow-session-memory-intent-commit-policy intent))
   (severity 'error)
   (runtime-executed #f)))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist] [Alist])
(def (poo-flow-memory-store-intent-diagnostics/tail spec intent tail)
  (let ((scope (poo-flow-session-memory-intent-scope intent))
        (commit-policy
         (poo-flow-session-memory-intent-commit-policy intent))
        (recall-keys (poo-flow-session-memory-intent-recall intent)))
    (let* ((recall-tail
            (if (or (null? recall-keys)
                    (not (null? (poo-flow-memory-store-spec-recall-policies
                                 spec))))
              tail
              (cons (poo-flow-memory-diagnostic
                     'memory-store-recall-disabled
                     intent)
                    tail)))
           (commit-tail
            (if (member commit-policy
                        (poo-flow-memory-store-spec-commit-policies spec))
              recall-tail
              (cons (poo-flow-memory-diagnostic
                     'memory-intent-commit-denied
                     intent)
                    recall-tail))))
      (if (member scope (poo-flow-memory-store-spec-scopes spec))
        commit-tail
        (cons (poo-flow-memory-diagnostic 'memory-intent-scope-denied
                                          intent)
              commit-tail)))))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist])
(def (poo-flow-memory-store-intent-diagnostics spec intent)
  (poo-flow-memory-store-intent-diagnostics/tail spec intent '()))

;; : (-> PooMemoryCatalog [PooSessionMemoryIntent] [Symbol] Integer [Symbol] [Symbol] [Symbol] [Alist] Alist)
(def (poo-flow-memory-policy-catalog-validation-summary-finish
      intent-count
      intent-store-refs-rev
      resolved-store-refs-rev
      unresolved-store-refs-rev
      diagnostics-rev)
  (list
   (cons 'intent-count intent-count)
   (cons 'intent-store-refs (reverse intent-store-refs-rev))
   (cons 'resolved-store-refs (reverse resolved-store-refs-rev))
   (cons 'unresolved-store-refs (reverse unresolved-store-refs-rev))
   (cons 'diagnostics (reverse diagnostics-rev))))

;; : (-> Object PooSessionMemoryIntent [Alist])
(def (poo-flow-memory-policy-catalog-intent-diagnostics spec intent)
  (if spec
    (poo-flow-memory-store-intent-diagnostics spec intent)
    (list (poo-flow-memory-diagnostic
           'memory-store-not-in-catalog
           intent))))

;; : (-> Boolean Symbol [Symbol] [Symbol])
(def (poo-flow-memory-policy-catalog-seen-store-refs already-seen?
                                                            store-ref
                                                            seen-store-refs)
  (if already-seen?
    seen-store-refs
    (cons store-ref seen-store-refs)))

;; : (-> Boolean Symbol [Symbol] [Symbol])
(def (poo-flow-memory-policy-catalog-intent-store-refs/rev already-seen?
                                                                  store-ref
                                                                  refs-rev)
  (if already-seen?
    refs-rev
    (cons store-ref refs-rev)))

;; : (-> Boolean Object Symbol [Symbol] [Symbol])
(def (poo-flow-memory-policy-catalog-resolved-store-refs/rev already-seen?
                                                                    spec
                                                                    store-ref
                                                                    refs-rev)
  (if (and (not already-seen?) spec)
    (cons store-ref refs-rev)
    refs-rev))

;; : (-> Boolean Object Symbol [Symbol] [Symbol])
(def (poo-flow-memory-policy-catalog-unresolved-store-refs/rev already-seen?
                                                                      spec
                                                                      store-ref
                                                                      refs-rev)
  (if (and (not already-seen?) (not spec))
    (cons store-ref refs-rev)
    refs-rev))

;; : (-> PooMemoryCatalog PooSessionMemoryIntent List List)
(def (poo-flow-memory-policy-catalog-validation-summary-step catalog intent state)
  (match state
    ([seen-store-refs intent-count intent-store-refs-rev
      resolved-store-refs-rev unresolved-store-refs-rev diagnostics-rev]
     (let* ((store-ref (poo-flow-session-memory-intent-store-ref intent))
            (already-seen? (member store-ref seen-store-refs))
            (spec (poo-flow-memory-catalog-find catalog store-ref))
            (intent-diagnostics
             (poo-flow-memory-policy-catalog-intent-diagnostics spec intent)))
       (list
        (poo-flow-memory-policy-catalog-seen-store-refs
         already-seen? store-ref seen-store-refs)
        (+ intent-count 1)
        (poo-flow-memory-policy-catalog-intent-store-refs/rev
         already-seen? store-ref intent-store-refs-rev)
        (poo-flow-memory-policy-catalog-resolved-store-refs/rev
         already-seen? spec store-ref resolved-store-refs-rev)
        (poo-flow-memory-policy-catalog-unresolved-store-refs/rev
         already-seen? spec store-ref unresolved-store-refs-rev)
        (poo-flow-memory-reverse-onto intent-diagnostics diagnostics-rev))))))

;; poo-flow-memory-policy-catalog-validation-summary/rev
;;   : (forall (a d) (-> PooMemoryCatalog (List a) [Symbol] Integer [Symbol] [Symbol] [Symbol] (List d) Alist))
;;   : (-> PooMemoryCatalog [PooSessionMemoryIntent] [Symbol] Integer [Symbol] [Symbol] [Symbol] [Alist] Alist)
;;   | result: ordered validation summary alist
;;   | doc m%
;;       `poo-flow-memory-policy-catalog-validation-summary/rev` folds session
;;       memory intents against a memory catalog while preserving
;;       declaration order and diagnostic provenance. This helper owns the
;;       accumulator state for catalog validation; runtime recall, commit, and
;;       persistence stay outside Scheme.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-memory-policy-catalog-validation-summary/rev
;;        catalog intents '() 0 '() '() '() '())
;;       ;; => validation summary alist
;;       ```
;;
;;       # Result
;;
;;       A validation summary alist with intent, resolved-store, unresolved-store,
;;       and diagnostic rows.
;;     %
(def (poo-flow-memory-policy-catalog-validation-summary/rev catalog
                                                            memory-intents
                                                            seen-store-refs
                                                            intent-count
                                                            intent-store-refs-rev
                                                            resolved-store-refs-rev
                                                            unresolved-store-refs-rev
                                                            diagnostics-rev)
  (match (fold
          (cut poo-flow-memory-policy-catalog-validation-summary-step
               catalog <> <>)
          (list seen-store-refs
                intent-count
                intent-store-refs-rev
                resolved-store-refs-rev
                unresolved-store-refs-rev
                diagnostics-rev)
          memory-intents)
    ([_ final-intent-count final-intent-store-refs-rev
      final-resolved-store-refs-rev final-unresolved-store-refs-rev
      final-diagnostics-rev]
      (poo-flow-memory-policy-catalog-validation-summary-finish
       final-intent-count
       final-intent-store-refs-rev
       final-resolved-store-refs-rev
       final-unresolved-store-refs-rev
       final-diagnostics-rev))))

;; : (-> PooMemoryCatalog [PooSessionMemoryIntent] Alist)
(def (poo-flow-memory-policy-catalog-validation-summary catalog memory-intents)
  (poo-flow-memory-policy-catalog-validation-summary/rev
   catalog
   memory-intents
   '()
   0
   '()
   '()
   '()
   '()))

;; : (-> Symbol PooMemoryCatalog [PooSessionMemoryIntent] [Alist] PooMemoryPolicyCatalogValidationReceipt)
(def (poo-flow-memory-policy-catalog-validation-receipt validation-id
                                                        catalog
                                                        memory-intents
                                                        . maybe-metadata)
  (poo-flow-session-require "memory validation id must be a symbol"
                            (symbol? validation-id)
                            validation-id)
  (poo-flow-session-require "memory validation requires a catalog"
                            (poo-flow-memory-catalog? catalog)
                            catalog)
  (poo-flow-session-require "memory validation intents must be memory intents"
                            (poo-flow-session-every?
                             poo-flow-session-memory-intent?
                             memory-intents)
                            memory-intents)
  (let* ((validation-summary
          (poo-flow-memory-policy-catalog-validation-summary
           catalog
           memory-intents))
         (intent-count-value
          (poo-flow-session-alist-ref validation-summary 'intent-count 0))
         (intent-store-refs
          (poo-flow-session-alist-ref validation-summary
                                      'intent-store-refs
                                      '()))
         (resolved-store-refs
          (poo-flow-session-alist-ref validation-summary
                                      'resolved-store-refs
                                      '()))
         (unresolved-store-refs
          (poo-flow-session-alist-ref validation-summary
                                      'unresolved-store-refs
                                      '()))
         (diagnostics
          (poo-flow-session-alist-ref validation-summary 'diagnostics '())))
    (poo-flow-memory-runtime-object
     (poo-flow-memory-policy-catalog-validation-receipt->alist
      (make-poo-flow-memory-policy-validation-receipt-record
       +poo-flow-ai-agentic-context-memory-policy-validation-receipt-kind+
       'poo-flow.modules.memory-core.policy-catalog-validation.v1
       validation-id
       (poo-flow-memory-catalog-ref catalog)
       (poo-flow-memory-catalog-store-count catalog)
       (poo-flow-memory-catalog-store-refs catalog)
       intent-count-value
       intent-store-refs
       resolved-store-refs
       unresolved-store-refs
       (null? diagnostics)
       (length diagnostics)
       diagnostics
       "marlin-agent-core"
       #f
       (if (null? maybe-metadata)
         '()
         (car maybe-metadata)))))))

;; : (-> POOObject Boolean)
(def (poo-flow-memory-policy-catalog-validation-receipt? value)
  (or (poo-flow-memory-policy-validation-receipt-record? value)
      (and (object? value)
           (eq? (poo-flow-memory-slot value 'kind #f)
                +poo-flow-ai-agentic-context-memory-policy-validation-receipt-kind+))))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Boolean)
(def (poo-flow-memory-policy-catalog-validation-receipt-valid? receipt)
  (if (poo-flow-memory-policy-validation-receipt-record? receipt)
    (poo-flow-memory-policy-validation-receipt-record-valid? receipt)
    (.ref receipt 'valid?)))

;; : (-> PooMemoryPolicyCatalogValidationReceipt [Alist])
(def (poo-flow-memory-policy-catalog-validation-receipt-diagnostics receipt)
  (if (poo-flow-memory-policy-validation-receipt-record? receipt)
    (poo-flow-memory-policy-validation-receipt-record-diagnostics receipt)
    (.ref receipt 'diagnostics)))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Alist)
(def (poo-flow-memory-policy-catalog-validation-receipt->alist receipt)
  (let (checked-receipt
        (poo-flow-session-require
         "memory policy validation projection requires a validation receipt"
         (poo-flow-memory-policy-catalog-validation-receipt? receipt)
         receipt))
    (if (poo-flow-memory-policy-validation-receipt-record? checked-receipt)
      (list
       (cons 'kind
             (poo-flow-memory-policy-validation-receipt-record-kind checked-receipt))
       (cons 'schema
             (poo-flow-memory-policy-validation-receipt-record-schema checked-receipt))
       (cons 'validation-id
             (poo-flow-memory-policy-validation-receipt-record-validation-id checked-receipt))
       (cons 'catalog-ref
             (poo-flow-memory-policy-validation-receipt-record-catalog-ref checked-receipt))
       (cons 'catalog-store-count
             (poo-flow-memory-policy-validation-receipt-record-catalog-store-count checked-receipt))
       (cons 'catalog-store-refs
             (poo-flow-memory-policy-validation-receipt-record-catalog-store-refs checked-receipt))
       (cons 'intent-count
             (poo-flow-memory-policy-validation-receipt-record-intent-count checked-receipt))
       (cons 'intent-store-refs
             (poo-flow-memory-policy-validation-receipt-record-intent-store-refs checked-receipt))
       (cons 'resolved-store-refs
             (poo-flow-memory-policy-validation-receipt-record-resolved-store-refs checked-receipt))
       (cons 'unresolved-store-refs
             (poo-flow-memory-policy-validation-receipt-record-unresolved-store-refs checked-receipt))
       (cons 'valid?
             (poo-flow-memory-policy-validation-receipt-record-valid? checked-receipt))
       (cons 'diagnostic-count
             (poo-flow-memory-policy-validation-receipt-record-diagnostic-count checked-receipt))
       (cons 'diagnostics
             (poo-flow-memory-policy-validation-receipt-record-diagnostics checked-receipt))
       (cons 'runtime-owner
             (poo-flow-memory-policy-validation-receipt-record-runtime-owner checked-receipt))
       (cons 'runtime-executed
             (poo-flow-memory-policy-validation-receipt-record-runtime-executed checked-receipt))
       (cons 'metadata
             (poo-flow-memory-policy-validation-receipt-record-metadata checked-receipt)))
      (list
       (cons 'kind (.ref checked-receipt 'kind))
       (cons 'schema (.ref checked-receipt 'schema))
       (cons 'validation-id (.ref checked-receipt 'validation-id))
       (cons 'catalog-ref (.ref checked-receipt 'catalog-ref))
       (cons 'catalog-store-count (.ref checked-receipt 'catalog-store-count))
       (cons 'catalog-store-refs (.ref checked-receipt 'catalog-store-refs))
       (cons 'intent-count (.ref checked-receipt 'intent-count))
       (cons 'intent-store-refs (.ref checked-receipt 'intent-store-refs))
       (cons 'resolved-store-refs (.ref checked-receipt 'resolved-store-refs))
       (cons 'unresolved-store-refs
             (.ref checked-receipt 'unresolved-store-refs))
       (cons 'valid? (.ref checked-receipt 'valid?))
       (cons 'diagnostic-count (.ref checked-receipt 'diagnostic-count))
       (cons 'diagnostics (.ref checked-receipt 'diagnostics))
       (cons 'runtime-owner (.ref checked-receipt 'runtime-owner))
       (cons 'runtime-executed (.ref checked-receipt 'runtime-executed))
       (cons 'metadata (.ref checked-receipt 'metadata))))))
