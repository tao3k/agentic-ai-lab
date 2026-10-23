;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def (NullExecution @ [] config)
  identity: 'null
  config: Config
  core:
  (.o requires: (.o) scope-contract: ScopeContract
      admissions:
      (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario)))
      exports: (null-scope (.get config provider-directory)))
  features: (.o))
