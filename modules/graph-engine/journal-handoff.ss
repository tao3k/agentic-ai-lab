;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Marlin / Runtime Journal Handoff Protocol for GraphEngine Convergent
;;; Trees (`modules/graph-engine/journal-handoff.ss`).
;;;
;;; INVARIANT: 100% PURE functional / POO semantic core.
;;; ZERO SQLite imports, ZERO `durable-journal` imports, ZERO filesystem I/O!
;;; Real Turso/SQLite WAL execution lives strictly behind the optional Yuanxu Feature
;;; `(graph-engine +sqlite-turso)` (`features/sqlite-turso/`) or an external
;;; Marlin host adapter consuming `JournalHandoffIntent.`.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter)
        "obligation-graph.ss"
        "delegation-fence.ss"
        "convergent-tree.ss")

(export JournalHandoffIntent.
        DurableTrunkRecoveryReceipt.
        trunk->inert-snapshot
        inert-snapshot->trunk
        plan-trunk-journal-handoff
        project-recovered-trunk-receipt)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def JournalHandoffIntent.
  kind: 'agentic-ai-lab.graph-engine.journal-handoff-intent.v1
  runtime-executed?: #f)

(.def DurableTrunkRecoveryReceipt.
  kind: 'agentic-ai-lab.graph-engine.durable-trunk-recovery.v1)

(def (inert-task-descriptor t)
  (.o (task-id := (.ref t 'task-id))
      (obligation-id := (.ref t 'obligation-id))
      (produces-evidence-id := (.ref t 'produces-evidence-id))
      (input := (.ref t 'input))
      (required-evidence-ids := (opt-ref t 'required-evidence-ids '()))
      (premise-ids := (opt-ref t 'premise-ids '()))
      (depends-on-tasks := (opt-ref t 'depends-on-tasks '()))
      (read-footprint := (opt-ref t 'read-footprint '()))
      (write-footprint := (opt-ref t 'write-footprint '()))
      (span := (opt-ref t 'span #f))
      (effect-class := (opt-ref t 'effect-class 'pure-cas))
      (env-digest := (opt-ref t 'env-digest "sha256:default-env"))
      (idempotency-key := (opt-ref t 'idempotency-key #f))
      (idempotency-commits := (opt-ref t 'idempotency-commits '()))))

(def (inert-evidence ev)
  (.o (evidence-id := (.ref ev 'evidence-id))
      (payload := (.ref ev 'payload))
      (cut := (.ref ev 'cut))
      (premise-ids := (opt-ref ev 'premise-ids '()))
      (origin-tier := (opt-ref ev 'origin-tier 'observed-fact))
      (endorsed? := (opt-ref ev 'endorsed? #t))
      (retracted? := (opt-ref ev 'retracted? #f))))

(def (inert-obligation ob)
  (.o (obligation-id := (.ref ob 'obligation-id))
      (title := (opt-ref ob 'title ""))
      (required-evidence-ids := (opt-ref ob 'required-evidence-ids '()))
      (depends-on := (opt-ref ob 'depends-on '()))
      (active-defeaters := (opt-ref ob 'active-defeaters '()))
      (premise-ids := (opt-ref ob 'premise-ids '()))))

(def (inert-hypothesis h)
  (.o (hypothesis-id := (.ref h 'hypothesis-id))
      (claim := (.ref h 'claim))
      (supporting-evidence-ids := (opt-ref h 'supporting-evidence-ids '()))
      (contradicting-evidence-ids := (opt-ref h 'contradicting-evidence-ids '()))
      (active-defeaters := (opt-ref h 'active-defeaters '()))
      (open-questions := (opt-ref h 'open-questions '()))))

(def (inert-envelope env)
  (.o (owner-id := (.ref env 'owner-id))
      (allowed-caps := (.ref env 'allowed-caps))
      (denied-caps := (.ref env 'denied-caps))
      (egress-allowed? := (.ref env 'egress-allowed?))))

(def (inert-branch b)
  (.o (branch-id := (.ref b 'branch-id))
      (branch-kind := (.ref b 'branch-kind))
      (trunk-id := (.ref b 'trunk-id))
      (serving-apex-id := (.ref b 'serving-apex-id))
      (target-obligation-id := (.ref b 'target-obligation-id))
      (shared-context-cut := (.ref b 'shared-context-cut))
      (kv-prefix-digest := (.ref b 'kv-prefix-digest))
      (bound-grant-epoch := (.ref b 'bound-grant-epoch))
      (c4-priority := (.ref b 'c4-priority))
      (required-for-apex? := (.ref b 'required-for-apex?))
      (can-finalize-trunk? := #f)
      (status := (.ref b 'status))
      (attempt-id := (.ref (.ref b 'delegation-token) 'attempt-id))
      (envelope := (inert-envelope (.ref b 'capability-envelope)))))

(def (inert-contribution c)
  (.o (branch-id := (.ref c 'branch-id))
      (branch-kind := (.ref c 'branch-kind))
      (serving-apex-id := (.ref c 'serving-apex-id))
      (target-obligation-id := (.ref c 'target-obligation-id))
      (shared-context-cut := (.ref c 'shared-context-cut))
      (bound-grant-epoch := (.ref c 'bound-grant-epoch))
      (c4-priority := (.ref c 'c4-priority))
      (exit-kind := (.ref c 'exit-kind))
      (evidence-facts := (map inert-evidence (opt-ref c 'evidence-facts '())))
      (completed-task-ids := (opt-ref c 'completed-task-ids '()))
      (hypotheses := (map inert-hypothesis (opt-ref c 'hypotheses '())))
      (counterexample-core := (opt-ref c 'counterexample-core '()))
      (declass-cert := (if (boolean? (.ref c 'declass-cert)) (.ref c 'declass-cert) #t))
      (summary := (opt-ref c 'summary ""))))

(def (inert-apex-receipt r)
  (and r
       (.o (trunk-id := (.ref r 'trunk-id))
           (apex-obligation-id := (.ref r 'apex-obligation-id))
           (shared-context-cut := (.ref r 'shared-context-cut))
           (kv-prefix-digest := (.ref r 'kv-prefix-digest))
           (absorbed-branch-ids-c4-order := (.ref r 'absorbed-branch-ids-c4-order))
           (counterexample-core := (.ref r 'counterexample-core))
           (hypothesis-verdict := (.ref r 'hypothesis-verdict))
           (total-llm-calls := (.ref r 'total-llm-calls))
           (total-det-tasks := (.ref r 'total-det-tasks))
           (receipt-digest := (.ref r 'receipt-digest)))))

;;; Convert a live `ContextTrunk.` into 100% inert POO data (zero code replay).
(def (trunk->inert-snapshot trunk)
  (let* ((g (.ref trunk 'obligation-graph))
         (graph-snap
          (.o (graph-id := (.ref g 'graph-id))
              (cut := (.ref g 'cut))
              (obligations := (map inert-obligation (.ref g 'obligations)))
              (hypotheses := (map inert-hypothesis (.ref g 'hypotheses)))
              (evidence := (map inert-evidence (.ref g 'evidence)))
              (det-tasks := (map inert-task-descriptor (.ref g 'det-tasks)))
              (attempted-holes := (.ref g 'attempted-holes))
              (completed-tasks := (.ref g 'completed-tasks))
              (cedar-grant-live? := (.ref g 'cedar-grant-live?))
              (mcp-manifest-healthy? := (.ref g 'mcp-manifest-healthy?))
              (max-reconcile-steps := (.ref g 'max-reconcile-steps)))))
    (.o (kind := 'agentic-ai-lab.graph-engine.inert-trunk-snapshot.v1)
        (trunk-id := (.ref trunk 'trunk-id))
        (apex-obligation-id := (.ref trunk 'apex-obligation-id))
        (shared-context-cut := (.ref trunk 'shared-context-cut))
        (kv-prefix-digest := (.ref trunk 'kv-prefix-digest))
        (live-grant-epoch := (.ref trunk 'live-grant-epoch))
        (trunk-grant-live? := (.ref trunk 'trunk-grant-live?))
        (capability-envelope := (inert-envelope (.ref trunk 'capability-envelope)))
        (graph := graph-snap)
        (branches := (map inert-branch (.ref trunk 'branches)))
        (absorbed-contributions := (map inert-contribution (.ref trunk 'absorbed-contributions)))
        (counterexample-core := (.ref trunk 'counterexample-core))
        (apex-status := (.ref trunk 'apex-status))
        (apex-receipt := (inert-apex-receipt (.ref trunk 'apex-receipt))))))

(def (rehydrate-envelope ie)
  (make-capability-envelope
   (.ref ie 'owner-id)
   allowed-caps: (.ref ie 'allowed-caps)
   denied-caps: (.ref ie 'denied-caps)
   egress-allowed?: (.ref ie 'egress-allowed?)))

(def (rehydrate-evidence ie)
  (make-evidence-fact
   (.ref ie 'evidence-id)
   (.ref ie 'payload)
   cut: (.ref ie 'cut)
   premise-ids: (.ref ie 'premise-ids)
   origin-tier: (.ref ie 'origin-tier)
   endorsed?: (.ref ie 'endorsed?)
   retracted?: (.ref ie 'retracted?)))

(def (rehydrate-obligation io)
  (make-obligation
   (.ref io 'obligation-id)
   title: (.ref io 'title)
   required-evidence-ids: (.ref io 'required-evidence-ids)
   depends-on: (.ref io 'depends-on)
   active-defeaters: (.ref io 'active-defeaters)
   premise-ids: (.ref io 'premise-ids)))

(def (rehydrate-hypothesis ih)
  (make-hypothesis
   (.ref ih 'hypothesis-id)
   (.ref ih 'claim)
   supporting-evidence-ids: (.ref ih 'supporting-evidence-ids)
   contradicting-evidence-ids: (.ref ih 'contradicting-evidence-ids)
   active-defeaters: (.ref ih 'active-defeaters)
   open-questions: (.ref ih 'open-questions)))

(def (lookup-flow registry task-id)
  (let ((pair (and (list? registry) (assoc task-id registry))))
    (and pair (cdr pair))))

;;; Rehydrate a live `ContextTrunk.` from an inert POO snapshot, rebinding
;;; pure FunFlow task flows by `task-id` from `task-flow-registry`.
(def (inert-snapshot->trunk snap task-flow-registry: (task-flow-registry '()))
  (let* ((gs (.ref snap 'graph))
         (tasks
          (map (lambda (td)
                 (make-deterministic-task-node
                  (.ref td 'task-id)
                  (.ref td 'obligation-id)
                  (.ref td 'produces-evidence-id)
                  (lookup-flow task-flow-registry (.ref td 'task-id))
                  (.ref td 'input)
                  required-evidence-ids: (.ref td 'required-evidence-ids)
                  premise-ids: (.ref td 'premise-ids)
                  depends-on-tasks: (.ref td 'depends-on-tasks)
                  read-footprint: (.ref td 'read-footprint)
                  write-footprint: (.ref td 'write-footprint)
                  span: (.ref td 'span)
                  effect-class: (.ref td 'effect-class)
                  env-digest: (.ref td 'env-digest)
                  idempotency-key: (.ref td 'idempotency-key)
                  idempotency-commits: (.ref td 'idempotency-commits)))
               (.ref gs 'det-tasks)))
         (g (make-obligation-graph
             (.ref gs 'graph-id)
             cut: (.ref gs 'cut)
             obligations: (map rehydrate-obligation (.ref gs 'obligations))
             hypotheses: (map rehydrate-hypothesis (.ref gs 'hypotheses))
             evidence: (map rehydrate-evidence (.ref gs 'evidence))
             det-tasks: tasks
             attempted-holes: (.ref gs 'attempted-holes)
             completed-tasks: (.ref gs 'completed-tasks)
             cedar-grant-live?: (.ref gs 'cedar-grant-live?)
             mcp-manifest-healthy?: (.ref gs 'mcp-manifest-healthy?)
             max-reconcile-steps: (.ref gs 'max-reconcile-steps)))
         (branches
          (map (lambda (ib)
                 (let* ((env (rehydrate-envelope (.ref ib 'envelope)))
                        (tok (make-delegated-obligation-token
                              (.ref ib 'trunk-id)
                              (.ref ib 'branch-id)
                              (.ref ib 'target-obligation-id)
                              env
                              (.ref ib 'shared-context-cut)
                              (.ref ib 'bound-grant-epoch)
                              attempt-id: (.ref ib 'attempt-id))))
                   (.o (kind := 'agentic-ai-lab.loop-engine.trunk-branch.v1)
                       (branch-id := (.ref ib 'branch-id))
                       (branch-kind := (.ref ib 'branch-kind))
                       (trunk-id := (.ref ib 'trunk-id))
                       (serving-apex-id := (.ref ib 'serving-apex-id))
                       (target-obligation-id := (.ref ib 'target-obligation-id))
                       (shared-context-cut := (.ref ib 'shared-context-cut))
                       (kv-prefix-digest := (.ref ib 'kv-prefix-digest))
                       (bound-grant-epoch := (.ref ib 'bound-grant-epoch))
                       (c4-priority := (.ref ib 'c4-priority))
                       (required-for-apex? := (.ref ib 'required-for-apex?))
                       (can-finalize-trunk? := #f)
                       (status := (.ref ib 'status))
                       (delegation-token := tok)
                       (capability-envelope := env))))
               (.ref snap 'branches)))
         (contribs
          (map (lambda (ic)
                 (.o (:: @ BranchContributionReceipt.)
                     (branch-id := (.ref ic 'branch-id))
                     (branch-kind := (.ref ic 'branch-kind))
                     (serving-apex-id := (.ref ic 'serving-apex-id))
                     (target-obligation-id := (.ref ic 'target-obligation-id))
                     (shared-context-cut := (.ref ic 'shared-context-cut))
                     (bound-grant-epoch := (.ref ic 'bound-grant-epoch))
                     (c4-priority := (.ref ic 'c4-priority))
                     (exit-kind := (.ref ic 'exit-kind))
                     (evidence-facts := (map rehydrate-evidence (.ref ic 'evidence-facts)))
                     (completed-task-ids := (.ref ic 'completed-task-ids))
                     (hypotheses := (map rehydrate-hypothesis (.ref ic 'hypotheses)))
                     (counterexample-core := (.ref ic 'counterexample-core))
                     (declass-cert := (.ref ic 'declass-cert))
                     (summary := (.ref ic 'summary))
                     (can-finalize-trunk? := #f)))
               (.ref snap 'absorbed-contributions))))
    (.o (:: @ ContextTrunk.)
        (trunk-id := (.ref snap 'trunk-id))
        (apex-obligation-id := (.ref snap 'apex-obligation-id))
        (shared-context-cut := (.ref snap 'shared-context-cut))
        (kv-prefix-digest := (.ref snap 'kv-prefix-digest))
        (live-grant-epoch := (.ref snap 'live-grant-epoch))
        (trunk-grant-live? := (.ref snap 'trunk-grant-live?))
        (capability-envelope := (rehydrate-envelope (.ref snap 'capability-envelope)))
        (obligation-graph := g)
        (branches)
        (absorbed-contributions := contribs)
        (counterexample-core := (.ref snap 'counterexample-core))
        (apex-status := (.ref snap 'apex-status))
        (apex-receipt := (.ref snap 'apex-receipt)))))

;;; Pure Marlin handoff planner: constructs an inert `JournalHandoffIntent.`
;;; describing the exact evidence, state snapshot, and optional Apex terminal
;;; to commit at the Marlin / `+sqlite-journal` Feature boundary (ZERO I/O!).
(def (plan-trunk-journal-handoff event-id event-payload trunk)
  (let* ((snap (trunk->inert-snapshot trunk))
         (evs (map (lambda (ev)
                     (cons (string-append "ev:" (.ref ev 'evidence-id))
                           (inert-evidence ev)))
                   (obligation-graph-live-evidence (.ref trunk 'obligation-graph))))
         (terminal (and (eq? (.ref trunk 'apex-status) 'converged)
                        (.o (session := (.ref trunk 'trunk-id))
                            (attempt := (.ref trunk 'apex-obligation-id))
                            (generation := (.ref trunk 'shared-context-cut))
                            (receipt-digest := (.ref (.ref trunk 'apex-receipt) 'receipt-digest))))))
    (.o (:: @ JournalHandoffIntent.)
        (state-key := "graph-engine:trunk")
        (event-id)
        (event-payload)
        (trunk-id := (.ref trunk 'trunk-id))
        (apex-status := (.ref trunk 'apex-status))
        (inert-snapshot := snap)
        (immutable-evidence-records := evs)
        (terminal-record := terminal))))

;;; Pure recovery projection: turns a verified inert snapshot + host epoch/hash
;;; into a `DurableTrunkRecoveryReceipt.` (ZERO I/O!).
(def (project-recovered-trunk-receipt
      snap
      journal-epoch: (journal-epoch 1)
      chain-head-hash: (chain-head-hash "root")
      task-flow-registry: (task-flow-registry '()))
  (if (not snap)
    (.o (:: @ DurableTrunkRecoveryReceipt.)
        (recovered? := #f)
        (reason := 'no-committed-trunk-snapshot)
        (journal-epoch)
        (chain-head-hash)
        (trunk := #f)
        (open-required-branch-ids := '())
        (needs-branch-reconciliation? := #f))
    (let* ((trunk (inert-snapshot->trunk snap task-flow-registry: task-flow-registry))
           (open-req-ids
            (map (lambda (b) (.ref b 'branch-id))
                 (filter (lambda (b)
                           (and (.ref b 'required-for-apex?)
                                (eq? (.ref b 'status) 'active)))
                         (.ref trunk 'branches)))))
      (.o (:: @ DurableTrunkRecoveryReceipt.)
          (recovered? := #t)
          (reason := (if (pair? open-req-ids)
                       'recovered-with-unclosed-serving-branches
                       'recovered-clean))
          (journal-epoch)
          (chain-head-hash)
          (trunk)
          (open-required-branch-ids := open-req-ids)
          (needs-branch-reconciliation? := (pair? open-req-ids))))))
