;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public text module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export Text
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def Text
  identity: 'text
  tags: '(text utilities)
  core: (.o scope-contract: TextScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/text/interface))
  features: (.o))
