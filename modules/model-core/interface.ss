;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public model-core module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export ModelCore
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def ModelCore
  identity: 'model-core
  tags: '(model policy)
  core: (.o scope-contract: ModelCoreScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/model-core/interface))
  features: (.o))
