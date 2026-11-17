;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in "./config.ss" Config)
        (only-in "./types.ss" MyModuleScopeContract))
(export MyModule)

(.def (MyModule @ [] config)
  identity: 'my-module
  config: Config
  core: (.o scope-contract: MyModuleScopeContract
            exports: (.o config))
  features: (.o))
