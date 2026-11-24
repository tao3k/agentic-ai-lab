;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public GraphEngine module interface.
;;; Unifies Acyclic FunFlow C4 DAGs, Convergent Trees (Trunk -> Subordinate
;;; Branches -> Apex), Durable SQLite WAL Recovery, Relational ASCENT
;;; Obligation Graphs, and Bounded Cyclic Feedback Subgraphs (Tarjan SCC).

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
                         durable-trunk-open: graph-durable-trunk-open
                         durable-trunk-commit-step!: graph-durable-trunk-commit-step!
                         durable-trunk-recover: graph-durable-trunk-recover
                         condense-graph-sccs: graph-condense-sccs
                         execute-unified-graph: graph-execute-unified))
  features: (.o))
