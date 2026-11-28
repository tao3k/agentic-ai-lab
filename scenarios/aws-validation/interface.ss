;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o .get)
        (only-in "./config.ss" Config)
        (only-in "./types.ss" AWSInterfaceContract)
        (only-in "./func.ss" validation-scope))
(export AWSValidation)

(.def (AWSValidation @ [] config)
  identity: 'aws-validation
  config: Config
  core:
  (.o scope-contract: AWSInterfaceContract
      admissions:
      (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario)))
      exports: (validation-scope (.get config provider-directory)))
  features: (.o))
