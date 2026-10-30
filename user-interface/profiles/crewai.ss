;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles
                 yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-profile-export
                 yuanxu-module-profiles))
(export crewai CrewAIModule)

(.def crewai
    (agent
     (.o (identity 'agent)
         (name 'crewai-agent)
         (contract 'role-goal-tool-memory-agent)
         (policy 'agent-tool-scope-contained)))
    (task
     (.o (identity 'task)
         (name 'crewai-task)
         (contract 'expected-output-task)
         (policy 'task-dependencies-closed)))
    (crew
     (.o (identity 'crew)
         (name 'crewai-crew)
         (contract 'agent-task-team)
         (policy 'crew-members-declared)))
    (planning
     (.o (identity 'planning)
         (name 'crewai-planning)
         (contract 'crew-planning-steps)
         (policy 'planning-before-task-dispatch)))
    (memory
     (.o (identity 'memory)
         (name 'crewai-memory)
         (contract 'crew-memory-scope)
         (policy 'memory-scope-contained)))
    (knowledge
     (.o (identity 'knowledge)
         (name 'crewai-knowledge)
         (contract 'crew-knowledge-source)
         (policy 'knowledge-sources-declared)))
    (sequential-process
     (.o (identity 'sequential-process)
         (name 'crewai-sequential-process)
         (contract 'ordered-task-process)
         (policy 'task-order-respects-dependencies)))
    (hierarchical-process
     (.o (identity 'hierarchical-process)
         (name 'crewai-hierarchical-process)
         (contract 'manager-delegates-to-agents)
         (policy 'delegation-targets-declared)))
    (flow-state
     (.o (identity 'flow-state)
         (name 'crewai-flow-state)
         (contract 'shared-flow-state)
         (policy 'state-updates-owned-by-step)))
    (flow-router
     (.o (identity 'flow-router)
         (name 'crewai-flow-router)
         (contract 'start-listen-router-control)
         (policy 'router-targets-declared)))
    (flow-persist
     (.o (identity 'flow-persist)
         (name 'crewai-flow-persist)
         (contract 'persist-resume-flow-state)
         (policy 'checkpoint-before-resume)))
    (guardrail
     (.o (identity 'guardrail)
         (name 'crewai-guardrail)
         (contract 'task-output-guardrail)
         (policy 'guardrail-before-downstream-task)))
    (human-input
     (.o (identity 'human-input)
         (name 'crewai-human-input)
         (contract 'human-review-trigger)
         (policy 'human-review-before-final-output)))
    (observability
     (.o (identity 'observability)
         (name 'crewai-observability)
         (contract 'flow-usage-and-trace)
         (policy 'trace-covers-agent-task-flow)))
    (runtime-handoff
     (.o (identity 'runtime-handoff)
         (name 'crewai-runtime-handoff)
         (contract 'external-runtime-execution)
         (policy 'handoff-after-proof-gate))))

(def CrewAIModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'user-interface 'crewai)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'agent (.ref crewai 'agent))
    (yuanxu-profile-export 'task (.ref crewai 'task))
    (yuanxu-profile-export 'crew (.ref crewai 'crew))
    (yuanxu-profile-export 'planning (.ref crewai 'planning))
    (yuanxu-profile-export 'memory (.ref crewai 'memory))
    (yuanxu-profile-export 'knowledge (.ref crewai 'knowledge))
    (yuanxu-profile-export 'sequential-process (.ref crewai 'sequential-process))
    (yuanxu-profile-export 'hierarchical-process (.ref crewai 'hierarchical-process))
    (yuanxu-profile-export 'flow-state (.ref crewai 'flow-state))
    (yuanxu-profile-export 'flow-router (.ref crewai 'flow-router))
    (yuanxu-profile-export 'flow-persist (.ref crewai 'flow-persist))
    (yuanxu-profile-export 'guardrail (.ref crewai 'guardrail))
    (yuanxu-profile-export 'human-input (.ref crewai 'human-input))
    (yuanxu-profile-export 'observability (.ref crewai 'observability))
    (yuanxu-profile-export 'runtime-handoff (.ref crewai 'runtime-handoff)))))
