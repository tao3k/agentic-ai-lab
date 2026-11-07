;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session selector receipts.
;;; Invariant: selector receipts describe routing intent only; Scheme never
;;; scores candidates, calls a model, dispatches workflows, or mutates sessions.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/receipt-syntax
        :agentic-ai-lab/modules/session/receipt-projection)

(export agentic-ai-lab-session-selector-candidate
        agentic-ai-lab-session-selector-candidate?
        agentic-ai-lab-session-selector-candidate-id
        agentic-ai-lab-session-selector-candidate-kind
        agentic-ai-lab-session-selector-candidate-target-ref
        agentic-ai-lab-session-selector-candidate->alist
        agentic-ai-lab-session-selector-candidates->alists
        agentic-ai-lab-session-selector-receipt
        agentic-ai-lab-session-selector-receipt?
        agentic-ai-lab-session-selector-receipt-selector-id
        agentic-ai-lab-session-selector-receipt-candidate-ids
        agentic-ai-lab-session-selector-receipt-selection-state
        agentic-ai-lab-session-selector-receipt-selected-candidate-ref
        agentic-ai-lab-session-selector-receipt-valid?
        agentic-ai-lab-session-selector-receipt-diagnostic-count
        agentic-ai-lab-session-selector-receipt-diagnostics
        agentic-ai-lab-session-selector-receipt->alist)

;; : [Symbol]
(def +agentic-ai-lab-session-selector-candidate-kinds+
  '(workflow transform agent-param))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-session-selector-candidate-kind? value)
  (and (symbol? value)
       (if (member value +agentic-ai-lab-session-selector-candidate-kinds+)
         #t
         #f)))

;; : (-> POOObject Symbol Value Value)
(def (agentic-ai-lab-session-selector-slot object key default)
  (with-catch
   (lambda (_failure) default)
   (lambda ()
     (.ref object key))))

;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-session-selector-policy-ref policy key default)
  (agentic-ai-lab-session-alist-ref policy key default))

;; : (-> List List List)
(def (agentic-ai-lab-session-selector-rows/tail rows tail)
  (foldr cons tail rows))

;;; Boundary: selector callers construct explicit field pairs; this function
;;; preserves their order without introducing a syntax-only row language.
;; : (-> (List (Pair Symbol Object)) (List (Pair Symbol Object)))
(def (agentic-ai-lab-session-selector-field-rows . rows)
  rows)

;; : (-> Symbol Symbol Alist)
(def (agentic-ai-lab-session-selector-diagnostic code selector-id detail)
  (agentic-ai-lab-session-selector-field-rows
   (cons 'kind 'agentic-ai-lab.session.selector.diagnostic)
   (cons 'schema 'agentic-ai-lab.modules.session.selector.diagnostic.v1)
   (cons 'code code)
   (cons 'selector-id selector-id)
   (cons 'detail detail)
   (cons 'severity 'error)
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol Symbol String [Symbol] [Alist] PooSessionSelectorCandidate)
(def (agentic-ai-lab-session-selector-candidate candidate-id
                                          candidate-kind
                                          target-ref
                                          description
                                          required-receipt-fields
                                          . maybe-metadata)
  (agentic-ai-lab-session-require "session selector candidate id must be a symbol"
                            (symbol? candidate-id)
                            candidate-id)
  (agentic-ai-lab-session-require
   "session selector candidate kind must be workflow, transform, or agent-param"
   (agentic-ai-lab-session-selector-candidate-kind? candidate-kind)
   candidate-kind)
  (agentic-ai-lab-session-require "session selector target ref must be a symbol"
                            (symbol? target-ref)
                            target-ref)
  (agentic-ai-lab-session-require "session selector candidate description must be a string"
                            (string? description)
                            description)
  (agentic-ai-lab-session-require
   "session selector required receipt fields must be symbols"
   (agentic-ai-lab-session-every? symbol? required-receipt-fields)
   required-receipt-fields)
  (object<-alist
   (list
    (cons 'kind 'agentic-ai-lab.session.selector-candidate)
    (cons 'schema 'agentic-ai-lab.modules.session.selector-candidate.v1)
    (cons 'candidate-id candidate-id)
    (cons 'candidate-kind candidate-kind)
    (cons 'target-ref target-ref)
    (cons 'description description)
    (cons 'required-receipt-fields required-receipt-fields)
    (cons 'runtime-owner "marlin-agent-core")
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-selector-candidate? value)
  (and (object? value)
       (eq? (agentic-ai-lab-session-selector-slot value 'kind #f)
            'agentic-ai-lab.session.selector-candidate)))

;; : (-> PooSessionSelectorCandidate Symbol)
(def (agentic-ai-lab-session-selector-candidate-id candidate)
  (.ref candidate 'candidate-id))

;; : (-> PooSessionSelectorCandidate Symbol)
(def (agentic-ai-lab-session-selector-candidate-kind candidate)
  (.ref candidate 'candidate-kind))

;; : (-> PooSessionSelectorCandidate Symbol)
(def (agentic-ai-lab-session-selector-candidate-target-ref candidate)
  (.ref candidate 'target-ref))

;; : (-> PooSessionSelectorCandidate Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-selector-candidate->alist
  (candidate)
  (require agentic-ai-lab-session-require
           "session selector candidate projection requires a candidate"
           (agentic-ai-lab-session-selector-candidate? candidate)
           candidate)
  (bindings ())
  (fields
   (('kind (.ref candidate 'kind))
    ('schema (.ref candidate 'schema))
    ('candidate-id (.ref candidate 'candidate-id))
    ('candidate-kind (.ref candidate 'candidate-kind))
    ('target-ref (.ref candidate 'target-ref))
    ('description (.ref candidate 'description))
    ('required-receipt-fields (.ref candidate 'required-receipt-fields))
    ('runtime-owner (.ref candidate 'runtime-owner))
    ('runtime-executed (.ref candidate 'runtime-executed))
    ('metadata (.ref candidate 'metadata)))))

;; : (-> [PooSessionSelectorCandidate] [Alist])
(def (agentic-ai-lab-session-selector-candidates->alists candidates)
  (agentic-ai-lab-session-receipt-projection-batch
   candidates
   agentic-ai-lab-session-selector-candidate->alist
   "session selector candidate projection requires a list"))

;; : (-> [PooSessionSelectorCandidate] Alist)
(def (agentic-ai-lab-session-selector-candidate-summary candidates)
  (let loop ((remaining-candidates candidates)
             (candidate-count 0)
             (candidate-ids-rev '())
             (workflow-candidate-ids-rev '())
             (transform-candidate-ids-rev '())
             (agent-param-candidate-ids-rev '()))
    (cond
     ((null? remaining-candidates)
      (list
       (cons 'candidate-count candidate-count)
       (cons 'candidate-ids (reverse candidate-ids-rev))
       (cons 'workflow-candidate-ids
             (reverse workflow-candidate-ids-rev))
       (cons 'transform-candidate-ids
             (reverse transform-candidate-ids-rev))
       (cons 'agent-param-candidate-ids
             (reverse agent-param-candidate-ids-rev))))
    (else
      (let* ((candidate (car remaining-candidates))
             (candidate-id
              (agentic-ai-lab-session-selector-candidate-id candidate))
             (candidate-kind
              (agentic-ai-lab-session-selector-candidate-kind candidate))
             (next-candidates (cdr remaining-candidates))
             (next-count (+ candidate-count 1))
             (next-candidate-ids
              (cons candidate-id candidate-ids-rev)))
        (cond
         ((eq? candidate-kind 'workflow)
          (loop next-candidates
                next-count
                next-candidate-ids
                (cons candidate-id workflow-candidate-ids-rev)
                transform-candidate-ids-rev
                agent-param-candidate-ids-rev))
         ((eq? candidate-kind 'transform)
          (loop next-candidates
                next-count
                next-candidate-ids
                workflow-candidate-ids-rev
                (cons candidate-id transform-candidate-ids-rev)
                agent-param-candidate-ids-rev))
         (else
          (loop next-candidates
                next-count
                next-candidate-ids
                workflow-candidate-ids-rev
                transform-candidate-ids-rev
                (cons candidate-id
                      agent-param-candidate-ids-rev)))))))))

;; : (-> Symbol Symbol)
(def (agentic-ai-lab-session-selector-target-policy-key candidate-kind)
  (cond
   ((eq? candidate-kind 'workflow) 'workflow-target-refs)
   ((eq? candidate-kind 'transform) 'transform-target-refs)
   (else 'agent-param-target-refs)))

;; : (-> Alist PooSessionSelectorCandidate MaybeSymbolList)
(def (agentic-ai-lab-session-selector-candidate-known-targets selection-policy
                                                        candidate)
  (agentic-ai-lab-session-selector-policy-ref
   selection-policy
   (agentic-ai-lab-session-selector-target-policy-key
    (agentic-ai-lab-session-selector-candidate-kind candidate))
   #f))

;; : (-> Alist PooSessionSelectorCandidate Boolean)
(def (agentic-ai-lab-session-selector-candidate-resolved? selection-policy
                                                    candidate)
  (let (known-targets
        (agentic-ai-lab-session-selector-candidate-known-targets
         selection-policy
         candidate))
    (or (not known-targets)
        (if (member (agentic-ai-lab-session-selector-candidate-target-ref
                     candidate)
                    known-targets)
          #t
          #f))))

;; : (-> Symbol PooSessionSelectorCandidate Alist)
(def (agentic-ai-lab-session-selector-candidate-diagnostic selector-id candidate)
  (agentic-ai-lab-session-selector-diagnostic
   'selector-candidate-target-not-declared
   selector-id
   (agentic-ai-lab-session-selector-field-rows
    (cons 'candidate-id
     (agentic-ai-lab-session-selector-candidate-id candidate))
    (cons 'candidate-kind
     (agentic-ai-lab-session-selector-candidate-kind candidate))
    (cons 'target-ref
     (agentic-ai-lab-session-selector-candidate-target-ref candidate)))))

;; : (-> Symbol [PooSessionSelectorCandidate] Alist [Symbol] [Symbol] [Alist] Alist)
(def (agentic-ai-lab-session-selector-resolution/rev selector-id
                                                candidates
                                                selection-policy
                                                resolved-ids-rev
                                                unresolved-ids-rev
                                                diagnostics-rev)
  (cond
   ((null? candidates)
    (list (cons 'resolved-candidate-ids (reverse resolved-ids-rev))
          (cons 'unresolved-candidate-ids (reverse unresolved-ids-rev))
          (cons 'diagnostics (reverse diagnostics-rev))))
   ((agentic-ai-lab-session-selector-candidate-resolved?
     selection-policy
     (car candidates))
    (agentic-ai-lab-session-selector-resolution/rev
     selector-id
     (cdr candidates)
     selection-policy
     (cons (agentic-ai-lab-session-selector-candidate-id (car candidates))
           resolved-ids-rev)
     unresolved-ids-rev
     diagnostics-rev))
   (else
    (agentic-ai-lab-session-selector-resolution/rev
     selector-id
     (cdr candidates)
     selection-policy
     resolved-ids-rev
     (cons (agentic-ai-lab-session-selector-candidate-id (car candidates))
           unresolved-ids-rev)
     (cons (agentic-ai-lab-session-selector-candidate-diagnostic
            selector-id
            (car candidates))
           diagnostics-rev)))))

;; : (-> Symbol [PooSessionSelectorCandidate] Alist Alist)
(def (agentic-ai-lab-session-selector-resolution selector-id
                                           candidates
                                           selection-policy)
  (agentic-ai-lab-session-selector-resolution/rev selector-id
                                            candidates
                                            selection-policy
                                            '()
                                            '()
                                            '()))

;; : (-> Symbol [Symbol] Alist Boolean)
(def (agentic-ai-lab-session-selector-fallback-resolved? fallback-ref
                                                   candidate-ids
                                                   selection-policy)
  (or (if (member fallback-ref candidate-ids) #t #f)
      (let (external-fallback-refs
            (agentic-ai-lab-session-selector-policy-ref
             selection-policy
             'external-fallback-refs
             #f))
        (or (not external-fallback-refs)
            (if (member fallback-ref external-fallback-refs) #t #f)))))

;; : (-> Symbol Symbol Alist)
(def (agentic-ai-lab-session-selector-fallback-diagnostic selector-id
                                                    fallback-ref)
  (agentic-ai-lab-session-selector-diagnostic
   'selector-fallback-not-declared
   selector-id
   (agentic-ai-lab-session-selector-field-rows
    (cons 'fallback-ref fallback-ref))))

;; : PooSessionSelectorReceiptRecordStruct
(defstruct agentic-ai-lab-session-selector-receipt-record
  (selector-id
   project-id
   root-session-ref
   input-session-ref
   candidate-count
   candidate-ids
   workflow-candidate-ids
   transform-candidate-ids
   agent-param-candidate-ids
   candidates
   selection-policy
   fallback-ref
   fallback-resolved?
   resolved-candidate-ids
   unresolved-candidate-ids
   selection-state
   selected-candidate-ref
   pending-selected-result
   valid?
   diagnostic-count
   diagnostics
   handoff-required
   runtime-owner
   runtime-executed
   metadata)
  transparent: #t)

;;; Boundary: selector receipts make parent/root fallback decisions explicit for
;;; policy and sandbox isolation checks.
;; : (-> Symbol Symbol Symbol Symbol [PooSessionSelectorCandidate] Alist Symbol [Alist] PooSessionSelectorReceipt)
(def (agentic-ai-lab-session-selector-receipt selector-id
                                        project-id
                                        root-session-ref
                                        input-session-ref
                                        candidates
                                        selection-policy
                                        fallback-ref
                                        . maybe-metadata)
  (agentic-ai-lab-session-require "session selector id must be a symbol"
                            (symbol? selector-id)
                            selector-id)
  (agentic-ai-lab-session-require "session selector project id must be a symbol"
                            (symbol? project-id)
                            project-id)
  (agentic-ai-lab-session-require "session selector root ref must be a symbol"
                            (symbol? root-session-ref)
                            root-session-ref)
  (agentic-ai-lab-session-require "session selector input ref must be a symbol"
                            (symbol? input-session-ref)
                            input-session-ref)
  (agentic-ai-lab-session-require "session selector candidates must be candidate rows"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-selector-candidate?
                             candidates)
                            candidates)
  (agentic-ai-lab-session-require "session selector policy must be an alist"
                            (list? selection-policy)
                            selection-policy)
  (agentic-ai-lab-session-require "session selector fallback ref must be a symbol"
                            (symbol? fallback-ref)
                            fallback-ref)
  (let* ((candidate-summary
          (agentic-ai-lab-session-selector-candidate-summary candidates))
         (candidate-count
          (agentic-ai-lab-session-alist-ref
           candidate-summary
           'candidate-count
           0))
         (candidate-ids
          (agentic-ai-lab-session-alist-ref
           candidate-summary
           'candidate-ids
           '()))
         (workflow-candidate-ids
          (agentic-ai-lab-session-alist-ref
           candidate-summary
           'workflow-candidate-ids
           '()))
         (transform-candidate-ids
          (agentic-ai-lab-session-alist-ref
           candidate-summary
           'transform-candidate-ids
           '()))
         (agent-param-candidate-ids
          (agentic-ai-lab-session-alist-ref
           candidate-summary
           'agent-param-candidate-ids
           '()))
         (resolution
          (agentic-ai-lab-session-selector-resolution selector-id
                                                candidates
                                                selection-policy))
         (resolved-candidate-ids
          (agentic-ai-lab-session-alist-ref
           resolution
           'resolved-candidate-ids
           '()))
         (unresolved-candidate-ids
          (agentic-ai-lab-session-alist-ref
           resolution
           'unresolved-candidate-ids
           '()))
         (fallback-resolved?
          (agentic-ai-lab-session-selector-fallback-resolved?
           fallback-ref
           candidate-ids
           selection-policy))
         (diagnostics0
          (agentic-ai-lab-session-alist-ref resolution 'diagnostics '()))
         (diagnostics
          (if fallback-resolved?
            diagnostics0
            (agentic-ai-lab-session-selector-rows/tail
             diagnostics0
             (list
              (agentic-ai-lab-session-selector-fallback-diagnostic
               selector-id
               fallback-ref))))))
    (make-agentic-ai-lab-session-selector-receipt-record
     selector-id
     project-id
     root-session-ref
     input-session-ref
     candidate-count
     candidate-ids
     workflow-candidate-ids
     transform-candidate-ids
     agent-param-candidate-ids
     candidates
     selection-policy
     fallback-ref
     fallback-resolved?
     resolved-candidate-ids
     unresolved-candidate-ids
     'pending
     #f
     (agentic-ai-lab-session-selector-field-rows
      (cons 'state 'pending)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f))
     (null? diagnostics)
     (length diagnostics)
     diagnostics
     #t
     "marlin-agent-core"
     #f
     (if (null? maybe-metadata)
       '()
       (car maybe-metadata)))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-selector-receipt? value)
  (agentic-ai-lab-session-selector-receipt-record? value))

;; : (-> PooSessionSelectorReceipt Symbol)
(def (agentic-ai-lab-session-selector-receipt-selector-id receipt)
  (agentic-ai-lab-session-selector-receipt-record-selector-id receipt))

;; : (-> PooSessionSelectorReceipt [Symbol])
(def (agentic-ai-lab-session-selector-receipt-candidate-ids receipt)
  (agentic-ai-lab-session-selector-receipt-record-candidate-ids receipt))

;; : (-> PooSessionSelectorReceipt Symbol)
(def (agentic-ai-lab-session-selector-receipt-selection-state receipt)
  (agentic-ai-lab-session-selector-receipt-record-selection-state receipt))

;; : (-> PooSessionSelectorReceipt MaybeSymbol)
(def (agentic-ai-lab-session-selector-receipt-selected-candidate-ref receipt)
  (agentic-ai-lab-session-selector-receipt-record-selected-candidate-ref receipt))

;; : (-> PooSessionSelectorReceipt Boolean)
(def (agentic-ai-lab-session-selector-receipt-valid? receipt)
  (agentic-ai-lab-session-selector-receipt-record-valid? receipt))

;; : (-> PooSessionSelectorReceipt Integer)
(def (agentic-ai-lab-session-selector-receipt-diagnostic-count receipt)
  (agentic-ai-lab-session-selector-receipt-record-diagnostic-count receipt))

;; : (-> PooSessionSelectorReceipt [Alist])
(def (agentic-ai-lab-session-selector-receipt-diagnostics receipt)
  (agentic-ai-lab-session-selector-receipt-record-diagnostics receipt))

;; : (-> PooSessionSelectorReceipt Alist)
(defpoo-session-receipt-projection
  agentic-ai-lab-session-selector-receipt->alist
  (receipt)
  (require agentic-ai-lab-session-require
           "session selector projection requires a receipt"
           (agentic-ai-lab-session-selector-receipt? receipt)
           receipt)
  (bindings ())
  (fields
   (('kind 'agentic-ai-lab.session.selector-receipt)
    ('schema 'agentic-ai-lab.modules.session.selector-receipt.v1)
    ('selector-id
     (agentic-ai-lab-session-selector-receipt-record-selector-id receipt))
    ('project-id
     (agentic-ai-lab-session-selector-receipt-record-project-id receipt))
    ('root-session-ref
     (agentic-ai-lab-session-selector-receipt-record-root-session-ref
      receipt))
    ('input-session-ref
     (agentic-ai-lab-session-selector-receipt-record-input-session-ref
      receipt))
    ('candidate-count
     (agentic-ai-lab-session-selector-receipt-record-candidate-count receipt))
    ('candidate-ids
     (agentic-ai-lab-session-selector-receipt-candidate-ids receipt))
    ('workflow-candidate-ids
     (agentic-ai-lab-session-selector-receipt-record-workflow-candidate-ids
      receipt))
    ('transform-candidate-ids
     (agentic-ai-lab-session-selector-receipt-record-transform-candidate-ids
      receipt))
    ('agent-param-candidate-ids
     (agentic-ai-lab-session-selector-receipt-record-agent-param-candidate-ids
      receipt))
    ('candidates
     (agentic-ai-lab-session-selector-candidates->alists
      (agentic-ai-lab-session-selector-receipt-record-candidates receipt)))
    ('selection-policy
     (agentic-ai-lab-session-selector-receipt-record-selection-policy receipt))
    ('fallback-ref
     (agentic-ai-lab-session-selector-receipt-record-fallback-ref receipt))
    ('fallback-resolved?
     (agentic-ai-lab-session-selector-receipt-record-fallback-resolved? receipt))
    ('resolved-candidate-ids
     (agentic-ai-lab-session-selector-receipt-record-resolved-candidate-ids
      receipt))
    ('unresolved-candidate-ids
     (agentic-ai-lab-session-selector-receipt-record-unresolved-candidate-ids
      receipt))
    ('selection-state
     (agentic-ai-lab-session-selector-receipt-selection-state receipt))
    ('selected-candidate-ref
     (agentic-ai-lab-session-selector-receipt-selected-candidate-ref receipt))
    ('pending-selected-result
     (agentic-ai-lab-session-selector-receipt-record-pending-selected-result
      receipt))
    ('valid?
     (agentic-ai-lab-session-selector-receipt-valid? receipt))
    ('diagnostic-count
     (agentic-ai-lab-session-selector-receipt-diagnostic-count receipt))
    ('diagnostics
     (agentic-ai-lab-session-selector-receipt-diagnostics receipt))
    ('handoff-required
     (agentic-ai-lab-session-selector-receipt-record-handoff-required receipt))
    ('runtime-owner
     (agentic-ai-lab-session-selector-receipt-record-runtime-owner receipt))
    ('runtime-executed
     (agentic-ai-lab-session-selector-receipt-record-runtime-executed receipt))
    ('metadata
     (agentic-ai-lab-session-selector-receipt-record-metadata receipt)))))
