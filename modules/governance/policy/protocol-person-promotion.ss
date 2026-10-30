;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: models protocol-person promotion facts and decisions as POO values.
;;; Invariant: promotion requires explicit provenance, commitments, and world evidence.
(import (only-in :clan/poo/object .o .ref))

(export agentic-ai-lab-provenance
        agentic-ai-lab-protocol-subject
        agentic-ai-lab-commitment
        agentic-ai-lab-promotion-intent
        agentic-ai-lab-promotion-world
        agentic-ai-lab-promotion-decision-facts
        make-agentic-ai-lab-promotion-validation-receipt
        agentic-ai-lab-promotion-validation-receipt?
        agentic-ai-lab-promotion-validation-receipt-kind
        agentic-ai-lab-promotion-validation-receipt-schema
        agentic-ai-lab-promotion-validation-receipt-promotion-id
        agentic-ai-lab-promotion-validation-receipt-candidate-digest
        agentic-ai-lab-promotion-validation-receipt-approved
        agentic-ai-lab-promotion-validation-receipt-active
        agentic-ai-lab-promotion-validation-receipt-approval-code
        agentic-ai-lab-promotion-validation-receipt-activation-code
        agentic-ai-lab-promotion-validation-receipt-approval-failures
        agentic-ai-lab-promotion-validation-receipt-activation-failures
        agentic-ai-lab-promotion-validation-receipt-checked-gates
        agentic-ai-lab-promotion-validation-receipt-evidence-root
        agentic-ai-lab-promotion-validation-receipt-materialization-id
        agentic-ai-lab-promotion-validation-receipt-injection-target
        agentic-ai-lab-promotion-validation-receipt-runtime-executed
        agentic-ai-lab-promotion-epochs-match?
        agentic-ai-lab-promotion-approved?
        agentic-ai-lab-promotion-active?
        agentic-ai-lab-promotion-intent-validate
        agentic-ai-lab-promotion-validation-receipt-approved?
        agentic-ai-lab-promotion-validation-receipt-active?
        agentic-ai-lab-promotion-validation-receipt->alist)

;; Protocol subjects are durable content identities.  The temporal role is a
;; projection over that identity, not a second identity and not a memory kind.
(def (agentic-ai-lab-provenance origin-value source-digest-value observed-at-value
                          parent-digests-value receipts-value)
  (.o (kind 'agentic-ai-lab-provenance)
      (schema 'agentic-ai-lab.provenance.draft.1)
      (origin origin-value)
      (source-digest source-digest-value)
      (observed-at observed-at-value)
      (parent-digests parent-digests-value)
      (receipts receipts-value)))

(def (agentic-ai-lab-protocol-subject subject-id-value content-digest-value
                                version-value provenance-value
                                temporal-role-value valid-from-value
                                valid-until-value invalidation-triggers-value)
  (.o (kind 'agentic-ai-lab-protocol-subject)
      (schema 'agentic-ai-lab.protocol-subject.draft.1)
      (subject-id subject-id-value)
      (content-digest content-digest-value)
      (version version-value)
      (provenance provenance-value)
      (temporal-role temporal-role-value)
      (valid-from valid-from-value)
      (valid-until valid-until-value)
      (invalidation-triggers invalidation-triggers-value)))

(def (agentic-ai-lab-commitment commitment-id-value subject-id-value
                          subject-digest-value contract-digest-value
                          scope-value authority-epoch-value status-value)
  (.o (kind 'agentic-ai-lab-commitment)
      (schema 'agentic-ai-lab.commitment.draft.1)
      (commitment-id commitment-id-value)
      (subject-id subject-id-value)
      (subject-digest subject-digest-value)
      (contract-digest contract-digest-value)
      (scope scope-value)
      (authority-epoch authority-epoch-value)
      (status status-value)))

(def (agentic-ai-lab-promotion-intent promotion-id-value candidate-digest-value
                                subject-id-value commitment-id-value
                                source-role-value target-role-value scope-value
                                bundle-epoch-value authority-epoch-value
                                proof-epoch-value evaluator-epoch-value
                                evidence-root-value materialization-id-value
                                injection-target-value rollback-target-value)
  (.o (kind 'agentic-ai-lab-promotion-intent)
      (schema 'agentic-ai-lab.promotion-intent.draft.1)
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

(def (agentic-ai-lab-promotion-world bundle-epoch-value authority-epoch-value
                               proof-epoch-value evaluator-epoch-value)
  (.o (kind 'agentic-ai-lab-promotion-world)
      (schema 'agentic-ai-lab.promotion-world.draft.1)
      (bundle-epoch bundle-epoch-value)
      (authority-epoch authority-epoch-value)
      (proof-epoch proof-epoch-value)
      (evaluator-epoch evaluator-epoch-value)))

(def (agentic-ai-lab-promotion-decision-facts cedar-permit-value
                                        lean-verified-value
                                        evaluator-applicable-value
                                        evidence-complete-value
                                        materialization-count-value
                                        injection-receipted-value)
  (.o (kind 'agentic-ai-lab-promotion-decision-facts)
      (schema 'agentic-ai-lab.promotion-decision-facts.draft.1)
      (cedar-permit? cedar-permit-value)
      (lean-verified? lean-verified-value)
      (evaluator-applicable? evaluator-applicable-value)
      (evidence-complete? evidence-complete-value)
      (materialization-count materialization-count-value)
      (injection-receipted? injection-receipted-value)))

;; The public inputs stay POO-native.  The receipt is deliberately closed so
;; callers cannot extend an approval result with unchecked fields.
(defstruct agentic-ai-lab-promotion-validation-receipt
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

(def +agentic-ai-lab-promotion-checked-gates+
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

(def (agentic-ai-lab-compact-failures values)
  (cond
   ((null? values) '())
   ((car values)
    (cons (car values) (agentic-ai-lab-compact-failures (cdr values))))
   (else
    (agentic-ai-lab-compact-failures (cdr values)))))

(def (agentic-ai-lab-promotion-approval-failures intent world facts)
  (agentic-ai-lab-compact-failures
   (list
    (and (not (eq? (.ref intent 'kind) 'agentic-ai-lab-promotion-intent))
         'invalid-promotion-intent)
    (and (not (eq? (.ref world 'kind) 'agentic-ai-lab-promotion-world))
         'invalid-promotion-world)
    (and (not (eq? (.ref facts 'kind) 'agentic-ai-lab-promotion-decision-facts))
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

(def (agentic-ai-lab-promotion-activation-failures approved? facts)
  (let (materialization-count (.ref facts 'materialization-count))
    (agentic-ai-lab-compact-failures
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

(def (agentic-ai-lab-promotion-epochs-match? intent world)
  (and (equal? (.ref intent 'expected-bundle-epoch)
               (.ref world 'bundle-epoch))
       (equal? (.ref intent 'expected-authority-epoch)
               (.ref world 'authority-epoch))
       (equal? (.ref intent 'expected-proof-epoch)
               (.ref world 'proof-epoch))
       (equal? (.ref intent 'expected-evaluator-epoch)
               (.ref world 'evaluator-epoch))))

(def (agentic-ai-lab-promotion-approved? intent world facts)
  (null? (agentic-ai-lab-promotion-approval-failures intent world facts)))

(def (agentic-ai-lab-promotion-active? intent world facts)
  (let (approved? (agentic-ai-lab-promotion-approved? intent world facts))
    (null? (agentic-ai-lab-promotion-activation-failures approved? facts))))

(def (agentic-ai-lab-promotion-intent-validate intent world facts)
  (let* ((approval-failures
          (agentic-ai-lab-promotion-approval-failures intent world facts))
         (approved? (null? approval-failures))
         (activation-failures
          (agentic-ai-lab-promotion-activation-failures approved? facts))
         (active? (null? activation-failures)))
    (make-agentic-ai-lab-promotion-validation-receipt
     'agentic-ai-lab-promotion-validation-receipt
     'agentic-ai-lab.promotion-validation-receipt.draft.1
     (.ref intent 'promotion-id)
     (.ref intent 'candidate-digest)
     approved?
     active?
     (if approved? 'promotion-approved (car approval-failures))
     (if active? 'promotion-active (car activation-failures))
     approval-failures
     activation-failures
     +agentic-ai-lab-promotion-checked-gates+
     (.ref intent 'evidence-root)
     (.ref intent 'materialization-id)
     (.ref intent 'injection-target)
     #f)))

(def (agentic-ai-lab-promotion-validation-receipt-approved? receipt)
  (and (agentic-ai-lab-promotion-validation-receipt? receipt)
       (agentic-ai-lab-promotion-validation-receipt-approved receipt)))

(def (agentic-ai-lab-promotion-validation-receipt-active? receipt)
  (and (agentic-ai-lab-promotion-validation-receipt? receipt)
       (agentic-ai-lab-promotion-validation-receipt-active receipt)))

(def (agentic-ai-lab-promotion-validation-receipt->alist receipt)
  (list
   (cons 'kind (agentic-ai-lab-promotion-validation-receipt-kind receipt))
   (cons 'schema (agentic-ai-lab-promotion-validation-receipt-schema receipt))
   (cons 'promotion-id
         (agentic-ai-lab-promotion-validation-receipt-promotion-id receipt))
   (cons 'candidate-digest
         (agentic-ai-lab-promotion-validation-receipt-candidate-digest receipt))
   (cons 'approved
         (agentic-ai-lab-promotion-validation-receipt-approved receipt))
   (cons 'active
         (agentic-ai-lab-promotion-validation-receipt-active receipt))
   (cons 'approval-code
         (agentic-ai-lab-promotion-validation-receipt-approval-code receipt))
   (cons 'activation-code
         (agentic-ai-lab-promotion-validation-receipt-activation-code receipt))
   (cons 'approval-failures
         (agentic-ai-lab-promotion-validation-receipt-approval-failures receipt))
   (cons 'activation-failures
         (agentic-ai-lab-promotion-validation-receipt-activation-failures receipt))
   (cons 'checked-gates
         (agentic-ai-lab-promotion-validation-receipt-checked-gates receipt))
   (cons 'evidence-root
         (agentic-ai-lab-promotion-validation-receipt-evidence-root receipt))
   (cons 'materialization-id
         (agentic-ai-lab-promotion-validation-receipt-materialization-id receipt))
   (cons 'injection-target
         (agentic-ai-lab-promotion-validation-receipt-injection-target receipt))
   (cons 'runtime-executed
         (agentic-ai-lab-promotion-validation-receipt-runtime-executed receipt))))
