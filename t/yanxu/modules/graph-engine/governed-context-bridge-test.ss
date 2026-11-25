;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Governed Context Bridge & Marlin Handoff Verification
;;; (`t/yanxu/modules/graph-engine/governed-context-bridge-test.ss`):
;;;   1. Real `ai-agentic-context` 5-stage assembly drives `ContextTrunk.`'s live
;;;      `kv-prefix-digest`, Stage-1 zero-token ORG AST repair, MINJA/MemoryGraft
;;;      quarantine, active-defeater L3 disclosure floor, and AuditCapsule.
;;;   2. Real `nono-sandbox-profile` blocks unendorsed Lethal-Trifecta while
;;;      admitting safe no-egress profiles.
;;;   3. Real Cedar `agentic-ai-lab-cedar-policy` produces inert Marlin handoff
;;;      (`runtime-executed?: #f`, zero in-process fallback).
;;;   4. Pure `plan-trunk-journal-handoff` emits inert `JournalHandoffIntent.`
;;;      without touching SQLite or filesystem I/O.

(import :std/test
        (only-in :clan/poo/object .o .ref)
        (only-in :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
                 nono-sandbox-profile)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-epistemic-consolidation
                 agentic-ai-lab-ai-agentic-context-memory-candidate)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/obligation-graph
                 make-obligation
                 make-evidence-fact
                 make-obligation-graph)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/delegation-fence
                 make-capability-envelope)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/journal-handoff
                 plan-trunk-journal-handoff
                 project-recovered-trunk-receipt)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/governed-context-bridge
                 make-graph-cedar-handoff
                 admit-graph-nono-sandbox
                 make-governed-context-trunk))

(export graph-engine-governed-context-bridge-test)

(def graph-engine-governed-context-bridge-test
  (test-suite "GraphEngine Pure Governed Context, Nono-Sandbox, Cedar & Marlin Journal Handoff"

    (test-case "real ai-agentic-context assembly drives Trunk kv-prefix, L3 defeater floor, MINJA quarantine & AuditCapsule"
      (let* ((mem-ok (agentic-ai-lab-ai-agentic-context-memory-candidate
                      "mem-verified-1" 'trusted-internal "sha256:clean-arch-note"))
             (mem-poison (agentic-ai-lab-ai-agentic-context-memory-candidate
                          "mem-minja-1" 'untrusted-ingest "sha256:poison-exfil"
                          self-claimed-success?: #t))
             (ob-defeated (make-obligation "ob-apex-1"
                                           required-evidence-ids: '("ev-1")
                                           active-defeaters: '("def-security-alert")))
             (g0 (make-obligation-graph "g-ctx-1"
                                        cut: 2
                                        obligations: (list ob-defeated)
                                        evidence: (list (make-evidence-fact "ev-1" 'observed cut: 2))))
             (env (make-capability-envelope "trunk-gov-1"
                                            allowed-caps: '(read-file)
                                            denied-caps: '(raw-bash-exec)))
             (cedar (make-graph-cedar-handoff
                     "pol-graph-trunk-1"
                     "permit(principal, action, resource);"
                     "trunk-gov-1"
                     bound-cut: 2))
             (sbx-ok (admit-graph-nono-sandbox
                      profile: nono-sandbox-profile
                      env-digest: "sha256:nono-env-v1"
                      has-untrusted-input?: #t
                      has-private-data?: #t
                      egress-endorsed?: #f))
             (bundle (make-governed-context-trunk
                      "trunk-gov-1"
                      "ob-apex-1"
                      g0
                      env
                      ;; Unclosed drawer -> repaired at 0 tokens by Stage-1 ORG AST repair!
                      "* TODO Investigate\n:PROPERTIES:\n:ID: node-1\n"
                      frozen-entries: (list (.o bind-these: #f
                                                epoch: 2
                                                node-id: "sys-root"
                                                content: "SYSTEM: Pure POO GraphEngine"))
                      memory-candidates: (list mem-ok mem-poison)
                      cedar-handoff: cedar
                      sandbox-admission: sbx-ok)))
        (check (.ref cedar 'policy-valid?) => #t)
        (check (.ref cedar 'runtime-executed?) => #f)
        (check (.ref sbx-ok 'admitted?) => #t)
        (check (.ref bundle 'admitted?) => #t)
        (check (.ref bundle 'runtime-executed?) => #f)
        ;; Active defeater forced full L3 unmasked disclosure floor!
        (check (.ref bundle 'effective-disclosure-depth) => 3)
        ;; MINJA quarantined candidate excluded before recall!
        (check (.ref bundle 'quarantined-excluded) => 1)
        ;; Trunk inherited exact Two-Zone frozen KV-Prefix digest!
        (check (equal? (.ref (.ref bundle 'trunk) 'kv-prefix-digest)
                       (.ref bundle 'kv-prefix-digest))
               => #t)
        ;; Pure Marlin journal handoff produces inert intent with ZERO SQLite I/O!
        (let* ((intent (plan-trunk-journal-handoff
                        "ev-handoff-1"
                        (.o bind-these: #f action: 'checkpoint)
                        (.ref bundle 'trunk)))
               (rec (project-recovered-trunk-receipt
                     (.ref intent 'inert-snapshot)
                     journal-epoch: 4
                     chain-head-hash: "sha256:test-head")))
          (check (.ref intent 'runtime-executed?) => #f)
          (check (length (.ref intent 'immutable-evidence-records)) => 1)
          (check (.ref rec 'recovered?) => #t)
          (check (.ref rec 'journal-epoch) => 4))))

    (test-case "nono-sandbox Lethal-Trifecta profile with unendorsed egress blocks governed trunk fail-closed"
      (let* ((egress-profile (.o (:: @ nono-sandbox-profile)
                                 egress-enabled?: #t))
             (sbx-bad (admit-graph-nono-sandbox
                       profile: egress-profile
                       env-digest: "sha256:nono-egress-v1"
                       has-untrusted-input?: #t
                       has-private-data?: #t
                       egress-endorsed?: #f))
             (g0 (make-obligation-graph "g-tri" cut: 1))
             (env (make-capability-envelope "trunk-tri" allowed-caps: '(read-file)))
             (bundle (make-governed-context-trunk
                      "trunk-tri" "ob-tri" g0 env "* TODO Check\n"
                      sandbox-admission: sbx-bad)))
        (check (.ref sbx-bad 'admitted?) => #f)
        (check (.ref bundle 'admitted?) => #f)
        (check (.ref (.ref bundle 'trunk) 'trunk-grant-live?) => #f)))))
