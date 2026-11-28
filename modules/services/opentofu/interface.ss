;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; OpenTofu publication over the explicitly imported Module roles.
(import (only-in :clan/poo/object .def .o .cc)
        (only-in "./types.ss" OpenTofuScopeContract)
        (only-in "./objects.ss" OpenTofuScope. JsonSchemaScope)
        (only-in "./config.ss" Config)
        (only-in "./func.ss" opentofu-service-configuration)
        (only-in "./package-build.ss" OpenTofuPackageBuild.))
(export OpenTofu)

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
