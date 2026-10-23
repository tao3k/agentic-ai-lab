;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained human/AI capability Profiles and Scenario graph.

(import (only-in :clan/poo/object .def .o)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-module-profiles
                 yuanxu-profile-export))

(export HumanAICapabilityModule HumanCapabilityScenarioProfile)

(.def AccessProfile
  (identity 'access) (name 'access) (module 'human-ai-capability)
  (kind 'interface) (scope 'knowledge)
  (capabilities '(discover retrieve attribute))
  (guard '(all provenance attribution)))
(.def UnderstandProfile
  (identity 'understand) (name 'understand) (module 'human-ai-capability)
  (kind 'human-ai) (scope 'meaning)
  (capabilities '(contextualize inspect contest))
  (guard '(all context traceability)))
(.def ComposeProfile
  (identity 'compose) (name 'compose) (module 'human-ai-capability)
  (kind 'human-ai) (scope 'synthesis)
  (capabilities '(connect model frame))
  (guard '(all source compatibility)))
(.def QualifyProfile
  (identity 'qualify) (name 'qualify) (module 'human-ai-capability)
  (kind 'authority) (scope 'evidence)
  (capabilities '(verify constrain admit))
  (guard '(all evidence qualification)))
(.def ActProfile
  (identity 'act) (name 'act) (module 'human-ai-capability)
  (kind 'human-authority) (scope 'execution)
  (capabilities '(decide execute pause stop))
  (guard '(all human authority)))
(.def LearnProfile
  (identity 'learn) (name 'learn) (module 'human-ai-capability)
  (kind 'evidence-return) (scope 'outcomes)
  (capabilities '(record correct reuse compound))
  (guard '(all receipt continuity)))

(def HumanAICapabilityModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'agentic-ai-lab 'human-ai-capability)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'access AccessProfile)
    (yuanxu-profile-export 'understand UnderstandProfile)
    (yuanxu-profile-export 'compose ComposeProfile)
    (yuanxu-profile-export 'qualify QualifyProfile)
    (yuanxu-profile-export 'act ActProfile)
    (yuanxu-profile-export 'learn LearnProfile))))

(.def HumanCapabilityScenarioProfile
  (identity 'human-capability-scenario)
  (name 'human-capability-scenario)
  (stages
   (.o knowledge:
       (.o guard: '(all (evidence provenance) (human review))
           steps: (.o access: #t understand: #t compose: #t)
           edges:
           (.o access-understand: '(access understand)
               understand-compose: '(understand compose)))
       governed-action:
       (.o guard: '(all (qualification admitted) (authority human))
           steps: (.o qualify: #t act: #t)
           edges: (.o qualify-act: '(qualify act)))
       evidence-return:
       (.o guard: '(all (outcome recorded) (correction available))
           steps: (.o learn: #t))
       human-capability-cycle:
       (.o guard: '(all (knowledge connected) (human authority))
           steps:
           (.o knowledge: #t governed-action: #t evidence-return: #t)
           edges:
           (.o knowledge-action: '(knowledge governed-action)
               action-evidence: '(governed-action evidence-return))))))
