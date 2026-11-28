;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in "./types.ss" FunflowScopeContract)
        (only-in "./objects.ss" FunflowModule.)
        (only-in "./config.ss" Config))
(export Funflow)
(.def Funflow
  identity: 'funflow
  tags: '(workflow)
  core:
  (.o scope-contract: FunflowScopeContract
      exports: (.o (:: @ FunflowModule.) config: Config))
  features: (.o))
