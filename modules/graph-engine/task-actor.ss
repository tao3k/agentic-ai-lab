;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Session-Free Lightweight TaskActor, C4 Mid-Flight Steering & Index Settlement
;;; (`modules/graph-engine/task-actor.ss`).
;;;
;;; Core Architectural Principles (Occam's Razor — Restrained Concurrency):
;;; 1. NO legacy `Session` concept and NO heavy Erlang-style concurrent actor soup.
;;;    Concurrency is restrained to:
;;;      - Disjoint tool/read fan-out inside a step (`FunFlow C4 DAG`),
;;;      - Weakly-coupled subordinate branches off a Trunk node (`D -> {D1, D2, D3}`),
;;;        which MUST re-converge back to the Trunk continuation (`D -> F -> G -> Apex`),
;;;      - Independent user tasks in the Workbench.
;;; 2. Dual Scope Mode (replaces Session completely):
;;;      - `'project`  (default): shares the governed structural Context & hot KV-prefix.
;;;      - `'detached` (out-of-project ad-hoc question): isolated scope, zero project pollution.
;;; 3. Dual Actor Kind:
;;;      - `'convergent-task`: bound to a `ContextTrunk.` with an Apex obligation.
;;;      - `'open-focus`:      lightweight exploratory thread before an Apex exists;
;;;                            can be promoted via `promote-focus->task-actor`.
;;; 4. C4 Mid-Flight Steering (`steer-task-actor`):
;;;      - `target: 'trunk`  -> steers the Main Trunk directly, bumps `fencing-epoch`,
;;;                             and optionally supersedes stale in-flight branches.
;;;      - `target: 'branch` -> spawns a subordinate branch anchored at `anchor-node-id`
;;;                             (e.g. `"D"`) with mandatory `join-node-id` (e.g. `"F"`);
;;;                             all derived checklist tasks must re-converge into `F -> G -> Apex`.
;;;                             A failed/defeated branch blocks continuation at `join-node-id`
;;;                             rather than silently skipping or hijacking the Trunk!
;;; 5. All-Terminal & Parked Index Settlement (`settle-task-actor`):
;;;      - Settles `converged` (requiring a real `ApexConvergenceReceipt.`) AND
;;;        `cancelled` / `failed` / `denied` / `parked` into `TaskActorIndex.` +
;;;        an inert `JournalHandoffIntent.` (`runtime-executed?: #f`), queryable by
;;;        `task-id` in `peek-readonly` mode with 0 actors / 0 LLM sessions spawned.
;;;
;;; INVARIANT: 100% PURE functional / POO — ZERO SQLite, ZERO `durable-journal`,
;;; ZERO filesystem or network I/O.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter every find filter-map)
        "convergent-tree.ss"
        "journal-handoff.ss")

(export TaskActor.
        SteeringMessage.
        BranchJoinRecord.
        TaskActorIndexEntry.
        TaskActorIndex.
        make-task-actor
        make-open-focus-actor
        promote-focus->task-actor
        task-actor?
        make-steering-message
        steer-task-actor
        complete-anchored-branch
        can-continue-trunk-at-join?
        make-task-actor-index
        task-actor-index?
        admit-task-actor-scope-access
        park-task-actor
        resume-task-actor
        update-task-actor-trunk
        enter-task-actor-detour
        exit-task-actor-detour
        settle-task-actor
        lookup-task-actor-by-id
        project-task-actors->workbench-tabs)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (non-empty-list? v)
  (and (list? v) (pair? v)))

(def +valid-scope-modes+ '(project detached))
(def +valid-actor-kinds+ '(convergent-task open-focus))
(def +valid-steering-targets+ '(trunk branch))
(def +valid-settlement-outcomes+ '(converged cancelled failed denied parked))
(def +valid-branch-outcomes+ '(completed failed defeated cancelled))
(def +valid-detour-modes+ '(mainline blocker-active side-quest-active))
(def +valid-detour-exits+ '(return-to-origin absorb-and-continue spawn-sibling-task abort-detour))

(.def TaskActor.
  kind: 'agentic-ai-lab.graph-engine.task-actor.v1
  actor-kind: 'convergent-task
  scope-mode: 'project
  session-free?: #t
  llm-sessions-spawned: 0
  fencing-epoch: 1
  detour-mode: 'mainline
  detour-node-id: #f
  detour-origin-epoch: #f
  status: 'active)

(.def SteeringMessage.
  kind: 'agentic-ai-lab.graph-engine.steering-message.v1
  c4-priority: 1
  target: 'branch)

(.def BranchJoinRecord.
  kind: 'agentic-ai-lab.graph-engine.branch-join-record.v1
  status: 'in-flight)

(.def TaskActorIndexEntry.
  kind: 'agentic-ai-lab.graph-engine.task-actor-index-entry.v1
  session-free?: #t
  archived?: #t
  queryable-by-id?: #t)

(.def TaskActorIndex.
  kind: 'agentic-ai-lab.graph-engine.task-actor-index.v1
  session-free?: #t
  entries: '())

(def (task-actor? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.graph-engine.task-actor.v1)))

(def (task-actor-index? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.graph-engine.task-actor-index.v1)))

(def (steer-denied reason actor)
  (.o (admitted? := #f) (reason) (actor) (spawned-branch := #f)))

(def (detour-enter-denied reason actor)
  (.o (admitted? := #f) (reason) (actor)))

(def (detour-exit-denied reason actor)
  (.o (exited? := #f) (reason) (actor) (sibling-actor := #f)))

(def (settle-denied reason actor index)
  (.o (settled? := #f) (reason) (actor) (index) (entry := #f) (handoff-intent := #f)))

;;; Spawn a convergent `TaskActor.` anchored to a `ContextTrunk.` over one or more
;;; Governance `scope-ids` (`scope-mode`: `'project` or `'detached`).
(def (make-task-actor
      task-id
      trunk
      scope-ids
      title: (title #f)
      worktree: (worktree "main")
      scope-mode: (scope-mode 'project)
      headless?: (headless? #f)
      fencing-epoch: (fencing-epoch 1))
  (cond
   ((not (and (string? task-id) (> (string-length task-id) 0)))
    (error "make-task-actor: task-id must be a non-empty string" task-id))
   ((not (context-trunk? trunk))
    (error "make-task-actor: trunk must be a ContextTrunk." trunk))
   ((not (non-empty-list? scope-ids))
    (error "make-task-actor: scope-ids must be a non-empty list of governance scopes" scope-ids))
   ((not (memq scope-mode +valid-scope-modes+))
    (error "make-task-actor: scope-mode must be 'project or 'detached" scope-mode))
   (else
    (.o (:: @ TaskActor.)
        (scope-mode)
        (fencing-epoch)
        (task-id)
        (title := (or title task-id))
        (worktree)
        (headless? := (and headless? #t))
        (scope-ids)
        (trunk-id := (.ref trunk 'trunk-id))
        (apex-obligation-id := (.ref trunk 'apex-obligation-id))
        (shared-context-cut := (.ref trunk 'shared-context-cut))
        (kv-prefix-digest := (.ref trunk 'kv-prefix-digest))
        (capability-envelope := (.ref trunk 'capability-envelope))
        (trunk)
        (steering-log := '())
        (branch-joins := '())))))

;;; Spawn a lightweight exploratory `open-focus` actor before an Apex exists
;;; (supports both `'project` shared structural Context and `'detached` ad-hoc scope).
(def (make-open-focus-actor
      task-id
      scope-ids
      capability-envelope
      title: (title #f)
      worktree: (worktree "main")
      scope-mode: (scope-mode 'project)
      shared-context-cut: (shared-context-cut 1)
      kv-prefix-digest: (kv-prefix-digest "sha256:detached-empty-prefix")
      headless?: (headless? #f))
  (cond
   ((not (and (string? task-id) (> (string-length task-id) 0)))
    (error "make-open-focus-actor: task-id must be a non-empty string" task-id))
   ((not (non-empty-list? scope-ids))
    (error "make-open-focus-actor: scope-ids must be a non-empty list" scope-ids))
   ((not (memq scope-mode +valid-scope-modes+))
    (error "make-open-focus-actor: scope-mode must be 'project or 'detached" scope-mode))
   (else
    (.o (:: @ TaskActor.)
        (actor-kind := 'open-focus)
        (scope-mode)
        (task-id)
        (title := (or title task-id))
        (worktree)
        (headless? := (and headless? #t))
        (scope-ids)
        (trunk-id := #f)
        (apex-obligation-id := #f)
        (shared-context-cut := (if (eq? scope-mode 'detached) 0 shared-context-cut))
        (kv-prefix-digest := (if (eq? scope-mode 'detached)
                               "sha256:detached-isolated-prefix"
                               kv-prefix-digest))
        (capability-envelope)
        (trunk := #f)
        (steering-log := '())
        (branch-joins := '())))))

;;; Promote an exploratory `open-focus` actor into a `convergent-task` bound to a `ContextTrunk.`.
(def (promote-focus->task-actor actor trunk)
  (cond
   ((not (task-actor? actor))
    (error "promote-focus->task-actor: expected TaskActor." actor))
   ((not (context-trunk? trunk))
    (error "promote-focus->task-actor: expected ContextTrunk." trunk))
   ((eq? (.ref actor 'status) 'settled)
    (error "promote-focus->task-actor: cannot promote a settled actor" (.ref actor 'task-id)))
   (else
    (.o (:: @ actor)
        (actor-kind := 'convergent-task)
        (fencing-epoch := (+ 1 (.ref actor 'fencing-epoch)))
        (status := 'active)
        (trunk-id := (.ref trunk 'trunk-id))
        (apex-obligation-id := (.ref trunk 'apex-obligation-id))
        (shared-context-cut := (.ref trunk 'shared-context-cut))
        (kv-prefix-digest := (.ref trunk 'kv-prefix-digest))
        (capability-envelope := (.ref trunk 'capability-envelope))
        (trunk)
        (detour-mode := (opt-ref actor 'detour-mode 'mainline))
        (detour-node-id := (opt-ref actor 'detour-node-id #f))
        (detour-origin-epoch := (opt-ref actor 'detour-origin-epoch #f))))))

(def (make-task-actor-index entries: (entries '()))
  (.o (:: @ TaskActorIndex.) (entries)))

;;; Construct a C4 Steering Message sent mid-flight to either `'trunk` (amends
;;; the Main Trunk with highest priority) or `'branch` (spawns a subordinate
;;; checklist/task branch anchored at `anchor-node-id` that MUST re-converge
;;; at `join-node-id` on the Trunk continuation).
(def (make-steering-message
      message-id
      target
      payload
      c4-priority: (c4-priority 1)
      anchor-node-id: (anchor-node-id #f)
      join-node-id: (join-node-id #f)
      branch-id: (branch-id #f)
      branch-kind: (branch-kind 'subordinate-task)
      requested-caps: (requested-caps '(context-read))
      target-obligation-id: (target-obligation-id #f)
      required-for-join?: (required-for-join? #t)
      supersede-stale-branches?: (supersede-stale-branches? #t))
  (cond
   ((not (memq target +valid-steering-targets+))
    (error "make-steering-message: target must be 'trunk or 'branch" target))
   (else
    (.o (:: @ SteeringMessage.)
        (message-id) (target) (payload) (c4-priority)
        (anchor-node-id) (join-node-id) (branch-id) (branch-kind)
        (requested-caps) (target-obligation-id)
        (required-for-join? := (and required-for-join? #t))
        (supersede-stale-branches? := (and supersede-stale-branches? #t))))))

(def (clone-actor
      actor
      status: (status #f)
      trunk: (trunk 'keep)
      fencing-epoch: (fencing-epoch #f)
      detour-mode: (detour-mode 'keep)
      detour-node-id: (detour-node-id 'keep)
      detour-origin-epoch: (detour-origin-epoch 'keep)
      steering-log: (steering-log 'keep)
      branch-joins: (branch-joins 'keep))
  (let* ((next-trunk (if (eq? trunk 'keep) (.ref actor 'trunk) trunk))
         (next-status (or status (.ref actor 'status)))
         (next-epoch (or fencing-epoch (.ref actor 'fencing-epoch)))
         (next-detour-mode (if (eq? detour-mode 'keep)
                             (opt-ref actor 'detour-mode 'mainline)
                             detour-mode))
         (next-detour-node (if (eq? detour-node-id 'keep)
                             (opt-ref actor 'detour-node-id #f)
                             detour-node-id))
         (next-detour-epoch (if (eq? detour-origin-epoch 'keep)
                              (opt-ref actor 'detour-origin-epoch #f)
                              detour-origin-epoch))
         (next-log (if (eq? steering-log 'keep) (.ref actor 'steering-log) steering-log))
         (next-joins (if (eq? branch-joins 'keep) (.ref actor 'branch-joins) branch-joins)))
    (.o (:: @ actor)
        (fencing-epoch := next-epoch)
        (status := next-status)
        (trunk-id := (if next-trunk (.ref next-trunk 'trunk-id) (.ref actor 'trunk-id)))
        (apex-obligation-id := (if next-trunk
                                 (.ref next-trunk 'apex-obligation-id)
                                 (.ref actor 'apex-obligation-id)))
        (shared-context-cut := (if next-trunk
                                 (.ref next-trunk 'shared-context-cut)
                                 (.ref actor 'shared-context-cut)))
        (kv-prefix-digest := (if next-trunk
                               (.ref next-trunk 'kv-prefix-digest)
                               (.ref actor 'kv-prefix-digest)))
        (capability-envelope := (if next-trunk
                                  (.ref next-trunk 'capability-envelope)
                                  (.ref actor 'capability-envelope)))
        (trunk := next-trunk)
        (detour-mode := next-detour-mode)
        (detour-node-id := next-detour-node)
        (detour-origin-epoch := next-detour-epoch)
        (steering-log := next-log)
        (branch-joins := next-joins))))

;;; Apply a C4 mid-flight Steering Message to a live `TaskActor.`:
;;; - `target: 'trunk`  -> steers the Main Trunk, advances `fencing-epoch`, and
;;;                        marks stale in-flight branch joins `'superseded` when
;;;                        `supersede-stale-branches?` is `#t`.
;;; - `target: 'branch` -> derives a subordinate branch off `anchor-node-id`
;;;                        (e.g. `D -> D1, D2`) bound to re-converge at `join-node-id`
;;;                        (e.g. `F` on `D -> F -> G -> Apex`).
(def (steer-task-actor actor steering-msg)
  (cond
   ((not (task-actor? actor))
    (steer-denied 'invalid-task-actor actor))
   ((not (eq? (.ref actor 'status) 'active))
    (steer-denied 'task-actor-not-active actor))
   (else
    (let* ((target (.ref steering-msg 'target))
           (next-log (append (.ref actor 'steering-log) (list steering-msg))))
      (cond
       ((eq? target 'trunk)
        (let* ((next-epoch (+ 1 (.ref actor 'fencing-epoch)))
               (trunk (.ref actor 'trunk))
               (supersede? (.ref steering-msg 'supersede-stale-branches?))
               (next-trunk (if (and trunk supersede?)
                             (trunk-advance-cut-or-revoke
                              trunk
                              new-cut: (+ 1 (.ref trunk 'shared-context-cut))
                              new-grant-epoch: next-epoch
                              trunk-grant-live?: #t)
                             trunk))
               (next-joins
                (if supersede?
                  (map (lambda (j)
                         (if (eq? (.ref j 'status) 'in-flight)
                           (.o (:: @ j) (status := 'superseded))
                           j))
                       (.ref actor 'branch-joins))
                  (.ref actor 'branch-joins)))
               (next-actor (clone-actor actor
                                        trunk: next-trunk
                                        fencing-epoch: next-epoch
                                        steering-log: next-log
                                        branch-joins: next-joins)))
          (.o (admitted? := #t)
              (reason := 'trunk-steered)
              (route := 'trunk)
              (fencing-epoch := next-epoch)
              (actor := next-actor)
              (spawned-branch := #f))))
       ((eq? target 'branch)
        (let* ((trunk (.ref actor 'trunk))
               (anchor-id (.ref steering-msg 'anchor-node-id))
               (join-id (.ref steering-msg 'join-node-id))
               (bid (.ref steering-msg 'branch-id)))
          (cond
           ((not trunk)
            (steer-denied 'branch-steering-requires-trunk actor))
           ((not (and (string? anchor-id) (string? join-id) (string? bid)))
            (steer-denied 'missing-anchor-join-or-branch-id actor))
           (else
            (let* ((sp (spawn-trunk-branch
                        trunk
                        bid
                        (.ref steering-msg 'branch-kind)
                        (.ref steering-msg 'requested-caps)
                        (or (.ref steering-msg 'target-obligation-id)
                            (.ref trunk 'apex-obligation-id))
                        c4-priority: (.ref steering-msg 'c4-priority)
                        required-for-apex?: (.ref steering-msg 'required-for-join?))))
              (if (not (.ref sp 'admitted?))
                (steer-denied (.ref sp 'reason) actor)
                (let* ((join-rec (.o (:: @ BranchJoinRecord.)
                                     (branch-id := bid)
                                     (anchor-node-id := anchor-id)
                                     (join-node-id := join-id)
                                     (c4-priority := (.ref steering-msg 'c4-priority))
                                     (required-for-join? := (.ref steering-msg 'required-for-join?))))
                       (next-actor (clone-actor
                                    actor
                                    trunk: (.ref sp 'trunk)
                                    steering-log: next-log
                                    branch-joins: (append (.ref actor 'branch-joins)
                                                          (list join-rec)))))
                  (.o (admitted? := #t)
                      (reason := 'branch-spawned-from-anchor)
                      (route := 'branch)
                      (anchor-node-id := anchor-id)
                      (join-node-id := join-id)
                      (actor := next-actor)
                      (spawned-branch := (.ref sp 'branch))))))))))
       (else
        (steer-denied 'invalid-steering-target actor)))))))

;;; Record completion (or failure/defeater/cancellation) of a branch anchored at
;;; `anchor-node-id` so the Trunk continuation gate at `join-node-id` can verify
;;; whether `D -> F -> G -> Apex` may proceed!
(def (complete-anchored-branch actor branch-id outcome: (outcome 'completed))
  (cond
   ((not (memq outcome +valid-branch-outcomes+))
    (error "complete-anchored-branch: invalid outcome" outcome))
   (else
    (let ((next-joins
           (map (lambda (j)
                  (if (equal? (.ref j 'branch-id) branch-id)
                    (.o (:: @ j) (status := outcome))
                    j))
                (.ref actor 'branch-joins))))
      (clone-actor actor branch-joins: next-joins)))))

;;; Verify whether all required branches targeting `join-node-id` (e.g. `"F"`
;;; after `D -> {D1, D2, D3}`) have converged cleanly. Any in-flight, failed, or
;;; defeated required branch blocks continuation rather than silently skipping!
(def (can-continue-trunk-at-join? actor join-node-id)
  (let* ((relevant (filter (lambda (j)
                             (and (equal? (.ref j 'join-node-id) join-node-id)
                                  (.ref j 'required-for-join?)
                                  (not (eq? (.ref j 'status) 'superseded))))
                           (.ref actor 'branch-joins)))
         (in-flight (filter (lambda (j) (eq? (.ref j 'status) 'in-flight)) relevant))
         (blocked (filter (lambda (j) (memq (.ref j 'status) '(failed defeated cancelled)))
                          relevant)))
    (cond
     ((pair? blocked)
      (.o (can-continue? := #f)
          (reason := 'required-branch-failed-or-defeated)
          (join-node-id)
          (blocking-branch-ids := (map (lambda (j) (.ref j 'branch-id)) blocked))))
     ((pair? in-flight)
      (.o (can-continue? := #f)
          (reason := 'required-branches-still-in-flight)
          (join-node-id)
          (blocking-branch-ids := (map (lambda (j) (.ref j 'branch-id)) in-flight))))
     (else
      (.o (can-continue? := #t)
          (reason := 'all-required-branches-converged)
          (join-node-id)
          (blocking-branch-ids := '()))))))

;;; Pure multi-scope Governance access check for a lightweight `TaskActor.`.
(def (admit-task-actor-scope-access actor target-scope required-cap)
  (cond
   ((not (task-actor? actor))
    (.o (admitted? := #f) (reason := 'invalid-task-actor)))
   ((not (eq? (.ref actor 'status) 'active))
    (.o (admitted? := #f) (reason := 'task-actor-not-active)))
   ((not (member target-scope (.ref actor 'scope-ids)))
    (.o (admitted? := #f) (reason := 'scope-out-of-bounds)))
   (else
    (let* ((env (.ref actor 'capability-envelope))
           (allowed (opt-ref env 'allowed-caps '()))
           (denied (opt-ref env 'denied-caps '())))
      (cond
       ((member required-cap denied)
        (.o (admitted? := #f) (reason := 'capability-explicitly-denied)))
       ((not (member required-cap allowed))
        (.o (admitted? := #f) (reason := 'capability-not-granted)))
       (else
        (.o (admitted? := #t)
            (reason := 'admitted)
            (task-id := (.ref actor 'task-id))
            (scope-mode := (.ref actor 'scope-mode))
            (target-scope)
            (required-cap)
            (kv-prefix-digest := (.ref actor 'kv-prefix-digest))
            (session-free? := #t))))))))

(def (park-task-actor actor)
  (if (eq? (.ref actor 'status) 'settled)
    actor
    (clone-actor actor status: 'parked)))

(def (resume-task-actor actor)
  (if (eq? (.ref actor 'status) 'settled)
    actor
    (clone-actor actor status: 'active fencing-epoch: (+ 1 (.ref actor 'fencing-epoch)))))

(def (update-task-actor-trunk actor next-trunk)
  (if (not (context-trunk? next-trunk))
    (error "update-task-actor-trunk: next-trunk must be a ContextTrunk." next-trunk)
    (clone-actor actor trunk: next-trunk)))

;;; Enter a Design 165 Scoped Detour (`'blocker-active` or `'side-quest-active`)
;;; anchored at `detour-node-id`. Rejects nested detours and inactive actors fail-closed.
(def (enter-task-actor-detour actor mode detour-node-id)
  (cond
   ((not (task-actor? actor))
    (detour-enter-denied 'invalid-task-actor actor))
   ((not (eq? (.ref actor 'status) 'active))
    (detour-enter-denied 'task-actor-not-active actor))
   ((not (memq mode '(blocker-active side-quest-active)))
    (detour-enter-denied 'invalid-detour-mode actor))
   ((not (and (string? detour-node-id) (> (string-length detour-node-id) 0)))
    (detour-enter-denied 'invalid-detour-node-id actor))
   ((not (eq? (opt-ref actor 'detour-mode 'mainline) 'mainline))
    (detour-enter-denied 'nested-detour-forbidden actor))
   (else
    (let ((next (clone-actor actor
                             detour-mode: mode
                             detour-node-id: detour-node-id
                             detour-origin-epoch: (.ref actor 'fencing-epoch))))
      (.o (admitted? := #t)
          (reason := 'detour-entered)
          (detour-mode := mode)
          (detour-node-id)
          (actor := next))))))

;;; Exit an active Design 165 Scoped Detour via one of the 4 canonical re-anchoring exits:
;;;   - `'return-to-origin`: returns parent to `'mainline` without mutating trunk cut.
;;;   - `'absorb-and-continue`: absorbs detour evidence and advances trunk `shared-context-cut` by +1.
;;;   - `'spawn-sibling-task`: promotes detour to an independent sibling `TaskActor.` and returns parent.
;;;   - `'abort-detour`: discards detour scratch and returns parent to `'mainline`.
(def (exit-task-actor-detour
      actor
      exit-kind
      sibling-task-id: (sibling-task-id #f)
      sibling-title: (sibling-title #f))
  (cond
   ((not (task-actor? actor))
    (detour-exit-denied 'invalid-task-actor actor))
   ((not (memq exit-kind +valid-detour-exits+))
    (detour-exit-denied 'invalid-detour-exit actor))
   ((eq? (opt-ref actor 'detour-mode 'mainline) 'mainline)
    (detour-exit-denied 'actor-not-in-detour actor))
   ((and (eq? exit-kind 'spawn-sibling-task)
         (not (and (string? sibling-task-id) (> (string-length sibling-task-id) 0))))
    (detour-exit-denied 'sibling-task-id-required actor))
   (else
    (let* ((trunk (.ref actor 'trunk))
           (next-trunk
            (if (and (eq? exit-kind 'absorb-and-continue) trunk)
              (trunk-advance-cut-or-revoke
               trunk
               new-cut: (+ 1 (.ref trunk 'shared-context-cut))
               new-grant-epoch: (.ref actor 'fencing-epoch)
               trunk-grant-live?: #t)
              'keep))
           (sibling
            (if (eq? exit-kind 'spawn-sibling-task)
              (make-open-focus-actor
               sibling-task-id
               (.ref actor 'scope-ids)
               (.ref actor 'capability-envelope)
               title: (or sibling-title sibling-task-id)
               worktree: (.ref actor 'worktree)
               scope-mode: (.ref actor 'scope-mode)
               shared-context-cut: (.ref actor 'shared-context-cut)
               kv-prefix-digest: (.ref actor 'kv-prefix-digest))
              #f))
           (next-actor
            (clone-actor actor
                         trunk: next-trunk
                         detour-mode: 'mainline
                         detour-node-id: #f
                         detour-origin-epoch: #f)))
      (.o (exited? := #t)
          (reason := 'detour-exited)
          (exit-kind)
          (actor := next-actor)
          (sibling-actor := sibling))))))

(def (upsert-index-entry entries entry)
  (let* ((tid (.ref entry 'task-id))
         (without (filter (lambda (e) (not (equal? (.ref e 'task-id) tid))) entries)))
    (append without (list entry))))

;;; Settle a `TaskActor.` into `TaskActorIndex.` and emit an inert `JournalHandoffIntent.`
;;; (`runtime-executed?: #f`) for Marlin / `+sqlite-turso` ID-indexed persistence.
;;; Supports ALL terminal & suspended outcomes:
;;;   - `'converged` (requires `trunk` converged at its Apex with `ApexConvergenceReceipt.`)
;;;   - `'cancelled` / `'failed` / `'denied` / `'parked` (always indexable for ID audit!)
;;; Detached actors (`scope-mode: 'detached`) do NOT pollute the project Index unless
;;; explicitly settled into a detached index, marked `detached-ephemeral?: #t`.
(def (settle-task-actor
      actor
      index
      outcome: (outcome 'converged)
      reason-note: (reason-note "")
      journal-epoch: (journal-epoch 1))
  (cond
   ((not (task-actor? actor))
    (settle-denied 'invalid-task-actor actor index))
   ((not (task-actor-index? index))
    (settle-denied 'invalid-task-actor-index actor index))
   ((not (memq outcome +valid-settlement-outcomes+))
    (settle-denied 'invalid-settlement-outcome actor index))
   ((and (eq? outcome 'converged)
         (eq? (opt-ref actor 'detour-mode 'mainline) 'blocker-active))
    (settle-denied 'blocker-detour-blocks-settlement actor index))
   (else
    (let* ((trunk (.ref actor 'trunk))
           (apex-status (and trunk (.ref trunk 'apex-status)))
           (apex-receipt (and trunk (.ref trunk 'apex-receipt))))
      (if (and (eq? outcome 'converged)
               (not (and trunk (eq? apex-status 'converged) apex-receipt)))
        (settle-denied 'trunk-not-converged actor index)
        (let* ((next-status (if (eq? outcome 'parked) 'parked 'settled))
               (settled-actor (clone-actor actor status: next-status))
               (absorbed-ids (if apex-receipt
                               (.ref apex-receipt 'absorbed-branch-ids-c4-order)
                               '()))
               (receipt-dig (if apex-receipt (.ref apex-receipt 'receipt-digest) #f))
               (entry (.o (:: @ TaskActorIndexEntry.)
                          (archived? := (not (eq? outcome 'parked)))
                          (detached-ephemeral? := (eq? (.ref actor 'scope-mode) 'detached))
                          (task-id := (.ref actor 'task-id))
                          (title := (.ref actor 'title))
                          (worktree := (.ref actor 'worktree))
                          (actor-kind := (.ref actor 'actor-kind))
                          (scope-mode := (.ref actor 'scope-mode))
                          (scope-ids := (.ref actor 'scope-ids))
                          (fencing-epoch := (.ref actor 'fencing-epoch))
                          (trunk-id := (.ref actor 'trunk-id))
                          (apex-obligation-id := (.ref actor 'apex-obligation-id))
                          (shared-context-cut := (.ref actor 'shared-context-cut))
                          (kv-prefix-digest := (.ref actor 'kv-prefix-digest))
                          (receipt-digest := receipt-dig)
                          (absorbed-branch-ids := absorbed-ids)
                          (total-llm-calls := (if apex-receipt (.ref apex-receipt 'total-llm-calls) 0))
                          (total-det-tasks := (if apex-receipt (.ref apex-receipt 'total-det-tasks) 0))
                          (outcome)
                          (reason-note)
                          (status := (if (eq? outcome 'converged) 'done outcome))))
               (next-index (if (eq? (.ref actor 'scope-mode) 'detached)
                             index
                             (make-task-actor-index
                              entries: (upsert-index-entry (.ref index 'entries) entry))))
               (event-id (string-append "settle:" (.ref actor 'task-id)
                                        ":e" (number->string journal-epoch)))
               (handoff (if trunk
                          (plan-trunk-journal-handoff event-id entry trunk)
                          (.o (:: @ JournalHandoffIntent.)
                              (state-key := "graph-engine:task-actor")
                              (event-id)
                              (event-payload := entry)
                              (trunk-id := (.ref actor 'task-id))
                              (outcome)))))
          (.o (settled? := #t)
              (reason := (if (eq? (.ref actor 'scope-mode) 'detached)
                           'settled-detached-no-project-pollution
                           'settled-into-index))
              (outcome)
              (actor := settled-actor)
              (index := next-index)
              (entry)
              (handoff-intent := handoff))))))))

;;; Query a settled task from `TaskActorIndex.` purely by `task-id`.
;;; Guarantees ZERO actors spawned and ZERO LLM sessions created!
(def (lookup-task-actor-by-id index task-id)
  (let ((found (and (task-actor-index? index)
                    (find (lambda (e) (equal? (.ref e 'task-id) task-id))
                          (.ref index 'entries)))))
    (.o (found? := (and found #t))
        (task-id)
        (entry := (or found #f))
        (mode := (if found 'peek-readonly 'not-found))
        (actors-spawned := 0)
        (llm-sessions-spawned := 0))))

(def (make-settled-workbench-tab entry mode)
  (.o (id := (.ref entry 'task-id))
      (label := (.ref entry 'title))
      (kind := 'task)
      (closable? := #t)
      (status := (.ref entry 'status))
      (outcome := (.ref entry 'outcome))
      (worktree := (.ref entry 'worktree))
      (scope-ids := (.ref entry 'scope-ids))
      (trunk-id := (.ref entry 'trunk-id))
      (archived? := #t)
      (mode)))

;;; Pure Workbench Tab projection from lightweight `TaskActor.`s + `TaskActorIndex.`.
(def (project-task-actors->workbench-tabs
      actors
      index
      peek-set: (peek-set '())
      focused-task-id: (focused-task-id #f)
      focused-tab-archive: (focused-tab-archive 'on-blur))
  (let* ((pinned (list (.o (id := 'index)
                           (label := "Index")
                           (kind := 'index)
                           (closable? := #f)
                           (mode := 'pinned))))
         (peek-list (if (list? peek-set) peek-set '()))
         (active-actors (filter (lambda (a)
                                  (and (task-actor? a)
                                       (not (eq? (.ref a 'status) 'settled))))
                                actors))
         (headless-ids (map (lambda (a) (.ref a 'task-id))
                            (filter (lambda (a) (.ref a 'headless?)) active-actors)))
         (visible-actors (filter (lambda (a) (not (.ref a 'headless?))) active-actors))
         (active-tabs
          (map (lambda (a)
                 (.o (id := (.ref a 'task-id))
                     (label := (.ref a 'title))
                     (kind := 'task)
                     (closable? := #t)
                     (actor-kind := (.ref a 'actor-kind))
                     (scope-mode := (.ref a 'scope-mode))
                     (status := (.ref a 'status))
                     (detour-mode := (opt-ref a 'detour-mode 'mainline))
                     (worktree := (.ref a 'worktree))
                     (scope-ids := (.ref a 'scope-ids))
                     (trunk-id := (.ref a 'trunk-id))
                     (kv-prefix-digest := (.ref a 'kv-prefix-digest))
                     (archived? := #f)
                     (mode := 'active)))
               visible-actors))
         (settled-entries (if (task-actor-index? index) (.ref index 'entries) '()))
         (archived-index
          (map (lambda (e)
                 (.o (task-id := (.ref e 'task-id))
                     (title := (.ref e 'title))
                     (status := (.ref e 'status))
                     (outcome := (.ref e 'outcome))
                     (worktree := (.ref e 'worktree))
                     (scope-ids := (.ref e 'scope-ids))
                     (trunk-id := (.ref e 'trunk-id))
                     (receipt-digest := (.ref e 'receipt-digest))
                     (archived? := (.ref e 'archived?))
                     (queryable-by-id? := #t)))
               settled-entries))
         (peek-or-blur-tabs
          (filter-map
           (lambda (e)
             (let* ((tid (.ref e 'task-id))
                    (peeked? (and (member tid peek-list) #t))
                    (focused? (and focused-task-id (equal? tid focused-task-id))))
               (cond
                (peeked? (make-settled-workbench-tab e 'peek-readonly))
                ((and focused? (eq? focused-tab-archive 'on-blur))
                 (make-settled-workbench-tab e 'archived-pending-blur))
                (else #f))))
           settled-entries))
         (dynamic-tabs (append active-tabs peek-or-blur-tabs)))
    (.o (kind := 'agentic-ai-lab.durable.workbench-tab-projection.v1)
        (session-free? := #t)
        (pinned-tabs := pinned)
        (dynamic-tabs)
        (archived-index)
        (visible-tab-ids := (cons 'index (map (lambda (t) (.ref t 'id)) dynamic-tabs)))
        (headless-actor-ids := headless-ids)
        (active-actor-count := (length active-actors))
        (settled-index-count := (length settled-entries)))))
