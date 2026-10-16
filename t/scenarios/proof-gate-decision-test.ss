;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/proof-gate-decision
        :poo-flow/modules/proof/projections/proof-gate-receipts)

(def proof-gate-decision-test
  (test-suite "proof gate decision"
    (poo-flow-test-case "derives accepted and rejected decisions"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof gate decision mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof gate decision expected true" label value)))

(def accepted-decision
  (poo-flow-langgraph-user-interface-proof-gate-decision))

(assert-true 'accepted-decision
             (poo-flow-proof-gate-decision-accepted? accepted-decision))
(assert-equal 'accepted-reasons
              (poo-flow-proof-gate-decision-rejection-reasons accepted-decision)
              '())

(def bad-override-receipts
  (let ((receipts (poo-flow-langgraph-user-interface-proof-receipts)))
    (list (assq 'schema receipts)
          (cons 'composition
                (list (cons 'fact-id 'decision-bad-override-composition)
                      (cons 'profile-refs-ok #t)
                      (cons 'overrides-scoped-ok #f)
                      (cons 'modules-ordered-ok #t)
                      (cons 'scenario-gate-ok #t)
                      (cons 'no-runtime-execution #t)))
          (assq 'scenario receipts)
          (assq 'handoff receipts))))

(def bad-override-decision
  (poo-flow-proof-gate-receipts->decision bad-override-receipts))

(assert-equal 'bad-override-accepted
              (poo-flow-proof-gate-decision-accepted? bad-override-decision)
              #f)
(assert-equal 'bad-override-reason-source
              (poo-flow-proof-fact-ref
               'source
               (car (poo-flow-proof-gate-decision-rejection-reasons
                     bad-override-decision)))
              'composition)
(assert-equal 'bad-override-reason-rule
              (poo-flow-proof-fact-ref
               'rejection-rule
               (car (poo-flow-proof-gate-decision-rejection-reasons
                     bad-override-decision)))
              'composition-rejected-by-override-scope)

(def runtime-owner-receipts
  (let ((receipts (poo-flow-langgraph-user-interface-proof-receipts)))
    (list (assq 'schema receipts)
          (assq 'composition receipts)
          (assq 'scenario receipts)
          (cons 'handoff
                (list (cons 'fact-id 'decision-runtime-owner-handoff)
                      (cons 'policy-ready #t)
                      (cons 'composition-accepted #t)
                      (cons 'graph-contract-ok #t)
                      (cons 'runtime-owner-external #f)
                      (cons 'execution-deferred #t)
                      (cons 'artifacts-declared #t))))))

(def runtime-owner-decision
  (poo-flow-proof-gate-receipts->decision runtime-owner-receipts))

(assert-equal 'runtime-owner-accepted
              (poo-flow-proof-gate-decision-accepted? runtime-owner-decision)
              #f)
(assert-equal 'runtime-owner-reason-count
              (length (poo-flow-proof-gate-decision-rejection-reasons
                       runtime-owner-decision))
              2))))
