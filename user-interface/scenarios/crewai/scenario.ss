(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        (only-in :agentic-ai-lab/init agentic-ai-lab.init.exports)
        (only-in :clan/poo/object .get))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Reusable Scenario: runtime Profile selection plus noun-slot metadata.

(import (only-in :clan/poo/object .def .o)
        (only-in :tao3k/yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :tao3k/yuanxu/profile-composition/selection-syntax
        )

(export CrewAIProductionProfile crewai-scenario)

(.def CrewAIProductionProfile
  (identity 'crewai-production)
  (stages
   (.o production:
       (.o graph: 'crewai-flow-graph
           loop: (.o fuel: 6 exit: 'final-output)
           proofs:
           (.o agent-tool-scope-contained: #t
               task-dependencies-closed: #t
               crew-members-declared: #t
               planning-before-task-dispatch: #t
               memory-scope-contained: #t
               knowledge-sources-declared: #t
               task-order-respects-dependencies: #t
               router-targets-declared: #t
               checkpoint-before-resume: #t
               guardrail-before-downstream-task: #t
               human-review-before-final-output: #t
               trace-covers-agent-task-flow: #t
               handoff-after-proof-gate: #t)
           handoff: 'marlin-control-plane))))

(def crewai-scenario
  (.new Scenario name: 'crewai-scenario
        config: (let ((CrewAIModule (.get agentic-ai-lab.init.exports Profiles crewai profile)))
    (compose profiles
    (use-module CrewAIModule as crew
      agent task crew planning memory knowledge sequential-process flow-state
      flow-router flow-persist guardrail human-input observability
      runtime-handoff)
    CrewAIProductionProfile))))
