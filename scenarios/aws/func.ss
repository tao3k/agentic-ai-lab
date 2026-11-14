;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./types.ss" "./objects.ss"
        (only-in :tao3k/agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.))
(export AWSScenarioScope. aws-opentofu-configuration)

(def (aws-opentofu-configuration config)
  (.o resource: (.get config resource)))

(def ScenarioPrototype Scenario)
(.def (AWSScenarioScope. @ [] config scenario-config provider)
  config: (.get OpenTofuScope. config)
  scenario-config: #f
  Profiles: (.o Web: (.get scenario-config resource aws_instance web))
  Scenario: (.cc ScenarioPrototype 'profile (.get scenario-config resource aws_instance web))
  provider: (.get (.cc OpenTofuScope. 'config config) modules aws provider)
  types: (.o Scenario: (aws-scenario-contract
                        (.get provider types resources aws_instance value-type))))
