;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in "./types.ss" GiteaScopeContract)
        (only-in "./config.ss" GiteaScope))
(export Gitea)

(.def Gitea
  identity: 'services/gitea
  core:
  (.o scope-contract: GiteaScopeContract
      exports: GiteaScope))
