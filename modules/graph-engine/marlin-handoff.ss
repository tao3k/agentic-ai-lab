;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scheme -> Marlin (`marlin-agent-core`) Dispatch Envelope, Flat ABI
;;; Projection & Fencing-Guarded Receipt Reconciliation
;;; (`modules/graph-engine/marlin-handoff.ss`).
;;;
;;; Architectural Invariants:
;;; 1. 100% PURE functional / POO semantic core — ZERO SQLite, ZERO disk/network
;;;    I/O, ZERO in-process side-effect execution (`runtime-executed?: #f`,
;;;    `handoff-required?: #t`, `runtime-parses-scheme-source?: #f`,
;;;    `scheme-manufactures-runtime-handlers?: #f`, `session-free?: #t`).
;;; 2. Fail-Closed Pre-Handoff Gate (`validate-graph-marlin-dispatch`):
;;;    Refuses to emit a Marlin dispatch envelope when:
;;;    - `actor` is not active (settled/parked tasks never dispatch),
;;;    - `join-node-id` continuation is blocked by an in-flight/failed/defeated branch,
;;;    - `nono-sandbox` admission is denied (Lethal Trifecta blocked),
;;;    - `cedar-handoff` is invalid or claims `runtime-executed?: #t`,
;;;    - `journal-handoff` claims `runtime-executed?: #t` or a `'detached` actor
;;;      attempts to write to the project Turso/Marlin journal!
;;; 3. Flat Wire ABI Projection (`graph-marlin-dispatch->alist`):
;;;    Converts the POO `MarlinDispatchEnvelope.` into a plain, byte-stable
;;;    alist so `marlin-agent-core` / Rust / C ABI consumes it without seeing
;;;    Gerbil POO internals or parsing Scheme source.
;;; 4. Fencing-Epoch Anti-Split-Brain Reconciliation (`reconcile-marlin-execution-receipt`):
;;;    Rejects any stale Marlin receipt whose `fencing-epoch` lags behind the
;;;    live `TaskActor.` (e.g. after a mid-flight C4 `target: 'trunk` steering
;;;    message), and advances anchored branch join gates (`D -> {D1, D2} -> F`).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list foldl)
        "task-actor.ss")

(export +graph-engine-marlin-dispatch-schema+
        +graph-engine-marlin-receipt-schema+
        MarlinDispatchEnvelope.
        MarlinExecutionReceipt.
        marlin-dispatch-envelope?
        marlin-execution-receipt?
        validate-graph-marlin-dispatch
        make-graph-marlin-dispatch
        graph-marlin-dispatch->alist
        graph-marlin-dispatch->c-abi-vector
        make-marlin-execution-receipt
        reconcile-marlin-execution-receipt)

(def +graph-engine-marlin-dispatch-schema+
  'agentic-ai-lab.graph-engine.marlin-dispatch.v1)

(def +graph-engine-marlin-receipt-schema+
  'agentic-ai-lab.graph-engine.marlin-receipt.v1)

(def +valid-marlin-operations+
  '(execute-frontier execute-branch continue-trunk commit-settlement))

(def +valid-substrate-targets+
  '(none sqlite-turso marlin-store))

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def MarlinDispatchEnvelope.
  kind: 'agentic-ai-lab.graph-engine.marlin-dispatch.v1
  schema: +graph-engine-marlin-dispatch-schema+
  runtime-owner: "marlin-agent-core"
  handoff-required?: #t
  runtime-executed?: #f
  runtime-parses-scheme-source?: #f
  scheme-manufactures-runtime-handlers?: #f
  session-free?: #t)

(.def MarlinExecutionReceipt.
  kind: 'agentic-ai-lab.graph-engine.marlin-receipt.v1
  schema: +graph-engine-marlin-receipt-schema+
  runtime-owner: "marlin-agent-core")

(def (marlin-dispatch-envelope? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.graph-engine.marlin-dispatch.v1)))

(def (marlin-execution-receipt? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.graph-engine.marlin-receipt.v1)))

;;; Fail-closed pre-handoff validation returning a list of error symbols.
;;; Empty list means the dispatch is admissible for `marlin-agent-core`.
(def (validate-graph-marlin-dispatch
      actor
      operation: (operation 'execute-frontier)
      join-node-id: (join-node-id #f)
      detour-mode: (detour-mode #f)
      cedar-handoff: (cedar-handoff #f)
      sandbox-admission: (sandbox-admission #f)
      journal-handoff: (journal-handoff #f)
      substrate-target: (substrate-target 'none))
  (let ((errs '())
        (eff-detour (or detour-mode
                        (if (task-actor? actor)
                          (opt-ref actor 'detour-mode 'mainline)
                          'mainline))))
    (unless (task-actor? actor)
      (set! errs (cons 'invalid-task-actor errs)))
    (unless (memq operation +valid-marlin-operations+)
      (set! errs (cons 'invalid-marlin-operation errs)))
    (unless (memq substrate-target +valid-substrate-targets+)
      (set! errs (cons 'invalid-substrate-target errs)))
    (unless (memq eff-detour '(mainline blocker-active side-quest-active))
      (set! errs (cons 'invalid-detour-mode errs)))
    (when (and (eq? eff-detour 'blocker-active)
               (eq? operation 'commit-settlement))
      (set! errs (cons 'blocker-detour-blocks-settlement errs)))
    (when (task-actor? actor)
      (unless (or (eq? (.ref actor 'status) 'active)
                  (and (eq? operation 'commit-settlement)
                       (memq (.ref actor 'status) '(settled parked))))
        (set! errs (cons 'task-actor-not-dispatchable errs)))
      (when (and join-node-id (eq? operation 'continue-trunk))
        (let ((gate (can-continue-trunk-at-join? actor join-node-id)))
          (unless (.ref gate 'can-continue?)
            (set! errs (cons (.ref gate 'reason) errs)))))
      (when (and (eq? (.ref actor 'scope-mode) 'detached)
                 (or journal-handoff (not (eq? substrate-target 'none))))
        (set! errs (cons 'detached-actor-cannot-write-project-journal errs))))
    (when sandbox-admission
      (unless (and (object? sandbox-admission)
                   (opt-ref sandbox-admission 'admitted? #f))
        (set! errs (cons 'sandbox-admission-denied errs)))
      (when (and (object? sandbox-admission)
                 (opt-ref sandbox-admission 'runtime-executed? #f))
        (set! errs (cons 'sandbox-handoff-must-be-inert errs))))
    (when cedar-handoff
      (unless (and (object? cedar-handoff)
                   (opt-ref cedar-handoff 'policy-valid? #f))
        (set! errs (cons 'cedar-handoff-invalid errs)))
      (when (and (object? cedar-handoff)
                 (opt-ref cedar-handoff 'runtime-executed? #f))
        (set! errs (cons 'cedar-handoff-must-be-inert errs))))
    (when journal-handoff
      (when (and (object? journal-handoff)
                 (opt-ref journal-handoff 'runtime-executed? #f))
        (set! errs (cons 'journal-handoff-must-be-inert errs))))
    (reverse errs)))

;;; Build a validated, fail-closed `MarlinDispatchEnvelope.` for `marlin-agent-core`.
(def (make-graph-marlin-dispatch
      actor
      operation: (operation 'execute-frontier)
      join-node-id: (join-node-id #f)
      detour-mode: (detour-mode #f)
      frontier-plan: (frontier-plan #f)
      scc-condensation: (scc-condensation #f)
      cedar-handoff: (cedar-handoff #f)
      sandbox-admission: (sandbox-admission #f)
      journal-handoff: (journal-handoff #f)
      substrate-target: (substrate-target 'none)
      request-id: (request-id #f))
  (let ((errs (validate-graph-marlin-dispatch
               actor
               operation: operation
               join-node-id: join-node-id
               detour-mode: detour-mode
               cedar-handoff: cedar-handoff
               sandbox-admission: sandbox-admission
               journal-handoff: journal-handoff
               substrate-target: substrate-target)))
    (if (pair? errs)
      (.o bind-these: #f
          admitted?: #f
          errors: errs
          envelope: #f)
      (let* ((tid (.ref actor 'task-id))
             (epoch (.ref actor 'fencing-epoch))
             (rid (or request-id
                      (string-append "marlin:" tid ":e" (number->string epoch)
                                     ":" (symbol->string operation))))
             (env (.o bind-these: #f
                      kind: 'agentic-ai-lab.graph-engine.marlin-dispatch.v1
                      schema: +graph-engine-marlin-dispatch-schema+
                      request-id: rid
                      runtime-owner: "marlin-agent-core"
                      handoff-required?: #t
                      runtime-executed?: #f
                      runtime-parses-scheme-source?: #f
                      scheme-manufactures-runtime-handlers?: #f
                      session-free?: #t
                      operation: operation
                      substrate-target: substrate-target
                      task-id: tid
                      actor-kind: (.ref actor 'actor-kind)
                      scope-mode: (.ref actor 'scope-mode)
                      scope-ids: (.ref actor 'scope-ids)
                      fencing-epoch: epoch
                      trunk-id: (.ref actor 'trunk-id)
                      apex-obligation-id: (.ref actor 'apex-obligation-id)
                      shared-context-cut: (.ref actor 'shared-context-cut)
                      kv-prefix-digest: (.ref actor 'kv-prefix-digest)
                      join-node-id: join-node-id
                      frontier-plan: frontier-plan
                      scc-condensation: scc-condensation
                      cedar-handoff: cedar-handoff
                      sandbox-admission: sandbox-admission
                      journal-handoff: journal-handoff)))
        (.o bind-these: #f
            admitted?: #t
            errors: '()
            envelope: env)))))

;;; Project a `MarlinDispatchEnvelope.` into a flat, POO-free wire ABI alist for
;;; `marlin-agent-core` / Rust / C ABI consumption.
(def (graph-marlin-dispatch->alist env)
  (let* ((cedar (.ref env 'cedar-handoff))
         (sbx (.ref env 'sandbox-admission))
         (jh (.ref env 'journal-handoff))
         (fp (.ref env 'frontier-plan))
         (scc (.ref env 'scc-condensation)))
    (list
     (cons 'schema (.ref env 'schema))
     (cons 'request-id (.ref env 'request-id))
     (cons 'runtime-owner (.ref env 'runtime-owner))
     (cons 'handoff-required? (.ref env 'handoff-required?))
     (cons 'runtime-executed? (.ref env 'runtime-executed?))
     (cons 'runtime-parses-scheme-source? (.ref env 'runtime-parses-scheme-source?))
     (cons 'scheme-manufactures-runtime-handlers? (.ref env 'scheme-manufactures-runtime-handlers?))
     (cons 'session-free? (.ref env 'session-free?))
     (cons 'operation (.ref env 'operation))
     (cons 'substrate-target (.ref env 'substrate-target))
     (cons 'task-id (.ref env 'task-id))
     (cons 'actor-kind (.ref env 'actor-kind))
     (cons 'scope-mode (.ref env 'scope-mode))
     (cons 'scope-ids (.ref env 'scope-ids))
     (cons 'fencing-epoch (.ref env 'fencing-epoch))
     (cons 'trunk-id (.ref env 'trunk-id))
     (cons 'apex-obligation-id (.ref env 'apex-obligation-id))
     (cons 'shared-context-cut (.ref env 'shared-context-cut))
     (cons 'kv-prefix-digest (.ref env 'kv-prefix-digest))
     (cons 'join-node-id (.ref env 'join-node-id))
     (cons 'frontier-wave-count (if fp (length (opt-ref fp 'waves '())) 0))
     (cons 'scc-has-cycles? (if scc (opt-ref scc 'has-cycles? #f) #f))
     (cons 'cedar-policy-valid? (if cedar (opt-ref cedar 'policy-valid? #f) #f))
     (cons 'sandbox-admitted? (if sbx (opt-ref sbx 'admitted? #f) #t))
     (cons 'journal-event-id (if jh (opt-ref jh 'event-id #f) #f)))))

;;; Project a `MarlinDispatchEnvelope.` into the exact 7-slot POO-free rooted vector
;;; consumed by `marlin-agent-core`'s `marlin_graph_engine_dispatch_vector` C-ABI:
;;;   #(request-id task-id operation fencing-epoch scope-mode join-node-id substrate-target)
(def (graph-marlin-dispatch->c-abi-vector env)
  (let* ((op (case (.ref env 'operation)
               ((execute-frontier) 'execute-frontier)
               ((execute-branch) 'apply-steering)
               ((continue-trunk) 'converge-apex)
               ((commit-settlement) 'commit-settlement)
               (else (.ref env 'operation))))
         (substrate (case (.ref env 'substrate-target)
                      ((sqlite-turso marlin-store) 'sqlite-turso)
                      (else 'pure-memory))))
    (vector (.ref env 'request-id)
            (.ref env 'task-id)
            op
            (.ref env 'fencing-epoch)
            (.ref env 'scope-mode)
            (.ref env 'join-node-id)
            substrate)))

;;; Construct an inbound `MarlinExecutionReceipt.` returned by `marlin-agent-core`
;;; (or the opt-in `+sqlite-turso` adapter) after executing a dispatched envelope.
(def (make-marlin-execution-receipt
      request-id
      task-id
      fencing-epoch
      status: (status 'ok)
      journal-epoch: (journal-epoch 0)
      chain-head-hash: (chain-head-hash #f)
      executed-wave-ids: (executed-wave-ids '())
      branch-outcomes: (branch-outcomes '())
      substrate: (substrate 'marlin-store))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.marlin-receipt.v1
      schema: +graph-engine-marlin-receipt-schema+
      runtime-owner: "marlin-agent-core"
      request-id: request-id
      task-id: task-id
      fencing-epoch: fencing-epoch
      status: status
      journal-epoch: journal-epoch
      chain-head-hash: chain-head-hash
      executed-wave-ids: executed-wave-ids
      branch-outcomes: branch-outcomes
      substrate: substrate))

;;; Purely reconcile an inbound `MarlinExecutionReceipt.` against a live `TaskActor.`.
;;; Enforces Fencing-Epoch anti-split-brain guard (`stale-fencing-epoch`) so a
;;; mid-flight C4 Trunk steering pivot ALWAYS invalidates stale Marlin receipts!
(def (reconcile-marlin-execution-receipt
      actor
      receipt
      join-node-id: (join-node-id #f))
  (cond
   ((not (task-actor? actor))
    (.o bind-these: #f accepted?: #f reason: 'invalid-task-actor actor: actor join-gate: #f))
   ((not (marlin-execution-receipt? receipt))
    (.o bind-these: #f accepted?: #f reason: 'invalid-marlin-receipt actor: actor join-gate: #f))
   ((not (equal? (.ref actor 'task-id) (.ref receipt 'task-id)))
    (.o bind-these: #f accepted?: #f reason: 'receipt-task-id-mismatch actor: actor join-gate: #f))
   ((not (= (.ref actor 'fencing-epoch) (.ref receipt 'fencing-epoch)))
    (.o bind-these: #f
        accepted?: #f
        reason: 'stale-fencing-epoch
        actor-fencing-epoch: (.ref actor 'fencing-epoch)
        receipt-fencing-epoch: (.ref receipt 'fencing-epoch)
        actor: actor
        join-gate: #f))
   (else
    (let* ((updated-actor
            (foldl (lambda (pair acc)
                     (complete-anchored-branch acc (car pair) outcome: (cdr pair)))
                   actor
                   (.ref receipt 'branch-outcomes)))
           (gate (and join-node-id
                      (can-continue-trunk-at-join? updated-actor join-node-id)))
           (next-action
            (cond
             ((not (eq? (.ref receipt 'status) 'ok)) 'handle-marlin-failure)
             ((and gate (not (.ref gate 'can-continue?))) 'blocked-on-branch)
             (gate 'continue-trunk)
             (else 'ready-for-next-step))))
      (.o bind-these: #f
          accepted?: #t
          reason: 'marlin-receipt-reconciled
          next-action: next-action
          journal-epoch: (.ref receipt 'journal-epoch)
          chain-head-hash: (.ref receipt 'chain-head-hash)
          actor: updated-actor
          join-gate: gate)))))
