;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export protocol-person-promotion-test)

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/policy/protocol-person-promotion)

(def provenance
  (agentic-ai-lab-provenance
   'org-bundle "source-digest-1" 101 '("parent-digest-0") '(receipt-1)))

(def subject
  (agentic-ai-lab-protocol-subject
   'subject-1 "candidate-digest-1" 3 provenance 'history 90 120
   '(model-changed repository-changed authority-epoch-changed)))

(def commitment
  (agentic-ai-lab-commitment
   'commitment-1 'subject-1 "candidate-digest-1" "contract-digest-1"
   'organization 7 'proposed))

(def intent
  (agentic-ai-lab-promotion-intent
   'promotion-1 "candidate-digest-1" 'subject-1 'commitment-1
   'history 'active 'organization 11 7 5 3 "evidence-root-1"
   'materialization-1 'org-bundle-active 'history-slot-1))

(def current-world (agentic-ai-lab-promotion-world 11 7 5 3))

(def (facts cedar? lean? evaluator? evidence? count injection?)
  (agentic-ai-lab-promotion-decision-facts
   cedar? lean? evaluator? evidence? count injection?))

(def (promotion-projection-ref projection key)
  (let (entry (assq key projection))
    (and entry (cdr entry))))

(def protocol-person-promotion-test
  (test-suite "RFC 149 protocol-person promotion"
  (yuanxu-test-case "protocol subjects keep identity, provenance, and temporal role separate"
    (check (.ref subject 'kind) => 'agentic-ai-lab-protocol-subject)
    (check (.ref subject 'content-digest) => "candidate-digest-1")
    (check (.ref subject 'temporal-role) => 'history)
    (check (.ref (.ref subject 'provenance) 'source-digest)
           => "source-digest-1")
    (check (.ref commitment 'subject-digest) => "candidate-digest-1")
    (check (.ref intent 'target-role) => 'active))

    (yuanxu-test-case "dual-engine approval plus exactly-once injection activates"
      (let (receipt
            (agentic-ai-lab-promotion-intent-validate
             intent current-world (facts #t #t #t #t 1 #t)))
        (check (agentic-ai-lab-promotion-validation-receipt? receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-approved? receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-active? receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-approval-code receipt)
               => 'promotion-approved)
        (check (agentic-ai-lab-promotion-validation-receipt-activation-code receipt)
               => 'promotion-active)
        (check (agentic-ai-lab-promotion-validation-receipt-runtime-executed receipt)
               => #f)))

    (yuanxu-test-case "Cedar deny and missing Lean proof fail closed"
      (let ((cedar
             (agentic-ai-lab-promotion-intent-validate
              intent current-world (facts #f #t #t #t 1 #t)))
            (lean
             (agentic-ai-lab-promotion-intent-validate
              intent current-world (facts #t #f #t #t 1 #t))))
        (check (agentic-ai-lab-promotion-validation-receipt-approval-code cedar)
               => 'cedar-deny)
        (check (agentic-ai-lab-promotion-validation-receipt-approved cedar) => #f)
        (check (agentic-ai-lab-promotion-validation-receipt-approval-code lean)
               => 'lean-unverified)
        (check (agentic-ai-lab-promotion-validation-receipt-active lean) => #f)))

    (yuanxu-test-case "all four epochs are part of the approval boundary"
      (let* ((stale-world (agentic-ai-lab-promotion-world 12 8 6 4))
             (receipt
              (agentic-ai-lab-promotion-intent-validate
               intent stale-world (facts #t #t #t #t 1 #t)))
             (failures
              (agentic-ai-lab-promotion-validation-receipt-approval-failures receipt)))
        (check (agentic-ai-lab-promotion-epochs-match? intent current-world) => #t)
        (check (agentic-ai-lab-promotion-epochs-match? intent stale-world) => #f)
        (check (member 'stale-bundle-epoch failures) ? values)
        (check (member 'stale-authority-epoch failures) ? values)
        (check (member 'stale-proof-epoch failures) ? values)
        (check (member 'stale-evaluator-epoch failures) ? values)))

    (yuanxu-test-case "evaluator applicability and evidence completeness are explicit"
      (let (receipt
            (agentic-ai-lab-promotion-intent-validate
             intent current-world (facts #t #t #f #f 1 #t)))
        (check (agentic-ai-lab-promotion-validation-receipt-approval-failures receipt)
               => '(evaluator-inapplicable evidence-incomplete))
        (check (agentic-ai-lab-promotion-validation-receipt-approved receipt) => #f)))

    (yuanxu-test-case "approval does not imply materialization"
      (let (receipt
            (agentic-ai-lab-promotion-intent-validate
             intent current-world (facts #t #t #t #t 0 #f)))
        (check (agentic-ai-lab-promotion-validation-receipt-approved receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-active receipt) => #f)
        (check (agentic-ai-lab-promotion-validation-receipt-activation-code receipt)
               => 'materialization-missing)))

    (yuanxu-test-case "duplicate materialization fails closed"
      (let (receipt
            (agentic-ai-lab-promotion-intent-validate
             intent current-world (facts #t #t #t #t 2 #t)))
        (check (agentic-ai-lab-promotion-validation-receipt-approved receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-active receipt) => #f)
        (check (agentic-ai-lab-promotion-validation-receipt-activation-code receipt)
               => 'materialization-duplicate)))

    (yuanxu-test-case "materialization without an injection receipt stays inactive"
      (let* ((receipt
              (agentic-ai-lab-promotion-intent-validate
               intent current-world (facts #t #t #t #t 1 #f)))
             (projection
              (agentic-ai-lab-promotion-validation-receipt->alist receipt)))
        (check (agentic-ai-lab-promotion-validation-receipt-approved receipt) => #t)
        (check (agentic-ai-lab-promotion-validation-receipt-active receipt) => #f)
        (check (agentic-ai-lab-promotion-validation-receipt-activation-code receipt)
               => 'injection-receipt-missing)
        (check (promotion-projection-ref projection 'candidate-digest)
               => "candidate-digest-1")
        (check (promotion-projection-ref projection 'runtime-executed) => #f))))
  )
