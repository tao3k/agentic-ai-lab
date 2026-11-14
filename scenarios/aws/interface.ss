;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :tao3k/agentic-ai-lab/modules/services/opentofu/package-build OpenTofuPackageBuild.))
(.def (AWS @ [] config)
  identity: 'aws
  config: Config
  core:
  (.o scope-contract: AWSInterfaceContract
      admissions:
      (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario)))
      exports: (.cc AWSScenarioScope. scenario-config: config)
      projections:
      (let (tofu (.get config opentofu))
        (if tofu (list (.cc OpenTofuPackageBuild. module: tofu
                       configuration-projection: aws-opentofu-configuration)) '())))
  features: (.o))
