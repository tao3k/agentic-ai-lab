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
        (only-in :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
                 nono-sandbox-profile)
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
        make-governed-context-trunk)

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
  (let ((pol (agentic-ai-lab-cedar-policy policy-id policy-source)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.cedar-handoff.v1
        policy: pol
        policy-valid?: (agentic-ai-lab-cedar-policy? pol)
        trunk-id: trunk-id
        bound-cut: bound-cut
        grant-epoch: grant-epoch
        runtime-executed?: #f)))

;;; Evaluate real `nono-sandbox-profile` (or any POO subtype) against Slice 52's
;;; Lethal-Trifecta sandbox gate (`untrusted-input + private-data + unendorsed egress`).
(def (admit-graph-nono-sandbox
      profile: (profile nono-sandbox-profile)
      env-digest: (env-digest "sha256:nono-default-env")
      has-untrusted-input?: (has-untrusted-input? #f)
      has-private-data?: (has-private-data? #f)
      egress-endorsed?: (egress-endorsed? #f)
      lease-valid?: (lease-valid? #t))
  (let* ((binding (sandbox-profile->external-binding
                   profile
                   env-digest: env-digest
                   has-untrusted-input?: has-untrusted-input?
                   has-private-data?: has-private-data?
                   egress-endorsed?: egress-endorsed?
                   lease-valid?: lease-valid?))
         (decision (funflow-admit-external-task-sandbox binding)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.sandbox-admission.v1
        admitted?: (.ref decision 'admitted?)
        reason: (.ref decision 'reason)
        sandbox-binding: binding
        decision: decision
        runtime-executed?: #f)))

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
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.governed-trunk-bundle.v1
        admitted?: admitted?
        reason: (cond
                 ((not (.ref assembly 'admitted?)) (.ref assembly 'reason))
                 ((not sandbox-ok?) (.ref sandbox-admission 'reason))
                 ((not cedar-ok?) 'invalid-cedar-policy-handoff)
                 (else 'governed-trunk-assembled))
        trunk: trunk
        context-assembly: assembly
        kv-prefix-digest: kv-dig
        effective-disclosure-depth: (.ref assembly 'effective-disclosure-depth)
        quarantined-excluded: (.ref (.ref assembly 'recall-view) 'quarantined-or-rejected-excluded)
        audit-capsule: (.ref assembly 'audit-capsule)
        cedar-handoff: cedar-handoff
        sandbox-admission: sandbox-admission
        runtime-executed?: #f)))
