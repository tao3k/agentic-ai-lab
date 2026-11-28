;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public session module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss"
        "objects.ss"
        "funs.ss"
        "syntax.ss"
        "config.ss"
        "lifecycle-gate.ss")
(export Session
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "syntax.ss")
        (import: "config.ss")
        (import: "lifecycle-gate.ss"))

(.def Session
  identity: 'session
  tags: '(session runtime)
  core: (.o scope-contract: SessionScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/session/interface
                         bundles: agentic-ai-lab-session-module-bundles))
  features: (.o))
