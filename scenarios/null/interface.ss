;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o .get)
        (only-in "./config.ss" Config)
        (only-in "./types.ss" ScopeContract)
        (only-in "./func.ss" null-scope))
(export NullExecution)

(.def (NullExecution @ [] config)
  identity: 'null
  config: Config
  core:
  (.o scope-contract: ScopeContract
      admissions:
      (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario)))
      exports: (null-scope (.get config provider-directory)))
  features: (.o))
