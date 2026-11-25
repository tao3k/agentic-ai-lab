;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: 100% pure GraphEngine functional combinators & non-shadowing aliases.
;;; ZERO SQLite imports — Turso/SQLite WAL lives in optional Feature `+sqlite-turso`.

(import "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "synthesis-oracle.ss"
        "durable-event-bridge.ss"
        "delegation-fence.ss"
        "convergent-tree.ss"
        "journal-handoff.ss"
        "governed-context-bridge.ss"
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
        graph-plan-trunk-journal-handoff
        graph-project-recovered-trunk-receipt
        graph-make-cedar-handoff
        graph-admit-nono-sandbox
        graph-make-governed-context-trunk
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
(def graph-plan-trunk-journal-handoff plan-trunk-journal-handoff)
(def graph-project-recovered-trunk-receipt project-recovered-trunk-receipt)
(def graph-make-cedar-handoff make-graph-cedar-handoff)
(def graph-admit-nono-sandbox admit-graph-nono-sandbox)
(def graph-make-governed-context-trunk make-governed-context-trunk)
(def graph-condense-sccs condense-graph-sccs)
(def graph-execute-unified execute-unified-graph)
