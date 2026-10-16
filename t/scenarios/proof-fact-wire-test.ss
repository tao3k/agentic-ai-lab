;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite)
        :poo-flow/modules/proof/projections/proof-fact-wire
        :poo-flow/modules/proof/projections/composition-facts
        :poo-flow/modules/workflow/graph/control-plane-handoff-facts
        :poo-flow/modules/workflow/graph/scenario-gap-rejection-facts)

(def proof-fact-wire-test
  (test-suite "proof fact wire"
    (poo-flow-test-case "validates composition handoff and scenario wires"

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "proof fact wire mismatch" label actual expected)))

(def (assert-true label value)
  (unless value
    (error "proof fact wire expected true" label value)))

(def composition-facts
  (poo-flow-composition-contract->proof-facts
   'generated-langgraph-composition-receipt
   #t
   #t
   #t
   #t
   #t
   #f))

(assert-true 'composition-schema-known
             (poo-flow-proof-facts-known-schema?
              'poo-flow.proof.composition.receipt))
(assert-equal 'composition-required-fields
              (poo-flow-proof-facts-required-fields
               'poo-flow.proof.composition.receipt)
              '(profile-refs-ok
                overrides-scoped-ok
                modules-ordered-ok
                scenario-gate-ok
                no-runtime-execution
                accepted?
                rejection
                rejection-rule))
(assert-equal 'composition-missing-required-fields
              (poo-flow-proof-facts-missing-required-fields composition-facts)
              '())

(def composition-wire
  (poo-flow-proof-facts->ffi-wire composition-facts))

(assert-true 'composition-wire-valid
             (poo-flow-proof-facts-ffi-wire-valid? composition-wire))
(assert-equal 'composition-wire-schema
              (poo-flow-proof-fact-ref 'schema composition-wire)
              'poo-flow.proof.ffi-wire)
(assert-equal 'composition-wire-version
              (poo-flow-proof-fact-ref 'version composition-wire)
              1)
(assert-equal 'composition-fact-schema
              (poo-flow-proof-fact-ref 'fact-schema composition-wire)
              'poo-flow.proof.composition.receipt)
(assert-equal 'composition-accepted
              (poo-flow-proof-fact-ref 'accepted? composition-wire)
              #t)
(assert-equal 'composition-rejection-rule
              (poo-flow-proof-fact-ref 'rejection-rule composition-wire)
              #f)

(def incomplete-composition-facts
  '((schema . poo-flow.proof.composition.receipt)
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
              (poo-flow-proof-facts-missing-required-fields
               incomplete-composition-facts)
              '(no-runtime-execution))

(def handoff-facts
  (poo-flow-control-plane-handoff-contract->proof-facts
   'generated-runtime-executed-here-handoff
   #t
   #t
   #t
   #t
   #f
   #t
   'execution))

(def handoff-wire
  (poo-flow-proof-facts->ffi-wire handoff-facts))

(assert-true 'handoff-wire-valid
             (poo-flow-proof-facts-ffi-wire-valid? handoff-wire))
(assert-equal 'handoff-fact-schema
              (poo-flow-proof-fact-ref 'fact-schema handoff-wire)
              'poo-flow.proof.control-plane.handoff)
(assert-equal 'handoff-accepted
              (poo-flow-proof-fact-ref 'accepted? handoff-wire)
              #f)
(assert-equal 'handoff-rejection-rule
              (poo-flow-proof-fact-ref 'rejection-rule handoff-wire)
              'control-plane-handoff-rejected-by-execution)

(def scenario-facts
  (poo-flow-scenario-gap-runtime-contract->proof-facts
   'generated-scenario-gap-missing-kind-runtime-row
   #t
   #t
   #f
   'accepted))

(def scenario-wire
  (poo-flow-proof-facts->ffi-wire scenario-facts))

(assert-true 'scenario-wire-valid
             (poo-flow-proof-facts-ffi-wire-valid? scenario-wire))
(assert-equal 'scenario-fact-schema
              (poo-flow-proof-fact-ref 'fact-schema scenario-wire)
              'poo-flow.proof.scenario-gap.runtime-row)
(assert-equal 'scenario-rejection-rule
              (poo-flow-proof-fact-ref 'rejection-rule scenario-wire)
              'runtime-row-rejected-by-accepted))))
