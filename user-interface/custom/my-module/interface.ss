;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def (MyModule @ [] config)
  identity: 'my-module
  config: Config
  core: (.o requires: (.o)
            scope-contract: MyModuleScopeContract
            exports: (.o config))
  features: (.o))
