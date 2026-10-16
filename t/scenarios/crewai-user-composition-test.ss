;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario: user-interface CrewAI-style composition instance.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :clan/poo/object .all-slots .o .ref .slot?)
        (only-in :std/test check-equal? test-suite)
        (only-in :poo-flow/modules/module-authoring/fragment-syntax load!)
        (only-in :poo-flow/modules/workflow/scenario/case
                 poo-flow-scenario-case?)
        :poo-flow/modules/workflow/scenario/accessors
        :poo-flow/user-interface/scenarios/crewai/scenario)


(def crewai-composition
  crewai-scenario)

(def (profile-name profile)
  (.ref profile (if (.slot? profile 'name) 'name 'identity)))

(def crewai-user-composition-test
 (test-suite "crewai user composition"
  (poo-flow-test-case "crewai declares one reusable production composition"
    (let* ((stage-space (poo-flow-scenario-case-stages crewai-composition))
           (stage (.ref stage-space 'production))
           (compose-payload
            (poo-flow-scenario-case-profiles crewai-composition))
           (loop-value (.ref stage 'loop)))
      (check-equal? (poo-flow-scenario-case? crewai-composition) #t)
      (check-equal? (poo-flow-scenario-case-name crewai-composition) 'crewai)
      (check-equal? (length (poo-flow-scenario-case-modules
                             crewai-composition))
                    1)
      (check-equal? (.all-slots stage-space) '(production))
      (check-equal? (length compose-payload) 15)
      (check-equal? (map profile-name compose-payload)
                    '(agent
                      task
                      crew
                      planning
                      memory
                      knowledge
                      sequential-process
                      flow-state
                      flow-router
                      flow-persist
                      guardrail
                      human-input
                      observability
                      runtime-handoff
                      crewai-production))
      (check-equal? (.ref stage 'graph) 'crewai-flow-graph)
      (check-equal? (.ref loop-value 'fuel) 6)
      (check-equal? (.ref loop-value 'exit) 'final-output)
      (check-equal? (.all-slots (.ref stage 'proofs))
                    '(agent-tool-scope-contained
                      task-dependencies-closed
                      crew-members-declared
                      planning-before-task-dispatch
                      memory-scope-contained
                      knowledge-sources-declared
                      task-order-respects-dependencies
                      router-targets-declared
                      checkpoint-before-resume
                      guardrail-before-downstream-task
                      human-review-before-final-output
                      trace-covers-agent-task-flow
                      handoff-after-proof-gate))
      (check-equal? (.ref stage 'handoff) 'marlin-control-plane)))))
