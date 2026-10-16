;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: models protocol-person promotion facts and decisions as POO values.
;;; Invariant: promotion requires explicit provenance, commitments, and world evidence.
(import (only-in :clan/poo/object .o .ref))

(export poo-flow-provenance
        poo-flow-protocol-subject
        poo-flow-commitment
        poo-flow-promotion-intent
        poo-flow-promotion-world
        poo-flow-promotion-decision-facts
        make-poo-flow-promotion-validation-receipt
        poo-flow-promotion-validation-receipt?
        poo-flow-promotion-validation-receipt-kind
        poo-flow-promotion-validation-receipt-schema
        poo-flow-promotion-validation-receipt-promotion-id
        poo-flow-promotion-validation-receipt-candidate-digest
        poo-flow-promotion-validation-receipt-approved
        poo-flow-promotion-validation-receipt-active
        poo-flow-promotion-validation-receipt-approval-code
        poo-flow-promotion-validation-receipt-activation-code
        poo-flow-promotion-validation-receipt-approval-failures
        poo-flow-promotion-validation-receipt-activation-failures
        poo-flow-promotion-validation-receipt-checked-gates
        poo-flow-promotion-validation-receipt-evidence-root
        poo-flow-promotion-validation-receipt-materialization-id
        poo-flow-promotion-validation-receipt-injection-target
        poo-flow-promotion-validation-receipt-runtime-executed
        poo-flow-promotion-epochs-match?
        poo-flow-promotion-approved?
        poo-flow-promotion-active?
        poo-flow-promotion-intent-validate
        poo-flow-promotion-validation-receipt-approved?
        poo-flow-promotion-validation-receipt-active?
        poo-flow-promotion-validation-receipt->alist)

;; Protocol subjects are durable content identities.  The temporal role is a
;; projection over that identity, not a second identity and not a memory kind.
(def (poo-flow-provenance origin-value source-digest-value observed-at-value
                          parent-digests-value receipts-value)
  (.o (kind 'poo-flow-provenance)
      (schema 'poo-flow.provenance.draft.1)
      (origin origin-value)
      (source-digest source-digest-value)
      (observed-at observed-at-value)
      (parent-digests parent-digests-value)
      (receipts receipts-value)))

(def (poo-flow-protocol-subject subject-id-value content-digest-value
                                version-value provenance-value
                                temporal-role-value valid-from-value
                                valid-until-value invalidation-triggers-value)
  (.o (kind 'poo-flow-protocol-subject)
      (schema 'poo-flow.protocol-subject.draft.1)
      (subject-id subject-id-value)
      (content-digest content-digest-value)
      (version version-value)
      (provenance provenance-value)
      (temporal-role temporal-role-value)
      (valid-from valid-from-value)
      (valid-until valid-until-value)
      (invalidation-triggers invalidation-triggers-value)))

(def (poo-flow-commitment commitment-id-value subject-id-value
                          subject-digest-value contract-digest-value
                          scope-value authority-epoch-value status-value)
  (.o (kind 'poo-flow-commitment)
      (schema 'poo-flow.commitment.draft.1)
      (commitment-id commitment-id-value)
      (subject-id subject-id-value)
      (subject-digest subject-digest-value)
      (contract-digest contract-digest-value)
      (scope scope-value)
      (authority-epoch authority-epoch-value)
      (status status-value)))

(def (poo-flow-promotion-intent promotion-id-value candidate-digest-value
                                subject-id-value commitment-id-value
                                source-role-value target-role-value scope-value
                                bundle-epoch-value authority-epoch-value
                                proof-epoch-value evaluator-epoch-value
                                evidence-root-value materialization-id-value
                                injection-target-value rollback-target-value)
  (.o (kind 'poo-flow-promotion-intent)
      (schema 'poo-flow.promotion-intent.draft.1)
      (promotion-id promotion-id-value)
      (candidate-digest candidate-digest-value)
      (subject-id subject-id-value)
      (commitment-id commitment-id-value)
      (source-role source-role-value)
      (target-role target-role-value)
      (scope scope-value)
      (expected-bundle-epoch bundle-epoch-value)
      (expected-authority-epoch authority-epoch-value)
      (expected-proof-epoch proof-epoch-value)
      (expected-evaluator-epoch evaluator-epoch-value)
      (evidence-root evidence-root-value)
      (materialization-id materialization-id-value)
      (injection-target injection-target-value)
      (rollback-target rollback-target-value)))

(def (poo-flow-promotion-world bundle-epoch-value authority-epoch-value
                               proof-epoch-value evaluator-epoch-value)
  (.o (kind 'poo-flow-promotion-world)
      (schema 'poo-flow.promotion-world.draft.1)
      (bundle-epoch bundle-epoch-value)
      (authority-epoch authority-epoch-value)
      (proof-epoch proof-epoch-value)
      (evaluator-epoch evaluator-epoch-value)))

(def (poo-flow-promotion-decision-facts cedar-permit-value
                                        lean-verified-value
                                        evaluator-applicable-value
                                        evidence-complete-value
                                        materialization-count-value
                                        injection-receipted-value)
  (.o (kind 'poo-flow-promotion-decision-facts)
      (schema 'poo-flow.promotion-decision-facts.draft.1)
      (cedar-permit? cedar-permit-value)
      (lean-verified? lean-verified-value)
      (evaluator-applicable? evaluator-applicable-value)
      (evidence-complete? evidence-complete-value)
      (materialization-count materialization-count-value)
      (injection-receipted? injection-receipted-value)))

;; The public inputs stay POO-native.  The receipt is deliberately closed so
;; callers cannot extend an approval result with unchecked fields.
(defstruct poo-flow-promotion-validation-receipt
  (kind
   schema
   promotion-id
   candidate-digest
   approved
   active
   approval-code
   activation-code
   approval-failures
   activation-failures
   checked-gates
   evidence-root
   materialization-id
   injection-target
   runtime-executed)
  transparent: #t)

(def +poo-flow-promotion-checked-gates+
  '(intent-kind
    world-kind
    decision-facts-kind
    cedar-permit
    lean-verified
    bundle-epoch
    authority-epoch
    proof-epoch
    evaluator-epoch
    evaluator-applicable
    evidence-complete
    exactly-once-materialization
    injection-receipt))

(def (poo-flow-compact-failures values)
  (cond
   ((null? values) '())
   ((car values)
    (cons (car values) (poo-flow-compact-failures (cdr values))))
   (else
    (poo-flow-compact-failures (cdr values)))))

(def (poo-flow-promotion-approval-failures intent world facts)
  (poo-flow-compact-failures
   (list
    (and (not (eq? (.ref intent 'kind) 'poo-flow-promotion-intent))
         'invalid-promotion-intent)
    (and (not (eq? (.ref world 'kind) 'poo-flow-promotion-world))
         'invalid-promotion-world)
    (and (not (eq? (.ref facts 'kind) 'poo-flow-promotion-decision-facts))
         'invalid-promotion-decision-facts)
    (and (not (.ref facts 'cedar-permit?)) 'cedar-deny)
    (and (not (.ref facts 'lean-verified?)) 'lean-unverified)
    (and (not (equal? (.ref intent 'expected-bundle-epoch)
                      (.ref world 'bundle-epoch)))
         'stale-bundle-epoch)
    (and (not (equal? (.ref intent 'expected-authority-epoch)
                      (.ref world 'authority-epoch)))
         'stale-authority-epoch)
    (and (not (equal? (.ref intent 'expected-proof-epoch)
                      (.ref world 'proof-epoch)))
         'stale-proof-epoch)
    (and (not (equal? (.ref intent 'expected-evaluator-epoch)
                      (.ref world 'evaluator-epoch)))
         'stale-evaluator-epoch)
    (and (not (.ref facts 'evaluator-applicable?)) 'evaluator-inapplicable)
    (and (not (.ref facts 'evidence-complete?)) 'evidence-incomplete))))

(def (poo-flow-promotion-activation-failures approved? facts)
  (let (materialization-count (.ref facts 'materialization-count))
    (poo-flow-compact-failures
     (list
      (and (not approved?) 'approval-rejected)
      (and (not (integer? materialization-count))
           'invalid-materialization-count)
      (and (integer? materialization-count)
           (< materialization-count 1)
           'materialization-missing)
      (and (integer? materialization-count)
           (> materialization-count 1)
           'materialization-duplicate)
      (and (not (.ref facts 'injection-receipted?))
           'injection-receipt-missing)))))

(def (poo-flow-promotion-epochs-match? intent world)
  (and (equal? (.ref intent 'expected-bundle-epoch)
               (.ref world 'bundle-epoch))
       (equal? (.ref intent 'expected-authority-epoch)
               (.ref world 'authority-epoch))
       (equal? (.ref intent 'expected-proof-epoch)
               (.ref world 'proof-epoch))
       (equal? (.ref intent 'expected-evaluator-epoch)
               (.ref world 'evaluator-epoch))))

(def (poo-flow-promotion-approved? intent world facts)
  (null? (poo-flow-promotion-approval-failures intent world facts)))

(def (poo-flow-promotion-active? intent world facts)
  (let (approved? (poo-flow-promotion-approved? intent world facts))
    (null? (poo-flow-promotion-activation-failures approved? facts))))

(def (poo-flow-promotion-intent-validate intent world facts)
  (let* ((approval-failures
          (poo-flow-promotion-approval-failures intent world facts))
         (approved? (null? approval-failures))
         (activation-failures
          (poo-flow-promotion-activation-failures approved? facts))
         (active? (null? activation-failures)))
    (make-poo-flow-promotion-validation-receipt
     'poo-flow-promotion-validation-receipt
     'poo-flow.promotion-validation-receipt.draft.1
     (.ref intent 'promotion-id)
     (.ref intent 'candidate-digest)
     approved?
     active?
     (if approved? 'promotion-approved (car approval-failures))
     (if active? 'promotion-active (car activation-failures))
     approval-failures
     activation-failures
     +poo-flow-promotion-checked-gates+
     (.ref intent 'evidence-root)
     (.ref intent 'materialization-id)
     (.ref intent 'injection-target)
     #f)))

(def (poo-flow-promotion-validation-receipt-approved? receipt)
  (and (poo-flow-promotion-validation-receipt? receipt)
       (poo-flow-promotion-validation-receipt-approved receipt)))

(def (poo-flow-promotion-validation-receipt-active? receipt)
  (and (poo-flow-promotion-validation-receipt? receipt)
       (poo-flow-promotion-validation-receipt-active receipt)))

(def (poo-flow-promotion-validation-receipt->alist receipt)
  (list
   (cons 'kind (poo-flow-promotion-validation-receipt-kind receipt))
   (cons 'schema (poo-flow-promotion-validation-receipt-schema receipt))
   (cons 'promotion-id
         (poo-flow-promotion-validation-receipt-promotion-id receipt))
   (cons 'candidate-digest
         (poo-flow-promotion-validation-receipt-candidate-digest receipt))
   (cons 'approved
         (poo-flow-promotion-validation-receipt-approved receipt))
   (cons 'active
         (poo-flow-promotion-validation-receipt-active receipt))
   (cons 'approval-code
         (poo-flow-promotion-validation-receipt-approval-code receipt))
   (cons 'activation-code
         (poo-flow-promotion-validation-receipt-activation-code receipt))
   (cons 'approval-failures
         (poo-flow-promotion-validation-receipt-approval-failures receipt))
   (cons 'activation-failures
         (poo-flow-promotion-validation-receipt-activation-failures receipt))
   (cons 'checked-gates
         (poo-flow-promotion-validation-receipt-checked-gates receipt))
   (cons 'evidence-root
         (poo-flow-promotion-validation-receipt-evidence-root receipt))
   (cons 'materialization-id
         (poo-flow-promotion-validation-receipt-materialization-id receipt))
   (cons 'injection-target
         (poo-flow-promotion-validation-receipt-injection-target receipt))
   (cons 'runtime-executed
         (poo-flow-promotion-validation-receipt-runtime-executed receipt))))
