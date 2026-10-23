;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared pure helpers for session policy validation.

(import (only-in :std/list/list fold)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-syntax
        :agentic-ai-lab/modules/session/receipt-syntax)

(export agentic-ai-lab-session-validation-slot
        agentic-ai-lab-session-validation-alist-ref
        agentic-ai-lab-session-validation-row-ref
        agentic-ai-lab-session-policy-validation-field-rows
        agentic-ai-lab-session-validation-member?
        agentic-ai-lab-session-validation-reverse-onto
        agentic-ai-lab-session-validation-granted?
        agentic-ai-lab-session-validation-partition/rev
        agentic-ai-lab-session-validation-partition
        agentic-ai-lab-session-validation-partition-accepted
        agentic-ai-lab-session-validation-partition-rejected
        agentic-ai-lab-session-validation-partition/with-context/rev
        agentic-ai-lab-session-validation-partition/with-context
        agentic-ai-lab-session-reverse-onto
        agentic-ai-lab-session-policy-tool-attempt
        agentic-ai-lab-session-policy-tool-attempt?
        agentic-ai-lab-session-policy-tool-attempt-id
        agentic-ai-lab-session-policy-tool-attempt-trigger-ref
        agentic-ai-lab-session-policy-tool-attempt-tool-ref
        agentic-ai-lab-session-policy-tool-attempt-action
        agentic-ai-lab-session-policy-tool-attempt-resource-ref
        agentic-ai-lab-session-policy-tool-attempt-principal-ref
        agentic-ai-lab-session-policy-diagnostic
        agentic-ai-lab-session-policy-slot-value
        agentic-ai-lab-session-policy-nested-slot
        agentic-ai-lab-session-policy-context-allowed
        agentic-ai-lab-session-policy-history-allowed
        agentic-ai-lab-session-policy-channel-allowed
        agentic-ai-lab-session-policy-communication-targets
        agentic-ai-lab-session-policy-resource-capabilities
        agentic-ai-lab-session-policy-resource-accounting-owner
        agentic-ai-lab-session-policy-resource-grants
        agentic-ai-lab-session-policy-isolation-mode
        agentic-ai-lab-session-policy-isolation-sibling-context
        agentic-ai-lab-session-policy-isolation-parent-write
        agentic-ai-lab-session-policy-isolation-peer-communication
        agentic-ai-lab-session-policy-sandbox-profile-ref
        agentic-ai-lab-session-policy-sandbox-inheritance-mode
        agentic-ai-lab-session-policy-sandbox-sharing-mode
        agentic-ai-lab-session-policy-sibling-context-allowed?
        agentic-ai-lab-session-policy-denied-sibling-context-refs
        agentic-ai-lab-session-resource-grant-accounted?
        agentic-ai-lab-session-resource-policy-accounted?
        agentic-ai-lab-session-policy-partition-refs)

;; : (-> POOObject Symbol Object Object)
(def (agentic-ai-lab-session-validation-slot policy key default)
  (with-catch
   (lambda (_failure) default)
   (lambda ()
     (.ref policy key))))

;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-session-validation-alist-ref row key default)
  (agentic-ai-lab-session-alist-ref row key default))

;; : (-> Datum Symbol Object Object)
(def (agentic-ai-lab-session-validation-row-ref row key default)
  (if (list? row)
    (agentic-ai-lab-session-validation-alist-ref row key default)
    (agentic-ai-lab-session-validation-slot row key default)))

;;; Boundary: callers construct explicit field pairs; this helper preserves
;;; their order without adding a second syntax layer over ordinary values.
;; : (-> (List (Pair Symbol Object)) (List (Pair Symbol Object)))
(def (agentic-ai-lab-session-policy-validation-field-rows . rows)
  rows)

;; : (-> Datum List Boolean)
(def (agentic-ai-lab-session-validation-member? value values)
  (if (member value values) #t #f))

;; : (forall (a) (-> (List a) (List a) (List a)))
(def (agentic-ai-lab-session-validation-reverse-onto values tail)
  (if (null? values)
    tail
    (agentic-ai-lab-session-validation-reverse-onto
     (cdr values)
     (cons (car values) tail))))

;; : (-> Datum List Boolean)
(def (agentic-ai-lab-session-validation-granted? value values)
  (or (agentic-ai-lab-session-validation-member? value values)
      (agentic-ai-lab-session-validation-member? '* values)))

;; : (-> Procedure List List List SessionValidationPartition)
(def (agentic-ai-lab-session-validation-partition/rev predicate
                                                   values
                                                   accepted-rev
                                                   rejected-rev)
  (cond
   ((null? values) (list accepted-rev rejected-rev))
   ((predicate (car values))
    (agentic-ai-lab-session-validation-partition/rev
     predicate
     (cdr values)
     (cons (car values) accepted-rev)
     rejected-rev))
   (else
    (agentic-ai-lab-session-validation-partition/rev
     predicate
     (cdr values)
     accepted-rev
     (cons (car values) rejected-rev)))))

;; : (-> Procedure List SessionValidationPartition)
(def (agentic-ai-lab-session-validation-partition predicate values)
  (let* ((partition
          (agentic-ai-lab-session-validation-partition/rev
           predicate
           values
           '()
           '()))
         (accepted-values-rev (car partition))
         (rejected-values-rev (cadr partition)))
    (list (reverse accepted-values-rev)
          (reverse rejected-values-rev))))

;;; Partition selectors centralize the internal two-list protocol so receipt
;;; assembly does not repeat shape dispatch for every policy family.
;; : (-> SessionValidationPartition List)
(def (agentic-ai-lab-session-validation-partition-accepted partition)
  (car partition))

;; : (-> SessionValidationPartition List)
(def (agentic-ai-lab-session-validation-partition-rejected partition)
  (cadr partition))

;; : (forall (c a) (-> (-> c a Boolean) c (List a) (List a) (List a) SessionValidationPartition))
;; : (-> Procedure Object List List List SessionValidationPartition)
(def (agentic-ai-lab-session-validation-partition/with-context/rev predicate
                                                                context
                                                                values
                                                                accepted-rev
                                                                rejected-rev)
  (cond
   ((null? values) (list accepted-rev rejected-rev))
   ((predicate context (car values))
    (agentic-ai-lab-session-validation-partition/with-context/rev
     predicate
     context
     (cdr values)
     (cons (car values) accepted-rev)
     rejected-rev))
   (else
    (agentic-ai-lab-session-validation-partition/with-context/rev
     predicate
     context
     (cdr values)
     accepted-rev
     (cons (car values) rejected-rev)))))

;; : (forall (c a) (-> (-> c a Boolean) c (List a) SessionValidationPartition))
;; : (-> Procedure Object List SessionValidationPartition)
(def (agentic-ai-lab-session-validation-partition/with-context predicate context values)
  (let* ((partition
          (agentic-ai-lab-session-validation-partition/with-context/rev
           predicate
           context
           values
           '()
           '()))
         (accepted-values-rev (car partition))
         (rejected-values-rev (cadr partition)))
    (list (reverse accepted-values-rev)
          (reverse rejected-values-rev))))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> List List List)
(def (agentic-ai-lab-session-reverse-onto values tail)
  (foldl cons tail values))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol [Alist] PooSessionToolAttempt)
(def (agentic-ai-lab-session-policy-tool-attempt attempt-id
                                          trigger-ref
                                          tool-ref
                                          action
                                          resource-ref
                                          principal-ref
                                          . maybe-metadata)
  (agentic-ai-lab-session-require "session policy attempt id must be a symbol"
                            (symbol? attempt-id)
                            attempt-id)
  (agentic-ai-lab-session-require "session policy attempt trigger must be a symbol"
                            (symbol? trigger-ref)
                            trigger-ref)
  (agentic-ai-lab-session-require "session policy attempt tool must be a symbol"
                            (symbol? tool-ref)
                            tool-ref)
  (agentic-ai-lab-session-require "session policy attempt action must be a symbol"
                            (symbol? action)
                            action)
  (agentic-ai-lab-session-require "session policy attempt resource must be a symbol"
                            (symbol? resource-ref)
                            resource-ref)
  (agentic-ai-lab-session-require "session policy attempt principal must be a symbol"
                            (symbol? principal-ref)
                            principal-ref)
  (agentic-ai-lab-session-policy-validation-field-rows
   (cons 'kind 'agentic-ai-lab.session.policy.tool-attempt)
   (cons 'schema 'agentic-ai-lab.modules.session.policy.tool-attempt.v1)
   (cons 'attempt-id attempt-id)
   (cons 'trigger-ref trigger-ref)
   (cons 'tool-ref tool-ref)
   (cons 'action action)
   (cons 'resource-ref resource-ref)
   (cons 'principal-ref principal-ref)
   (cons 'metadata (if (null? maybe-metadata)
                     '()
                     (car maybe-metadata)))
   (cons 'runtime-executed #f)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-tool-attempt? value)
  (and (list? value)
       (eq? (agentic-ai-lab-session-validation-alist-ref value 'kind #f)
            'agentic-ai-lab.session.policy.tool-attempt)))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-id attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'attempt-id #f))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-trigger-ref attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'trigger-ref #f))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-tool-ref attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'tool-ref #f))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-action attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'action #f))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-resource-ref attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'resource-ref #f))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-policy-tool-attempt-principal-ref attempt)
  (agentic-ai-lab-session-validation-alist-ref attempt 'principal-ref #f))

;; : (-> Symbol Symbol Datum Alist)
(def (agentic-ai-lab-session-policy-diagnostic code scope-ref detail)
  (agentic-ai-lab-session-policy-validation-field-rows
   (cons 'kind 'agentic-ai-lab.session.policy.diagnostic)
   (cons 'schema 'agentic-ai-lab.modules.session.policy.diagnostic.v1)
   (cons 'code code)
   (cons 'scope-ref scope-ref)
   (cons 'detail detail)
   (cons 'severity 'error)
   (cons 'runtime-executed #f)))

;; : (-> PooSessionPolicy Symbol Object)
(def (agentic-ai-lab-session-policy-slot-value policy key default)
  (agentic-ai-lab-session-validation-slot policy key default))

;; : (-> PooSessionPolicy Symbol Object)
(def (agentic-ai-lab-session-policy-nested-slot policy key default)
  (let (slots (agentic-ai-lab-session-validation-slot policy 'policy-slots '()))
    (agentic-ai-lab-session-validation-alist-ref slots key default)))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-context-allowed policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'allowed-session-refs '()))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-history-allowed policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'allowed-records '()))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-channel-allowed policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'channel-refs '()))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-communication-targets policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'target-session-refs '()))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-resource-capabilities policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'capability-refs '()))

;; : (-> PooSessionPolicy Object)
(def (agentic-ai-lab-session-policy-resource-accounting-owner policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'accounting-owner #f))

;; : (-> PooSessionPolicy [Alist])
(def (agentic-ai-lab-session-policy-resource-grants policy)
  (agentic-ai-lab-session-policy-slot-value policy 'resource-grants '()))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-isolation-mode policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'mode #f))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-isolation-sibling-context policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'sibling-context 'denied))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-isolation-parent-write policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'parent-write 'denied))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-isolation-peer-communication policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'peer-communication 'denied))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-sandbox-profile-ref policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'profile-ref #f))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-sandbox-inheritance-mode policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'inheritance-mode #f))

;; : (-> PooSessionPolicy Symbol)
(def (agentic-ai-lab-session-policy-sandbox-sharing-mode policy)
  (agentic-ai-lab-session-policy-nested-slot policy 'sharing-mode #f))

;; : (-> PooSessionPolicy Boolean)
(def (agentic-ai-lab-session-policy-sibling-context-allowed? isolation-policy)
  (let (sibling-context
        (agentic-ai-lab-session-policy-isolation-sibling-context isolation-policy))
    (or (eq? sibling-context 'allow)
        (eq? sibling-context 'allowed)
        (eq? sibling-context 'read)
        (eq? sibling-context 'shared)
        (eq? sibling-context '*))))

;; : (-> [Symbol] [Symbol] PooSessionPolicy [Symbol])
(def (agentic-ai-lab-session-policy-denied-sibling-context-refs requested-refs
                                                           sibling-refs
                                                           isolation-policy)
  (cond
   ((agentic-ai-lab-session-policy-sibling-context-allowed? isolation-policy) '())
   ((null? requested-refs) '())
   ((agentic-ai-lab-session-validation-member? (car requested-refs) sibling-refs)
    (cons (car requested-refs)
          (agentic-ai-lab-session-policy-denied-sibling-context-refs
           (cdr requested-refs)
           sibling-refs
           isolation-policy)))
   (else
    (agentic-ai-lab-session-policy-denied-sibling-context-refs
     (cdr requested-refs)
     sibling-refs
     isolation-policy))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-session-resource-grant-accounted? grant)
  (let (payload (if (and (pair? grant) (list? (cdr grant)))
                  (cdr grant)
                  grant))
    (if (and (list? payload) (assoc 'accounting payload))
      #t
      #f)))

;; : (-> PooSessionPolicy Boolean)
(def (agentic-ai-lab-session-resource-policy-accounted? policy)
  (let (resource-grants (agentic-ai-lab-session-policy-resource-grants policy))
    (or (null? resource-grants)
        (symbol? (agentic-ai-lab-session-policy-resource-accounting-owner policy))
        (agentic-ai-lab-session-every?
         agentic-ai-lab-session-resource-grant-accounted?
         resource-grants))))

;; : (-> [Symbol] [Symbol] SessionValidationPartition)
(def (agentic-ai-lab-session-policy-partition-refs requested allowed)
  (agentic-ai-lab-session-validation-partition
   (lambda (value)
     (agentic-ai-lab-session-validation-granted? value allowed))
   requested))
