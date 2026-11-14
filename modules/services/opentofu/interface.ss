;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One declarative publication. The admitted role wrapper owns compiler imports.
(import (only-in "./package-build.ss" OpenTofuPackageBuild.))
(.def OpenTofu
  identity: 'services/opentofu
  tags: '(deployment)
  core:
  (.o scope-contract: OpenTofuScopeContract
      ;; Join this publication's role values once. Reusable prototypes can have
      ;; compiled imports from another context; those are not the role bindings.
      scope: (.cc OpenTofuScope. config: Config JsonSchema: JsonSchemaScope)
      exports: scope
      package-build: (lambda () (.cc OpenTofuPackageBuild. module: scope))
      projections: (if (opentofu-service-configuration Config)
                     (list (.cc (package-build)
                               configuration-projection: opentofu-service-configuration)) '())
      admissions: (.o Config: (.o export-path: '(config) contract-path: '(types config))
                      Null: (.o export-path: '(Null) contract-path: '(types Null))))
  features: (.o))
