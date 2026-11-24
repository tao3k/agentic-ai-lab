;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: GraphEngine public functional combinators and non-shadowing aliases.

(import "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "synthesis-oracle.ss"
        "durable-event-bridge.ss"
        "delegation-fence.ss"
        "convergent-tree.ss"
        "durable-tree-journal.ss"
        "cyclic-subgraph.ss")

(export (import: "ascent-reconciler.ss")
        (import: "synthesis-oracle.ss")
        (import: "durable-event-bridge.ss")
        graph-reconcile-frontier
        graph-plan-funflow-c4-frontier
        graph-reconcile-to-fixed-point
        graph-reconcile-event-stream
        graph-work-snapshot->obligation-graph
        graph-attenuate-delegation-envelope
        graph-admit-delegated-execution-fence
        graph-make-context-trunk
        graph-spawn-trunk-branch
        graph-execute-branch-funflow-dag
        graph-absorb-branch-contribution
        graph-converge-trunk-to-apex
        graph-durable-trunk-open
        graph-durable-trunk-commit-step!
        graph-durable-trunk-recover
        graph-condense-sccs
        graph-execute-unified)

(def graph-reconcile-frontier ascent-reconcile-frontier)
(def graph-plan-funflow-c4-frontier plan-funflow-c4-frontier)
(def graph-reconcile-to-fixed-point reconcile-to-fixed-point)
(def graph-reconcile-event-stream reconcile-event-stream)
(def graph-work-snapshot->obligation-graph work-snapshot->obligation-graph)
(def graph-attenuate-delegation-envelope attenuate-delegation-envelope)
(def graph-admit-delegated-execution-fence admit-delegated-execution-fence)
(def graph-make-context-trunk make-context-trunk)
(def graph-spawn-trunk-branch spawn-trunk-branch)
(def graph-execute-branch-funflow-dag execute-branch-funflow-dag)
(def graph-absorb-branch-contribution absorb-branch-contribution)
(def graph-converge-trunk-to-apex converge-trunk-to-apex)
(def graph-durable-trunk-open durable-trunk-open)
(def graph-durable-trunk-commit-step! durable-trunk-commit-step!)
(def graph-durable-trunk-recover durable-trunk-recover)
(def graph-condense-sccs condense-graph-sccs)
(def graph-execute-unified execute-unified-graph)
