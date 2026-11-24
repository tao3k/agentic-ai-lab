;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; End-to-End Verification of the Unified GraphEngine:
;;;   1. FunFlow CAS DAG + C4 Parallel Frontier vs Write-Footprint / Causal Serialization
;;;      (Parallel commands = DAG speed, 0 Subagents, 0 LLM!)
;;;   2. Tarjan SCC Cycle Detection Fail-Closed
;;;   3. Shared-Context Convergent Tree (Trunk -> 3 Subordinate Branch Kinds -> Apex):
;;;      - Zero isolated subagents (must share live ContextCut, KV-Prefix, Apex)
;;;      - No Branch Trunk-Finality (branch can complete a real task, NEVER finalize Trunk)
;;;      - Trunk Cut/Epoch Drift & Cedar Revocation immediately supersede active branches
;;;        while monotonically preserving counterexample-core
;;;      - C4 Priority Absorption + ASCENT Obligation Fixpoint + Apex-Driven Cancellation

(import :std/test
        (only-in :std/list/list filter)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/number Integer)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 make-pure-task Fun task-flow
                 make-runner make-local-eager-strategy
                 make-request-only-adapter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/cas-store
                 make-funflow-cas-store)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 ParallelFrontierStrategy.)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 make-governed-funflow-runner)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/obligation-graph
                 make-obligation
                 make-hypothesis
                 make-evidence-fact
                 make-deterministic-task-node
                 make-obligation-graph)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/dag-frontier-scheduler
                 footprints-compatible?
                 plan-funflow-c4-frontier)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/synthesis-oracle
                 reconcile-once
                 reconcile-to-fixed-point)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/delegation-fence
                 make-capability-envelope)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/convergent-tree
                 make-context-trunk
                 spawn-trunk-branch
                 branch-attempt-direct-trunk-finalization
                 admit-branch-execution-step
                 execute-branch-funflow-dag
                 make-branch-contribution
                 absorb-branch-contribution
                 trunk-advance-cut-or-revoke
                 converge-trunk-to-apex))

(export graph-engine-convergent-tree-e2e-test)

(def (make-pure-runner)
  (make-governed-funflow-runner
   (make-runner (make-local-eager-strategy) (make-request-only-adapter))
   cas-store: (make-funflow-cas-store)
   env-digest: "sha256:graph-engine-tree-env-v1"))

(def (mk-pure-flow tag)
  (task-flow tag (make-pure-task tag (Fun Integer <- Integer) (lambda (x) (+ x 1)))))

(def FiveWayParallelStrategy.
  (.o (:: @ ParallelFrontierStrategy.)
      name: 'five-way-parallel-frontier
      max-concurrency: 5))

(def graph-engine-convergent-tree-e2e-test
  (test-suite "GraphEngine: FunFlow C4 DAG Frontier & Shared-Context Convergent Tree"

    ;; -----------------------------------------------------------------------
    ;; 1. Disjoint Parallel Commands = FunFlow C4 DAG (0 Subagents, 0 LLM!)
    ;;    Overlapping write footprints & A->B edges strictly serialize!
    ;; -----------------------------------------------------------------------
    (test-case "disjoint read-only commands fan out in FunFlow C4 DAG with 0 subagents while write conflicts & A->B edges serialize"
      (let* ((runner (make-pure-runner))
             (t1 (make-deterministic-task-node "diag-1" "ob-apex" "ev-1" (mk-pure-flow 'd1) 1
                                               read-footprint: '(git-status) write-footprint: '()))
             (t2 (make-deterministic-task-node "diag-2" "ob-apex" "ev-2" (mk-pure-flow 'd2) 2
                                               read-footprint: '(lint) write-footprint: '()))
             (t3 (make-deterministic-task-node "diag-3" "ob-apex" "ev-3" (mk-pure-flow 'd3) 3
                                               read-footprint: '(types) write-footprint: '()))
             (t4 (make-deterministic-task-node "diag-4" "ob-apex" "ev-4" (mk-pure-flow 'd4) 4
                                               read-footprint: '(deps) write-footprint: '()))
             (t5 (make-deterministic-task-node "diag-5" "ob-apex" "ev-5" (mk-pure-flow 'd5) 5
                                               read-footprint: '(tests) write-footprint: '()))
             (g-par (make-obligation-graph
                     "g-parallel-5"
                     obligations: (list (make-obligation "ob-apex"
                                                         required-evidence-ids: '("ev-1" "ev-2" "ev-3" "ev-4" "ev-5")))
                     det-tasks: (list t1 t2 t3 t4 t5)))
             (step1 (reconcile-once g-par funflow-runner: runner dag-strategy: FiveWayParallelStrategy.)))
        ;; All 5 disjoint read-only commands execute in ONE parallel DAG wave: 0 subagents, 0 LLM!
        (check (.ref step1 'parallel-batch-size) => 5)
        (check (.ref step1 'deferred-by-conflict) => 0)
        (check (.ref step1 'det-tasks-executed) => 5)
        (check (.ref step1 'subagents-spawned) => 0)
        (check (.ref step1 'llm-calls-used) => 0)
        (check (.ref (.ref step1 'frontier-plan) 'subagents-spawned) => 0))

      ;; Overlapping write footprint: tw-a and tw-b both write `config.ss` -> serialized!
      ;; Plus causal edge: tw-c depends on `ev-a` produced by tw-a -> runs after tw-a!
      (let* ((runner (make-pure-runner))
             (tw-a (make-deterministic-task-node "tw-a" "ob-ser" "ev-a" (mk-pure-flow 'wa) 10
                                                 read-footprint: '(config.ss) write-footprint: '(config.ss)))
             (tw-b (make-deterministic-task-node "tw-b" "ob-ser" "ev-b" (mk-pure-flow 'wb) 20
                                                 read-footprint: '(config.ss) write-footprint: '(config.ss)))
             (tw-c (make-deterministic-task-node "tw-c" "ob-ser" "ev-c" (mk-pure-flow 'wc) 30
                                                 required-evidence-ids: '("ev-a")
                                                 depends-on-tasks: '("tw-a")
                                                 read-footprint: '(config.ss) write-footprint: '()))
             (g-ser (make-obligation-graph
                     "g-serial-conflict"
                     obligations: (list (make-obligation "ob-ser"
                                                         required-evidence-ids: '("ev-a" "ev-b" "ev-c")))
                     det-tasks: (list tw-a tw-b tw-c)))
             (step1 (reconcile-once g-ser funflow-runner: runner dag-strategy: ParallelFrontierStrategy.))
             (rep (reconcile-to-fixed-point g-ser funflow-runner: runner dag-strategy: ParallelFrontierStrategy.)))
        ;; Wave 1 admits only tw-a (tw-b deferred due to write/write conflict on config.ss)
        (check (.ref step1 'parallel-batch-size) => 1)
        (check (.ref step1 'deferred-by-conflict) => 1)
        (check (.ref step1 'subagents-spawned) => 0)
        ;; Full convergence completes all 3 tasks in order with 0 LLM calls!
        (check (.ref rep 'quiescent?) => #t)
        (check (.ref rep 'total-det-tasks) => 3)
        (check (.ref rep 'total-llm-calls) => 0)
        (check (and (member "ob-ser"
                            (map (lambda (o) (.ref o 'obligation-id))
                                 (.ref (.ref rep 'final-frontier) 'discharged-obligations)))
                    #t)
               => #t)))

    ;; -----------------------------------------------------------------------
    ;; 2. Cyclic DAG Tasks Fail-Closed via Tarjan SCC
    ;; -----------------------------------------------------------------------
    (test-case "cyclic task dependencies fail closed into HumanInbox with 0 executions"
      (let* ((runner (make-pure-runner))
             (tc1 (make-deterministic-task-node "cyc-1" "ob-cyc" "ev-c1" (mk-pure-flow 'c1) 1
                                                depends-on-tasks: '("cyc-2")))
             (tc2 (make-deterministic-task-node "cyc-2" "ob-cyc" "ev-c2" (mk-pure-flow 'c2) 2
                                                depends-on-tasks: '("cyc-1")))
             (g-cyc (make-obligation-graph
                     "g-cycle"
                     obligations: (list (make-obligation "ob-cyc" required-evidence-ids: '("ev-c1" "ev-c2")))
                     det-tasks: (list tc1 tc2)))
             (step1 (reconcile-once g-cyc funflow-runner: runner)))
        (check (.ref step1 'mode) => 'blocked-on-dag-cycle)
        (check (.ref step1 'quiescent?) => #t)
        (check (.ref step1 'blocked-reason) => 'funflow-dag-cycle-detected)
        (check (.ref step1 'det-tasks-executed) => 0)
        (check (.ref step1 'llm-calls-used) => 0)))

    ;; -----------------------------------------------------------------------
    ;; 3. Shared-Context Convergent Tree:
    ;;    - Zero isolated subagents
    ;;    - No Branch Trunk-Finality (even after branch completes a real task!)
    ;;    - Cut drift / revocation supersedes active branches & keeps counterexamples
    ;;    - Full 3-branch convergence (Enrichment + Divergent + SubordinateTask) -> Apex
    ;;    - Apex-Driven Cancellation of remaining optional branches
    ;; -----------------------------------------------------------------------
    (test-case "shared-context tree enforces zero isolated subagents, no branch trunk-finality, C4 absorption, and apex-driven cancellation"
      (let* ((runner (make-pure-runner))
             (trunk-env (make-capability-envelope
                         "trunk-root"
                         allowed-caps: '(read-file query-gql run-subdag propose-patch)
                         denied-caps: '(raw-bash-exec push-main)))
             (ob-apex (make-obligation
                       "ob-apex-refactor"
                       title: "Converge refactor with diag DAG + spec detour + subtask artifact"
                       required-evidence-ids: '("ev-diag-a" "ev-diag-b" "ev-spec-doc" "ev-subtask-patch")))
             (diag-a (make-deterministic-task-node "diag-a" "ob-apex-refactor" "ev-diag-a"
                                                   (mk-pure-flow 'diag-a) 1
                                                   read-footprint: '(ast) write-footprint: '()))
             (diag-b (make-deterministic-task-node "diag-b" "ob-apex-refactor" "ev-diag-b"
                                                   (mk-pure-flow 'diag-b) 2
                                                   read-footprint: '(tests) write-footprint: '()))
             (g0 (make-obligation-graph
                  "g-tree-e2e"
                  cut: 1
                  obligations: (list ob-apex)
                  hypotheses: (list (make-hypothesis "h-race" "Race condition in cut fence")
                                    (make-hypothesis "h-cache" "Stale CAS fingerprint"))
                  det-tasks: (list diag-a diag-b)))
             (trunk0 (make-context-trunk "trunk-refactor-1" "ob-apex-refactor" g0 trunk-env))

             ;; A. Refuse isolated / unshared branch spawns (wrong cut, wrong KV-prefix, detached apex)
             (bad-cut (spawn-trunk-branch trunk0 "b-iso-cut" 'context-enrichment-detour
                                          '(read-file) "ob-apex-refactor"
                                          requested-shared-cut: 999))
             (bad-kv (spawn-trunk-branch trunk0 "b-iso-kv" 'divergent-exploration
                                         '(read-file) "ob-apex-refactor"
                                         requested-kv-prefix: "sha256:detached-prefix"))
             (bad-apex (spawn-trunk-branch trunk0 "b-iso-apex" 'subordinate-task
                                           '(run-subdag) "ob-apex-refactor"
                                           requested-apex-id: "ob-other-mission")))
        (check (.ref bad-cut 'admitted?) => #f)
        (check (.ref bad-cut 'reason) => 'isolated-or-stale-context-cut-forbidden)
        (check (.ref bad-kv 'admitted?) => #f)
        (check (.ref bad-kv 'reason) => 'unshared-kv-prefix-forbidden)
        (check (.ref bad-apex 'admitted?) => #f)
        (check (.ref bad-apex 'reason) => 'detached-apex-target-forbidden)

        ;; B. Spawn a branch at Cut 1, then advance Trunk to Cut 2 -> immediately superseded!
        (let* ((sp-stale (spawn-trunk-branch trunk0 "b-stale-cut1" 'divergent-exploration
                                             '(read-file raw-bash-exec) "ob-apex-refactor"
                                             c4-priority: 5))
               (trunk1 (.ref sp-stale 'trunk))
               (b-stale (.ref sp-stale 'branch))
               ;; Even at Cut 1, parent deny `raw-bash-exec` dominates!
               (deny-check (admit-branch-execution-step trunk1 b-stale 'raw-bash-exec))
               ;; Trunk advances to Cut 2 -> b-stale immediately becomes superseded-stale!
               (trunk2 (trunk-advance-cut-or-revoke trunk1 new-cut: 2))
               (stale-exec (admit-branch-execution-step trunk2 b-stale 'read-file))
               ;; Late contribution from b-stale is rejected from polluting Trunk, YET counterexample is preserved!
               (stale-contrib (make-branch-contribution
                               b-stale
                               exit-kind: 'completed
                               evidence-facts: (list (make-evidence-fact "ev-stale-junk" 'bad cut: 1))
                               counterexample-core: '("ce-cut1-invalidated-assumption")))
               (abs-stale (absorb-branch-contribution trunk2 stale-contrib))
               (trunk3 (.ref abs-stale 'trunk)))
          (check (.ref sp-stale 'admitted?) => #t)
          (check (.ref deny-check 'admitted?) => #f)
          (check (.ref stale-exec 'admitted?) => #f)
          (check (.ref stale-exec 'reason) => 'branch-superseded-or-closed)
          (check (.ref abs-stale 'admitted?) => #f)
          (check (.ref abs-stale 'reason) => 'branch-contribution-superseded-by-trunk-cut-or-epoch)
          (check (and (member "ce-cut1-invalidated-assumption" (.ref trunk3 'counterexample-core)) #t) => #t)

          ;; C. At live Cut 2, spawn all 3 subordinate branch kinds + 1 optional branch:
          ;;    1) ContextEnrichmentDetour (c4-priority 2)
          ;;    2) DivergentExplorationBranch (c4-priority 1)
          ;;    3) SubordinateTaskBranch (c4-priority 3) — runs its own FunFlow sub-DAG!
          ;;    4) Optional background branch (required-for-apex?: #f) — must be auto-superseded on Apex!
          (let* ((sp-detour (spawn-trunk-branch trunk3 "b-enrichment" 'context-enrichment-detour
                                                '(read-file query-gql) "ob-apex-refactor"
                                                c4-priority: 2 required-for-apex?: #t))
                 (sp-div (spawn-trunk-branch (.ref sp-detour 'trunk) "b-divergent" 'divergent-exploration
                                             '(read-file) "ob-apex-refactor"
                                             c4-priority: 1 required-for-apex?: #t))
                 (sp-task (spawn-trunk-branch (.ref sp-div 'trunk) "b-subtask" 'subordinate-task
                                              '(run-subdag propose-patch) "ob-apex-refactor"
                                              c4-priority: 3 required-for-apex?: #t))
                 (sp-opt (spawn-trunk-branch (.ref sp-task 'trunk) "b-optional-hint" 'divergent-exploration
                                             '(read-file) "ob-apex-refactor"
                                             c4-priority: 9 required-for-apex?: #f))
                 (trunk4 (.ref sp-opt 'trunk))
                 (b-detour (.ref sp-detour 'branch))
                 (b-div (.ref sp-div 'branch))
                 (b-task (.ref sp-task 'branch))

                 ;; While required branches are still active, Trunk CANNOT converge to Apex!
                 (premature-apex (converge-trunk-to-apex trunk4 funflow-runner: runner))

                 ;; SubordinateTaskBranch executes its own internal FunFlow DAG task!
                 (subtask-node (make-deterministic-task-node
                                "subtask-build-patch" "ob-apex-refactor" "ev-subtask-patch"
                                (mk-pure-flow 'subtask-patch) 42
                                read-footprint: '(module-a) write-footprint: '(overlay-a)))
                 (subtask-res (execute-branch-funflow-dag
                               trunk4 b-task (list subtask-node) 'run-subdag runner))
                 ;; Hard Invariant: Branch completed its task, YET CANNOT directly finalize Trunk!
                 (direct-fin (branch-attempt-direct-trunk-finalization b-task))

                 ;; Submit contributions from all 3 required branches (in non-C4 order: 3, 2, 1!)
                 (abs1 (absorb-branch-contribution trunk4 (.ref subtask-res 'contribution)))
                 (detour-contrib (make-branch-contribution
                                  b-detour
                                  exit-kind: 'completed
                                  evidence-facts: (list (make-evidence-fact "ev-spec-doc" 'rfc-43-spec cut: 2))
                                  counterexample-core: '("ce-detour-edge-case")))
                 (abs2 (absorb-branch-contribution (.ref abs1 'trunk) detour-contrib))
                 (div-contrib (make-branch-contribution
                               b-div
                               exit-kind: 'completed
                               hypotheses: (list (make-hypothesis "h-epoch-skew" "Grant epoch skew across overlays"))
                               counterexample-core: '("ce-cache-hypothesis-weakened")))
                 (abs3 (absorb-branch-contribution (.ref abs2 'trunk) div-contrib))
                 (trunk5 (.ref abs3 'trunk))

                 ;; Now converge Trunk to Apex!
                 (apex-res (converge-trunk-to-apex trunk5 funflow-runner: runner))
                 (trunk-final (.ref apex-res 'trunk))
                 (receipt (.ref apex-res 'apex-receipt))
                 (opt-final (car (filter (lambda (b) (equal? (.ref b 'branch-id) "b-optional-hint"))
                                         (.ref trunk-final 'branches)))))
            ;; Premature Apex blocked
            (check (.ref premature-apex 'converged?) => #f)
            (check (.ref premature-apex 'reason) => 'unclosed-serving-branches-remaining)
            ;; Subordinate branch completed its internal FunFlow DAG, still cannot finalize Trunk directly
            (check (.ref subtask-res 'admitted?) => #t)
            (check (.ref subtask-res 'can-finalize-trunk?) => #f)
            (check (.ref direct-fin 'admitted?) => #f)
            (check (.ref direct-fin 'reason) => 'branch-cannot-finalize-trunk-directly)
            ;; All 3 contributions absorbed cleanly
            (check (.ref abs1 'admitted?) => #t)
            (check (.ref abs2 'admitted?) => #t)
            (check (.ref abs3 'admitted?) => #t)
            ;; Apex converged with 0 LLM calls, deterministic C4 absorption order (1 -> 2 -> 3),
            ;; monotonic counterexample-core across ALL branches (including stale Cut 1!),
            ;; preserved competing hypotheses, and automatic Apex-Driven Cancellation of optional branch!
            (check (.ref apex-res 'converged?) => #t)
            (check (.ref trunk-final 'apex-status) => 'converged)
            (check (.ref receipt 'total-llm-calls) => 0)
            (check (.ref receipt 'total-det-tasks) => 2)
            (check (.ref receipt 'absorbed-branch-ids-c4-order)
                   => '("b-divergent" "b-enrichment" "b-subtask"))
            (check (and (member "ce-cut1-invalidated-assumption" (.ref receipt 'counterexample-core)) #t) => #t)
            (check (and (member "ce-detour-edge-case" (.ref receipt 'counterexample-core)) #t) => #t)
            (check (and (member "ce-cache-hypothesis-weakened" (.ref receipt 'counterexample-core)) #t) => #t)
            (check (.ref receipt 'hypothesis-verdict) => 'open-competition)
            (check (length (.ref receipt 'unrefuted-hypotheses)) => 3)
            (check (.ref opt-final 'status) => 'superseded-by-apex)))))))
