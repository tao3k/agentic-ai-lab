;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/proof-gate-bundle)

(def proof-gate-bundle-test
  (test-suite "proof gate bundle"
    (yuanxu-test-case "validates accepted and rejected bundles"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof gate bundle mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof gate bundle expected true" label value)))

(def accepted-bundle
  (agentic-ai-lab-langgraph-proof-gate-bundle))

(assert-true 'accepted-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid? accepted-bundle))
(assert-equal 'accepted-schema
              (agentic-ai-lab-proof-fact-ref 'schema accepted-bundle)
              'agentic-ai-lab.proof.gate.bundle)
(assert-equal 'accepted-runtime-boundary
              (agentic-ai-lab-proof-fact-ref 'runtime-boundary-ok? accepted-bundle)
              #t)
(assert-equal 'accepted-bundle-result
              (agentic-ai-lab-proof-fact-ref 'accepted? accepted-bundle)
              #t)
(assert-equal 'accepted-scenario-schema
              (agentic-ai-lab-proof-fact-ref
               'fact-schema
               (agentic-ai-lab-proof-fact-ref 'scenario accepted-bundle))
              'agentic-ai-lab.proof.scenario-gap.runtime-row)

(def runtime-owner-rejected-bundle
  (agentic-ai-lab-langgraph-runtime-owner-rejected-bundle))

(assert-true 'runtime-owner-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid?
              runtime-owner-rejected-bundle))
(assert-equal 'runtime-owner-boundary
              (agentic-ai-lab-proof-fact-ref
               'runtime-boundary-ok?
               runtime-owner-rejected-bundle)
              #f)
(assert-equal 'runtime-owner-rejected
              (agentic-ai-lab-proof-fact-ref
               'accepted?
               runtime-owner-rejected-bundle)
              #f)
(assert-equal 'runtime-owner-rule
              (agentic-ai-lab-proof-fact-ref
               'rejection-rule
               (agentic-ai-lab-proof-fact-ref 'handoff
                                        runtime-owner-rejected-bundle))
              'control-plane-handoff-rejected-by-runtime-owner)

(def missing-capability-rejected-bundle
  (agentic-ai-lab-langgraph-missing-capability-rejected-bundle))

(assert-true 'missing-capability-bundle-valid
             (agentic-ai-lab-proof-gate-bundle-valid?
              missing-capability-rejected-bundle))
(assert-equal 'missing-capability-boundary
              (agentic-ai-lab-proof-fact-ref
               'runtime-boundary-ok?
               missing-capability-rejected-bundle)
              #t)
(assert-equal 'missing-capability-rejected
              (agentic-ai-lab-proof-fact-ref
               'accepted?
               missing-capability-rejected-bundle)
              #f)
(assert-equal 'missing-capability-rule
              (agentic-ai-lab-proof-fact-ref
               'rejection-rule
               (agentic-ai-lab-proof-fact-ref 'scenario
                                        missing-capability-rejected-bundle))
              'runtime-row-rejected-by-accepted))))
