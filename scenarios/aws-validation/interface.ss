;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def (AWSValidation @ [] config)
  identity: 'aws-validation
  config: Config
  core:
  (.o requires: (.o) scope-contract: AWSInterfaceContract
      admissions:
      (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario)))
      exports: (validation-scope (.get config provider-directory)))
  features: (.o))
