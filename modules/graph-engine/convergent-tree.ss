;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Slice 59 Runtime Engine:
;;; Shared-Context Convergent Tree (`ContextTrunk.` -> Subordinate Branches ->
;;; `ApexConvergenceReceipt.`) (`modules/loop-engine/convergent-tree.ss`).
;;;
;;; Core Architectural Invariants:
;;; 1. ZERO Isolated Subagents: every branch MUST grow from the Trunk's live
;;;    `shared-context-cut`, `kv-prefix-digest`, and `serving-apex-id`, with a
;;;    Slice 58 attenuated capability envelope (`(parent ∩ req) \ parent.denied`).
;;; 2. Three Subordinate Branch Kinds (ALL serving the Trunk & Apex):
;;;    - `ContextEnrichmentDetour.`   (acquires missing upstream/downstream context)
;;;    - `DivergentExplorationBranch.`(explores competing hypotheses on shared prefix)
;;;    - `SubordinateTaskBranch.`     (completes a branch-scoped task / sub-DAG in overlay)
;;; 3. No Branch Trunk-Finality: a branch can complete its own local task, NEVER
;;;    finalize the Trunk or publish to external Host CAS; it may only submit a
;;;    `BranchContributionReceipt.` to be absorbed into the Trunk via Slice 50
;;;    4-Exit protocol + C4 deterministic priority + ASCENT obligation reconciliation.
;;; 4. Apex-Driven Lifecycle: advancing Trunk cut/epoch, revoking Trunk grant, or
;;;    converging to the Apex immediately supersedes/invalidates stale branches so
;;;    zero orphan/zombie subagents survive.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter every any)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 ParallelFrontierStrategy.)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 governed-funflow-run)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 adapter-result? adapter-result-value)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "synthesis-oracle.ss"
        "delegation-fence.ss")

(export ContextTrunk.
        ContextEnrichmentDetour.
        DivergentExplorationBranch.
        SubordinateTaskBranch.
        BranchContributionReceipt.
        ApexConvergenceReceipt.
        make-context-trunk
        context-trunk?
        spawn-trunk-branch
        trunk-branch?
        branch-attempt-direct-trunk-finalization
        admit-branch-execution-step
        execute-branch-funflow-dag
        make-branch-contribution
        absorb-branch-contribution
        trunk-advance-cut-or-revoke
        converge-trunk-to-apex)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (dedup xs)
  (let loop ((rest xs) (seen '()) (acc '()))
    (cond
     ((null? rest) (reverse acc))
     ((member (car rest) seen) (loop (cdr rest) seen acc))
     (else (loop (cdr rest) (cons (car rest) seen) (cons (car rest) acc))))))

(def +valid-branch-kinds+
  '(context-enrichment-detour divergent-exploration subordinate-task))

(def +valid-exit-kinds+
  '(completed parked-custody cancelled promoted-to-task))

(.def ContextTrunk.
  kind: 'agentic-ai-lab.loop-engine.context-trunk.v1)

(.def ContextEnrichmentDetour.
  kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
  branch-kind: 'context-enrichment-detour
  can-finalize-trunk?: #f)

(.def DivergentExplorationBranch.
  kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
  branch-kind: 'divergent-exploration
  can-finalize-trunk?: #f)

(.def SubordinateTaskBranch.
  kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
  branch-kind: 'subordinate-task
  can-finalize-trunk?: #f)

(.def BranchContributionReceipt.
  kind: 'agentic-ai-lab.loop-engine.branch-contribution.v1)

(.def ApexConvergenceReceipt.
  kind: 'agentic-ai-lab.loop-engine.apex-convergence.v1)

(def (context-trunk? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.context-trunk.v1)))

(def (trunk-branch? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.trunk-branch.v1)))

(def (make-context-trunk
      trunk-id
      apex-obligation-id
      obligation-graph
      capability-envelope
      shared-context-cut: (shared-context-cut #f)
      kv-prefix-digest: (kv-prefix-digest #f)
      live-grant-epoch: (live-grant-epoch 1)
      trunk-grant-live?: (trunk-grant-live? #t))
  (let* ((cut-val (or shared-context-cut (.ref obligation-graph 'cut)))
         (kv-dig (or kv-prefix-digest
                     (digest (list 'shared-context-kv-prefix.v1 trunk-id cut-val)))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
        trunk-id: trunk-id
        apex-obligation-id: apex-obligation-id
        shared-context-cut: cut-val
        kv-prefix-digest: kv-dig
        live-grant-epoch: live-grant-epoch
        trunk-grant-live?: (and trunk-grant-live? #t)
        capability-envelope: capability-envelope
        obligation-graph: obligation-graph
        branches: '()
        absorbed-contributions: '()
        counterexample-core: '()
        apex-status: 'open
        apex-receipt: #f)))

;;; Spawn a subordinate branch anchored directly to the shared Context Trunk.
;;; Refuses isolated/unshared spawns, invalid branch kinds, or non-open Trunks.
;;; Every branch receives a Slice 58 attenuated envelope & bound token, and has
;;; `can-finalize-trunk?: #f` structurally sealed.
(def (spawn-trunk-branch
      trunk
      branch-id
      branch-kind
      requested-caps
      target-obligation-id
      c4-priority: (c4-priority 10)
      required-for-apex?: (required-for-apex? #t)
      requested-shared-cut: (requested-shared-cut #f)
      requested-kv-prefix: (requested-kv-prefix #f)
      requested-apex-id: (requested-apex-id #f))
  (cond
   ((not (context-trunk? trunk))
    (.o bind-these: #f admitted?: #f reason: 'invalid-context-trunk trunk: trunk branch: #f))
   ((not (eq? (.ref trunk 'apex-status) 'open))
    (.o bind-these: #f admitted?: #f reason: 'trunk-apex-not-open trunk: trunk branch: #f))
   ((not (.ref trunk 'trunk-grant-live?))
    (.o bind-these: #f admitted?: #f reason: 'trunk-cedar-grant-revoked trunk: trunk branch: #f))
   ((not (memq branch-kind +valid-branch-kinds+))
    (.o bind-these: #f admitted?: #f reason: 'invalid-branch-kind trunk: trunk branch: #f))
   ((and requested-shared-cut (not (equal? requested-shared-cut (.ref trunk 'shared-context-cut))))
    (.o bind-these: #f admitted?: #f reason: 'isolated-or-stale-context-cut-forbidden trunk: trunk branch: #f))
   ((and requested-kv-prefix (not (equal? requested-kv-prefix (.ref trunk 'kv-prefix-digest))))
    (.o bind-these: #f admitted?: #f reason: 'unshared-kv-prefix-forbidden trunk: trunk branch: #f))
   ((and requested-apex-id (not (equal? requested-apex-id (.ref trunk 'apex-obligation-id))))
    (.o bind-these: #f admitted?: #f reason: 'detached-apex-target-forbidden trunk: trunk branch: #f))
   (else
    (let* ((env (attenuate-delegation-envelope
                 (.ref trunk 'capability-envelope)
                 branch-id
                 requested-caps))
           (tok (make-delegated-obligation-token
                 (.ref trunk 'trunk-id)
                 branch-id
                 target-obligation-id
                 env
                 (.ref trunk 'shared-context-cut)
                 (.ref trunk 'live-grant-epoch)
                 attempt-id: (string-append "attempt-" branch-id)))
           (branch (.o bind-these: #f
                       kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
                       branch-id: branch-id
                       branch-kind: branch-kind
                       trunk-id: (.ref trunk 'trunk-id)
                       serving-apex-id: (.ref trunk 'apex-obligation-id)
                       target-obligation-id: target-obligation-id
                       shared-context-cut: (.ref trunk 'shared-context-cut)
                       kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                       bound-grant-epoch: (.ref trunk 'live-grant-epoch)
                       c4-priority: c4-priority
                       required-for-apex?: (and required-for-apex? #t)
                       can-finalize-trunk?: #f
                       status: 'active
                       delegation-token: tok
                       capability-envelope: env))
           (trunk-next (.o bind-these: #f
                           kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                           trunk-id: (.ref trunk 'trunk-id)
                           apex-obligation-id: (.ref trunk 'apex-obligation-id)
                           shared-context-cut: (.ref trunk 'shared-context-cut)
                           kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                           live-grant-epoch: (.ref trunk 'live-grant-epoch)
                           trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                           capability-envelope: (.ref trunk 'capability-envelope)
                           obligation-graph: (.ref trunk 'obligation-graph)
                           branches: (append (.ref trunk 'branches) (list branch))
                           absorbed-contributions: (.ref trunk 'absorbed-contributions)
                           counterexample-core: (.ref trunk 'counterexample-core)
                           apex-status: (.ref trunk 'apex-status)
                           apex-receipt: (.ref trunk 'apex-receipt))))
      (.o bind-these: #f
          admitted?: #t
          reason: 'shared-context-branch-spawned
          trunk: trunk-next
          branch: branch)))))

;;; Hard Invariant 1 (No Branch Trunk-Finality):
;;; A branch may complete its own local task, NEVER finalize the Trunk or
;;; commit directly to Host CAS.
(def (branch-attempt-direct-trunk-finalization branch)
  (.o bind-these: #f
      admitted?: #f
      branch-id: (if (trunk-branch? branch) (.ref branch 'branch-id) "unknown")
      can-finalize-trunk?: #f
      reason: 'branch-cannot-finalize-trunk-directly
      action-authorized?: #f))

;;; Find the current trunk-recorded branch object by id.
(def (trunk-find-branch trunk branch-id)
  (let loop ((bs (.ref trunk 'branches)))
    (cond
     ((null? bs) #f)
     ((equal? (.ref (car bs) 'branch-id) branch-id) (car bs))
     (else (loop (cdr bs))))))

;;; Atomic execution fence for ANY step inside a subordinate branch:
;;; Enforces live Trunk anchor, shared ContextCut, shared KV-Prefix, active
;;; branch status, and Slice 58 Cedar/Cut/Epoch/Attenuation TOCTOU fence.
(def (admit-branch-execution-step trunk branch requested-cap)
  (let* ((bid (if (trunk-branch? branch) (.ref branch 'branch-id) "unknown"))
         (live-b (and (context-trunk? trunk) (trunk-find-branch trunk bid))))
    (cond
     ((not (and (context-trunk? trunk) (trunk-branch? branch) live-b))
      (.o bind-these: #f admitted?: #f reason: 'unregistered-or-detached-branch action-authorized?: #f))
     ((not (eq? (.ref trunk 'apex-status) 'open))
      (.o bind-these: #f admitted?: #f reason: 'trunk-apex-already-closed action-authorized?: #f))
     ((not (eq? (.ref live-b 'status) 'active))
      (.o bind-these: #f admitted?: #f reason: 'branch-superseded-or-closed action-authorized?: #f))
     ((not (equal? (.ref live-b 'serving-apex-id) (.ref trunk 'apex-obligation-id)))
      (.o bind-these: #f admitted?: #f reason: 'branch-apex-mismatch action-authorized?: #f))
     ((not (equal? (.ref live-b 'kv-prefix-digest) (.ref trunk 'kv-prefix-digest)))
      (.o bind-these: #f admitted?: #f reason: 'branch-kv-prefix-drift action-authorized?: #f))
     (else
      (admit-delegated-execution-fence
       (.ref live-b 'delegation-token)
       requested-cap
       parent-grant-live?: (.ref trunk 'trunk-grant-live?)
       live-cut: (.ref trunk 'shared-context-cut)
       live-grant-epoch: (.ref trunk 'live-grant-epoch))))))

(def (make-branch-contribution
      branch
      exit-kind: (exit-kind 'completed)
      evidence-facts: (evidence-facts '())
      completed-task-ids: (completed-task-ids '())
      hypotheses: (hypotheses '())
      counterexample-core: (counterexample-core '())
      declass-cert: (declass-cert #t)
      summary: (summary ""))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.branch-contribution.v1
      branch-id: (.ref branch 'branch-id)
      branch-kind: (.ref branch 'branch-kind)
      serving-apex-id: (.ref branch 'serving-apex-id)
      target-obligation-id: (.ref branch 'target-obligation-id)
      shared-context-cut: (.ref branch 'shared-context-cut)
      bound-grant-epoch: (.ref branch 'bound-grant-epoch)
      c4-priority: (.ref branch 'c4-priority)
      exit-kind: exit-kind
      evidence-facts: evidence-facts
      completed-task-ids: completed-task-ids
      hypotheses: hypotheses
      counterexample-core: counterexample-core
      declass-cert: declass-cert
      summary: summary
      can-finalize-trunk?: #f))

;;; Execute a SubordinateTaskBranch's internal FunFlow CAS DAG inside its
;;; confined overlay. Still NEVER finalizes the Trunk; returns an immutable
;;; `BranchContributionReceipt.` ready for Trunk absorption.
(def (execute-branch-funflow-dag
      trunk
      branch
      branch-tasks
      required-cap
      funflow-runner
      strategy: (strategy ParallelFrontierStrategy.))
  (let ((fence (admit-branch-execution-step trunk branch required-cap)))
    (if (not (.ref fence 'admitted?))
      (.o bind-these: #f
          admitted?: #f
          reason: (.ref fence 'reason)
          contribution: #f
          subagents-spawned: 0
          can-finalize-trunk?: #f)
      (let* ((sub-graph (make-obligation-graph
                         (string-append "branch-dag:" (.ref branch 'branch-id))
                         cut: (.ref trunk 'shared-context-cut)
                         det-tasks: branch-tasks))
             (plan (plan-funflow-c4-frontier
                    sub-graph
                    branch-tasks
                    strategy: strategy)))
        (if (not (.ref plan 'valid?))
          (.o bind-these: #f
              admitted?: #f
              reason: (.ref plan 'reason)
              frontier-plan: plan
              contribution: #f
              subagents-spawned: 0
              can-finalize-trunk?: #f)
          (let loop ((tasks (.ref plan 'parallel-batch))
                     (evs-rev '())
                     (tids-rev '())
                     (failed-reason #f))
            (cond
             (failed-reason
              (.o bind-these: #f
                  admitted?: #f
                  reason: failed-reason
                  frontier-plan: plan
                  contribution: #f
                  subagents-spawned: 0
                  can-finalize-trunk?: #f))
             ((null? tasks)
              (let ((contrib (make-branch-contribution
                              branch
                              exit-kind: 'completed
                              evidence-facts: (reverse evs-rev)
                              completed-task-ids: (reverse tids-rev)
                              summary: "subordinate-branch-dag-completed")))
                (.o bind-these: #f
                    admitted?: #t
                    reason: 'subordinate-branch-task-completed-awaiting-trunk-absorption
                    frontier-plan: plan
                    contribution: contrib
                    subagents-spawned: 0
                    can-finalize-trunk?: #f)))
             (else
              (let* ((t (car tasks))
                     (cut-str (string-append "cut-" (number->string (.ref trunk 'shared-context-cut))))
                     (ff-res (governed-funflow-run
                              funflow-runner
                              (.ref t 'flow)
                              (.ref t 'input)
                              capsule-id: (string-append (.ref branch 'branch-id) ":" cut-str)
                              sandbox-override: (.ref t 'sandbox-profile)
                              env-digest-override: (.ref t 'env-digest)
                              idempotency-key: (.ref t 'idempotency-key)
                              idempotency-commits: (.ref t 'idempotency-commits))))
                (if (not (.ref ff-res 'admitted?))
                  (loop '() evs-rev tids-rev (.ref ff-res 'reason))
                  (let* ((raw-val (.ref ff-res 'value))
                         (payload (if (adapter-result? raw-val) (adapter-result-value raw-val) raw-val))
                         (ev (make-evidence-fact
                              (.ref t 'produces-evidence-id)
                              payload
                              cut: (.ref trunk 'shared-context-cut)
                              premise-ids: (.ref t 'premise-ids)
                              origin-tier: 'observed-fact
                              endorsed?: #t)))
                    (loop (cdr tasks)
                          (cons ev evs-rev)
                          (cons (.ref t 'task-id) tids-rev)
                          #f))))))))))))

(def (update-branch-status branches branch-id new-status)
  (map (lambda (b)
         (if (equal? (.ref b 'branch-id) branch-id)
           (.o bind-these: #f
               kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
               branch-id: (.ref b 'branch-id)
               branch-kind: (.ref b 'branch-kind)
               trunk-id: (.ref b 'trunk-id)
               serving-apex-id: (.ref b 'serving-apex-id)
               target-obligation-id: (.ref b 'target-obligation-id)
               shared-context-cut: (.ref b 'shared-context-cut)
               kv-prefix-digest: (.ref b 'kv-prefix-digest)
               bound-grant-epoch: (.ref b 'bound-grant-epoch)
               c4-priority: (.ref b 'c4-priority)
               required-for-apex?: (.ref b 'required-for-apex?)
               can-finalize-trunk?: #f
               status: new-status
               delegation-token: (.ref b 'delegation-token)
               capability-envelope: (.ref b 'capability-envelope))
           b))
       branches))

(def (sort-contributions-c4 contribs)
  (list-sort (lambda (a b)
               (let ((pa (.ref a 'c4-priority))
                     (pb (.ref b 'c4-priority)))
                 (or (< pa pb)
                     (and (= pa pb)
                          (string<? (.ref a 'branch-id) (.ref b 'branch-id))))))
             contribs))

;;; Slice 50 4-Exit Absorption Gate + C4 Priority Ordering onto the Trunk:
;;; - Re-checks `shared-context-cut`, `live-grant-epoch`, and `declass-cert`
;;; - Always preserves `counterexample-core` monotonically (even on cancel/park/stale!)
;;; - Never silently force-merges stale or revoked branch outputs into the Trunk.
(def (absorb-branch-contribution trunk contribution)
  (let* ((bid (.ref contribution 'branch-id))
         (exit-k (.ref contribution 'exit-kind))
         (live-b (trunk-find-branch trunk bid))
         (new-ce (dedup (append (.ref trunk 'counterexample-core)
                                (opt-ref contribution 'counterexample-core '())))))
    (cond
     ((not live-b)
      (.o bind-these: #f admitted?: #f reason: 'unknown-branch-contribution trunk: trunk))
     ((not (memq exit-k +valid-exit-kinds+))
      (.o bind-these: #f admitted?: #f reason: 'invalid-4-exit-kind trunk: trunk))
     ((not (eq? (.ref trunk 'apex-status) 'open))
      (.o bind-these: #f admitted?: #f reason: 'superseded-by-closed-apex trunk: trunk))
     ((or (not (equal? (.ref contribution 'shared-context-cut) (.ref trunk 'shared-context-cut)))
          (not (= (.ref contribution 'bound-grant-epoch) (.ref trunk 'live-grant-epoch)))
          (eq? (.ref live-b 'status) 'superseded-stale))
      ;; Record counterexamples monotonically, mark branch superseded, NEVER pollute Trunk evidence!
      (let* ((bs* (update-branch-status (.ref trunk 'branches) bid 'superseded-stale))
             (trunk-next (.o bind-these: #f
                             kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                             trunk-id: (.ref trunk 'trunk-id)
                             apex-obligation-id: (.ref trunk 'apex-obligation-id)
                             shared-context-cut: (.ref trunk 'shared-context-cut)
                             kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                             live-grant-epoch: (.ref trunk 'live-grant-epoch)
                             trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                             capability-envelope: (.ref trunk 'capability-envelope)
                             obligation-graph: (.ref trunk 'obligation-graph)
                             branches: bs*
                             absorbed-contributions: (.ref trunk 'absorbed-contributions)
                             counterexample-core: new-ce
                             apex-status: (.ref trunk 'apex-status)
                             apex-receipt: (.ref trunk 'apex-receipt))))
        (.o bind-these: #f
            admitted?: #f
            reason: 'branch-contribution-superseded-by-trunk-cut-or-epoch
            trunk: trunk-next)))
     ((and (eq? exit-k 'completed) (not (.ref contribution 'declass-cert)))
      (.o bind-these: #f admitted?: #f reason: 'missing-declassification-certificate trunk: trunk))
     ((memq exit-k '(parked-custody cancelled))
      (let* ((bs* (update-branch-status (.ref trunk 'branches) bid exit-k))
             (trunk-next (.o bind-these: #f
                             kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                             trunk-id: (.ref trunk 'trunk-id)
                             apex-obligation-id: (.ref trunk 'apex-obligation-id)
                             shared-context-cut: (.ref trunk 'shared-context-cut)
                             kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                             live-grant-epoch: (.ref trunk 'live-grant-epoch)
                             trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                             capability-envelope: (.ref trunk 'capability-envelope)
                             obligation-graph: (.ref trunk 'obligation-graph)
                             branches: bs*
                             absorbed-contributions: (.ref trunk 'absorbed-contributions)
                             counterexample-core: new-ce
                             apex-status: (.ref trunk 'apex-status)
                             apex-receipt: (.ref trunk 'apex-receipt))))
        (.o bind-these: #f
            admitted?: #t
            reason: (if (eq? exit-k 'cancelled) 'branch-cancelled-counterexamples-preserved 'branch-parked-custody)
            trunk: trunk-next)))
     (else
      ;; Completed / promoted-to-task: absorb evidence & competing hypotheses onto Trunk in C4 order
      (let* ((g0 (.ref trunk 'obligation-graph))
             (g1 (let loop ((evs (.ref contribution 'evidence-facts)) (g g0))
                   (if (null? evs) g (loop (cdr evs) (obligation-graph-with-evidence g (car evs))))))
             (hyps (opt-ref contribution 'hypotheses '()))
             (g2 (if (pair? hyps) (obligation-graph-with-hypotheses g1 hyps) g1))
             (bs* (update-branch-status (.ref trunk 'branches) bid 'absorbed))
             (contribs* (sort-contributions-c4
                         (cons contribution (.ref trunk 'absorbed-contributions))))
             (trunk-next (.o bind-these: #f
                             kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                             trunk-id: (.ref trunk 'trunk-id)
                             apex-obligation-id: (.ref trunk 'apex-obligation-id)
                             shared-context-cut: (.ref trunk 'shared-context-cut)
                             kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                             live-grant-epoch: (.ref trunk 'live-grant-epoch)
                             trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                             capability-envelope: (.ref trunk 'capability-envelope)
                             obligation-graph: g2
                             branches: bs*
                             absorbed-contributions: contribs*
                             counterexample-core: new-ce
                             apex-status: (.ref trunk 'apex-status)
                             apex-receipt: (.ref trunk 'apex-receipt))))
        (.o bind-these: #f
            admitted?: #t
            reason: 'branch-contribution-absorbed-into-trunk
            trunk: trunk-next))))))

;;; Apex-Driven Lifecycle Invalidation:
;;; Advancing Trunk cut/epoch or revoking Trunk Cedar grant immediately marks
;;; every active branch bound to an older cut/epoch as `superseded-stale`.
(def (trunk-advance-cut-or-revoke
      trunk
      new-cut: (new-cut #f)
      new-grant-epoch: (new-grant-epoch #f)
      trunk-grant-live?: (trunk-grant-live? 'unchanged))
  (let* ((cut* (or new-cut (.ref trunk 'shared-context-cut)))
         (epoch* (or new-grant-epoch (.ref trunk 'live-grant-epoch)))
         (live?* (if (eq? trunk-grant-live? 'unchanged)
                   (.ref trunk 'trunk-grant-live?)
                   (and trunk-grant-live? #t)))
         (kv* (if new-cut
                (digest (list 'shared-context-kv-prefix.v1 (.ref trunk 'trunk-id) cut*))
                (.ref trunk 'kv-prefix-digest)))
         (g* (let* ((g0 (.ref trunk 'obligation-graph))
                    (g1 (if new-cut
                          (obligation-graph-apply-event
                           g0 (.o bind-these: #f event-kind: 'advance-cut cut: cut*))
                          g0)))
               (if (eq? trunk-grant-live? 'unchanged)
                 g1
                 (obligation-graph-apply-event
                  g1 (.o bind-these: #f event-kind: (if live?* 'cedar-restored 'cedar-revoked))))))
         (bs* (map (lambda (b)
                     (if (and (eq? (.ref b 'status) 'active)
                              (or (not live?*)
                                  (not (equal? (.ref b 'shared-context-cut) cut*))
                                  (not (= (.ref b 'bound-grant-epoch) epoch*))))
                       (.o bind-these: #f
                           kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
                           branch-id: (.ref b 'branch-id)
                           branch-kind: (.ref b 'branch-kind)
                           trunk-id: (.ref b 'trunk-id)
                           serving-apex-id: (.ref b 'serving-apex-id)
                           target-obligation-id: (.ref b 'target-obligation-id)
                           shared-context-cut: (.ref b 'shared-context-cut)
                           kv-prefix-digest: (.ref b 'kv-prefix-digest)
                           bound-grant-epoch: (.ref b 'bound-grant-epoch)
                           c4-priority: (.ref b 'c4-priority)
                           required-for-apex?: (.ref b 'required-for-apex?)
                           can-finalize-trunk?: #f
                           status: 'superseded-stale
                           delegation-token: (.ref b 'delegation-token)
                           capability-envelope: (.ref b 'capability-envelope))
                       b))
                   (.ref trunk 'branches))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
        trunk-id: (.ref trunk 'trunk-id)
        apex-obligation-id: (.ref trunk 'apex-obligation-id)
        shared-context-cut: cut*
        kv-prefix-digest: kv*
        live-grant-epoch: epoch*
        trunk-grant-live?: live?*
        capability-envelope: (.ref trunk 'capability-envelope)
        obligation-graph: g*
        branches: bs*
        absorbed-contributions: (.ref trunk 'absorbed-contributions)
        counterexample-core: (.ref trunk 'counterexample-core)
        apex-status: (.ref trunk 'apex-status)
        apex-receipt: (.ref trunk 'apex-receipt))))

;;; Convergent Apex Join Gate (`converge-trunk-to-apex`):
;;; The ONLY place where the Trunk may declare global task completion.
;;; 1. Blocks if ANY required serving branch is still `active` (unclosed).
;;; 2. Runs ASCENT Obligation-Fixpoint Reconciler + FunFlow C4 DAG Frontier on
;;;    the Trunk's absorbed ObligationGraph.
;;; 3. Verifies `apex-obligation-id` is discharged and Cedar grant is live.
;;; 4. Preserves competing hypotheses & `counterexample-core` in `ApexConvergenceReceipt.`
;;; 5. Immediately supersedes any remaining optional branches upon Apex closure.
(def (converge-trunk-to-apex
      trunk
      funflow-runner: (funflow-runner #f)
      oracle-fn: (oracle-fn #f)
      dag-strategy: (dag-strategy ParallelFrontierStrategy.))
  (let* ((open-required-ids
          (map (lambda (b) (.ref b 'branch-id))
               (filter (lambda (b)
                         (and (.ref b 'required-for-apex?)
                              (eq? (.ref b 'status) 'active)))
                       (.ref trunk 'branches))))
         (open-check (parent-completion-admitted? #t open-required-ids '())))
    (cond
     ((not (.ref trunk 'trunk-grant-live?))
      (.o bind-these: #f
          converged?: #f
          reason: 'trunk-cedar-grant-revoked
          trunk: trunk
          apex-receipt: #f))
     ((not (.ref open-check 'admitted?))
      (.o bind-these: #f
          converged?: #f
          reason: 'unclosed-serving-branches-remaining
          open-branch-ids: open-required-ids
          trunk: trunk
          apex-receipt: #f))
     (else
      (let* ((report (reconcile-to-fixed-point
                      (.ref trunk 'obligation-graph)
                      oracle-fn: oracle-fn
                      funflow-runner: funflow-runner
                      dag-strategy: dag-strategy))
             (g-final (.ref report 'graph))
             (frontier (.ref report 'final-frontier))
             (apex-id (.ref trunk 'apex-obligation-id))
             (discharged-ids (map (lambda (o) (if (object? o) (.ref o 'obligation-id) o))
                                  (.ref frontier 'discharged-obligations)))
             (apex-discharged? (and (member apex-id discharged-ids) #t)))
        (if (not apex-discharged?)
          (let ((trunk-open (.o bind-these: #f
                                kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                                trunk-id: (.ref trunk 'trunk-id)
                                apex-obligation-id: apex-id
                                shared-context-cut: (.ref trunk 'shared-context-cut)
                                kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                                live-grant-epoch: (.ref trunk 'live-grant-epoch)
                                trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                                capability-envelope: (.ref trunk 'capability-envelope)
                                obligation-graph: g-final
                                branches: (.ref trunk 'branches)
                                absorbed-contributions: (.ref trunk 'absorbed-contributions)
                                counterexample-core: (.ref trunk 'counterexample-core)
                                apex-status: 'open
                                apex-receipt: #f)))
            (.o bind-these: #f
                converged?: #f
                reason: 'apex-obligation-not-yet-discharged
                reconcile-report: report
                trunk: trunk-open
                apex-receipt: #f))
          (let* ((absorbed-ids (map (lambda (c) (.ref c 'branch-id))
                                    (.ref trunk 'absorbed-contributions)))
                 ;; Apex-Driven Cancellation: supersede any remaining active optional branches
                 (bs-closed (map (lambda (b)
                                   (if (eq? (.ref b 'status) 'active)
                                     (.o bind-these: #f
                                         kind: 'agentic-ai-lab.loop-engine.trunk-branch.v1
                                         branch-id: (.ref b 'branch-id)
                                         branch-kind: (.ref b 'branch-kind)
                                         trunk-id: (.ref b 'trunk-id)
                                         serving-apex-id: (.ref b 'serving-apex-id)
                                         target-obligation-id: (.ref b 'target-obligation-id)
                                         shared-context-cut: (.ref b 'shared-context-cut)
                                         kv-prefix-digest: (.ref b 'kv-prefix-digest)
                                         bound-grant-epoch: (.ref b 'bound-grant-epoch)
                                         c4-priority: (.ref b 'c4-priority)
                                         required-for-apex?: (.ref b 'required-for-apex?)
                                         can-finalize-trunk?: #f
                                         status: 'superseded-by-apex
                                         delegation-token: (.ref b 'delegation-token)
                                         capability-envelope: (.ref b 'capability-envelope))
                                     b))
                                 (.ref trunk 'branches)))
                 (receipt (.o bind-these: #f
                              kind: 'agentic-ai-lab.loop-engine.apex-convergence.v1
                              trunk-id: (.ref trunk 'trunk-id)
                              apex-obligation-id: apex-id
                              shared-context-cut: (.ref trunk 'shared-context-cut)
                              kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                              absorbed-branch-ids-c4-order: absorbed-ids
                              counterexample-core: (.ref trunk 'counterexample-core)
                              unrefuted-hypotheses: (.ref frontier 'unrefuted-hypotheses)
                              hypothesis-verdict: (.ref frontier 'epistemic-competition-status)
                              total-llm-calls: (.ref report 'total-llm-calls)
                              total-det-tasks: (.ref report 'total-det-tasks)
                              receipt-digest: (digest (list 'apex-convergence.v1
                                                            (.ref trunk 'trunk-id)
                                                            apex-id
                                                            (.ref trunk 'shared-context-cut)
                                                            absorbed-ids
                                                            (.ref trunk 'counterexample-core)))))
                 (trunk-done (.o bind-these: #f
                                 kind: 'agentic-ai-lab.loop-engine.context-trunk.v1
                                 trunk-id: (.ref trunk 'trunk-id)
                                 apex-obligation-id: apex-id
                                 shared-context-cut: (.ref trunk 'shared-context-cut)
                                 kv-prefix-digest: (.ref trunk 'kv-prefix-digest)
                                 live-grant-epoch: (.ref trunk 'live-grant-epoch)
                                 trunk-grant-live?: (.ref trunk 'trunk-grant-live?)
                                 capability-envelope: (.ref trunk 'capability-envelope)
                                 obligation-graph: g-final
                                 branches: bs-closed
                                 absorbed-contributions: (.ref trunk 'absorbed-contributions)
                                 counterexample-core: (.ref trunk 'counterexample-core)
                                 apex-status: 'converged
                                 apex-receipt: receipt)))
            (.o bind-these: #f
                converged?: #t
                reason: 'apex-converged
                reconcile-report: report
                trunk: trunk-done
                apex-receipt: receipt))))))))
