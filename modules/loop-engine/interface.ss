;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public loop-engine module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss"
        (only-in "control/descriptor.ss" loop-agent-role)
        (only-in "control/strategy.ss" loop-strategy-plan?)
        (only-in "control/governor.ss" loop-governor-role))
(export LoopEngine
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def LoopEngine
  identity: 'loop-engine
  tags: '(loop-engine control)
  core: (.o scope-contract: LoopEngineScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/loop-engine/interface
                         agent-role: loop-agent-role
                         strategy-plan?: loop-strategy-plan?
                         governor-role: loop-governor-role))
  features: (.o))
