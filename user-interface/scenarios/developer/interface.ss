;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def (Developer @ [] config)
  identity: 'developer
  config: Config
  core: (.o scope-contract: DeveloperScopeContract
            exports: (.cc Developer. 'config config))
  features: (.o))
