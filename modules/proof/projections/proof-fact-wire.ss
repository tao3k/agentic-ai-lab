;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof fact wire schema validators and FFI projection.
;;; - Keep serialized proof facts bounded before they cross the external verifier boundary.
(export poo-flow-proof-fact-ref
        poo-flow-proof-facts-known-schema?
        poo-flow-proof-facts-required-fields
        poo-flow-proof-facts-missing-required-fields
        poo-flow-proof-facts->ffi-wire
        poo-flow-proof-facts-ffi-wire-valid?)

;; : (-> Symbol Alist Object)
(def (poo-flow-proof-fact-ref key facts)
  (let ((entry (assq key facts)))
    (if entry
      (cdr entry)
      (error "missing proof fact key" key facts))))

;; : (-> Symbol Alist Boolean)
(def (poo-flow-proof-fact-has-key? key facts)
  (if (assq key facts) #t #f))

;; : (-> Symbol Boolean)
(def (poo-flow-proof-facts-known-schema? schema)
  (case schema
    ((poo-flow.proof.composition.receipt) #t)
    ((poo-flow.proof.control-plane.handoff) #t)
    ((poo-flow.proof.scenario-gap.runtime-row) #t)
    (else #f)))

;; : (-> Symbol [Symbol])
(def (poo-flow-proof-facts-required-fields schema)
  (case schema
    ((poo-flow.proof.composition.receipt)
     '(profile-refs-ok
       overrides-scoped-ok
       modules-ordered-ok
       scenario-gate-ok
       no-runtime-execution
       accepted?
       rejection
       rejection-rule))
    ((poo-flow.proof.control-plane.handoff)
     '(policy-ready
       composition-accepted
       graph-contract-ok
       runtime-owner-external
       execution-deferred
       artifacts-declared
       accepted?
       rejection
       rejection-rule))
    ((poo-flow.proof.scenario-gap.runtime-row)
     '(plan-ok
       rejections-ok
       accepted-ok
       accepted?
       rejection
       rejection-rule))
    (else
     (error "unknown proof fact schema" schema))))

;; : (forall (v) (-> [(Pair Symbol v)] [Symbol]))
;; : (-> Alist [Symbol])
(def (poo-flow-proof-facts-missing-required-fields facts)
  (let ((schema (poo-flow-proof-fact-ref 'schema facts)))
    (filter
     (lambda (key)
       (not (poo-flow-proof-fact-has-key? key facts)))
     (poo-flow-proof-facts-required-fields schema))))

;; : (-> Pair Boolean)
(def (poo-flow-proof-fact-field? entry)
  (and (pair? entry)
       (not (eq? (car entry) 'schema))
       (not (eq? (car entry) 'fact-id))
       (not (eq? (car entry) 'ffi-ready?))))

;; : (-> Alist Alist)
(def (poo-flow-proof-fact-fields facts)
  (filter poo-flow-proof-fact-field? facts))

;; : (-> Alist Symbol Boolean)
(def (poo-flow-proof-facts-required-fields-present? fields schema)
  (andmap
   (lambda (key)
     (poo-flow-proof-fact-has-key? key fields))
   (poo-flow-proof-facts-required-fields schema)))

;; : (-> Alist Alist)
(def (poo-flow-proof-facts->ffi-wire facts)
  (let ((fact-schema (poo-flow-proof-fact-ref 'schema facts))
        (fact-id (poo-flow-proof-fact-ref 'fact-id facts))
        (ffi-ready? (poo-flow-proof-fact-ref 'ffi-ready? facts)))
    (unless (poo-flow-proof-facts-known-schema? fact-schema)
      (error "unknown proof fact schema" fact-schema facts))
    (let ((missing (poo-flow-proof-facts-missing-required-fields facts)))
      (unless (null? missing)
        (error "proof facts missing required fields" fact-id missing facts)))
    (unless ffi-ready?
      (error "proof facts are not FFI-ready" fact-id facts))
    (list (cons 'schema 'poo-flow.proof.ffi-wire)
          (cons 'version 1)
          (cons 'fact-schema fact-schema)
          (cons 'fact-id fact-id)
          (cons 'accepted? (poo-flow-proof-fact-ref 'accepted? facts))
          (cons 'rejection-rule
                (poo-flow-proof-fact-ref 'rejection-rule facts))
          (cons 'fields (poo-flow-proof-fact-fields facts)))))

;; : (-> Alist Boolean)
(def (poo-flow-proof-facts-ffi-wire-valid? wire)
  (let ((schema (poo-flow-proof-fact-ref 'schema wire))
        (version (poo-flow-proof-fact-ref 'version wire))
        (fact-schema (poo-flow-proof-fact-ref 'fact-schema wire))
        (fact-id (poo-flow-proof-fact-ref 'fact-id wire))
        (fields (poo-flow-proof-fact-ref 'fields wire)))
    (and (eq? schema 'poo-flow.proof.ffi-wire)
         (equal? version 1)
         (poo-flow-proof-facts-known-schema? fact-schema)
         fact-id
         (list? fields)
         (not (null? fields))
         (poo-flow-proof-facts-required-fields-present?
          fields
          fact-schema))))
