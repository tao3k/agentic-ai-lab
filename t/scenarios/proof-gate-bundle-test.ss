;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/proof-gate-bundle)

(def proof-gate-bundle-test
  (test-suite "proof gate bundle"
    (poo-flow-test-case "validates accepted and rejected bundles"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof gate bundle mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof gate bundle expected true" label value)))

(def accepted-bundle
  (poo-flow-langgraph-proof-gate-bundle))

(assert-true 'accepted-bundle-valid
             (poo-flow-proof-gate-bundle-valid? accepted-bundle))
(assert-equal 'accepted-schema
              (poo-flow-proof-fact-ref 'schema accepted-bundle)
              'poo-flow.proof.gate.bundle)
(assert-equal 'accepted-runtime-boundary
              (poo-flow-proof-fact-ref 'runtime-boundary-ok? accepted-bundle)
              #t)
(assert-equal 'accepted-bundle-result
              (poo-flow-proof-fact-ref 'accepted? accepted-bundle)
              #t)
(assert-equal 'accepted-scenario-schema
              (poo-flow-proof-fact-ref
               'fact-schema
               (poo-flow-proof-fact-ref 'scenario accepted-bundle))
              'poo-flow.proof.scenario-gap.runtime-row)

(def runtime-owner-rejected-bundle
  (poo-flow-langgraph-runtime-owner-rejected-bundle))

(assert-true 'runtime-owner-bundle-valid
             (poo-flow-proof-gate-bundle-valid?
              runtime-owner-rejected-bundle))
(assert-equal 'runtime-owner-boundary
              (poo-flow-proof-fact-ref
               'runtime-boundary-ok?
               runtime-owner-rejected-bundle)
              #f)
(assert-equal 'runtime-owner-rejected
              (poo-flow-proof-fact-ref
               'accepted?
               runtime-owner-rejected-bundle)
              #f)
(assert-equal 'runtime-owner-rule
              (poo-flow-proof-fact-ref
               'rejection-rule
               (poo-flow-proof-fact-ref 'handoff
                                        runtime-owner-rejected-bundle))
              'control-plane-handoff-rejected-by-runtime-owner)

(def missing-capability-rejected-bundle
  (poo-flow-langgraph-missing-capability-rejected-bundle))

(assert-true 'missing-capability-bundle-valid
             (poo-flow-proof-gate-bundle-valid?
              missing-capability-rejected-bundle))
(assert-equal 'missing-capability-boundary
              (poo-flow-proof-fact-ref
               'runtime-boundary-ok?
               missing-capability-rejected-bundle)
              #t)
(assert-equal 'missing-capability-rejected
              (poo-flow-proof-fact-ref
               'accepted?
               missing-capability-rejected-bundle)
              #f)
(assert-equal 'missing-capability-rule
              (poo-flow-proof-fact-ref
               'rejection-rule
               (poo-flow-proof-fact-ref 'scenario
                                        missing-capability-rejected-bundle))
              'runtime-row-rejected-by-accepted))))
