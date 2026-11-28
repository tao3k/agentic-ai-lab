;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Governed Context, Nono-Sandbox & Cedar Handoff Bridge for GraphEngine
;;; (`modules/graph-engine/governed-context-bridge.ss`).
;;;
;;; INVARIANT: 100% PURE functional / POO — ZERO SQLite, ZERO disk/network I/O,
;;; ZERO in-process Cedar fallback evaluation!
;;; Composes:
;;;   1. `modules/ai-agentic-context/funs-assembly-pipeline.ss`:
;;;      Drives `ContextTrunk.`'s live `kv-prefix-digest`, MINJA/MemoryGraft
;;;      quarantine, active-defeater L3 disclosure floor, Stage-1 ORG AST repair,
;;;      and Capstone-47 zero-LLM `DeterministicAuditCapsule`.
;;;   2. `modules/nono-sandbox/profile-interface.ss` + `modules/funflow/governed-runner.ss`:
;;;      Projects real POO `nono-sandbox-profile` into Slice 52 Lethal-Trifecta
;;;      admission (`funflow-admit-external-task-sandbox`).
;;;   3. `modules/authorization/providers/cedar/objects.ss`:
;;;      Packages real Cedar `agentic-ai-lab-cedar-policy` values as inert
;;;      Marlin handoff descriptors (`runtime-executed?: #f`).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-assembly-pipeline
                 agentic-ai-lab-ai-agentic-context-assemble-governed-turn)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 funflow-admit-external-task-sandbox)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 sandbox-profile->external-binding)
        (only-in :tao3k/agentic-ai-lab/modules/authorization/providers/cedar/objects
                 agentic-ai-lab-cedar-policy
                 agentic-ai-lab-cedar-policy?)
        "convergent-tree.ss")

(export GraphCedarHandoff.
        make-graph-cedar-handoff
        admit-graph-nono-sandbox
        make-governed-context-trunk
        governed-trunk-bundle->marlin-capsule-vector)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def GraphCedarHandoff.
  kind: 'agentic-ai-lab.graph-engine.cedar-handoff.v1
  runtime-executed?: #f)

;;; Package a real Cedar POO policy (`agentic-ai-lab-cedar-policy`) + trunk/cut
;;; scope into an inert Marlin authorization handoff (`runtime-executed?: #f`).
(def (make-graph-cedar-handoff
      policy-id
      policy-source
      trunk-id
      bound-cut: (bound-cut 1)
      grant-epoch: (grant-epoch 1))
  (let ((policy (agentic-ai-lab-cedar-policy policy-id policy-source)))
    (.o (:: @ GraphCedarHandoff.)
        (policy)
        (policy-valid? := (agentic-ai-lab-cedar-policy? policy))
        (trunk-id) (bound-cut) (grant-epoch))))

(.def GraphDefaultNonoProfile.
  backend-kind: 'nono
  capabilities: '(process-run filesystem-read tmpdir)
  egress-enabled?: #f)

;;; Evaluate real `nono-sandbox-profile` (or any `sandbox-profile` POO subtype)
;;; against Slice 52's Lethal-Trifecta sandbox gate (`untrusted-input + private-data + unendorsed egress`).
(def (admit-graph-nono-sandbox
      profile: (profile GraphDefaultNonoProfile.)
      env-digest: (env-digest "sha256:nono-default-env")
      has-untrusted-input?: (has-untrusted-input? #f)
      has-private-data?: (has-private-data? #f)
      egress-endorsed?: (egress-endorsed? #f)
      lease-valid?: (lease-valid? #t))
  (let* ((sandbox-binding (sandbox-profile->external-binding
                           profile
                           env-digest: env-digest
                           has-untrusted-input?: has-untrusted-input?
                           has-private-data?: has-private-data?
                           egress-endorsed?: egress-endorsed?
                           lease-valid?: lease-valid?))
         (decision (funflow-admit-external-task-sandbox sandbox-binding)))
    (.o (kind := 'agentic-ai-lab.graph-engine.sandbox-admission.v1)
        (admitted? := (.ref decision 'admitted?))
        (reason := (.ref decision 'reason))
        (sandbox-binding)
        (decision)
        (runtime-executed? := #f))))

;;; Assemble a live governed Context turn via `ai-agentic-context` (Stage-1 ORG
;;; AST repair + L0..L3 progressive disclosure + MINJA quarantine + Two-Zone
;;; KV-Prefix + Capstone-47 AuditCapsule) and bind its exact `frozen-prefix-digest`
;;; directly onto a `ContextTrunk.`!
(def (make-governed-context-trunk
      trunk-id
      apex-obligation-id
      obligation-graph
      capability-envelope
      org-text
      frozen-entries: (frozen-entries '())
      memory-candidates: (memory-candidates '())
      cedar-handoff: (cedar-handoff #f)
      sandbox-admission: (sandbox-admission #f)
      live-grant-epoch: (live-grant-epoch 1)
      trunk-grant-live?: (trunk-grant-live? #t))
  (let* ((cut-val (.ref obligation-graph 'cut))
         (cut-str (string-append "cut-" (number->string cut-val)))
         (has-defeater? (pair? (filter (lambda (o) (pair? (.ref o 'active-defeaters)))
                                       (.ref obligation-graph 'obligations))))
         (assembly (agentic-ai-lab-ai-agentic-context-assemble-governed-turn
                    org-text
                    epoch: cut-val
                    bound-cut: cut-str
                    live-cut: cut-str
                    frozen-entries: frozen-entries
                    memory-candidates: memory-candidates
                    has-active-defeater?: has-defeater?))
         (kv-dig (.ref (.ref assembly 'two-zone-prompt) 'frozen-prefix-digest))
         (sandbox-ok? (or (not sandbox-admission) (.ref sandbox-admission 'admitted?)))
         (cedar-ok? (or (not cedar-handoff) (.ref cedar-handoff 'policy-valid?)))
         (admitted? (and (.ref assembly 'admitted?) sandbox-ok? cedar-ok?))
         (trunk (make-context-trunk
                 trunk-id
                 apex-obligation-id
                 obligation-graph
                 capability-envelope
                 shared-context-cut: cut-val
                 kv-prefix-digest: kv-dig
                 live-grant-epoch: live-grant-epoch
                 trunk-grant-live?: (and trunk-grant-live? admitted?))))
    (.o (kind := 'agentic-ai-lab.graph-engine.governed-trunk-bundle.v1)
        (admitted?)
        (reason := (cond
                    ((not (.ref assembly 'admitted?)) (.ref assembly 'reason))
                    ((not sandbox-ok?) (.ref sandbox-admission 'reason))
                    ((not cedar-ok?) 'invalid-cedar-policy-handoff)
                    (else 'governed-trunk-assembled)))
        (trunk)
        (context-assembly := assembly)
        (kv-prefix-digest := kv-dig)
        (effective-disclosure-depth := (.ref assembly 'effective-disclosure-depth))
        (quarantined-excluded := (.ref (.ref assembly 'recall-view) 'quarantined-or-rejected-excluded))
        (audit-capsule := (.ref assembly 'audit-capsule))
        (cedar-handoff)
        (sandbox-admission)
        (runtime-executed? := #f))))

;;; Project a `make-governed-context-trunk` bundle into the exact 10-slot rooted
;;; Scheme vector consumed by `marlin-agent-core`'s C-ABI symbol
;;; `marlin_graph_engine_governed_context_vector` (MAR-GRAPH-R06 + Design 165):
;;;   #(task-id context-cut kv-prefix-digest disclosure-depth has-active-defeater?
;;;     quarantined-memory-count sandbox-admitted? cedar-handoff-valid?
;;;     detour-mode auto-archive-enabled?)
(def (governed-trunk-bundle->marlin-capsule-vector
      task-id
      bundle
      actor: (actor #f)
      detour-mode: (detour-mode #f)
      auto-archive-enabled?: (auto-archive-enabled? 'auto))
  (let* ((eff-detour (or detour-mode
                         (if (and (object? actor) (.slot? actor 'detour-mode))
                           (.ref actor 'detour-mode)
                           'mainline)))
         (eff-auto-archive (if (eq? auto-archive-enabled? 'auto)
                             (not (eq? eff-detour 'blocker-active))
                             (and auto-archive-enabled? #t))))
    (unless (memq eff-detour '(mainline blocker-active side-quest-active))
      (error "invalid Scoped Detour mode" eff-detour))
    (when (and (eq? eff-detour 'blocker-active) eff-auto-archive)
      (error "blocker-detour-must-disable-auto-archive"))
    (let* ((trunk (.ref bundle 'trunk))
           (cut (.ref trunk 'shared-context-cut))
           (kv-dig (.ref bundle 'kv-prefix-digest))
           (depth-num (.ref bundle 'effective-disclosure-depth))
           (depth-sym (case depth-num
                        ((0) 'L0)
                        ((1) 'L1)
                        ((2) 'L2)
                        (else 'L3)))
           (og (.ref trunk 'obligation-graph))
           (has-defeater? (pair? (filter (lambda (o) (pair? (.ref o 'active-defeaters)))
                                         (.ref og 'obligations))))
           (quarantined (.ref bundle 'quarantined-excluded))
           (sbx (.ref bundle 'sandbox-admission))
           (cedar (.ref bundle 'cedar-handoff))
           (sandbox-ok? (if sbx (opt-ref sbx 'admitted? #f) #t))
           (cedar-ok? (if cedar (opt-ref cedar 'policy-valid? #f) #t)))
      (vector task-id
              cut
              kv-dig
              depth-sym
              (and has-defeater? #t)
              quarantined
              (and sandbox-ok? #t)
              (and cedar-ok? #t)
              eff-detour
              eff-auto-archive))))
