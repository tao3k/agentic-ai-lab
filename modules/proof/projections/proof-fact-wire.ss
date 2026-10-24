;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof fact wire schema validators and FFI projection.
;;; - Keep serialized proof facts bounded before they cross the external verifier boundary.
(export agentic-ai-lab-proof-fact-ref
        agentic-ai-lab-proof-facts-known-schema?
        agentic-ai-lab-proof-facts-required-fields
        agentic-ai-lab-proof-facts-missing-required-fields
        agentic-ai-lab-proof-facts->ffi-wire
        agentic-ai-lab-proof-facts-ffi-wire-valid?)

;; : (-> Symbol Alist Object)
(def (agentic-ai-lab-proof-fact-ref key facts)
  (let ((entry (assq key facts)))
    (if entry
      (cdr entry)
      (error "missing proof fact key" key facts))))

;; : (-> Symbol Alist Boolean)
(def (agentic-ai-lab-proof-fact-has-key? key facts)
  (if (assq key facts) #t #f))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-proof-facts-known-schema? schema)
  (case schema
    ((agentic-ai-lab.proof.composition.receipt) #t)
    ((agentic-ai-lab.proof.control-plane.handoff) #t)
    ((agentic-ai-lab.proof.scenario-gap.runtime-row) #t)
    (else #f)))

;; : (-> Symbol [Symbol])
(def (agentic-ai-lab-proof-facts-required-fields schema)
  (case schema
    ((agentic-ai-lab.proof.composition.receipt)
     '(profile-refs-ok
       overrides-scoped-ok
       modules-ordered-ok
       scenario-gate-ok
       no-runtime-execution
       accepted?
       rejection
       rejection-rule))
    ((agentic-ai-lab.proof.control-plane.handoff)
     '(policy-ready
       composition-accepted
       graph-contract-ok
       runtime-owner-external
       execution-deferred
       artifacts-declared
       accepted?
       rejection
       rejection-rule))
    ((agentic-ai-lab.proof.scenario-gap.runtime-row)
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
(def (agentic-ai-lab-proof-facts-missing-required-fields facts)
  (let ((schema (agentic-ai-lab-proof-fact-ref 'schema facts)))
    (filter
     (lambda (key)
       (not (agentic-ai-lab-proof-fact-has-key? key facts)))
     (agentic-ai-lab-proof-facts-required-fields schema))))

;; : (-> Pair Boolean)
(def (agentic-ai-lab-proof-fact-field? entry)
  (and (pair? entry)
       (not (eq? (car entry) 'schema))
       (not (eq? (car entry) 'fact-id))
       (not (eq? (car entry) 'ffi-ready?))))

;; : (-> Alist Alist)
(def (agentic-ai-lab-proof-fact-fields facts)
  (filter agentic-ai-lab-proof-fact-field? facts))

;; : (-> Alist Symbol Boolean)
(def (agentic-ai-lab-proof-facts-required-fields-present? fields schema)
  (andmap
   (lambda (key)
     (agentic-ai-lab-proof-fact-has-key? key fields))
   (agentic-ai-lab-proof-facts-required-fields schema)))

;; : (-> Alist Alist)
(def (agentic-ai-lab-proof-facts->ffi-wire facts)
  (let ((fact-schema (agentic-ai-lab-proof-fact-ref 'schema facts))
        (fact-id (agentic-ai-lab-proof-fact-ref 'fact-id facts))
        (ffi-ready? (agentic-ai-lab-proof-fact-ref 'ffi-ready? facts)))
    (unless (agentic-ai-lab-proof-facts-known-schema? fact-schema)
      (error "unknown proof fact schema" fact-schema facts))
    (let ((missing (agentic-ai-lab-proof-facts-missing-required-fields facts)))
      (unless (null? missing)
        (error "proof facts missing required fields" fact-id missing facts)))
    (unless ffi-ready?
      (error "proof facts are not FFI-ready" fact-id facts))
    (list (cons 'schema 'agentic-ai-lab.proof.ffi-wire)
          (cons 'version 1)
          (cons 'fact-schema fact-schema)
          (cons 'fact-id fact-id)
          (cons 'accepted? (agentic-ai-lab-proof-fact-ref 'accepted? facts))
          (cons 'rejection-rule
                (agentic-ai-lab-proof-fact-ref 'rejection-rule facts))
          (cons 'fields (agentic-ai-lab-proof-fact-fields facts)))))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-proof-facts-ffi-wire-valid? wire)
  (let ((schema (agentic-ai-lab-proof-fact-ref 'schema wire))
        (version (agentic-ai-lab-proof-fact-ref 'version wire))
        (fact-schema (agentic-ai-lab-proof-fact-ref 'fact-schema wire))
        (fact-id (agentic-ai-lab-proof-fact-ref 'fact-id wire))
        (fields (agentic-ai-lab-proof-fact-ref 'fields wire)))
    (and (eq? schema 'agentic-ai-lab.proof.ffi-wire)
         (equal? version 1)
         (agentic-ai-lab-proof-facts-known-schema? fact-schema)
         fact-id
         (list? fields)
         (not (null? fields))
         (agentic-ai-lab-proof-facts-required-fields-present?
          fields
          fact-schema))))
