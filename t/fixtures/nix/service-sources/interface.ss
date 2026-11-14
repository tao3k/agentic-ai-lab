;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :tao3k/yuanxu/module-system/source/declaration .def))
(.def GiteaPostgreSQL
  identity: 'applications/gitea-postgresql
  core:
  (.o scope-contract: ApplicationScopeContract
      admissions: (.o Application: (.o export-path: '(Scenario) contract-path: '(types Application)))
      contributions:
      (.o postgresql-port: (.o target-owner: 'applications/gitea-postgresql target-admission: 'Application
                              export-path: '(requirements postgresql))
          gitea-port: (.o target-owner: 'applications/gitea-postgresql target-admission: 'Application
                         export-path: '(requirements gitea)))
      exports: (configured-application-scope Config))
  features: (.o))
