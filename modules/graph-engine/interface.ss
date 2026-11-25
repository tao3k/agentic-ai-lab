;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public GraphEngine module interface (100% pure semantic core).
;;; Unifies Acyclic FunFlow C4 DAGs, Convergent Trees (Trunk -> Subordinate
;;; Branches -> Apex), Pure Marlin Journal Handoff, Governed Context/Sandbox/
;;; Cedar Handoff, Relational ASCENT Obligation Graphs, and Tarjan SCC Cyclic
;;; Feedback Subgraphs.
;;;
;;; Real Turso/SQLite WAL execution is an OPTIONAL Yuanxu Feature (`+sqlite-turso`
;;; under `features/sqlite-turso/`) and is NEVER loaded by default pure core!

(import (only-in :clan/poo/object .def .o)
        "types.ss"
        "objects.ss"
        "funs.ss")
(export GraphEngine
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss"))

(.def GraphEngine
  identity: 'graph-engine
  tags: '(graph-engine control ascent-reconciler funflow-dag convergent-tree cyclic-scc)
  core: (.o scope-contract: GraphEngineScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/graph-engine/interface
                         obligation-graph: ObligationGraph.
                         frontier-plan: FunflowFrontierPlan.
                         context-trunk: ContextTrunk.
                         reconcile-frontier: graph-reconcile-frontier
                         plan-funflow-c4-frontier: graph-plan-funflow-c4-frontier
                         reconcile-to-fixed-point: graph-reconcile-to-fixed-point
                         reconcile-event-stream: graph-reconcile-event-stream
                         work-snapshot->obligation-graph: graph-work-snapshot->obligation-graph
                         attenuate-delegation-envelope: graph-attenuate-delegation-envelope
                         admit-delegated-execution-fence: graph-admit-delegated-execution-fence
                         make-context-trunk: graph-make-context-trunk
                         spawn-trunk-branch: graph-spawn-trunk-branch
                         execute-branch-funflow-dag: graph-execute-branch-funflow-dag
                         absorb-branch-contribution: graph-absorb-branch-contribution
                         converge-trunk-to-apex: graph-converge-trunk-to-apex
                         plan-trunk-journal-handoff: graph-plan-trunk-journal-handoff
                         project-recovered-trunk-receipt: graph-project-recovered-trunk-receipt
                         make-graph-cedar-handoff: graph-make-cedar-handoff
                         admit-graph-nono-sandbox: graph-admit-nono-sandbox
                         make-governed-context-trunk: graph-make-governed-context-trunk
                         condense-graph-sccs: graph-condense-sccs
                         execute-unified-graph: graph-execute-unified))
  features: '(sqlite-turso))
