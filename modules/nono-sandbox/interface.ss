;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public nono-sandbox module interface; all internal roles close through this file.

(import (only-in :tao3k/yuanxu/module-system/source/declaration .def)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def NonoSandbox
  identity: 'nono-sandbox
  tags: '(sandbox)
  core: (.o
            scope-contract: NonoSandboxScope
            exports: (.o profile-config: agentic-ai-lab-nono-sandbox-profile-config))
  features: (.o))
