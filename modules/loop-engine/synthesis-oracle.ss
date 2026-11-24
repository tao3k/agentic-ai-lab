;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Post-ReAct Loop Engine Core — Module 3:
;;; Stateless Typed Leaf `SynthesisOracle` Gate + Dual-Mode (Batch Fixed-Point
;;; & Event-Driven Reactive) Reconciler Driver (`modules/loop-engine/synthesis-oracle.ss`).
;;;
;;; Strictly enforces:
;;; 1. ZERO raw single-step ReAct tool calls from the LLM oracle (`raw-single-step-tool-call-forbidden`).
;;; 2. Oracle may emit ONLY:
;;;    - `TypedFunflowDagPatch.` (contract-checked FunFlow tasks + Slice 55 MCP/CaMeL/MindGuard + Slice 52 nono-sandbox)
;;;    - `BoundedCompetingBranches.` (bounded POO branches evaluated against EVERY active hypothesis!)
;;; 3. Deterministic FunFlow frontier executes FIRST via `GovernedFunflowRunner.` (`0 LLM calls`).
;;; 4. Every synthesis hole `(hole-id . premise-digest)` is permanently marked attempted
;;;    before merging so Datalog fixed-point quiescence holds unconditionally.
;;; 5. Dual-Mode execution:
;;;    - `reconcile-to-fixed-point`: offline deterministic batch convergence
;;;    - `reconcile-event-stream`:   event-driven Durable Work / Journal incremental reconciliation

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every filter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 flow? adapter-result? adapter-result-value)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 governed-funflow-run)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-assembly-pipeline
                 agentic-ai-lab-ai-agentic-context-assemble-governed-turn)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-trust-lattice
                 agentic-ai-lab-ai-agentic-context-admit-mcp-tool-registration
                 agentic-ai-lab-ai-agentic-context-admit-camel-sensitive-sink
                 agentic-ai-lab-ai-agentic-context-audit-tool-metadata-decision-dependence
                 agentic-ai-lab-ai-agentic-context-replay-audit-capsule)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest)
        "obligation-graph.ss"
        "ascent-reconciler.ss")

(export make-typed-funflow-dag-patch
        make-bounded-competing-branches
        make-raw-tool-call-proposal
        admit-synthesis-proposal
        evaluate-competing-branches
        reconcile-once
        reconcile-to-fixed-point
        reconcile-event-stream)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (first-failing results)
  (let loop ((xs results))
    (cond
     ((null? xs) #f)
     ((not (.ref (car xs) 'admitted?)) (car xs))
     (else (loop (cdr xs))))))

;;; ---------------------------------------------------------------------------
;;; 1. Typed Oracle Proposal Constructors (Zero Raw ReAct Tool Calls!)
;;; ---------------------------------------------------------------------------

(def (make-typed-funflow-dag-patch
      tasks
      mcp-registrations: (mcp-registrations '())
      camel-sink-checks: (camel-sink-checks '())
      mindguard-audit: (mindguard-audit #f))
  (.o bind-these: #f
      kind: 'typed-funflow-dag-patch
      tasks: tasks
      mcp-registrations: mcp-registrations
      camel-sink-checks: camel-sink-checks
      mindguard-audit: mindguard-audit))

(def (make-bounded-competing-branches
      branches
      mcp-registrations: (mcp-registrations '())
      camel-sink-checks: (camel-sink-checks '())
      mindguard-audit: (mindguard-audit #f))
  (.o bind-these: #f
      kind: 'bounded-competing-branches
      branches: branches
      mcp-registrations: mcp-registrations
      camel-sink-checks: camel-sink-checks
      mindguard-audit: mindguard-audit))

;;; Negative-control constructor representing a forbidden ReAct single-step tool call.
(def (make-raw-tool-call-proposal tool-name args)
  (.o bind-these: #f
      kind: 'raw-single-step-tool-call
      tool-name: tool-name
      args: args))

;;; Evaluates EVERY bounded POO branch against EVERY active hypothesis in the
;;; graph, preserving competing hypotheses, contradictions, defeaters, and open
;;; questions — NEVER collapsing to a single "next" step or likelihood ranking
;;; inferred from missing-claim counts.
(def (evaluate-competing-branches branches hypotheses)
  (let ((rows
         (map (lambda (br)
                (let* ((bid (.ref br 'branch-id))
                       (supports (opt-ref br 'supports-hypotheses '()))
                       (contradicts (opt-ref br 'contradicts-hypotheses '()))
                       (open-qs (opt-ref br 'open-questions '()))
                       (assessments
                        (map (lambda (h)
                               (let ((hid (.ref h 'hypothesis-id)))
                                 (.o bind-these: #f
                                     hypothesis-id: hid
                                     relation: (cond
                                                ((member hid contradicts) 'contradicts)
                                                ((member hid supports) 'consistent-with)
                                                (else 'undetermined))
                                     active-defeaters: (.ref h 'active-defeaters)
                                     open-questions: (append (.ref h 'open-questions) open-qs))))
                             hypotheses)))
                  (.o bind-these: #f
                      branch-id: bid
                      description: (opt-ref br 'description "")
                      hypothesis-assessments: assessments
                      action-authorized?: #f)))
              branches)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.competing-branch-matrix.v1
        branch-count: (length branches)
        hypothesis-count: (length hypotheses)
        rows: rows
        action-authorized?: #f)))

;;; Fail-closed admission gate for stateless leaf `SynthesisOracle` outputs.
(def (admit-synthesis-proposal proposal max-branches: (max-branches 4))
  (let ((pkind (opt-ref proposal 'kind #f)))
    (cond
     ((eq? pkind 'raw-single-step-tool-call)
      (.o bind-these: #f
          admitted?: #f
          reason: 'raw-single-step-tool-call-forbidden
          action-authorized?: #f))
     ((not (memq pkind '(typed-funflow-dag-patch bounded-competing-branches)))
      (.o bind-these: #f
          admitted?: #f
          reason: 'unknown-oracle-proposal-kind
          action-authorized?: #f))
     (else
      ;; Run Slice 55 MCP shadow check + CaMeL sensitive sink check + MindGuard 0-LLM audit
      (let* ((mcp-results
              (map (lambda (r)
                     (agentic-ai-lab-ai-agentic-context-admit-mcp-tool-registration
                      (opt-ref r 'registry '())
                      (.ref r 'server-id)
                      (.ref r 'tool-id)
                      (opt-ref r 'description "")
                      (opt-ref r 'schema '())))
                   (opt-ref proposal 'mcp-registrations '())))
             (mcp-fail (first-failing mcp-results))
             (camel-results
              (map (lambda (c)
                     (agentic-ai-lab-ai-agentic-context-admit-camel-sensitive-sink
                      (.ref c 'sink-sensitivity)
                      (.ref c 'arg-origin)
                      (.ref c 'manifest-pinned?)
                      declass-cert: (opt-ref c 'declass-cert #f)
                      declass-cert-active?: (opt-ref c 'declass-cert-active? #f)))
                   (opt-ref proposal 'camel-sink-checks '())))
             (camel-fail (first-failing camel-results))
             (mg-spec (opt-ref proposal 'mindguard-audit #f))
             (mg-res (and mg-spec
                          (agentic-ai-lab-ai-agentic-context-audit-tool-metadata-decision-dependence
                           (.ref mg-spec 'tool-with-metadata)
                           (.ref mg-spec 'tool-without-metadata)
                           (opt-ref mg-spec 'metadata-endorsed? #f))))
             (mg-hijack? (and mg-res (.ref mg-res 'decision-hijack-flagged?))))
        (cond
         (mcp-fail
          (.o bind-these: #f admitted?: #f reason: (.ref mcp-fail 'reason) action-authorized?: #f))
         (camel-fail
          (.o bind-these: #f admitted?: #f reason: (.ref camel-fail 'reason) action-authorized?: #f))
         (mg-hijack?
          (.o bind-these: #f admitted?: #f reason: 'mindguard-tool-metadata-decision-hijack
              mindguard-audit: mg-res action-authorized?: #f))
         ((eq? pkind 'typed-funflow-dag-patch)
          (let ((tasks (opt-ref proposal 'tasks '())))
            (if (and (pair? tasks)
                     (every (lambda (t)
                              (and (deterministic-task-node? t)
                                   (flow? (.ref t 'flow))))
                            tasks))
              (.o bind-these: #f admitted?: #t reason: 'typed-funflow-dag-patch-admitted
                  proposal-kind: pkind action-authorized?: #f)
              (.o bind-these: #f admitted?: #f reason: 'invalid-funflow-dag-patch-contract
                  action-authorized?: #f))))
         (else
          ;; bounded-competing-branches
          (let ((branches (opt-ref proposal 'branches '())))
            (if (and (pair? branches)
                     (<= (length branches) max-branches)
                     (every (lambda (b) (and (object? b) (.slot? b 'branch-id))) branches))
              (.o bind-these: #f admitted?: #t reason: 'bounded-competing-branches-admitted
                  proposal-kind: pkind action-authorized?: #f)
              (.o bind-these: #f admitted?: #f reason: 'unbounded-or-empty-competing-branches
                  action-authorized?: #f))))))))))

;;; ---------------------------------------------------------------------------
;;; 2. Single Incremental Reconciliation Step (`reconcile-once`)
;;; ---------------------------------------------------------------------------

(def (seal-reconcile-capsule graph mode detail)
  (let* ((cut-str (string-append "cut-" (number->string (.ref graph 'cut))))
         (bytes (string-append "* RECONCILE " (.ref graph 'graph-id) " " cut-str "\n"))
         (journal (list (list 'graph-id (.ref graph 'graph-id))
                        (list 'cut cut-str)
                        (list 'mode mode)
                        (list 'detail detail)))
         (commit (digest (list 'deterministic-audit-capsule.v1 cut-str bytes journal)))
         (replay (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                  bytes journal cut-str cut-str commit)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.reconcile-audit-capsule.v1
        bound-cut: cut-str
        repaired-bytes: bytes
        journal-entries: journal
        commitment: commit
        replay: replay
        llm-calls-used: 0
        action-authorized?: #f)))

(def (reconcile-once
      graph
      oracle-fn: (oracle-fn #f)
      funflow-runner: (funflow-runner #f)
      context-spec: (context-spec #f))
  (let* ((frontier (ascent-reconcile-frontier graph))
         (mode (.ref frontier 'frontier-mode)))
    (cond
     ;; 1. Quiescent Fixed Point -> natural zero-LLM termination!
     ((eq? mode 'quiescent-fixed-point)
      (let* ((cap (seal-reconcile-capsule graph mode 'fixed-point-quiescent))
             (g1 (obligation-graph-append-capsule graph cap)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.reconcile-step-result.v1
            graph: g1
            frontier: frontier
            mode: mode
            quiescent?: #t
            llm-calls-used: 0
            det-tasks-executed: 0
            cas-hits: 0
            audit-capsule: cap)))

     ;; 2. Governance Blocked -> fail-closed escalation to HumanInbox (0 LLM, 0 adapter calls)
     ((eq? mode 'blocked-on-governance)
      (let* ((inbox-item (.o bind-these: #f
                             kind: 'agentic-ai-lab.loop-engine.human-inbox-item.v1
                             graph-id: (.ref graph 'graph-id)
                             cut: (.ref graph 'cut)
                             reason: (if (not (.ref graph 'cedar-grant-live?))
                                       'cedar-grant-revoked
                                       'mcp-manifest-mutated-unpinned)
                             action-authorized?: #f))
             (cap (seal-reconcile-capsule graph mode (.ref inbox-item 'reason)))
             (g1 (obligation-graph-append-capsule
                  (obligation-graph-add-human-inbox graph inbox-item) cap)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.reconcile-step-result.v1
            graph: g1
            frontier: frontier
            mode: mode
            quiescent?: #t
            llm-calls-used: 0
            det-tasks-executed: 0
            cas-hits: 0
            audit-capsule: cap)))

     ;; 3. Deterministic FunFlow Frontier (STRICT PRECEDENCE, 0 LLM CALLS!)
     ((eq? mode 'dispatch-deterministic-funflow)
      (unless funflow-runner
        (error "reconcile-once needs funflow-runner to execute ready deterministic tasks"))
      (let loop ((tasks (.ref frontier 'ready-deterministic-tasks))
                 (g-cur graph)
                 (ran 0)
                 (hits 0)
                 (blocked? #f)
                 (block-reason #f))
        (if (or (null? tasks) blocked?)
          (let* ((cap (seal-reconcile-capsule g-cur mode (or block-reason 'deterministic-frontier-completed)))
                 (g-out (obligation-graph-append-capsule g-cur cap)))
            (.o bind-these: #f
                kind: 'agentic-ai-lab.loop-engine.reconcile-step-result.v1
                graph: g-out
                frontier: frontier
                mode: (if blocked? 'blocked-on-sandbox mode)
                quiescent?: blocked?
                llm-calls-used: 0
                det-tasks-executed: ran
                cas-hits: hits
                blocked-reason: block-reason
                audit-capsule: cap))
          (let* ((t (car tasks))
                 (tid (.ref t 'task-id))
                 (ob-id (.ref t 'obligation-id))
                 (pdig (obligation-graph-premise-digest g-cur ob-id (.ref t 'premise-ids)))
                 (cut-str (string-append "cut-" (number->string (.ref g-cur 'cut))))
                 (ff-res (governed-funflow-run
                          funflow-runner
                          (.ref t 'flow)
                          (.ref t 'input)
                          capsule-id: (string-append (.ref g-cur 'graph-id) ":" cut-str)
                          sandbox-override: (.ref t 'sandbox-profile)
                          env-digest-override: (.ref t 'env-digest)
                          idempotency-key: (.ref t 'idempotency-key)
                          idempotency-commits: (.ref t 'idempotency-commits))))
            (if (not (.ref ff-res 'admitted?))
              (let ((g-blk (obligation-graph-add-human-inbox
                            g-cur
                            (.o bind-these: #f
                                kind: 'agentic-ai-lab.loop-engine.human-inbox-item.v1
                                task-id: tid
                                obligation-id: ob-id
                                reason: (.ref ff-res 'reason)
                                action-authorized?: #f))))
                (loop '() g-blk ran hits #t (.ref ff-res 'reason)))
              (let* ((raw-val (.ref ff-res 'value))
                     (payload (if (adapter-result? raw-val) (adapter-result-value raw-val) raw-val))
                     (ev (make-evidence-fact
                          (.ref t 'produces-evidence-id)
                          payload
                          cut: (.ref g-cur 'cut)
                          premise-ids: (.ref t 'premise-ids)
                          origin-tier: 'observed-fact
                          endorsed?: #t))
                     (g-next (obligation-graph-mark-task-completed
                              (obligation-graph-with-evidence g-cur ev)
                              tid pdig))
                     (is-hit? (and (.slot? ff-res 'cas-hit?) (.ref ff-res 'cas-hit?))))
                (loop (cdr tasks)
                      g-next
                      (+ ran 1)
                      (if is-hit? (+ hits 1) hits)
                      #f #f)))))))

     ;; 4. Stateless Typed Leaf SynthesisOracle (ONLY when deterministic frontier is empty!)
     ((eq? mode 'invoke-typed-synthesis-oracle)
      (let* ((hole (car (.ref frontier 'ready-synthesis-holes)))
             (cut-str (string-append "cut-" (number->string (.ref graph 'cut))))
             ;; Assemble governed context via ContextAssemblyPipeline (MINJA + KV-Prefix + L3)
             (org-text (if context-spec
                         (opt-ref context-spec 'org-text "* TODO Synthesize\n")
                         "* TODO Synthesize\n"))
             (assembly
              (agentic-ai-lab-ai-agentic-context-assemble-governed-turn
               org-text
               epoch: (.ref graph 'cut)
               bound-cut: cut-str
               live-cut: cut-str
               frozen-entries: (if context-spec (opt-ref context-spec 'frozen-entries '()) '())
               memory-candidates: (if context-spec (opt-ref context-spec 'memory-candidates '()) '())
               has-active-defeater?: (pair? (filter (lambda (o) (pair? (.ref o 'active-defeaters)))
                                                    (.ref graph 'obligations)))))
             ;; Permanently record `(hole-id . premise-digest)` FIRST so Datalog can NEVER spin!
             (g-marked (obligation-graph-mark-hole-attempted graph hole))
             (proposal (if (procedure? oracle-fn)
                         (oracle-fn hole assembly (.ref frontier 'unrefuted-hypotheses))
                         #f))
             (admission (if proposal
                          (admit-synthesis-proposal proposal max-branches: (.ref hole 'max-branches))
                          (.o bind-these: #f admitted?: #f reason: 'no-oracle-proposal action-authorized?: #f))))
        (if (not (.ref admission 'admitted?))
          (let* ((g-esc (obligation-graph-add-human-inbox
                         g-marked
                         (.o bind-these: #f
                             kind: 'agentic-ai-lab.loop-engine.human-inbox-item.v1
                             hole-id: (.ref hole 'hole-id)
                             obligation-id: (.ref hole 'obligation-id)
                             reason: (.ref admission 'reason)
                             action-authorized?: #f)))
                 (cap (seal-reconcile-capsule g-esc mode (.ref admission 'reason)))
                 (g-out (obligation-graph-append-capsule g-esc cap)))
            (.o bind-these: #f
                kind: 'agentic-ai-lab.loop-engine.reconcile-step-result.v1
                graph: g-out
                frontier: frontier
                mode: mode
                quiescent?: #f
                llm-calls-used: 1
                det-tasks-executed: 0
                cas-hits: 0
                oracle-admission: admission
                context-assembly: assembly
                audit-capsule: cap))
          (let* ((pkind (.ref admission 'proposal-kind))
                 (g-merged
                  (cond
                   ((eq? pkind 'typed-funflow-dag-patch)
                    (obligation-graph-with-tasks g-marked (.ref proposal 'tasks)))
                   ((eq? pkind 'bounded-competing-branches)
                    (let ((matrix (evaluate-competing-branches
                                   (.ref proposal 'branches)
                                   (.ref frontier 'unrefuted-hypotheses))))
                      (obligation-graph-record-branch-matrix g-marked matrix)))
                   (else g-marked)))
                 (cap (seal-reconcile-capsule g-merged mode (.ref admission 'reason)))
                 (g-out (obligation-graph-append-capsule g-merged cap)))
            (.o bind-these: #f
                kind: 'agentic-ai-lab.loop-engine.reconcile-step-result.v1
                graph: g-out
                frontier: frontier
                mode: mode
                quiescent?: #f
                llm-calls-used: 1
                det-tasks-executed: 0
                cas-hits: 0
                oracle-admission: admission
                context-assembly: assembly
                audit-capsule: cap))))))))

;;; ---------------------------------------------------------------------------
;;; 3. Dual-Mode Drivers: Offline Batch Fixed-Point + Event-Driven Reactive Stream
;;; ---------------------------------------------------------------------------

(def (reconcile-to-fixed-point
      graph
      oracle-fn: (oracle-fn #f)
      funflow-runner: (funflow-runner #f)
      context-spec: (context-spec #f))
  (let ((cap-steps (.ref graph 'max-reconcile-steps)))
    (let loop ((g graph) (step 0) (llm-total 0) (det-total 0) (cas-total 0) (trace-rev '()))
      (if (>= step cap-steps)
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.fixed-point-report.v1
            graph: g
            quiescent?: #f
            steps: step
            total-llm-calls: llm-total
            total-det-tasks: det-total
            total-cas-hits: cas-total
            final-frontier: (ascent-reconcile-frontier g)
            trace: (reverse trace-rev))
        (let* ((res (reconcile-once g
                                    oracle-fn: oracle-fn
                                    funflow-runner: funflow-runner
                                    context-spec: context-spec))
               (g1 (.ref res 'graph))
               (llm1 (+ llm-total (.ref res 'llm-calls-used)))
               (det1 (+ det-total (.ref res 'det-tasks-executed)))
               (cas1 (+ cas-total (.ref res 'cas-hits))))
          (if (.ref res 'quiescent?)
            (.o bind-these: #f
                kind: 'agentic-ai-lab.loop-engine.fixed-point-report.v1
                graph: g1
                quiescent?: #t
                steps: (+ step 1)
                total-llm-calls: llm1
                total-det-tasks: det1
                total-cas-hits: cas1
                final-frontier: (.ref res 'frontier)
                final-mode: (.ref res 'mode)
                trace: (reverse (cons res trace-rev)))
            (loop g1 (+ step 1) llm1 det1 cas1 (cons res trace-rev))))))))

(def (reconcile-event-stream
      initial-graph
      events
      oracle-fn: (oracle-fn #f)
      funflow-runner: (funflow-runner #f)
      context-spec: (context-spec #f))
  (let* ((init-report (reconcile-to-fixed-point
                       initial-graph
                       oracle-fn: oracle-fn
                       funflow-runner: funflow-runner
                       context-spec: context-spec)))
    (let loop ((evs events)
               (g (.ref init-report 'graph))
               (llm-total (.ref init-report 'total-llm-calls))
               (det-total (.ref init-report 'total-det-tasks))
               (cas-total (.ref init-report 'total-cas-hits))
               (reports-rev (list init-report)))
      (if (null? evs)
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.event-stream-report.v1
            final-graph: g
            final-frontier: (ascent-reconcile-frontier g)
            total-llm-calls: llm-total
            total-det-tasks: det-total
            total-cas-hits: cas-total
            reconcile-epochs: (reverse reports-rev))
        (let* ((ev (car evs))
               (g-ev (obligation-graph-apply-event g ev))
               (rep (reconcile-to-fixed-point
                     g-ev
                     oracle-fn: oracle-fn
                     funflow-runner: funflow-runner
                     context-spec: context-spec)))
          (loop (cdr evs)
                (.ref rep 'graph)
                (+ llm-total (.ref rep 'total-llm-calls))
                (+ det-total (.ref rep 'total-det-tasks))
                (+ cas-total (.ref rep 'total-cas-hits))
                (cons rep reports-rev)))))))
