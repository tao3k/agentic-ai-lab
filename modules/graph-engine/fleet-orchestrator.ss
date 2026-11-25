;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scheme Multi-Actor Fleet Orchestrator
;;; (`modules/graph-engine/fleet-orchestrator.ss`).
;;;
;;; Elevates single-actor `unified-effect-driver.ss` to a full Session-free
;;; Fleet of concurrent `TaskActor.`s (primary actors + siblings spawned via
;;; Design 165 `spawn-sibling-task` detour exit + auto-archived settled actors
;;; + disjoint read-only peeks), emitting ONE merged parallel `[AtomicEffect...]`
;;; batch per round for Marlin's thin 4-primitive Rust `effect_pump` and
;;; projecting the entire live Fleet directly into Marlin's `WorkbenchTabProjection`.
;;;
;;; ZERO Rust edits, ZERO isolated subagents (siblings inherit parent scope &
;;; frozen Zone-1 `kv-prefix-digest`), and strict non-authorizing security
;;; inference invariants preserved across every actor in the Fleet.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter find)
        "obligation-graph.ss"
        "delegation-fence.ss"
        "convergent-tree.ss"
        "journal-handoff.ss"
        "task-actor.ss"
        "atomic-effect-orchestrator.ss"
        "unified-effect-driver.ss")

(export GraphFleetState.
        GraphFleetStepResult.
        GraphFleetRunTrace.
        GraphFleetSnapshot.
        make-graph-fleet-state
        fleet-spawn-sibling-from-detour
        fleet-apply-bitemporal-event
        fleet-propose-hypothesis-branch
        fleet-propagate-shared-defeater
        step-graph-fleet
        run-graph-fleet-to-quiescence
        fleet->inert-snapshot
        inert-snapshot->fleet
        fleet->wire-string
        wire-string->fleet
        plan-fleet-cas-checkpoint
        restore-fleet-from-cas-receipt
        project-fleet->workbench-projection)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (strip-prefix prefix s)
  (let ((plen (string-length prefix))
        (slen (string-length s)))
    (if (and (>= slen plen) (string-prefix? prefix s))
      (substring s plen slen)
      #f)))

(.def GraphFleetState.
  kind: 'agentic-ai-lab.graph-engine.fleet-state.v1
  authorizes-effect?: #f)

(.def GraphFleetStepResult.
  kind: 'agentic-ai-lab.graph-engine.fleet-step-result.v1
  authorizes-effect?: #f)

(.def GraphFleetRunTrace.
  kind: 'agentic-ai-lab.graph-engine.fleet-run-trace.v1
  authorizes-effect?: #f)

(.def GraphFleetSnapshot.
  kind: 'agentic-ai-lab.graph-engine.fleet-snapshot.v1
  runtime-executed?: #f)

(def (make-graph-fleet-state
      active-drivers
      archived-actors: (archived-actors '())
      peek-set: (peek-set '())
      focused-task-id: (focused-task-id #f)
      round-count: (round-count 0))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.fleet-state.v1
      active-drivers: active-drivers
      archived-actors: archived-actors
      peek-set: peek-set
      focused-task-id: focused-task-id
      round-count: round-count
      authorizes-effect?: #f))

(def (namespace-effect task-id eff)
  (let ((ns-id (string-append "actor:" task-id "::" (.ref eff 'effect-id)))
        (k (.ref eff 'kind)))
    (cond
     ((eq? k 'cas-get)
      (make-cas-get-effect ns-id (.ref eff 'key)))
     ((eq? k 'cas-put)
      (make-cas-put-effect ns-id (.ref eff 'key) (.ref eff 'payload)))
     ((eq? k 'llm-complete)
      (make-llm-complete-effect
       ns-id
       (.ref eff 'endpoint)
       (.ref eff 'messages)
       metadata: (cons (cons 'owner-task-id task-id) (opt-ref eff 'metadata '()))))
     ((eq? k 'sandbox-run)
      (make-sandbox-run-effect
       ns-id
       (.ref eff 'program)
       (.ref eff 'args)
       cwd: (opt-ref eff 'cwd #f)))
     (else eff))))

(def (unnamespace-receipt-for task-id receipt)
  (let* ((prefix (string-append "actor:" task-id "::"))
         (eid (and (object? receipt) (opt-ref receipt 'effect-id "")))
         (inner-id (and (string? eid) (strip-prefix prefix eid))))
    (if (not inner-id)
      #f
      (let ((k (.ref receipt 'kind)))
        (cond
         ((eq? k 'cas-hit) (make-cas-hit-receipt inner-id (.ref receipt 'payload)))
         ((eq? k 'cas-miss) (make-cas-miss-receipt inner-id))
         ((eq? k 'cas-stored) (make-cas-stored-receipt inner-id))
         ((eq? k 'llm-completed) (make-llm-completed-receipt inner-id (.ref receipt 'content)))
         ((eq? k 'sandbox-exited)
          (make-sandbox-exited-receipt
           inner-id (.ref receipt 'exit-code) (.ref receipt 'stdout)
           stderr: (opt-ref receipt 'stderr "")))
         (else (make-effect-error-receipt inner-id (opt-ref receipt 'message "error"))))))))

(def (receipts-for-actor task-id receipts)
  (let loop ((rs receipts) (acc '()))
    (if (null? rs)
      (reverse acc)
      (let ((u (unnamespace-receipt-for task-id (car rs))))
        (loop (cdr rs) (if u (cons u acc) acc))))))

;;; Exit `parent-task-id`'s active Scoped Detour via `spawn-sibling-task`,
;;; spawning a convergent sibling `TaskActor.` inheriting the parent's `scope-mode`,
;;; `worktree`, and frozen `kv-prefix-digest` (zero isolated subagents!).
(def (fleet-spawn-sibling-from-detour
      fleet
      parent-task-id
      sibling-task-id
      sibling-title
      sibling-obligation-graph
      sibling-apex-id: (sibling-apex-id "ob-sibling")
      sibling-hypotheses: (sibling-hypotheses '())
      sibling-branches: (sibling-branches '()))
  (let* ((drivers (.ref fleet 'active-drivers))
         (parent-st (find (lambda (st) (equal? (.ref (.ref st 'actor) 'task-id) parent-task-id))
                          drivers)))
    (unless parent-st
      (error "fleet-spawn-sibling-from-detour: parent task actor not found in active fleet"
             parent-task-id))
    (let* ((parent-actor (.ref parent-st 'actor))
           (parent-ctx (.ref parent-st 'governed-context))
           (parent-trunk (.ref parent-actor 'trunk))
           (exit-res (exit-task-actor-detour
                      parent-actor 'spawn-sibling-task
                      sibling-task-id: sibling-task-id))
           (updated-parent-actor (.ref exit-res 'actor))
           (updated-parent-st (make-unified-driver-state
                               updated-parent-actor
                               (.ref parent-st 'obligation-graph)
                               parent-ctx
                               competing-hypotheses: (.ref parent-st 'competing-hypotheses)
                               branch-proposals: (.ref parent-st 'branch-proposals)
                               hypothesis-matrix: (opt-ref parent-st 'hypothesis-matrix #f)
                               completed-step-outputs: (opt-ref parent-st 'completed-step-outputs '())
                               step-count: (opt-ref parent-st 'step-count 0)))
           (sib-trunk (make-context-trunk
                       (string-append "trunk-" sibling-task-id)
                       sibling-apex-id
                       sibling-obligation-graph
                       (.ref parent-trunk 'capability-envelope)
                       shared-context-cut: (.ref parent-trunk 'shared-context-cut)
                       kv-prefix-digest: (.ref parent-trunk 'kv-prefix-digest)))
           (sib-actor (make-task-actor
                       sibling-task-id
                       sib-trunk
                       (.ref parent-actor 'scope-ids)
                       title: sibling-title
                       worktree: (opt-ref parent-actor 'worktree "main")
                       scope-mode: (opt-ref parent-actor 'scope-mode 'project)))
           (sib-st (make-unified-driver-state
                    sib-actor
                    sibling-obligation-graph
                    parent-ctx
                    competing-hypotheses: sibling-hypotheses
                    branch-proposals: sibling-branches))
           (next-drivers
            (append
             (map (lambda (st)
                    (if (equal? (.ref (.ref st 'actor) 'task-id) parent-task-id)
                      updated-parent-st
                      st))
                  drivers)
             (list sib-st))))
      (make-graph-fleet-state
       next-drivers
       archived-actors: (.ref fleet 'archived-actors)
       peek-set: (.ref fleet 'peek-set)
       focused-task-id: (or (.ref fleet 'focused-task-id) sibling-task-id)
       round-count: (.ref fleet 'round-count)))))

(def (graph-has-active-defeaters? g)
  (let loop ((obs (.ref g 'obligations)))
    (cond
     ((null? obs) #f)
     ((pair? (.ref (car obs) 'active-defeaters)) #t)
     (else (loop (cdr obs))))))

;;; Inject an external bitemporal event (`defeater-discovered`, `premise-retracted`,
;;; `cedar-revoked`, `cedar-restored`, `human-approved`, `evidence-arrived`, etc.)
;;; onto `task-id` inside the live Fleet:
;;;   - Selectively updates `ObligationGraph` (preserving unrelated CAS receipts!)
;;;   - On defeater/retraction/revocation: elevates `governed-context` to L3,
;;;     appends a `human-inbox` diagnostic entry, and enters `blocker-active` Detour!
;;;   - On `human-approved` / `cedar-restored`: clears resolved blocker & exits
;;;     `blocker-active` cleanly via `'return-to-origin`.
(def (fleet-apply-bitemporal-event fleet task-id event)
  (let* ((ekind (.ref event 'event-kind))
         (drivers (.ref fleet 'active-drivers))
         (next-drivers
          (map
           (lambda (st)
             (if (not (equal? (.ref (.ref st 'actor) 'task-id) task-id))
               st
               (let* ((actor (.ref st 'actor))
                      (graph0 (.ref st 'obligation-graph))
                      (ctx0 (.ref st 'governed-context))
                      (g1 (obligation-graph-apply-event graph0 event))
                      (blocking? (memq ekind '(defeater-discovered premise-retracted
                                               cedar-revoked mcp-manifest-mutated)))
                      (resolving? (memq ekind '(human-approved cedar-restored mcp-manifest-repinned)))
                      (g2 (if blocking?
                            (obligation-graph-add-human-inbox
                             g1
                             (.o bind-these: #f
                                 kind: ekind
                                 task-id: task-id
                                 detail: (or (opt-ref event 'defeater-id #f)
                                             (opt-ref event 'premise-id #f)
                                             (symbol->string ekind))))
                            g1))
                      (defeater-now? (graph-has-active-defeaters? g2))
                      (next-ctx
                       (.o bind-these: #f
                           context-cut: (.ref g2 'cut)
                           kv-prefix-digest: (opt-ref ctx0 'kv-prefix-digest "sha256:unbound")
                           disclosure-depth: (if (or blocking? defeater-now?)
                                               'L3
                                               (opt-ref ctx0 'disclosure-depth 'L1))
                           has-active-defeater?: (or defeater-now? (eq? ekind 'defeater-discovered))
                           sandbox-admitted?: (opt-ref ctx0 'sandbox-admitted? #t)
                           cedar-handoff-valid?: (cond
                                                  ((eq? ekind 'cedar-revoked) #f)
                                                  ((memq ekind '(cedar-restored human-approved)) #t)
                                                  (else (opt-ref ctx0 'cedar-handoff-valid? #t)))))
                      (cur-detour (opt-ref actor 'detour-mode 'mainline))
                      (next-actor
                       (cond
                        ((and blocking? (eq? cur-detour 'mainline))
                         (.ref (enter-task-actor-detour
                                actor 'blocker-active
                                (string-append "blk-event-" (symbol->string ekind)))
                               'actor))
                        ((and resolving? (eq? cur-detour 'blocker-active) (not defeater-now?)
                              (.ref g2 'cedar-grant-live?))
                         (.ref (exit-task-actor-detour actor 'return-to-origin) 'actor))
                        (else actor))))
                 (make-unified-driver-state
                  next-actor g2 next-ctx
                  competing-hypotheses: (.ref st 'competing-hypotheses)
                  branch-proposals: (.ref st 'branch-proposals)
                  hypothesis-matrix: (opt-ref st 'hypothesis-matrix #f)
                  completed-step-outputs: (opt-ref st 'completed-step-outputs '())
                  step-count: (opt-ref st 'step-count 0)
                  repair-budget: (opt-ref st 'repair-budget 3)
                  repair-history: (opt-ref st 'repair-history '())))))
           drivers)))
    (make-graph-fleet-state
     next-drivers
     archived-actors: (.ref fleet 'archived-actors)
     peek-set: (.ref fleet 'peek-set)
     focused-task-id: (.ref fleet 'focused-task-id)
     round-count: (.ref fleet 'round-count))))

;;; Append a bounded investigator/agent POO `HypothesisBranchProposal.` onto
;;; `task-id` inside the live Fleet, invalidating ONLY `hypothesis-matrix` so
;;; the next `step-graph-fleet` evaluates EVERY branch against EVERY preserved
;;; competing hypothesis without re-running completed deterministic CAS steps
;;; or authorizing any effect!
(def (fleet-propose-hypothesis-branch
      fleet
      task-id
      branch-proposal
      max-branches: (max-branches 16))
  (unless (and (object? branch-proposal)
               (eq? (opt-ref branch-proposal 'kind #f)
                    'agentic-ai-lab.graph-engine.hypothesis-branch-proposal.v1)
               (not (opt-ref branch-proposal 'authorizes-effect? #t)))
    (error "fleet-propose-hypothesis-branch: requires non-authorizing HypothesisBranchProposal."
           branch-proposal))
  (let* ((drivers (.ref fleet 'active-drivers))
         (target-st (find (lambda (st) (equal? (.ref (.ref st 'actor) 'task-id) task-id))
                          drivers)))
    (unless target-st
      (error "fleet-propose-hypothesis-branch: active task actor not found" task-id))
    (let* ((bid (.ref branch-proposal 'branch-id))
           (existing (.ref target-st 'branch-proposals))
           (kept (filter (lambda (b) (not (equal? (.ref b 'branch-id) bid))) existing))
           (updated (append kept (list branch-proposal))))
      (when (> (length updated) (max 1 max-branches))
        (error "fleet-propose-hypothesis-branch: bounded branch limit exceeded" max-branches))
      (let ((next-drivers
             (map (lambda (st)
                    (if (not (equal? (.ref (.ref st 'actor) 'task-id) task-id))
                      st
                      (make-unified-driver-state
                       (.ref st 'actor)
                       (.ref st 'obligation-graph)
                       (.ref st 'governed-context)
                       competing-hypotheses: (.ref st 'competing-hypotheses)
                       branch-proposals: updated
                       hypothesis-matrix: #f
                       completed-step-outputs: (opt-ref st 'completed-step-outputs '())
                       step-count: (opt-ref st 'step-count 0)
                       repair-budget: (opt-ref st 'repair-budget 3)
                       repair-history: (opt-ref st 'repair-history '()))))
                  drivers)))
        (make-graph-fleet-state
         next-drivers
         archived-actors: (.ref fleet 'archived-actors)
         peek-set: (.ref fleet 'peek-set)
         focused-task-id: (.ref fleet 'focused-task-id)
         round-count: (.ref fleet 'round-count))))))

;;; Propagate a newly discovered defeater across EVERY active actor in the Fleet
;;; whose obligations depend on `shared-premise-id` (entering `blocker-active`,
;;; L3 disclosure floor, and appending a `human-inbox` diagnostic), while leaving
;;; all independent actors untouched in `mainline`!
(def (fleet-propagate-shared-defeater
      fleet
      defeater-id
      shared-premise-id
      source-task-id: (source-task-id #f))
  (let loop ((ds (.ref fleet 'active-drivers)) (fl fleet))
    (if (null? ds)
      fl
      (let* ((st (car ds))
             (tid (.ref (.ref st 'actor) 'task-id))
             (obs (.ref (.ref st 'obligation-graph) 'obligations))
             (matching-obs
              (filter (lambda (o)
                        (or (member shared-premise-id (opt-ref o 'premise-ids '()))
                            (member shared-premise-id (opt-ref o 'required-evidence-ids '()))
                            (and source-task-id (equal? tid source-task-id))))
                      obs)))
        (if (null? matching-obs)
          (loop (cdr ds) fl)
          (let ob-loop ((mos matching-obs) (cur-fl fl))
            (if (null? mos)
              (loop (cdr ds) cur-fl)
              (let ((ev (.o bind-these: #f
                            event-kind: 'defeater-discovered
                            obligation-id: (.ref (car mos) 'obligation-id)
                            defeater-id: defeater-id)))
                (ob-loop (cdr mos) (fleet-apply-bitemporal-event cur-fl tid ev))))))))))

;;; Pure functional fleet step: runs `drive-graph-actor-step` across EVERY active
;;; actor simultaneously, merges all emitted `AtomicEffect.`s into a single
;;; parallel batch for Marlin's thin Tokio pump, and optionally auto-archives
;;; settled mainline actors reaching `quiescent-fixed-point`.
(def (step-graph-fleet fleet (receipts '()) auto-archive?: (auto-archive? #t))
  (let ((drivers (.ref fleet 'active-drivers))
        (prior-archived (.ref fleet 'archived-actors))
        (next-round (+ (.ref fleet 'round-count) 1)))
    (let loop ((ds drivers)
               (kept-drivers '())
               (kept-steps '())
               (newly-archived '())
               (merged-effects '())
               (total-llm 0)
               (total-cas-hits 0)
               (total-cas-puts 0))
      (if (null? ds)
        (let* ((final-drivers (reverse kept-drivers))
               (final-steps (reverse kept-steps))
               (final-archived (append prior-archived (reverse newly-archived)))
               (next-fleet (make-graph-fleet-state
                            final-drivers
                            archived-actors: final-archived
                            peek-set: (.ref fleet 'peek-set)
                            focused-task-id: (.ref fleet 'focused-task-id)
                            round-count: next-round)))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.graph-engine.fleet-step-result.v1
              fleet: next-fleet
              actor-steps: final-steps
              effects: (reverse merged-effects)
              llm-calls-emitted: total-llm
              cas-hits-observed: total-cas-hits
              cas-puts-emitted: total-cas-puts
              newly-archived-ids: (map (lambda (a) (.ref a 'task-id)) (reverse newly-archived))
              authorizes-effect?: #f))
        (let* ((st (car ds))
               (tid (.ref (.ref st 'actor) 'task-id))
               (my-rcpts (receipts-for-actor tid receipts))
               (step (drive-graph-actor-step st my-rcpts))
               (phase (.ref step 'phase))
               (effs (.ref step 'effects))
               (next-st (.ref step 'state))
               (next-actor (.ref next-st 'actor))
               (detour-mode (opt-ref next-actor 'detour-mode 'mainline))
               (should-archive? (and auto-archive?
                                     (eq? phase 'quiescent-fixed-point)
                                     (eq? detour-mode 'mainline)
                                     (null? effs)))
               (ns-effs (map (lambda (e) (namespace-effect tid e)) effs)))
          (if should-archive?
            (let ((settled (.o bind-these: #f
                               task-id: tid
                               title: (opt-ref next-actor 'title tid)
                               worktree: (opt-ref next-actor 'worktree "main")
                               status: 'done
                               archived?: #t
                               competing-hypotheses: (.ref next-st 'competing-hypotheses)
                               hypothesis-matrix: (.ref step 'hypothesis-matrix))))
              (loop (cdr ds)
                    kept-drivers
                    kept-steps
                    (cons settled newly-archived)
                    merged-effects
                    (+ total-llm (.ref step 'llm-calls-emitted))
                    (+ total-cas-hits (opt-ref step 'cas-hits-observed 0))
                    (+ total-cas-puts (opt-ref step 'cas-puts-emitted 0))))
            (loop (cdr ds)
                  (cons next-st kept-drivers)
                  (cons step kept-steps)
                  newly-archived
                  (append (reverse ns-effs) merged-effects)
                  (+ total-llm (.ref step 'llm-calls-emitted))
                  (+ total-cas-hits (opt-ref step 'cas-hits-observed 0))
                  (+ total-cas-puts (opt-ref step 'cas-puts-emitted 0)))))))))

;;; Pure multi-round Fleet trampoline driving ALL active actors concurrently
;;; through `effect-interpreter` until zero atomic effects remain.
(def (run-graph-fleet-to-quiescence
      initial-fleet
      effect-interpreter
      max-rounds: (max-rounds 12)
      auto-archive?: (auto-archive? #t))
  (let loop ((fl initial-fleet)
             (incoming '())
             (round 1)
             (total-llm 0)
             (total-cas-hits 0)
             (total-cas-puts 0)
             (trace '()))
    (let* ((res (step-graph-fleet fl incoming auto-archive?: auto-archive?))
           (next-fl (.ref res 'fleet))
           (effs (.ref res 'effects))
           (llm-n (+ total-llm (.ref res 'llm-calls-emitted)))
           (hit-n (+ total-cas-hits (.ref res 'cas-hits-observed)))
           (put-n (+ total-cas-puts (.ref res 'cas-puts-emitted)))
           (entry (.o bind-these: #f
                      round: round
                      active-count: (length (.ref next-fl 'active-drivers))
                      archived-count: (length (.ref next-fl 'archived-actors))
                      effects-count: (length effs)
                      llm-calls-emitted: (.ref res 'llm-calls-emitted)
                      cas-hits-observed: (.ref res 'cas-hits-observed)
                      cas-puts-emitted: (.ref res 'cas-puts-emitted)))
           (next-trace (append trace (list entry))))
      (if (or (null? effs) (>= round max-rounds))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.graph-engine.fleet-run-trace.v1
            final-fleet: next-fl
            final-step: res
            rounds-executed: round
            total-llm-calls: llm-n
            total-cas-hits: hit-n
            total-cas-puts: put-n
            active-task-ids: (map (lambda (st) (.ref (.ref st 'actor) 'task-id))
                                  (.ref next-fl 'active-drivers))
            settled-task-ids: (map (lambda (a) (.ref a 'task-id))
                                   (.ref next-fl 'archived-actors))
            trace: next-trace
            authorizes-effect?: #f)
        (let ((next-receipts (effect-interpreter effs)))
          (loop next-fl next-receipts (+ round 1) llm-n hit-n put-n next-trace))))))

;;; Pure Scheme inert snapshot of a complete multi-actor `GraphFleetState.`
;;; (suitable for persisting via Marlin's thin `CasPutEffect.` / Turso WAL and
;;; lossless crash-restart recovery without touching Rust high-order logic!).
(def (fleet->inert-snapshot fleet-or-run)
  (let* ((fleet (if (and (object? fleet-or-run)
                         (eq? (opt-ref fleet-or-run 'kind #f)
                              'agentic-ai-lab.graph-engine.fleet-run-trace.v1))
                  (.ref fleet-or-run 'final-fleet)
                  fleet-or-run))
         (active-entries
          (map (lambda (st)
                 (let ((actor (.ref st 'actor)))
                   (.o bind-these: #f
                       task-id: (.ref actor 'task-id)
                       title: (opt-ref actor 'title (.ref actor 'task-id))
                       worktree: (opt-ref actor 'worktree "main")
                       scope-mode: (opt-ref actor 'scope-mode 'project)
                       scope-ids: (opt-ref actor 'scope-ids '("scope-main"))
                       fencing-epoch: (opt-ref actor 'fencing-epoch 1)
                       detour-mode: (opt-ref actor 'detour-mode 'mainline)
                       detour-node-id: (opt-ref actor 'detour-node-id #f)
                       trunk-snapshot: (trunk->inert-snapshot (.ref actor 'trunk))
                       obligation-graph: (.ref st 'obligation-graph)
                       governed-context: (.ref st 'governed-context)
                       competing-hypotheses: (.ref st 'competing-hypotheses)
                       branch-proposals: (.ref st 'branch-proposals)
                       hypothesis-matrix: (opt-ref st 'hypothesis-matrix #f)
                       completed-step-outputs: (opt-ref st 'completed-step-outputs '())
                       step-count: (opt-ref st 'step-count 0)
                       repair-budget: (opt-ref st 'repair-budget 3)
                       repair-history: (opt-ref st 'repair-history '()))))
               (.ref fleet 'active-drivers))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.fleet-snapshot.v1
        active-entries: active-entries
        archived-actors: (.ref fleet 'archived-actors)
        peek-set: (.ref fleet 'peek-set)
        focused-task-id: (.ref fleet 'focused-task-id)
        round-count: (.ref fleet 'round-count)
        runtime-executed?: #f)))

;;; Reconstruct a live, runnable `GraphFleetState.` from a `GraphFleetSnapshot.`.
(def (inert-snapshot->fleet snap)
  (let ((drivers
         (map (lambda (e)
                (let* ((trunk (inert-snapshot->trunk (.ref e 'trunk-snapshot)))
                       (base-actor (make-task-actor
                                    (.ref e 'task-id)
                                    trunk
                                    (.ref e 'scope-ids)
                                    title: (.ref e 'title)
                                    worktree: (.ref e 'worktree)
                                    scope-mode: (.ref e 'scope-mode)
                                    fencing-epoch: (.ref e 'fencing-epoch)))
                       (dmode (.ref e 'detour-mode))
                       (actor (if (eq? dmode 'mainline)
                                base-actor
                                (.ref (enter-task-actor-detour
                                       base-actor dmode (or (.ref e 'detour-node-id) "restored-detour"))
                                      'actor))))
                  (make-unified-driver-state
                   actor
                   (.ref e 'obligation-graph)
                   (.ref e 'governed-context)
                   competing-hypotheses: (.ref e 'competing-hypotheses)
                   branch-proposals: (.ref e 'branch-proposals)
                   hypothesis-matrix: (.ref e 'hypothesis-matrix)
                   completed-step-outputs: (.ref e 'completed-step-outputs)
                   step-count: (.ref e 'step-count)
                   repair-budget: (.ref e 'repair-budget)
                   repair-history: (.ref e 'repair-history))))
              (.ref snap 'active-entries))))
    (make-graph-fleet-state
     drivers
     archived-actors: (.ref snap 'archived-actors)
     peek-set: (.ref snap 'peek-set)
     focused-task-id: (.ref snap 'focused-task-id)
     round-count: (.ref snap 'round-count))))

;;; ---------------------------------------------------------------------------
;;; Pure Scheme UTF-8 Wire Serialization (`fleet->wire-string` / `wire-string->fleet`)
;;; ---------------------------------------------------------------------------
;;; Converts a complete `GraphFleetState.` into plain, closure-free Scheme data
;;; (lists/symbols/strings/numbers/booleans) serialized as a deterministic UTF-8
;;; S-expression string suitable for real disk / Turso SQLite WAL `CasPut`/`CasGet`
;;; persistence across full VM/process restarts!

(def (wire-alist-ref alist key default)
  (let ((pair (and (list? alist) (assq key alist))))
    (if pair (cdr pair) default)))

(def (ob->wire o)
  (list (cons 'obligation-id (.ref o 'obligation-id))
        (cons 'title (opt-ref o 'title ""))
        (cons 'required-evidence-ids (opt-ref o 'required-evidence-ids '()))
        (cons 'depends-on (opt-ref o 'depends-on '()))
        (cons 'active-defeaters (opt-ref o 'active-defeaters '()))
        (cons 'premise-ids (opt-ref o 'premise-ids '()))))

(def (wire->ob a)
  (make-obligation
   (wire-alist-ref a 'obligation-id "ob-restored")
   title: (wire-alist-ref a 'title "")
   required-evidence-ids: (wire-alist-ref a 'required-evidence-ids '())
   depends-on: (wire-alist-ref a 'depends-on '())
   active-defeaters: (wire-alist-ref a 'active-defeaters '())
   premise-ids: (wire-alist-ref a 'premise-ids '())))

(def (ev->wire ev)
  (list (cons 'evidence-id (.ref ev 'evidence-id))
        (cons 'payload (opt-ref ev 'payload ""))
        (cons 'cut (opt-ref ev 'cut 1))
        (cons 'premise-ids (opt-ref ev 'premise-ids '()))
        (cons 'origin-tier (opt-ref ev 'origin-tier 'observed-fact))
        (cons 'endorsed? (opt-ref ev 'endorsed? #t))
        (cons 'retracted? (opt-ref ev 'retracted? #f))))

(def (wire->ev a)
  (make-evidence-fact
   (wire-alist-ref a 'evidence-id "ev-restored")
   (wire-alist-ref a 'payload "")
   cut: (wire-alist-ref a 'cut 1)
   premise-ids: (wire-alist-ref a 'premise-ids '())
   origin-tier: (wire-alist-ref a 'origin-tier 'observed-fact)
   endorsed?: (wire-alist-ref a 'endorsed? #t)
   retracted?: (wire-alist-ref a 'retracted? #f)))

(def (det-task->wire t)
  (list (cons 'task-id (.ref t 'task-id))
        (cons 'obligation-id (.ref t 'obligation-id))
        (cons 'produces-evidence-id (.ref t 'produces-evidence-id))
        (cons 'input (opt-ref t 'input ""))
        (cons 'required-evidence-ids (opt-ref t 'required-evidence-ids '()))
        (cons 'premise-ids (opt-ref t 'premise-ids '()))
        (cons 'depends-on-tasks (opt-ref t 'depends-on-tasks '()))
        (cons 'read-footprint (opt-ref t 'read-footprint '()))
        (cons 'write-footprint (opt-ref t 'write-footprint '()))
        (cons 'effect-class (opt-ref t 'effect-class 'pure-cas))
        (cons 'env-digest (opt-ref t 'env-digest "sha256:default-env"))))

(def (wire->det-task a)
  (make-deterministic-task-node
   (wire-alist-ref a 'task-id "det-restored")
   (wire-alist-ref a 'obligation-id "ob-restored")
   (wire-alist-ref a 'produces-evidence-id "ev-restored")
   'restored-flow
   (wire-alist-ref a 'input "")
   required-evidence-ids: (wire-alist-ref a 'required-evidence-ids '())
   premise-ids: (wire-alist-ref a 'premise-ids '())
   depends-on-tasks: (wire-alist-ref a 'depends-on-tasks '())
   read-footprint: (wire-alist-ref a 'read-footprint '())
   write-footprint: (wire-alist-ref a 'write-footprint '())
   effect-class: (wire-alist-ref a 'effect-class 'pure-cas)
   env-digest: (wire-alist-ref a 'env-digest "sha256:default-env")))

(def (inbox-item->wire item)
  (list (cons 'kind (opt-ref item 'kind 'diagnostic))
        (cons 'task-id (opt-ref item 'task-id ""))
        (cons 'detail (opt-ref item 'detail ""))))

(def (wire->inbox-item a)
  (.o bind-these: #f
      kind: (wire-alist-ref a 'kind 'diagnostic)
      task-id: (wire-alist-ref a 'task-id "")
      detail: (wire-alist-ref a 'detail "")))

(def (comp-hyp->wire h)
  (list (cons 'hypothesis-id (.ref h 'hypothesis-id))
        (cons 'claim (opt-ref h 'claim ""))
        (cons 'evidence-lineage (opt-ref h 'evidence-lineage '()))
        (cons 'contradictions (opt-ref h 'contradictions '()))
        (cons 'open-questions (opt-ref h 'open-questions '()))))

(def (wire->comp-hyp a)
  (make-competing-hypothesis
   (wire-alist-ref a 'hypothesis-id "H?")
   (wire-alist-ref a 'claim "")
   evidence-lineage: (wire-alist-ref a 'evidence-lineage '())
   contradictions: (wire-alist-ref a 'contradictions '())
   open-questions: (wire-alist-ref a 'open-questions '())))

(def (branch-prop->wire b)
  (list (cons 'branch-id (.ref b 'branch-id))
        (cons 'question (opt-ref b 'question ""))
        (cons 'proposer (opt-ref b 'proposer 'investigator))
        (cons 'endpoint (opt-ref b 'endpoint "openai/gpt-marlin"))
        (cons 'evidence-refs (opt-ref b 'evidence-refs '()))))

(def (wire->branch-prop a)
  (make-hypothesis-branch-proposal
   (wire-alist-ref a 'branch-id "B?")
   (wire-alist-ref a 'question "")
   proposer: (wire-alist-ref a 'proposer 'investigator)
   endpoint: (wire-alist-ref a 'endpoint "openai/gpt-marlin")
   evidence-refs: (wire-alist-ref a 'evidence-refs '())))

(def (graph->wire g)
  (list (cons 'graph-id (.ref g 'graph-id))
        (cons 'cut (.ref g 'cut))
        (cons 'obligations (map ob->wire (.ref g 'obligations)))
        (cons 'evidence (map ev->wire (.ref g 'evidence)))
        (cons 'det-tasks (map det-task->wire (.ref g 'det-tasks)))
        (cons 'completed-tasks (opt-ref g 'completed-tasks '()))
        (cons 'human-inbox (map inbox-item->wire (opt-ref g 'human-inbox '())))
        (cons 'cedar-grant-live? (opt-ref g 'cedar-grant-live? #t))
        (cons 'mcp-manifest-healthy? (opt-ref g 'mcp-manifest-healthy? #t))))

(def (wire->graph a)
  (let* ((base (make-obligation-graph
                (wire-alist-ref a 'graph-id "g-restored")
                cut: (wire-alist-ref a 'cut 1)
                obligations: (map wire->ob (wire-alist-ref a 'obligations '()))
                evidence: (map wire->ev (wire-alist-ref a 'evidence '()))
                det-tasks: (map wire->det-task (wire-alist-ref a 'det-tasks '()))
                completed-tasks: (wire-alist-ref a 'completed-tasks '())
                cedar-grant-live?: (wire-alist-ref a 'cedar-grant-live? #t)
                mcp-manifest-healthy?: (wire-alist-ref a 'mcp-manifest-healthy? #t))))
    (let loop ((items (map wire->inbox-item (wire-alist-ref a 'human-inbox '())))
               (g base))
      (if (null? items)
        g
        (loop (cdr items) (obligation-graph-add-human-inbox g (car items)))))))

(def (ctx->wire c)
  (list (cons 'context-cut (opt-ref c 'context-cut 1))
        (cons 'kv-prefix-digest (opt-ref c 'kv-prefix-digest "sha256:unbound"))
        (cons 'disclosure-depth (opt-ref c 'disclosure-depth 'L1))
        (cons 'has-active-defeater? (opt-ref c 'has-active-defeater? #f))
        (cons 'sandbox-admitted? (opt-ref c 'sandbox-admitted? #t))
        (cons 'cedar-handoff-valid? (opt-ref c 'cedar-handoff-valid? #t))))

(def (wire->ctx a)
  (.o bind-these: #f
      context-cut: (wire-alist-ref a 'context-cut 1)
      kv-prefix-digest: (wire-alist-ref a 'kv-prefix-digest "sha256:unbound")
      disclosure-depth: (wire-alist-ref a 'disclosure-depth 'L1)
      has-active-defeater?: (wire-alist-ref a 'has-active-defeater? #f)
      sandbox-admitted?: (wire-alist-ref a 'sandbox-admitted? #t)
      cedar-handoff-valid?: (wire-alist-ref a 'cedar-handoff-valid? #t)))

(def (archived->wire a)
  (list (cons 'task-id (.ref a 'task-id))
        (cons 'title (opt-ref a 'title (.ref a 'task-id)))
        (cons 'worktree (opt-ref a 'worktree "main"))
        (cons 'status (opt-ref a 'status 'done))
        (cons 'archived? #t)
        (cons 'competing-hypotheses (map comp-hyp->wire (opt-ref a 'competing-hypotheses '())))))

(def (wire->archived a)
  (.o bind-these: #f
      task-id: (wire-alist-ref a 'task-id "archived")
      title: (wire-alist-ref a 'title "archived")
      worktree: (wire-alist-ref a 'worktree "main")
      status: (wire-alist-ref a 'status 'done)
      archived?: #t
      competing-hypotheses: (map wire->comp-hyp (wire-alist-ref a 'competing-hypotheses '()))
      hypothesis-matrix: #f))

(def (fleet->wire-string fleet-or-run)
  (let* ((fleet (if (and (object? fleet-or-run)
                         (eq? (opt-ref fleet-or-run 'kind #f)
                              'agentic-ai-lab.graph-engine.fleet-run-trace.v1))
                  (.ref fleet-or-run 'final-fleet)
                  fleet-or-run))
         (active-wires
          (map (lambda (st)
                 (let* ((actor (.ref st 'actor))
                        (trunk (.ref actor 'trunk))
                        (env (.ref trunk 'capability-envelope)))
                   (list (cons 'task-id (.ref actor 'task-id))
                         (cons 'title (opt-ref actor 'title (.ref actor 'task-id)))
                         (cons 'worktree (opt-ref actor 'worktree "main"))
                         (cons 'scope-mode (opt-ref actor 'scope-mode 'project))
                         (cons 'scope-ids (opt-ref actor 'scope-ids '("scope-main")))
                         (cons 'fencing-epoch (opt-ref actor 'fencing-epoch 1))
                         (cons 'detour-mode (opt-ref actor 'detour-mode 'mainline))
                         (cons 'detour-node-id (opt-ref actor 'detour-node-id #f))
                         (cons 'trunk-id (.ref trunk 'trunk-id))
                         (cons 'apex-obligation-id (.ref trunk 'apex-obligation-id))
                         (cons 'shared-context-cut (.ref trunk 'shared-context-cut))
                         (cons 'kv-prefix-digest (.ref trunk 'kv-prefix-digest))
                         (cons 'env-owner (.ref env 'owner-id))
                         (cons 'env-allowed (.ref env 'allowed-caps))
                         (cons 'env-denied (.ref env 'denied-caps))
                         (cons 'env-egress? (.ref env 'egress-allowed?))
                         (cons 'obligation-graph (graph->wire (.ref st 'obligation-graph)))
                         (cons 'governed-context (ctx->wire (.ref st 'governed-context)))
                         (cons 'competing-hypotheses (map comp-hyp->wire (.ref st 'competing-hypotheses)))
                         (cons 'branch-proposals (map branch-prop->wire (.ref st 'branch-proposals)))
                         (cons 'step-count (opt-ref st 'step-count 0))
                         (cons 'repair-budget (opt-ref st 'repair-budget 3))
                         (cons 'repair-history (opt-ref st 'repair-history '())))))
               (.ref fleet 'active-drivers)))
         (wire-sexp
          (list 'fleet-wire-v1
                (cons 'active active-wires)
                (cons 'archived (map archived->wire (.ref fleet 'archived-actors)))
                (cons 'peek-set (.ref fleet 'peek-set))
                (cons 'focused-task-id (.ref fleet 'focused-task-id))
                (cons 'round-count (.ref fleet 'round-count)))))
    (call-with-output-string (lambda (port) (write wire-sexp port)))))

(def (wire-string->fleet wire-str)
  (let ((parsed (call-with-input-string wire-str read)))
    (unless (and (pair? parsed) (eq? (car parsed) 'fleet-wire-v1))
      (error "wire-string->fleet: invalid fleet-wire-v1 header" parsed))
    (let* ((alist (cdr parsed))
           (drivers
            (map (lambda (e)
                   (let* ((g (wire->graph (wire-alist-ref e 'obligation-graph '())))
                          (env (make-capability-envelope
                                (wire-alist-ref e 'env-owner "owner")
                                allowed-caps: (wire-alist-ref e 'env-allowed '(context-read))
                                denied-caps: (wire-alist-ref e 'env-denied '(host-egress))
                                egress-allowed?: (wire-alist-ref e 'env-egress? #f)))
                          (trunk (make-context-trunk
                                  (wire-alist-ref e 'trunk-id "trunk-restored")
                                  (wire-alist-ref e 'apex-obligation-id "ob-restored")
                                  g
                                  env
                                  shared-context-cut: (wire-alist-ref e 'shared-context-cut 1)
                                  kv-prefix-digest: (wire-alist-ref e 'kv-prefix-digest "sha256:unbound")))
                          (base-actor (make-task-actor
                                       (wire-alist-ref e 'task-id "task-restored")
                                       trunk
                                       (wire-alist-ref e 'scope-ids '("scope-main"))
                                       title: (wire-alist-ref e 'title "Restored")
                                       worktree: (wire-alist-ref e 'worktree "main")
                                       scope-mode: (wire-alist-ref e 'scope-mode 'project)
                                       fencing-epoch: (wire-alist-ref e 'fencing-epoch 1)))
                          (dmode (wire-alist-ref e 'detour-mode 'mainline))
                          (actor (if (eq? dmode 'mainline)
                                   base-actor
                                   (.ref (enter-task-actor-detour
                                          base-actor dmode
                                          (or (wire-alist-ref e 'detour-node-id #f) "restored-detour"))
                                         'actor))))
                     (make-unified-driver-state
                      actor
                      g
                      (wire->ctx (wire-alist-ref e 'governed-context '()))
                      competing-hypotheses: (map wire->comp-hyp (wire-alist-ref e 'competing-hypotheses '()))
                      branch-proposals: (map wire->branch-prop (wire-alist-ref e 'branch-proposals '()))
                      step-count: (wire-alist-ref e 'step-count 0)
                      repair-budget: (wire-alist-ref e 'repair-budget 3)
                      repair-history: (wire-alist-ref e 'repair-history '()))))
                 (wire-alist-ref alist 'active '()))))
      (make-graph-fleet-state
       drivers
       archived-actors: (map wire->archived (wire-alist-ref alist 'archived '()))
       peek-set: (wire-alist-ref alist 'peek-set '())
       focused-task-id: (wire-alist-ref alist 'focused-task-id #f)
       round-count: (wire-alist-ref alist 'round-count 0)))))

;;; Emit a single canonical `CasPutEffect.` carrying UTF-8 wire bytes of the
;;; complete Fleet snapshot for Marlin's thin `effect_pump` / Turso WAL CAS.
(def (plan-fleet-cas-checkpoint fleet-or-run cas-key)
  (make-cas-put-effect
   (string-append "fleet-checkpoint:" cas-key)
   cas-key
   (fleet->wire-string fleet-or-run)))

;;; Restore a live `GraphFleetState.` from a Marlin `cas-hit` receipt (supports
;;; both UTF-8 wire strings from real Turso WAL and in-memory POO snapshots).
(def (restore-fleet-from-cas-receipt receipt)
  (if (and (object? receipt) (eq? (opt-ref receipt 'kind #f) 'cas-hit))
    (let ((payload (.ref receipt 'payload)))
      (if (string? payload)
        (wire-string->fleet payload)
        (inert-snapshot->fleet payload)))
    (error "restore-fleet-from-cas-receipt: expected cas-hit receipt" receipt)))

;;; Project an entire multi-actor `GraphFleetState.` (or `GraphFleetRunTrace.`)
;;; into a canonical Marlin `WorkbenchTabProjection`:
;;;   - Left pinned `index`
;;;   - Active task tabs (with live `driver-phase`, `detour-mode`, checklist, hypotheses)
;;;   - Disjoint `peek-readonly` tabs for archived tasks present in `peek-set`
;;;   - Complete `archived-index` of auto-archived settled actors.
(def (project-fleet->workbench-projection fleet-or-run)
  (let* ((fleet (if (and (object? fleet-or-run)
                         (eq? (opt-ref fleet-or-run 'kind #f)
                              'agentic-ai-lab.graph-engine.fleet-run-trace.v1))
                  (.ref fleet-or-run 'final-fleet)
                  fleet-or-run))
         (active-drivers (.ref fleet 'active-drivers))
         (archived-actors (.ref fleet 'archived-actors))
         (peek-set (.ref fleet 'peek-set))
         (active-tabs
          (map (lambda (st)
                 (car (.ref (project-driver-state->workbench-projection st) 'dynamic-tabs)))
               active-drivers))
         (active-ids (map (lambda (t) (.ref t 'id)) active-tabs))
         (peek-tabs
          (filter
           values
           (map (lambda (a)
                  (let ((tid (.ref a 'task-id)))
                    (if (and (member tid peek-set) (not (member tid active-ids)))
                      (.o bind-these: #f
                          id: tid
                          label: (opt-ref a 'title tid)
                          status: 'done
                          mode: 'peek-readonly
                          detour-mode: 'mainline
                          detour-node-id: #f
                          driver-phase: 'quiescent-fixed-point
                          pending-effects-count: 0
                          worktree: (opt-ref a 'worktree "main")
                          checklist-done: 1
                          checklist-total: 1
                          competing-hypotheses: (opt-ref a 'competing-hypotheses '()))
                      #f)))
                archived-actors)))
         (dynamic-tabs (append active-tabs peek-tabs)))
    (.o bind-these: #f
        pinned-tab: 'index
        dynamic-tabs: dynamic-tabs
        archived-index: archived-actors
        visible-tab-ids: (cons 'index (map (lambda (t) (.ref t 'id)) dynamic-tabs)))))
