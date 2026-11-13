;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario: user-interface CrewAI-style composition instance.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .all-slots .o .ref .slot?)
        (only-in :std/test check-equal? test-suite)
        (only-in :clan/poo/mop element?)
        (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)

        :agentic-ai-lab/user-interface/scenarios/crewai/scenario)


(def crewai-composition
  crewai-scenario)

(def (profile-identity profile)
  (.ref profile 'identity))

(export crewai-user-composition-test)

(def crewai-user-composition-test
 (test-suite "crewai user composition"
  (yuanxu-test-case "crewai declares one reusable production composition"
    (let* ((stage-space (.ref crewai-composition 'stages))
           (stage (.ref stage-space 'production))
           (compose-payload
            (.ref crewai-composition 'profiles))
           (loop-value (.ref stage 'loop)))
      (check-equal? (element? Scenario crewai-composition) #t)
      ;; The composition declares its Case identity explicitly.
      (check-equal? (.ref crewai-composition 'name) 'crewai-scenario)
      (check-equal? (length (.ref crewai-composition 'modules))
                    1)
      (check-equal? (.all-slots stage-space) '(production))
      (check-equal? (length compose-payload) 15)
      (check-equal? (map profile-identity compose-payload)
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
