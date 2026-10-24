;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory policy/catalog validation receipts.

(import (only-in :std/list/list fold)
        (only-in :clan/poo/object .o .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-catalog)

(export agentic-ai-lab-memory-policy-validation-receipt-record
        make-agentic-ai-lab-memory-policy-validation-receipt-record
        agentic-ai-lab-memory-policy-validation-receipt-record?
        agentic-ai-lab-memory-diagnostic
        agentic-ai-lab-memory-store-intent-diagnostics/tail
        agentic-ai-lab-memory-store-intent-diagnostics
        agentic-ai-lab-memory-policy-catalog-validation-summary-finish
        agentic-ai-lab-memory-policy-catalog-intent-diagnostics
        agentic-ai-lab-memory-policy-catalog-seen-store-refs
        agentic-ai-lab-memory-policy-catalog-intent-store-refs/rev
        agentic-ai-lab-memory-policy-catalog-resolved-store-refs/rev
        agentic-ai-lab-memory-policy-catalog-unresolved-store-refs/rev
        agentic-ai-lab-memory-policy-catalog-validation-summary/rev
        agentic-ai-lab-memory-policy-catalog-validation-summary
        agentic-ai-lab-memory-policy-catalog-validation-receipt
        agentic-ai-lab-memory-policy-catalog-validation-receipt?
        agentic-ai-lab-memory-policy-catalog-validation-receipt-valid?
        agentic-ai-lab-memory-policy-catalog-validation-receipt-diagnostics
        agentic-ai-lab-memory-policy-catalog-validation-receipt->alist)

(defstruct agentic-ai-lab-memory-policy-validation-receipt-record
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
(def (agentic-ai-lab-memory-diagnostic code intent)
  (agentic-ai-lab-memory-field-rows
   (kind 'agentic-ai-lab.memory-core.diagnostic)
   (schema 'agentic-ai-lab.modules.memory-core.diagnostic.v1)
   (code code)
   (intent-name (agentic-ai-lab-session-memory-intent-name intent))
   (store-ref (agentic-ai-lab-session-memory-intent-store-ref intent))
   (scope (agentic-ai-lab-session-memory-intent-scope intent))
   (commit-policy (agentic-ai-lab-session-memory-intent-commit-policy intent))
   (severity 'error)
   (runtime-executed #f)))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist] [Alist])
(def (agentic-ai-lab-memory-store-intent-diagnostics/tail spec intent tail)
  (let ((scope (agentic-ai-lab-session-memory-intent-scope intent))
        (commit-policy
         (agentic-ai-lab-session-memory-intent-commit-policy intent))
        (recall-keys (agentic-ai-lab-session-memory-intent-recall intent)))
    (let* ((recall-tail
            (if (or (null? recall-keys)
                    (not (null? (agentic-ai-lab-memory-store-spec-recall-policies
                                 spec))))
              tail
              (cons (agentic-ai-lab-memory-diagnostic
                     'memory-store-recall-disabled
                     intent)
                    tail)))
           (commit-tail
            (if (member commit-policy
                        (agentic-ai-lab-memory-store-spec-commit-policies spec))
              recall-tail
              (cons (agentic-ai-lab-memory-diagnostic
                     'memory-intent-commit-denied
                     intent)
                    recall-tail))))
      (if (member scope (agentic-ai-lab-memory-store-spec-scopes spec))
        commit-tail
        (cons (agentic-ai-lab-memory-diagnostic 'memory-intent-scope-denied
                                          intent)
              commit-tail)))))

;; : (-> PooMemoryStoreSpec PooSessionMemoryIntent [Alist])
(def (agentic-ai-lab-memory-store-intent-diagnostics spec intent)
  (agentic-ai-lab-memory-store-intent-diagnostics/tail spec intent '()))

;; : (-> PooMemoryCatalog [PooSessionMemoryIntent] [Symbol] Integer [Symbol] [Symbol] [Symbol] [Alist] Alist)
(def (agentic-ai-lab-memory-policy-catalog-validation-summary-finish
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
(def (agentic-ai-lab-memory-policy-catalog-intent-diagnostics spec intent)
  (if spec
    (agentic-ai-lab-memory-store-intent-diagnostics spec intent)
    (list (agentic-ai-lab-memory-diagnostic
           'memory-store-not-in-catalog
           intent))))

;; : (-> Boolean Symbol [Symbol] [Symbol])
(def (agentic-ai-lab-memory-policy-catalog-seen-store-refs already-seen?
                                                            store-ref
                                                            seen-store-refs)
  (if already-seen?
    seen-store-refs
    (cons store-ref seen-store-refs)))

;; : (-> Boolean Symbol [Symbol] [Symbol])
(def (agentic-ai-lab-memory-policy-catalog-intent-store-refs/rev already-seen?
                                                                  store-ref
                                                                  refs-rev)
  (if already-seen?
    refs-rev
    (cons store-ref refs-rev)))

;; : (-> Boolean Object Symbol [Symbol] [Symbol])
(def (agentic-ai-lab-memory-policy-catalog-resolved-store-refs/rev already-seen?
                                                                    spec
                                                                    store-ref
                                                                    refs-rev)
  (if (and (not already-seen?) spec)
    (cons store-ref refs-rev)
    refs-rev))

;; : (-> Boolean Object Symbol [Symbol] [Symbol])
(def (agentic-ai-lab-memory-policy-catalog-unresolved-store-refs/rev already-seen?
                                                                      spec
                                                                      store-ref
                                                                      refs-rev)
  (if (and (not already-seen?) (not spec))
    (cons store-ref refs-rev)
    refs-rev))

;; : (-> PooMemoryCatalog PooSessionMemoryIntent List List)
(def (agentic-ai-lab-memory-policy-catalog-validation-summary-step catalog intent state)
  (match state
    ([seen-store-refs intent-count intent-store-refs-rev
      resolved-store-refs-rev unresolved-store-refs-rev diagnostics-rev]
     (let* ((store-ref (agentic-ai-lab-session-memory-intent-store-ref intent))
            (already-seen? (member store-ref seen-store-refs))
            (spec (agentic-ai-lab-memory-catalog-find catalog store-ref))
            (intent-diagnostics
             (agentic-ai-lab-memory-policy-catalog-intent-diagnostics spec intent)))
       (list
        (agentic-ai-lab-memory-policy-catalog-seen-store-refs
         already-seen? store-ref seen-store-refs)
        (+ intent-count 1)
        (agentic-ai-lab-memory-policy-catalog-intent-store-refs/rev
         already-seen? store-ref intent-store-refs-rev)
        (agentic-ai-lab-memory-policy-catalog-resolved-store-refs/rev
         already-seen? spec store-ref resolved-store-refs-rev)
        (agentic-ai-lab-memory-policy-catalog-unresolved-store-refs/rev
         already-seen? spec store-ref unresolved-store-refs-rev)
        (agentic-ai-lab-memory-reverse-onto intent-diagnostics diagnostics-rev))))))

;; agentic-ai-lab-memory-policy-catalog-validation-summary/rev
;;   : (forall (a d) (-> PooMemoryCatalog (List a) [Symbol] Integer [Symbol] [Symbol] [Symbol] (List d) Alist))
;;   : (-> PooMemoryCatalog [PooSessionMemoryIntent] [Symbol] Integer [Symbol] [Symbol] [Symbol] [Alist] Alist)
;;   | result: ordered validation summary alist
;;   | doc m%
;;       `agentic-ai-lab-memory-policy-catalog-validation-summary/rev` folds session
;;       memory intents against a memory catalog while preserving
;;       declaration order and diagnostic provenance. This helper owns the
;;       accumulator state for catalog validation; runtime recall, commit, and
;;       persistence stay outside Scheme.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-memory-policy-catalog-validation-summary/rev
;;        catalog intents '() 0 '() '() '() '())
;;       ;; => validation summary alist
;;       ```
;;
;;       # Result
;;
;;       A validation summary alist with intent, resolved-store, unresolved-store,
;;       and diagnostic rows.
;;     %
(def (agentic-ai-lab-memory-policy-catalog-validation-summary/rev catalog
                                                            memory-intents
                                                            seen-store-refs
                                                            intent-count
                                                            intent-store-refs-rev
                                                            resolved-store-refs-rev
                                                            unresolved-store-refs-rev
                                                            diagnostics-rev)
  (match (fold
          (cut agentic-ai-lab-memory-policy-catalog-validation-summary-step
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
      (agentic-ai-lab-memory-policy-catalog-validation-summary-finish
       final-intent-count
       final-intent-store-refs-rev
       final-resolved-store-refs-rev
       final-unresolved-store-refs-rev
       final-diagnostics-rev))))

;; : (-> PooMemoryCatalog [PooSessionMemoryIntent] Alist)
(def (agentic-ai-lab-memory-policy-catalog-validation-summary catalog memory-intents)
  (agentic-ai-lab-memory-policy-catalog-validation-summary/rev
   catalog
   memory-intents
   '()
   0
   '()
   '()
   '()
   '()))

;; : (-> Symbol PooMemoryCatalog [PooSessionMemoryIntent] [Alist] PooMemoryPolicyCatalogValidationReceipt)
(def (agentic-ai-lab-memory-policy-catalog-validation-receipt validation-id
                                                        catalog
                                                        memory-intents
                                                        . maybe-metadata)
  (agentic-ai-lab-session-require "memory validation id must be a symbol"
                            (symbol? validation-id)
                            validation-id)
  (agentic-ai-lab-session-require "memory validation requires a catalog"
                            (agentic-ai-lab-memory-catalog? catalog)
                            catalog)
  (agentic-ai-lab-session-require "memory validation intents must be memory intents"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-memory-intent?
                             memory-intents)
                            memory-intents)
  (let* ((validation-summary
          (agentic-ai-lab-memory-policy-catalog-validation-summary
           catalog
           memory-intents))
         (intent-count-value
          (agentic-ai-lab-session-alist-ref validation-summary 'intent-count 0))
         (intent-store-refs
          (agentic-ai-lab-session-alist-ref validation-summary
                                      'intent-store-refs
                                      '()))
         (resolved-store-refs
          (agentic-ai-lab-session-alist-ref validation-summary
                                      'resolved-store-refs
                                      '()))
         (unresolved-store-refs
          (agentic-ai-lab-session-alist-ref validation-summary
                                      'unresolved-store-refs
                                      '()))
         (diagnostics
          (agentic-ai-lab-session-alist-ref validation-summary 'diagnostics '())))
    (agentic-ai-lab-memory-runtime-object
     (agentic-ai-lab-memory-policy-catalog-validation-receipt->alist
      (make-agentic-ai-lab-memory-policy-validation-receipt-record
       +agentic-ai-lab-ai-agentic-context-memory-policy-validation-receipt-kind+
       'agentic-ai-lab.modules.memory-core.policy-catalog-validation.v1
       validation-id
       (agentic-ai-lab-memory-catalog-ref catalog)
       (agentic-ai-lab-memory-catalog-store-count catalog)
       (agentic-ai-lab-memory-catalog-store-refs catalog)
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
(def (agentic-ai-lab-memory-policy-catalog-validation-receipt? value)
  (or (agentic-ai-lab-memory-policy-validation-receipt-record? value)
      (and (object? value)
           (eq? (agentic-ai-lab-memory-slot value 'kind #f)
                +agentic-ai-lab-ai-agentic-context-memory-policy-validation-receipt-kind+))))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Boolean)
(def (agentic-ai-lab-memory-policy-catalog-validation-receipt-valid? receipt)
  (if (agentic-ai-lab-memory-policy-validation-receipt-record? receipt)
    (agentic-ai-lab-memory-policy-validation-receipt-record-valid? receipt)
    (.ref receipt 'valid?)))

;; : (-> PooMemoryPolicyCatalogValidationReceipt [Alist])
(def (agentic-ai-lab-memory-policy-catalog-validation-receipt-diagnostics receipt)
  (if (agentic-ai-lab-memory-policy-validation-receipt-record? receipt)
    (agentic-ai-lab-memory-policy-validation-receipt-record-diagnostics receipt)
    (.ref receipt 'diagnostics)))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Alist)
(def (agentic-ai-lab-memory-policy-catalog-validation-receipt->alist receipt)
  (let (checked-receipt
        (agentic-ai-lab-session-require
         "memory policy validation projection requires a validation receipt"
         (agentic-ai-lab-memory-policy-catalog-validation-receipt? receipt)
         receipt))
    (if (agentic-ai-lab-memory-policy-validation-receipt-record? checked-receipt)
      (list
       (cons 'kind
             (agentic-ai-lab-memory-policy-validation-receipt-record-kind checked-receipt))
       (cons 'schema
             (agentic-ai-lab-memory-policy-validation-receipt-record-schema checked-receipt))
       (cons 'validation-id
             (agentic-ai-lab-memory-policy-validation-receipt-record-validation-id checked-receipt))
       (cons 'catalog-ref
             (agentic-ai-lab-memory-policy-validation-receipt-record-catalog-ref checked-receipt))
       (cons 'catalog-store-count
             (agentic-ai-lab-memory-policy-validation-receipt-record-catalog-store-count checked-receipt))
       (cons 'catalog-store-refs
             (agentic-ai-lab-memory-policy-validation-receipt-record-catalog-store-refs checked-receipt))
       (cons 'intent-count
             (agentic-ai-lab-memory-policy-validation-receipt-record-intent-count checked-receipt))
       (cons 'intent-store-refs
             (agentic-ai-lab-memory-policy-validation-receipt-record-intent-store-refs checked-receipt))
       (cons 'resolved-store-refs
             (agentic-ai-lab-memory-policy-validation-receipt-record-resolved-store-refs checked-receipt))
       (cons 'unresolved-store-refs
             (agentic-ai-lab-memory-policy-validation-receipt-record-unresolved-store-refs checked-receipt))
       (cons 'valid?
             (agentic-ai-lab-memory-policy-validation-receipt-record-valid? checked-receipt))
       (cons 'diagnostic-count
             (agentic-ai-lab-memory-policy-validation-receipt-record-diagnostic-count checked-receipt))
       (cons 'diagnostics
             (agentic-ai-lab-memory-policy-validation-receipt-record-diagnostics checked-receipt))
       (cons 'runtime-owner
             (agentic-ai-lab-memory-policy-validation-receipt-record-runtime-owner checked-receipt))
       (cons 'runtime-executed
             (agentic-ai-lab-memory-policy-validation-receipt-record-runtime-executed checked-receipt))
       (cons 'metadata
             (agentic-ai-lab-memory-policy-validation-receipt-record-metadata checked-receipt)))
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
