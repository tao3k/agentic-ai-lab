;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/proof-gate-receipts
        :agentic-ai-lab/modules/proof/projections/proof-gate-bundle)

(def proof-gate-receipts-test
  (test-suite "proof gate receipts"
    (yuanxu-test-case "assembles accepted and rejected receipt bundles"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof gate receipt mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof gate receipt expected true" label value)))

(def accepted-bundle
  (agentic-ai-lab-langgraph-user-interface-proof-gate-bundle))

(assert-true 'accepted-receipt-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid? accepted-bundle))
(assert-equal 'accepted-receipt-bundle-result
              (agentic-ai-lab-proof-fact-ref 'accepted? accepted-bundle)
              #t)

(def bad-override-receipts
  (let ((receipts (agentic-ai-lab-langgraph-user-interface-proof-receipts)))
    (list (assq 'schema receipts)
          (cons 'composition
                (list (cons 'fact-id 'langgraph-bad-override-composition)
                      (cons 'profile-refs-ok #t)
                      (cons 'overrides-scoped-ok #f)
                      (cons 'modules-ordered-ok #t)
                      (cons 'scenario-gate-ok #t)
                      (cons 'no-runtime-execution #t)))
          (assq 'scenario receipts)
          (assq 'handoff receipts))))

(def bad-override-bundle
  (agentic-ai-lab-proof-gate-receipts->bundle bad-override-receipts))

(assert-true 'bad-override-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid? bad-override-bundle))
(assert-equal 'bad-override-rejected
              (agentic-ai-lab-proof-fact-ref 'accepted? bad-override-bundle)
              #f)
(assert-equal 'bad-override-rule
              (agentic-ai-lab-proof-fact-ref
               'rejection-rule
               (agentic-ai-lab-proof-fact-ref 'composition bad-override-bundle))
              'composition-rejected-by-override-scope)

(def missing-capability-receipts
  (let ((receipts (agentic-ai-lab-langgraph-user-interface-proof-receipts)))
    (list (assq 'schema receipts)
          (assq 'composition receipts)
          (cons 'scenario
                (list (cons 'fact-id 'langgraph-missing-capability-scenario)
                      (cons 'plan-ok #t)
                      (cons 'rejections-ok #t)
                      (cons 'accepted-ok #f)))
          (assq 'handoff receipts))))

(def missing-capability-bundle
  (agentic-ai-lab-proof-gate-receipts->bundle missing-capability-receipts))

(assert-true 'missing-capability-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid? missing-capability-bundle))
(assert-equal 'missing-capability-rejected
              (agentic-ai-lab-proof-fact-ref 'accepted? missing-capability-bundle)
              #f)
(assert-equal 'missing-capability-rule
              (agentic-ai-lab-proof-fact-ref
               'rejection-rule
               (agentic-ai-lab-proof-fact-ref 'scenario missing-capability-bundle))
              'runtime-row-rejected-by-accepted)

(def runtime-owner-receipts
  (let ((receipts (agentic-ai-lab-langgraph-user-interface-proof-receipts)))
    (list (assq 'schema receipts)
          (assq 'composition receipts)
          (assq 'scenario receipts)
          (cons 'handoff
                (list (cons 'fact-id 'langgraph-runtime-owner-handoff)
                      (cons 'policy-ready #t)
                      (cons 'composition-accepted #t)
                      (cons 'graph-contract-ok #t)
                      (cons 'runtime-owner-external #f)
                      (cons 'execution-deferred #t)
                      (cons 'artifacts-declared #t))))))

(def runtime-owner-bundle
  (agentic-ai-lab-proof-gate-receipts->bundle runtime-owner-receipts))

(assert-true 'runtime-owner-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid? runtime-owner-bundle))
(assert-equal 'runtime-owner-rejected
              (agentic-ai-lab-proof-fact-ref 'accepted? runtime-owner-bundle)
              #f)
(assert-equal 'runtime-boundary-failed
              (agentic-ai-lab-proof-fact-ref
               'runtime-boundary-ok?
               runtime-owner-bundle)
              #f))))
