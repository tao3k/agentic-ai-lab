;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o .cc)
        (only-in "./config.ss" Config)
        (only-in "./types.ss" ScopeContract)
        (only-in "./objects.ss" Profile.))
(export Published)

(.def (Published @ [] config)
  identity: 'langchain
  config: Config
  core: (.o scope-contract: ScopeContract
            exports: (.cc Profile. 'config config))
  features: (.o))
