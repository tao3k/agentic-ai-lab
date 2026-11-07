;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained agentic-research Profiles and browser Scenario graph.

(import (only-in :clan/poo/object .def .o)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-module-profiles
                 yuanxu-profile-export))

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
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'agentic-ai-lab 'agentic-research)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'researcher ResearcherProfile)
    (yuanxu-profile-export 'evidence-curator EvidenceCuratorProfile)
    (yuanxu-profile-export 'runtime ResearchRuntimeProfile))))

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
