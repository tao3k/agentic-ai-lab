;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public loop-engine module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss"
        (only-in "control/descriptor.ss" loop-agent-role)
        (only-in "control/strategy.ss" loop-strategy-plan?)
        (only-in "control/governor.ss" loop-governor-role)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "synthesis-oracle.ss"
        "durable-event-bridge.ss"
        "delegation-fence.ss"
        (prefix-in (only-in "synthesis-oracle.ss"
                            reconcile-to-fixed-point
                            reconcile-event-stream)
                   loop-)
        (prefix-in (only-in "durable-event-bridge.ss"
                            work-snapshot->obligation-graph)
                   loop-)
        (prefix-in (only-in "delegation-fence.ss"
                            attenuate-delegation-envelope
                            admit-delegated-execution-fence)
                   loop-))
(export LoopEngine
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss")
        (import: "obligation-graph.ss")
        (import: "ascent-reconciler.ss")
        (import: "synthesis-oracle.ss")
        (import: "durable-event-bridge.ss")
        (import: "delegation-fence.ss"))

(.def LoopEngine
  identity: 'loop-engine
  tags: '(loop-engine control ascent-reconciler)
  core: (.o scope-contract: LoopEngineScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/loop-engine/interface
                         agent-role: loop-agent-role
                         strategy-plan?: loop-strategy-plan?
                         governor-role: loop-governor-role
                         obligation-graph: ObligationGraph.
                         reconcile-frontier: ascent-reconcile-frontier
                         reconcile-to-fixed-point: loop-reconcile-to-fixed-point
                         reconcile-event-stream: loop-reconcile-event-stream
                         work-snapshot->obligation-graph: loop-work-snapshot->obligation-graph
                         attenuate-delegation-envelope: loop-attenuate-delegation-envelope
                         admit-delegated-execution-fence: loop-admit-delegated-execution-fence))
  features: (.o))
