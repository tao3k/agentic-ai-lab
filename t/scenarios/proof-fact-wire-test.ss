;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        :agentic-ai-lab/modules/proof/projections/proof-fact-wire
        :agentic-ai-lab/modules/proof/projections/composition-facts
        :agentic-ai-lab/modules/workflow/graph/control-plane-handoff-facts
        :agentic-ai-lab/modules/workflow/graph/scenario-gap-rejection-facts)

(def proof-fact-wire-test
  (test-suite "proof fact wire"
    (yuanxu-test-case "validates composition handoff and scenario wires"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof fact wire mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof fact wire expected true" label value)))

(def composition-facts
  (agentic-ai-lab-composition-contract->proof-facts
   'generated-langgraph-composition-receipt
   #t
   #t
   #t
   #t
   #t
   #f))

(assert-true 'composition-schema-known
             (agentic-ai-lab-proof-facts-known-schema?
              'agentic-ai-lab.proof.composition.receipt))
(assert-equal 'composition-required-fields
              (agentic-ai-lab-proof-facts-required-fields
               'agentic-ai-lab.proof.composition.receipt)
              '(profile-refs-ok
                overrides-scoped-ok
                modules-ordered-ok
                scenario-gate-ok
                no-runtime-execution
                accepted?
                rejection
                rejection-rule))
(assert-equal 'composition-missing-required-fields
              (agentic-ai-lab-proof-facts-missing-required-fields composition-facts)
              '())

(def composition-wire
  (agentic-ai-lab-proof-facts->ffi-wire composition-facts))

(assert-true 'composition-wire-valid
             (agentic-ai-lab-proof-facts-ffi-wire-valid? composition-wire))
(assert-equal 'composition-wire-schema
              (agentic-ai-lab-proof-fact-ref 'schema composition-wire)
              'agentic-ai-lab.proof.ffi-wire)
(assert-equal 'composition-wire-version
              (agentic-ai-lab-proof-fact-ref 'version composition-wire)
              1)
(assert-equal 'composition-fact-schema
              (agentic-ai-lab-proof-fact-ref 'fact-schema composition-wire)
              'agentic-ai-lab.proof.composition.receipt)
(assert-equal 'composition-accepted
              (agentic-ai-lab-proof-fact-ref 'accepted? composition-wire)
              #t)
(assert-equal 'composition-rejection-rule
              (agentic-ai-lab-proof-fact-ref 'rejection-rule composition-wire)
              #f)

(def incomplete-composition-facts
  '((schema . agentic-ai-lab.proof.composition.receipt)
    (fact-id . incomplete-composition)
    (profile-refs-ok . #t)
    (overrides-scoped-ok . #t)
    (modules-ordered-ok . #t)
    (scenario-gate-ok . #t)
    (accepted? . #t)
    (rejection . #f)
    (rejection-rule . #f)
    (ffi-ready? . #t)))

(assert-equal 'incomplete-composition-missing
              (agentic-ai-lab-proof-facts-missing-required-fields
               incomplete-composition-facts)
              '(no-runtime-execution))

(def handoff-facts
  (agentic-ai-lab-control-plane-handoff-contract->proof-facts
   'generated-runtime-executed-here-handoff
   #t
   #t
   #t
   #t
   #f
   #t
   'execution))

(def handoff-wire
  (agentic-ai-lab-proof-facts->ffi-wire handoff-facts))

(assert-true 'handoff-wire-valid
             (agentic-ai-lab-proof-facts-ffi-wire-valid? handoff-wire))
(assert-equal 'handoff-fact-schema
              (agentic-ai-lab-proof-fact-ref 'fact-schema handoff-wire)
              'agentic-ai-lab.proof.control-plane.handoff)
(assert-equal 'handoff-accepted
              (agentic-ai-lab-proof-fact-ref 'accepted? handoff-wire)
              #f)
(assert-equal 'handoff-rejection-rule
              (agentic-ai-lab-proof-fact-ref 'rejection-rule handoff-wire)
              'control-plane-handoff-rejected-by-execution)

(def scenario-facts
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   'generated-scenario-gap-missing-kind-runtime-row
   #t
   #t
   #f
   'accepted))

(def scenario-wire
  (agentic-ai-lab-proof-facts->ffi-wire scenario-facts))

(assert-true 'scenario-wire-valid
             (agentic-ai-lab-proof-facts-ffi-wire-valid? scenario-wire))
(assert-equal 'scenario-fact-schema
              (agentic-ai-lab-proof-fact-ref 'fact-schema scenario-wire)
              'agentic-ai-lab.proof.scenario-gap.runtime-row)
(assert-equal 'scenario-rejection-rule
              (agentic-ai-lab-proof-fact-ref 'rejection-rule scenario-wire)
              'runtime-row-rejected-by-accepted))))
