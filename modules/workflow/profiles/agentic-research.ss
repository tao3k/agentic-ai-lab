;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained agentic-research Profiles and browser Scenario graph.

(import (only-in :clan/poo/object .def .o)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        (only-in :core/profile-composition/profile-bundle
                 poo-flow-module-profiles
                 poo-flow-profile-export))

(export AgenticResearchModule BrowserResearchScenarioProfile)

(.def ResearcherProfile
  (identity 'researcher) (name 'researcher) (module 'agentic-research)
  (kind 'agent) (scope 'research)
  (capabilities '(discover synthesize)))
(.def EvidenceCuratorProfile
  (identity 'evidence-curator) (name 'evidence-curator)
  (module 'agentic-research) (kind 'agent) (scope 'evidence)
  (capabilities '(qualify trace)))
(.def ResearchRuntimeProfile
  (identity 'runtime) (name 'runtime) (module 'agentic-research)
  (kind 'runtime) (scope 'execution)
  (capabilities '(schedule observe)))

(def AgenticResearchModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'poo-flow 'agentic-research)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'researcher ResearcherProfile)
    (poo-flow-profile-export 'evidence-curator EvidenceCuratorProfile)
    (poo-flow-profile-export 'runtime ResearchRuntimeProfile))))

(.def BrowserResearchScenarioProfile
  (identity 'browser-research-scenario)
  (name 'browser-research-scenario)
  (stages
   (.o research-case:
       (.o steps: (.o researcher: #t evidence-curator: #t)
           edges: (.o researcher-curator: '(researcher evidence-curator)))
       qualification-case:
       (.o steps: (.o evidence-curator: #t)
           proofs: (.o admissible-evidence: #t))
       real-scenario:
       (.o steps: (.o research-case: #t qualification-case: #t)
           handoffs: (.o runtime: #t)))))
