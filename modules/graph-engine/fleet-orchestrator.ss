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
        "convergent-tree.ss"
        "task-actor.ss"
        "atomic-effect-orchestrator.ss"
        "unified-effect-driver.ss")

(export GraphFleetState.
        GraphFleetStepResult.
        GraphFleetRunTrace.
        make-graph-fleet-state
        fleet-spawn-sibling-from-detour
        step-graph-fleet
        run-graph-fleet-to-quiescence
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
