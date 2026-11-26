;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scheme Multi-Actor Fleet Orchestrator
;;; (`modules/graph-engine/fleet-orchestrator.ss`).
;;;
;;; Elevates single-actor `unified-effect-driver.ss` to a Session-free Fleet of
;;; concurrent `TaskActor.`s using idiomatic `gerbil-poo` prototypes, constant
;;; slot capture `(slot)` / `(slot := expr)`, runtime prototype refinement
;;; `(.o (:: @ base) ...)`, standard functional combinators, and a minimal
;;; `defrules` wire-projection frame (`define-wire-rows`).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter filter-map find any)
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
        FleetAuditCapsule.
        make-graph-fleet-state
        fleet-spawn-sibling-from-detour
        fleet-apply-bitemporal-event
        fleet-propose-hypothesis-branch
        fleet-propagate-shared-defeater
        fleet-peek-archived-actor
        fleet-unpeek-archived-actor
        fleet-reopen-archived-actor
        fleet-export-audit-capsule
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
  (if (and (object? obj) (.slot? obj key)) (.ref obj key) default))

(def (strip-prefix prefix s)
  (let ((plen (string-length prefix)) (slen (string-length s)))
    (and (>= slen plen) (string-prefix? prefix s) (substring s plen slen))))

(def (wire-ref alist key default)
  (let ((pair (and (list? alist) (assq key alist))))
    (if pair (cdr pair) default)))

(def (unwrap-fleet fleet-or-run)
  (if (and (object? fleet-or-run)
           (eq? (opt-ref fleet-or-run 'kind #f)
                'agentic-ai-lab.graph-engine.fleet-run-trace.v1))
    (.ref fleet-or-run 'final-fleet)
    fleet-or-run))

(def (driver-task-id st) (.ref (.ref st 'actor) 'task-id))

(def (graph-has-active-defeaters? g)
  (any (lambda (o) (pair? (.ref o 'active-defeaters))) (.ref g 'obligations)))

(def (graph-defeater-count g)
  (foldl (lambda (o acc) (+ acc (length (.ref o 'active-defeaters))))
         0 (.ref g 'obligations)))

;;; Minimal `defrules` frame (Style 05) for structural POO -> final wire-alist
;;; rows (Style 03 permits alists strictly at final wire/receipt projections).
(defrules wire-rows ()
  ((_ obj (slot default) ...)
   (list (cons 'slot (opt-ref obj 'slot default)) ...))
  ((_ obj ((slot expr) ...) (dslot default) ...)
   (append (list (cons 'slot expr) ...)
           (list (cons 'dslot (opt-ref obj 'dslot default)) ...))))

;;; ---------------------------------------------------------------------------
;;; 1. POO Prototypes & Constructors
;;; ---------------------------------------------------------------------------

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

(.def FleetAuditCapsule.
  kind: 'agentic-ai-lab.graph-engine.fleet-audit-capsule.v1
  favored-path-collapsed?: #f
  missing-claim-likelihood-inferred?: #f
  authenticates-evidence?: #f
  establishes-attribution?: #f
  authorizes-effect?: #f
  runtime-executed?: #f)

(def (make-graph-fleet-state
      active-drivers
      archived-actors: (archived-actors '())
      peek-set: (peek-set '())
      focused-task-id: (focused-task-id #f)
      round-count: (round-count 0))
  (.o (:: @ GraphFleetState.)
      (active-drivers) (archived-actors) (peek-set) (focused-task-id) (round-count)))

;;; ---------------------------------------------------------------------------
;;; 2. Effect Namespacing & Receipt Routing
;;; ---------------------------------------------------------------------------

(def (namespace-effect task-id eff)
  (let ((ns-id (string-append "actor:" task-id "::" (.ref eff 'effect-id)))
        (k (.ref eff 'kind)))
    (case k
      ((cas-get) (make-cas-get-effect ns-id (.ref eff 'key)))
      ((cas-put) (make-cas-put-effect ns-id (.ref eff 'key) (.ref eff 'payload)))
      ((llm-complete)
       (make-llm-complete-effect
        ns-id (.ref eff 'endpoint) (.ref eff 'messages)
        metadata: (cons (cons 'owner-task-id task-id) (opt-ref eff 'metadata '()))))
      ((sandbox-run)
       (make-sandbox-run-effect
        ns-id (.ref eff 'program) (.ref eff 'args) cwd: (opt-ref eff 'cwd #f)))
      (else eff))))

(def (unnamespace-receipt-for task-id receipt)
  (let* ((prefix (string-append "actor:" task-id "::"))
         (eid (and (object? receipt) (opt-ref receipt 'effect-id "")))
         (inner (and (string? eid) (strip-prefix prefix eid))))
    (and inner
         (case (.ref receipt 'kind)
           ((cas-hit) (make-cas-hit-receipt inner (.ref receipt 'payload)))
           ((cas-miss) (make-cas-miss-receipt inner))
           ((cas-stored) (make-cas-stored-receipt inner))
           ((llm-completed) (make-llm-completed-receipt inner (.ref receipt 'content)))
           ((sandbox-exited)
            (make-sandbox-exited-receipt
             inner (.ref receipt 'exit-code) (.ref receipt 'stdout)
             stderr: (opt-ref receipt 'stderr "")))
           (else (make-effect-error-receipt inner (opt-ref receipt 'message "error")))))))

(def (receipts-for-actor task-id receipts)
  (filter-map (lambda (r) (unnamespace-receipt-for task-id r)) receipts))

;;; ---------------------------------------------------------------------------
;;; 3. Multi-Actor Fleet Operations (Pure POO Refinement)
;;; ---------------------------------------------------------------------------

(def (fleet-spawn-sibling-from-detour
      fleet parent-task-id sibling-task-id sibling-title sibling-obligation-graph
      sibling-apex-id: (sibling-apex-id "ob-sibling")
      sibling-hypotheses: (sibling-hypotheses '())
      sibling-branches: (sibling-branches '()))
  (let* ((drivers (.ref fleet 'active-drivers))
         (parent-st (find (lambda (st) (equal? (driver-task-id st) parent-task-id)) drivers)))
    (unless parent-st
      (error "fleet-spawn-sibling-from-detour: parent task actor not found in active fleet"
             parent-task-id))
    (let* ((parent-actor (.ref parent-st 'actor))
           (parent-trunk (.ref parent-actor 'trunk))
           (updated-parent-actor
            (.ref (exit-task-actor-detour
                   parent-actor 'spawn-sibling-task sibling-task-id: sibling-task-id)
                  'actor))
           (updated-parent-st (.o (:: @ parent-st) (actor := updated-parent-actor)))
           (sib-trunk (make-context-trunk
                       (string-append "trunk-" sibling-task-id)
                       sibling-apex-id
                       sibling-obligation-graph
                       (.ref parent-trunk 'capability-envelope)
                       shared-context-cut: (.ref parent-trunk 'shared-context-cut)
                       kv-prefix-digest: (.ref parent-trunk 'kv-prefix-digest)))
           (sib-actor (make-task-actor
                       sibling-task-id sib-trunk (.ref parent-actor 'scope-ids)
                       title: sibling-title
                       worktree: (opt-ref parent-actor 'worktree "main")
                       scope-mode: (opt-ref parent-actor 'scope-mode 'project)))
           (sib-st (make-unified-driver-state
                    sib-actor sibling-obligation-graph (.ref parent-st 'governed-context)
                    competing-hypotheses: sibling-hypotheses
                    branch-proposals: sibling-branches))
           (next-drivers
            (append (map (lambda (st)
                           (if (equal? (driver-task-id st) parent-task-id) updated-parent-st st))
                         drivers)
                    (list sib-st))))
      (.o (:: @ fleet)
          (active-drivers := next-drivers)
          (focused-task-id := (or (.ref fleet 'focused-task-id) sibling-task-id))))))

(def (fleet-apply-bitemporal-event fleet task-id event)
  (let* ((ekind (.ref event 'event-kind))
         (blocking? (memq ekind '(defeater-discovered premise-retracted
                                  cedar-revoked mcp-manifest-mutated)))
         (resolving? (memq ekind '(human-approved cedar-restored mcp-manifest-repinned)))
         (next-drivers
          (map
           (lambda (st)
             (if (not (equal? (driver-task-id st) task-id))
               st
               (let* ((actor (.ref st 'actor))
                      (ctx0 (.ref st 'governed-context))
                      (g1 (obligation-graph-apply-event (.ref st 'obligation-graph) event))
                      (g2 (if blocking?
                            (obligation-graph-add-human-inbox
                             g1
                             (.o (kind := ekind)
                                 (task-id)
                                 (detail := (or (opt-ref event 'defeater-id #f)
                                                (opt-ref event 'premise-id #f)
                                                (symbol->string ekind)))))
                            g1))
                      (defeater-now? (graph-has-active-defeaters? g2))
                      (next-ctx
                       (.o (:: @ ctx0)
                           (context-cut := (.ref g2 'cut))
                           (disclosure-depth := (if (or blocking? defeater-now?)
                                                  'L3
                                                  (opt-ref ctx0 'disclosure-depth 'L1)))
                           (has-active-defeater? := (or defeater-now? (eq? ekind 'defeater-discovered)))
                           (cedar-handoff-valid? := (cond
                                                     ((eq? ekind 'cedar-revoked) #f)
                                                     ((memq ekind '(cedar-restored human-approved)) #t)
                                                     (else (opt-ref ctx0 'cedar-handoff-valid? #t))))))
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
                 (.o (:: @ st)
                     (actor := next-actor)
                     (obligation-graph := g2)
                     (governed-context := next-ctx)))))
           (.ref fleet 'active-drivers))))
    (.o (:: @ fleet) (active-drivers := next-drivers))))

(def (fleet-propose-hypothesis-branch fleet task-id branch-proposal max-branches: (max-branches 16))
  (unless (and (object? branch-proposal)
               (eq? (opt-ref branch-proposal 'kind #f)
                    'agentic-ai-lab.graph-engine.hypothesis-branch-proposal.v1)
               (not (opt-ref branch-proposal 'authorizes-effect? #t)))
    (error "fleet-propose-hypothesis-branch: requires non-authorizing HypothesisBranchProposal."
           branch-proposal))
  (let* ((drivers (.ref fleet 'active-drivers))
         (target-st (find (lambda (st) (equal? (driver-task-id st) task-id)) drivers)))
    (unless target-st
      (error "fleet-propose-hypothesis-branch: active task actor not found" task-id))
    (let* ((bid (.ref branch-proposal 'branch-id))
           (kept (filter (lambda (b) (not (equal? (.ref b 'branch-id) bid)))
                         (.ref target-st 'branch-proposals)))
           (updated (append kept (list branch-proposal))))
      (when (> (length updated) (max 1 max-branches))
        (error "fleet-propose-hypothesis-branch: bounded branch limit exceeded" max-branches))
      (.o (:: @ fleet)
          (active-drivers :=
           (map (lambda (st)
                  (if (equal? (driver-task-id st) task-id)
                    (.o (:: @ st) (branch-proposals := updated) (hypothesis-matrix := #f))
                    st))
                drivers))))))

(def (fleet-propagate-shared-defeater
      fleet defeater-id shared-premise-id source-task-id: (source-task-id #f))
  (foldl
   (lambda (st cur-fl)
     (let* ((tid (driver-task-id st))
            (matching-obs
             (filter (lambda (o)
                       (or (member shared-premise-id (opt-ref o 'premise-ids '()))
                           (member shared-premise-id (opt-ref o 'required-evidence-ids '()))
                           (and source-task-id (equal? tid source-task-id))))
                     (.ref (.ref st 'obligation-graph) 'obligations))))
       (foldl (lambda (o fl)
                (fleet-apply-bitemporal-event
                 fl tid
                 (.o (event-kind := 'defeater-discovered)
                     (obligation-id := (.ref o 'obligation-id))
                     (defeater-id))))
              cur-fl matching-obs)))
   fleet (.ref fleet 'active-drivers)))

(def (fleet-peek-archived-actor fleet task-id)
  (let ((active-ids (map driver-task-id (.ref fleet 'active-drivers)))
        (arch (find (lambda (a) (equal? (.ref a 'task-id) task-id)) (.ref fleet 'archived-actors)))
        (cur-peek (.ref fleet 'peek-set)))
    (cond
     ((or (member task-id active-ids) (member task-id cur-peek)) fleet)
     ((not arch) (error "fleet-peek-archived-actor: archived actor not found" task-id))
     (else (.o (:: @ fleet) (peek-set := (append cur-peek (list task-id))))))))

(def (fleet-unpeek-archived-actor fleet task-id)
  (.o (:: @ fleet)
      (peek-set := (filter (lambda (id) (not (equal? id task-id))) (.ref fleet 'peek-set)))))

(def (fleet-reopen-archived-actor fleet task-id reason: (reason "durable-reopen"))
  (let ((arch (find (lambda (a) (equal? (.ref a 'task-id) task-id))
                    (.ref fleet 'archived-actors))))
    (unless arch (error "fleet-reopen-archived-actor: archived actor not found" task-id))
    (let* ((next-epoch (+ (opt-ref arch 'fencing-epoch 1) 1))
           (kv-dig (opt-ref arch 'kv-prefix-digest "sha256:unbound"))
           (cut-val (opt-ref arch 'shared-context-cut 1))
           (apex-id (opt-ref arch 'apex-obligation-id (string-append "ob-" task-id)))
           (prior-g (opt-ref arch 'obligation-graph #f))
           (g (if (object? prior-g)
                (obligation-graph-apply-event
                 prior-g (.o (event-kind := 'advance-cut) (cut := (+ (.ref prior-g 'cut) 1))))
                (make-obligation-graph
                 (string-append "g-" task-id) cut: (+ cut-val 1)
                 obligations: (list (make-obligation apex-id title: (opt-ref arch 'title task-id)
                                                     required-evidence-ids: '()))
                 evidence: '() det-tasks: '())))
           (env (make-capability-envelope "reopen-owner"
                                          allowed-caps: '(context-read)
                                          denied-caps: '(host-egress)
                                          egress-allowed?: #f))
           (trunk (make-context-trunk
                   (string-append "trunk-" task-id) apex-id g env
                   shared-context-cut: (.ref g 'cut) kv-prefix-digest: kv-dig))
           (actor (make-task-actor
                   task-id trunk (opt-ref arch 'scope-ids '("scope-main"))
                   title: (opt-ref arch 'title task-id)
                   worktree: (opt-ref arch 'worktree "main")
                   scope-mode: (opt-ref arch 'scope-mode 'project)
                   fencing-epoch: next-epoch))
           (prior-ctx (opt-ref arch 'governed-context #f))
           (ctx (.o (context-cut := (.ref g 'cut))
                    (kv-prefix-digest := (opt-ref prior-ctx 'kv-prefix-digest kv-dig))
                    (disclosure-depth := (opt-ref prior-ctx 'disclosure-depth 'L1))
                    (has-active-defeater? := (graph-has-active-defeaters? g))
                    (sandbox-admitted? := (opt-ref prior-ctx 'sandbox-admitted? #t))
                    (cedar-handoff-valid? := (opt-ref prior-ctx 'cedar-handoff-valid? #t))))
           (reopened-st (make-unified-driver-state
                         actor g ctx
                         competing-hypotheses: (opt-ref arch 'competing-hypotheses '())
                         branch-proposals: (opt-ref arch 'branch-proposals '()))))
      (.o (:: @ fleet)
          (active-drivers := (append (.ref fleet 'active-drivers) (list reopened-st)))
          (archived-actors := (filter (lambda (a) (not (equal? (.ref a 'task-id) task-id)))
                                      (.ref fleet 'archived-actors)))
          (peek-set := (filter (lambda (id) (not (equal? id task-id))) (.ref fleet 'peek-set)))
          (focused-task-id := task-id)))))

(def (fleet-export-audit-capsule fleet-or-run)
  (let* ((fleet (unwrap-fleet fleet-or-run))
         (drivers (.ref fleet 'active-drivers))
         (archived (.ref fleet 'archived-actors))
         (actor-audits
          (map (lambda (st)
                 (let* ((actor (.ref st 'actor))
                        (g (.ref st 'obligation-graph))
                        (mat (opt-ref st 'hypothesis-matrix #f)))
                   (.o (task-id := (.ref actor 'task-id))
                       (detour-mode := (opt-ref actor 'detour-mode 'mainline))
                       (fencing-epoch := (opt-ref actor 'fencing-epoch 1))
                       (kv-prefix-digest := (opt-ref (.ref actor 'trunk) 'kv-prefix-digest "sha256:unbound"))
                       (active-defeaters-count := (graph-defeater-count g))
                       (human-inbox-count := (length (opt-ref g 'human-inbox '())))
                       (preserved-hypotheses :=
                        (map (lambda (h)
                               (.o (hypothesis-id := (.ref h 'hypothesis-id))
                                   (claim := (.ref h 'claim))
                                   (contradictions := (.ref h 'contradictions))
                                   (open-questions := (.ref h 'open-questions))))
                             (.ref st 'competing-hypotheses)))
                       (branch-count := (length (.ref st 'branch-proposals)))
                       (matrix-cells-count := (if (object? mat) (length (.ref mat 'cells)) 0)))))
               drivers)))
    (.o (:: @ FleetAuditCapsule.)
        (round-count := (.ref fleet 'round-count))
        (active-actor-count := (length drivers))
        (archived-actor-count := (length archived))
        (peek-count := (length (.ref fleet 'peek-set)))
        (total-active-defeaters :=
         (foldl (lambda (a acc) (+ acc (.ref a 'active-defeaters-count))) 0 actor-audits))
        (total-human-inbox-items :=
         (foldl (lambda (a acc) (+ acc (.ref a 'human-inbox-count))) 0 actor-audits))
        (actors := actor-audits))))

;;; ---------------------------------------------------------------------------
;;; 4. Multi-Actor Step & Quiescence Trampoline
;;; ---------------------------------------------------------------------------

(def (archive-settled-driver next-st step)
  (let* ((actor (.ref next-st 'actor))
         (tid (.ref actor 'task-id))
         (trunk (.ref actor 'trunk)))
    (.o (task-id := tid)
        (title := (opt-ref actor 'title tid))
        (worktree := (opt-ref actor 'worktree "main"))
        (scope-mode := (opt-ref actor 'scope-mode 'project))
        (scope-ids := (opt-ref actor 'scope-ids '("scope-main")))
        (fencing-epoch := (opt-ref actor 'fencing-epoch 1))
        (kv-prefix-digest := (opt-ref trunk 'kv-prefix-digest "sha256:unbound"))
        (shared-context-cut := (opt-ref trunk 'shared-context-cut 1))
        (apex-obligation-id := (opt-ref trunk 'apex-obligation-id (string-append "ob-" tid)))
        (obligation-graph := (.ref next-st 'obligation-graph))
        (governed-context := (.ref next-st 'governed-context))
        (status := 'done)
        (archived? := #t)
        (competing-hypotheses := (.ref next-st 'competing-hypotheses))
        (branch-proposals := (.ref next-st 'branch-proposals))
        (hypothesis-matrix := (.ref step 'hypothesis-matrix)))))

(def (step-graph-fleet fleet (receipts '()) auto-archive?: (auto-archive? #t))
  (let ((next-round (+ (.ref fleet 'round-count) 1)))
    (let loop ((ds (.ref fleet 'active-drivers))
               (kept-drivers '()) (kept-steps '()) (newly-archived '())
               (merged-effects '()) (total-llm 0) (total-hits 0) (total-puts 0))
      (if (null? ds)
        (let* ((rev-arch (reverse newly-archived))
               (next-fleet
                (make-graph-fleet-state
                 (reverse kept-drivers)
                 archived-actors: (append (.ref fleet 'archived-actors) rev-arch)
                 peek-set: (.ref fleet 'peek-set)
                 focused-task-id: (.ref fleet 'focused-task-id)
                 round-count: next-round)))
          (.o (:: @ GraphFleetStepResult.)
              (fleet := next-fleet)
              (actor-steps := (reverse kept-steps))
              (effects := (reverse merged-effects))
              (llm-calls-emitted := total-llm)
              (cas-hits-observed := total-hits)
              (cas-puts-emitted := total-puts)
              (newly-archived-ids := (map (lambda (a) (.ref a 'task-id)) rev-arch))))
        (let* ((st (car ds))
               (tid (driver-task-id st))
               (step (drive-graph-actor-step st (receipts-for-actor tid receipts)))
               (effs (.ref step 'effects))
               (next-st (.ref step 'state))
               (archive? (and auto-archive?
                              (eq? (.ref step 'phase) 'quiescent-fixed-point)
                              (eq? (opt-ref (.ref next-st 'actor) 'detour-mode 'mainline) 'mainline)
                              (null? effs)))
               (llm (+ total-llm (.ref step 'llm-calls-emitted)))
               (hits (+ total-hits (opt-ref step 'cas-hits-observed 0)))
               (puts (+ total-puts (opt-ref step 'cas-puts-emitted 0))))
          (if archive?
            (loop (cdr ds) kept-drivers kept-steps
                  (cons (archive-settled-driver next-st step) newly-archived)
                  merged-effects llm hits puts)
            (loop (cdr ds) (cons next-st kept-drivers) (cons step kept-steps) newly-archived
                  (append (reverse (map (lambda (e) (namespace-effect tid e)) effs)) merged-effects)
                  llm hits puts)))))))

(def (run-graph-fleet-to-quiescence
      initial-fleet effect-interpreter max-rounds: (max-rounds 12) auto-archive?: (auto-archive? #t))
  (let loop ((fl initial-fleet) (incoming '()) (round 1)
             (total-llm 0) (total-hits 0) (total-puts 0) (trace '()))
    (let* ((res (step-graph-fleet fl incoming auto-archive?: auto-archive?))
           (next-fl (.ref res 'fleet))
           (effs (.ref res 'effects))
           (llm-n (+ total-llm (.ref res 'llm-calls-emitted)))
           (hit-n (+ total-hits (.ref res 'cas-hits-observed)))
           (put-n (+ total-puts (.ref res 'cas-puts-emitted)))
           (entry (.o (round)
                      (active-count := (length (.ref next-fl 'active-drivers)))
                      (archived-count := (length (.ref next-fl 'archived-actors)))
                      (effects-count := (length effs))
                      (llm-calls-emitted := (.ref res 'llm-calls-emitted))
                      (cas-hits-observed := (.ref res 'cas-hits-observed))
                      (cas-puts-emitted := (.ref res 'cas-puts-emitted))))
           (next-trace (append trace (list entry))))
      (if (or (null? effs) (>= round max-rounds))
        (.o (:: @ GraphFleetRunTrace.)
            (final-fleet := next-fl)
            (final-step := res)
            (rounds-executed := round)
            (total-llm-calls := llm-n)
            (total-cas-hits := hit-n)
            (total-cas-puts := put-n)
            (active-task-ids := (map driver-task-id (.ref next-fl 'active-drivers)))
            (settled-task-ids := (map (lambda (a) (.ref a 'task-id)) (.ref next-fl 'archived-actors)))
            (trace := next-trace))
        (loop next-fl (effect-interpreter effs) (+ round 1) llm-n hit-n put-n next-trace)))))

;;; ---------------------------------------------------------------------------
;;; 5. Inert Snapshots & Declarative UTF-8 Wire Serialization
;;; ---------------------------------------------------------------------------

(def (fleet->inert-snapshot fleet-or-run)
  (let ((fleet (unwrap-fleet fleet-or-run)))
    (.o (:: @ GraphFleetSnapshot.)
        (active-entries :=
         (map (lambda (st)
                (let ((actor (.ref st 'actor)))
                  (.o (task-id := (.ref actor 'task-id))
                      (title := (opt-ref actor 'title (.ref actor 'task-id)))
                      (worktree := (opt-ref actor 'worktree "main"))
                      (scope-mode := (opt-ref actor 'scope-mode 'project))
                      (scope-ids := (opt-ref actor 'scope-ids '("scope-main")))
                      (fencing-epoch := (opt-ref actor 'fencing-epoch 1))
                      (detour-mode := (opt-ref actor 'detour-mode 'mainline))
                      (detour-node-id := (opt-ref actor 'detour-node-id #f))
                      (trunk-snapshot := (trunk->inert-snapshot (.ref actor 'trunk)))
                      (obligation-graph := (.ref st 'obligation-graph))
                      (governed-context := (.ref st 'governed-context))
                      (competing-hypotheses := (.ref st 'competing-hypotheses))
                      (branch-proposals := (.ref st 'branch-proposals))
                      (hypothesis-matrix := (opt-ref st 'hypothesis-matrix #f))
                      (completed-step-outputs := (opt-ref st 'completed-step-outputs '()))
                      (step-count := (opt-ref st 'step-count 0))
                      (repair-budget := (opt-ref st 'repair-budget 3))
                      (repair-history := (opt-ref st 'repair-history '())))))
              (.ref fleet 'active-drivers)))
        (archived-actors := (.ref fleet 'archived-actors))
        (peek-set := (.ref fleet 'peek-set))
        (focused-task-id := (.ref fleet 'focused-task-id))
        (round-count := (.ref fleet 'round-count)))))

(def (restore-detour base-actor dmode dnode)
  (if (eq? dmode 'mainline)
    base-actor
    (.ref (enter-task-actor-detour base-actor dmode (or dnode "restored-detour")) 'actor)))

(def (inert-snapshot->fleet snap)
  (make-graph-fleet-state
   (map (lambda (e)
          (let* ((trunk (inert-snapshot->trunk (.ref e 'trunk-snapshot)))
                 (base (make-task-actor
                        (.ref e 'task-id) trunk (.ref e 'scope-ids)
                        title: (.ref e 'title) worktree: (.ref e 'worktree)
                        scope-mode: (.ref e 'scope-mode) fencing-epoch: (.ref e 'fencing-epoch)))
                 (actor (restore-detour base (.ref e 'detour-mode) (.ref e 'detour-node-id))))
            (make-unified-driver-state
             actor (.ref e 'obligation-graph) (.ref e 'governed-context)
             competing-hypotheses: (.ref e 'competing-hypotheses)
             branch-proposals: (.ref e 'branch-proposals)
             hypothesis-matrix: (.ref e 'hypothesis-matrix)
             completed-step-outputs: (.ref e 'completed-step-outputs)
             step-count: (.ref e 'step-count)
             repair-budget: (.ref e 'repair-budget)
             repair-history: (.ref e 'repair-history))))
        (.ref snap 'active-entries))
   archived-actors: (.ref snap 'archived-actors)
   peek-set: (.ref snap 'peek-set)
   focused-task-id: (.ref snap 'focused-task-id)
   round-count: (.ref snap 'round-count)))

(def (ob->wire o)
  (wire-rows o (obligation-id "ob") (title "") (required-evidence-ids '())
             (depends-on '()) (active-defeaters '()) (premise-ids '())))
(def (wire->ob a)
  (make-obligation (wire-ref a 'obligation-id "ob-restored")
                   title: (wire-ref a 'title "")
                   required-evidence-ids: (wire-ref a 'required-evidence-ids '())
                   depends-on: (wire-ref a 'depends-on '())
                   active-defeaters: (wire-ref a 'active-defeaters '())
                   premise-ids: (wire-ref a 'premise-ids '())))

(def (ev->wire e)
  (wire-rows e (evidence-id "ev") (payload "") (cut 1) (premise-ids '())
             (origin-tier 'observed-fact) (endorsed? #t) (retracted? #f)))
(def (wire->ev a)
  (make-evidence-fact (wire-ref a 'evidence-id "ev-restored") (wire-ref a 'payload "")
                      cut: (wire-ref a 'cut 1) premise-ids: (wire-ref a 'premise-ids '())
                      origin-tier: (wire-ref a 'origin-tier 'observed-fact)
                      endorsed?: (wire-ref a 'endorsed? #t) retracted?: (wire-ref a 'retracted? #f)))

(def (det-task->wire t)
  (wire-rows t (task-id "det") (obligation-id "ob") (produces-evidence-id "ev") (input "")
             (required-evidence-ids '()) (premise-ids '()) (depends-on-tasks '())
             (read-footprint '()) (write-footprint '())
             (effect-class 'pure-cas) (env-digest "sha256:default-env")))
(def (wire->det-task a)
  (make-deterministic-task-node
   (wire-ref a 'task-id "det-restored") (wire-ref a 'obligation-id "ob-restored")
   (wire-ref a 'produces-evidence-id "ev-restored") 'restored-flow (wire-ref a 'input "")
   required-evidence-ids: (wire-ref a 'required-evidence-ids '())
   premise-ids: (wire-ref a 'premise-ids '()) depends-on-tasks: (wire-ref a 'depends-on-tasks '())
   read-footprint: (wire-ref a 'read-footprint '()) write-footprint: (wire-ref a 'write-footprint '())
   effect-class: (wire-ref a 'effect-class 'pure-cas)
   env-digest: (wire-ref a 'env-digest "sha256:default-env")))

(def (inbox->wire i) (wire-rows i (kind 'diagnostic) (task-id "") (detail "")))
(def (wire->inbox a)
  (.o (kind := (wire-ref a 'kind 'diagnostic))
      (task-id := (wire-ref a 'task-id ""))
      (detail := (wire-ref a 'detail ""))))

(def (hyp->wire h)
  (wire-rows h (hypothesis-id "H?") (claim "") (evidence-lineage '())
             (contradictions '()) (open-questions '())))
(def (wire->hyp a)
  (make-competing-hypothesis
   (wire-ref a 'hypothesis-id "H?") (wire-ref a 'claim "")
   evidence-lineage: (wire-ref a 'evidence-lineage '())
   contradictions: (wire-ref a 'contradictions '())
   open-questions: (wire-ref a 'open-questions '())))

(def (branch->wire b)
  (wire-rows b (branch-id "B?") (question "") (proposer 'investigator)
             (endpoint "openai/gpt-marlin") (evidence-refs '())))
(def (wire->branch a)
  (make-hypothesis-branch-proposal
   (wire-ref a 'branch-id "B?") (wire-ref a 'question "")
   proposer: (wire-ref a 'proposer 'investigator)
   endpoint: (wire-ref a 'endpoint "openai/gpt-marlin")
   evidence-refs: (wire-ref a 'evidence-refs '())))

(def (graph->wire g)
  (wire-rows g
             ((obligations (map ob->wire (.ref g 'obligations)))
              (evidence (map ev->wire (.ref g 'evidence)))
              (det-tasks (map det-task->wire (.ref g 'det-tasks)))
              (human-inbox (map inbox->wire (opt-ref g 'human-inbox '()))))
             (graph-id "g") (cut 1) (completed-tasks '())
             (cedar-grant-live? #t) (mcp-manifest-healthy? #t)))
(def (wire->graph a)
  (foldl (lambda (item g) (obligation-graph-add-human-inbox g item))
         (make-obligation-graph
          (wire-ref a 'graph-id "g-restored") cut: (wire-ref a 'cut 1)
          obligations: (map wire->ob (wire-ref a 'obligations '()))
          evidence: (map wire->ev (wire-ref a 'evidence '()))
          det-tasks: (map wire->det-task (wire-ref a 'det-tasks '()))
          completed-tasks: (wire-ref a 'completed-tasks '())
          cedar-grant-live?: (wire-ref a 'cedar-grant-live? #t)
          mcp-manifest-healthy?: (wire-ref a 'mcp-manifest-healthy? #t))
         (map wire->inbox (wire-ref a 'human-inbox '()))))

(def (ctx->wire c)
  (wire-rows c (context-cut 1) (kv-prefix-digest "sha256:unbound")
             (disclosure-depth 'L1) (has-active-defeater? #f)
             (sandbox-admitted? #t) (cedar-handoff-valid? #t)))
(def (wire->ctx a)
  (.o (context-cut := (wire-ref a 'context-cut 1))
      (kv-prefix-digest := (wire-ref a 'kv-prefix-digest "sha256:unbound"))
      (disclosure-depth := (wire-ref a 'disclosure-depth 'L1))
      (has-active-defeater? := (wire-ref a 'has-active-defeater? #f))
      (sandbox-admitted? := (wire-ref a 'sandbox-admitted? #t))
      (cedar-handoff-valid? := (wire-ref a 'cedar-handoff-valid? #t))))

(def (archived->wire a)
  (let ((g (opt-ref a 'obligation-graph #f)) (c (opt-ref a 'governed-context #f)))
    (wire-rows a
               ((obligation-graph (and (object? g) (graph->wire g)))
                (governed-context (and (object? c) (ctx->wire c)))
                (archived? #t)
                (competing-hypotheses (map hyp->wire (opt-ref a 'competing-hypotheses '())))
                (branch-proposals (map branch->wire (opt-ref a 'branch-proposals '()))))
               (task-id "archived") (title "archived") (worktree "main")
               (scope-mode 'project) (scope-ids '("scope-main")) (fencing-epoch 1)
               (kv-prefix-digest "sha256:unbound") (shared-context-cut 1)
               (apex-obligation-id "ob-archived") (status 'done))))
(def (wire->archived a)
  (let ((gw (wire-ref a 'obligation-graph #f)) (cw (wire-ref a 'governed-context #f)))
    (.o (task-id := (wire-ref a 'task-id "archived"))
        (title := (wire-ref a 'title "archived"))
        (worktree := (wire-ref a 'worktree "main"))
        (scope-mode := (wire-ref a 'scope-mode 'project))
        (scope-ids := (wire-ref a 'scope-ids '("scope-main")))
        (fencing-epoch := (wire-ref a 'fencing-epoch 1))
        (kv-prefix-digest := (wire-ref a 'kv-prefix-digest "sha256:unbound"))
        (shared-context-cut := (wire-ref a 'shared-context-cut 1))
        (apex-obligation-id := (wire-ref a 'apex-obligation-id "ob-archived"))
        (obligation-graph := (and (list? gw) (wire->graph gw)))
        (governed-context := (and (list? cw) (wire->ctx cw)))
        (status := (wire-ref a 'status 'done))
        (archived? := #t)
        (competing-hypotheses := (map wire->hyp (wire-ref a 'competing-hypotheses '())))
        (branch-proposals := (map wire->branch (wire-ref a 'branch-proposals '())))
        (hypothesis-matrix := #f))))

(def (fleet->wire-string fleet-or-run)
  (let* ((fleet (unwrap-fleet fleet-or-run))
         (active-wires
          (map (lambda (st)
                 (let* ((actor (.ref st 'actor))
                        (trunk (.ref actor 'trunk))
                        (env (.ref trunk 'capability-envelope)))
                   (append
                    (wire-rows actor
                               (task-id "task") (title "task") (worktree "main")
                               (scope-mode 'project) (scope-ids '("scope-main"))
                               (fencing-epoch 1) (detour-mode 'mainline) (detour-node-id #f))
                    (wire-rows trunk
                               (trunk-id "trunk") (apex-obligation-id "ob")
                               (shared-context-cut 1) (kv-prefix-digest "sha256:unbound"))
                    (list (cons 'env-owner (.ref env 'owner-id))
                          (cons 'env-allowed (.ref env 'allowed-caps))
                          (cons 'env-denied (.ref env 'denied-caps))
                          (cons 'env-egress? (.ref env 'egress-allowed?))
                          (cons 'obligation-graph (graph->wire (.ref st 'obligation-graph)))
                          (cons 'governed-context (ctx->wire (.ref st 'governed-context)))
                          (cons 'competing-hypotheses (map hyp->wire (.ref st 'competing-hypotheses)))
                          (cons 'branch-proposals (map branch->wire (.ref st 'branch-proposals)))
                          (cons 'step-count (opt-ref st 'step-count 0))
                          (cons 'repair-budget (opt-ref st 'repair-budget 3))
                          (cons 'repair-history (opt-ref st 'repair-history '()))))))
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
    (let ((alist (cdr parsed)))
      (make-graph-fleet-state
       (map (lambda (e)
              (let* ((g (wire->graph (wire-ref e 'obligation-graph '())))
                     (env (make-capability-envelope
                           (wire-ref e 'env-owner "owner")
                           allowed-caps: (wire-ref e 'env-allowed '(context-read))
                           denied-caps: (wire-ref e 'env-denied '(host-egress))
                           egress-allowed?: (wire-ref e 'env-egress? #f)))
                     (trunk (make-context-trunk
                             (wire-ref e 'trunk-id "trunk-restored")
                             (wire-ref e 'apex-obligation-id "ob-restored")
                             g env
                             shared-context-cut: (wire-ref e 'shared-context-cut 1)
                             kv-prefix-digest: (wire-ref e 'kv-prefix-digest "sha256:unbound")))
                     (base (make-task-actor
                            (wire-ref e 'task-id "task-restored") trunk
                            (wire-ref e 'scope-ids '("scope-main"))
                            title: (wire-ref e 'title "Restored")
                            worktree: (wire-ref e 'worktree "main")
                            scope-mode: (wire-ref e 'scope-mode 'project)
                            fencing-epoch: (wire-ref e 'fencing-epoch 1)))
                     (actor (restore-detour base (wire-ref e 'detour-mode 'mainline)
                                            (wire-ref e 'detour-node-id #f))))
                (make-unified-driver-state
                 actor g (wire->ctx (wire-ref e 'governed-context '()))
                 competing-hypotheses: (map wire->hyp (wire-ref e 'competing-hypotheses '()))
                 branch-proposals: (map wire->branch (wire-ref e 'branch-proposals '()))
                 step-count: (wire-ref e 'step-count 0)
                 repair-budget: (wire-ref e 'repair-budget 3)
                 repair-history: (wire-ref e 'repair-history '()))))
            (wire-ref alist 'active '()))
       archived-actors: (map wire->archived (wire-ref alist 'archived '()))
       peek-set: (wire-ref alist 'peek-set '())
       focused-task-id: (wire-ref alist 'focused-task-id #f)
       round-count: (wire-ref alist 'round-count 0)))))

(def (plan-fleet-cas-checkpoint fleet-or-run cas-key)
  (make-cas-put-effect
   (string-append "fleet-checkpoint:" cas-key) cas-key (fleet->wire-string fleet-or-run)))

(def (restore-fleet-from-cas-receipt receipt)
  (if (and (object? receipt) (eq? (opt-ref receipt 'kind #f) 'cas-hit))
    (let ((payload (.ref receipt 'payload)))
      (if (string? payload) (wire-string->fleet payload) (inert-snapshot->fleet payload)))
    (error "restore-fleet-from-cas-receipt: expected cas-hit receipt" receipt)))

;;; ---------------------------------------------------------------------------
;;; 6. Marlin Declarative Workbench Tab Projection
;;; ---------------------------------------------------------------------------

(def (project-fleet->workbench-projection fleet-or-run)
  (let* ((fleet (unwrap-fleet fleet-or-run))
         (active-tabs
          (map (lambda (st)
                 (car (.ref (project-driver-state->workbench-projection st) 'dynamic-tabs)))
               (.ref fleet 'active-drivers)))
         (active-ids (map (lambda (t) (.ref t 'id)) active-tabs))
         (archived-actors (.ref fleet 'archived-actors))
         (peek-set (.ref fleet 'peek-set))
         (peek-tabs
          (filter-map
           (lambda (a)
             (let ((tid (.ref a 'task-id)))
               (and (member tid peek-set)
                    (not (member tid active-ids))
                    (.o (id := tid)
                        (label := (opt-ref a 'title tid))
                        (status := (opt-ref a 'status 'done))
                        (mode := 'peek-readonly)
                        (detour-mode := 'mainline)
                        (detour-node-id := #f)
                        (driver-phase := 'settled-archived)
                        (pending-effects-count := 0)
                        (worktree := (opt-ref a 'worktree "main"))
                        (checklist-done := 1)
                        (checklist-total := 1)
                        (competing-hypotheses := (opt-ref a 'competing-hypotheses '()))
                        (human-inbox := '())
                        (active-defeaters-count := 0)
                        (repair-attempts := 0)
                        (repair-budget := #f)))))
           archived-actors))
         (all-dynamic (append active-tabs peek-tabs))
         (archived-index
          (map (lambda (a)
                 (.o (task-id := (.ref a 'task-id))
                     (title := (opt-ref a 'title (.ref a 'task-id)))
                     (worktree := (opt-ref a 'worktree "main"))))
               archived-actors)))
    (.o (pinned-tab := 'index)
        (dynamic-tabs := all-dynamic)
        (archived-index)
        (visible-tab-ids := (cons 'index (map (lambda (t) (.ref t 'id)) all-dynamic))))))
