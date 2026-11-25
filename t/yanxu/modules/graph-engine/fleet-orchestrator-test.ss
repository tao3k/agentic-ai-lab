;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scheme Multi-Actor Fleet + Cold-Miss-to-Warm-Hit FunFlow CAS +
;;; Sibling Spawn + Blocker Isolation + Auto-Archive Workbench Projection Tests
;;; (`t/yanxu/modules/graph-engine/fleet-orchestrator-test.ss`).

(import :std/test
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/graph-engine/interface)

(export fleet-orchestrator-test)

(def (make-fleet-ctx)
  (.o bind-these: #f
      context-cut: 4
      kv-prefix-digest: "sha256:fleet-zone1-shared-prefix"
      disclosure-depth: 'L3
      has-active-defeater?: #f
      sandbox-admitted?: #t
      cedar-handoff-valid?: #t))

(def (make-in-memory-cas-pump cas-table)
  (lambda (effects)
    (map (lambda (eff)
           (let ((k (.ref eff 'kind))
                 (id (.ref eff 'effect-id)))
             (cond
              ((eq? k 'cas-get)
               (let ((hit (hash-get cas-table (.ref eff 'key))))
                 (if hit
                   (make-cas-hit-receipt id hit)
                   (make-cas-miss-receipt id))))
              ((eq? k 'cas-put)
               (hash-put! cas-table (.ref eff 'key) (.ref eff 'payload))
               (make-cas-stored-receipt id))
              ((eq? k 'llm-complete)
               (make-llm-completed-receipt id (string-append "fresh-llm:" id)))
              (else
               (make-effect-error-receipt id "unexpected effect")))))
         effects)))

(def fleet-orchestrator-test
  (test-suite "graph-engine-fleet-orchestrator"

    (test-case "Cold CAS miss triggers Two-Zone LLM fill + CasPut; second warm run hits CAS with 0 LLM calls"
      (let* ((cas-table (make-hash-table))
             (pump (make-in-memory-cas-pump cas-table))
             (env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '(host-egress) egress-allowed?: #f))
             (ob (make-obligation "ob-cold" title: "Cold Step" required-evidence-ids: '("ev-cold")))
             (det (make-deterministic-task-node
                   "det-cold-1" "ob-cold" "ev-cold" 'funflow-cold "in"
                   effect-class: 'pure-cas read-footprint: '("x.ss") write-footprint: '()))
             (g0 (make-obligation-graph "g-cold" cut: 4 obligations: (list ob) evidence: '() det-tasks: (list det)))
             (trunk (make-context-trunk "trunk-cold" "ob-cold" g0 env
                                        shared-context-cut: 4
                                        kv-prefix-digest: "sha256:fleet-zone1-shared-prefix"))
             (actor (graph-make-task-actor "task-cold-01" trunk '("scope-main") title: "Cold-to-Warm"))
             (st0 (make-unified-driver-state actor g0 (make-fleet-ctx)))
             ;; Run #1 (Cold CAS): cas-get -> cas-miss -> llm-complete -> cas-put -> quiescent!
             (cold-run (run-unified-driver-to-quiescence st0 pump))
             ;; Run #2 (Warm CAS on same fresh state): cas-get -> cas-hit -> quiescent with 0 LLM calls!
             (warm-run (run-unified-driver-to-quiescence st0 pump)))
        (check (.ref cold-run 'final-phase) => 'quiescent-fixed-point)
        (check (.ref cold-run 'total-llm-calls) => 1)
        (check (.ref cold-run 'cas-puts-count) => 1)
        (check (.ref cold-run 'cas-hits-count) => 0)
        (check (.ref warm-run 'final-phase) => 'quiescent-fixed-point)
        (check (.ref warm-run 'total-llm-calls) => 0)
        (check (.ref warm-run 'cas-hits-count) => 1)))

    (test-case "Multi-actor Fleet spawns sibling from detour, isolates blocker-active parent, auto-archives settled sibling, and projects read-only peek"
      (let* ((cas-table (make-hash-table))
             (pump (make-in-memory-cas-pump cas-table))
             (env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '(host-egress) egress-allowed?: #f))
             (ob-p (make-obligation "ob-p" title: "Parent" required-evidence-ids: '("ev-p")))
             (det-p (make-deterministic-task-node
                     "det-p" "ob-p" "ev-p" 'funflow-p "p"
                     effect-class: 'pure-cas read-footprint: '("p.ss") write-footprint: '()))
             (g-p (make-obligation-graph "g-p" cut: 4 obligations: (list ob-p) evidence: '() det-tasks: (list det-p)))
             (trunk-p (make-context-trunk "trunk-p" "ob-p" g-p env
                                          shared-context-cut: 4
                                          kv-prefix-digest: "sha256:fleet-zone1-shared-prefix"))
             (parent0 (graph-make-task-actor "task-parent" trunk-p '("scope-main") title: "Parent Mission"))
             ;; Enter side-quest detour on parent so we can exit via `spawn-sibling-task`
             (parent-sq (.ref (graph-enter-task-actor-detour parent0 'side-quest-active "sq-split") 'actor))
             (fleet0 (make-graph-fleet-state
                      (list (make-unified-driver-state parent-sq g-p (make-fleet-ctx)))
                      peek-set: '("task-sibling")))
             ;; Sibling obligation graph with 2 competing hypotheses & 1 branch
             (ob-s (make-obligation "ob-s" title: "Sibling" required-evidence-ids: '("ev-s")))
             (det-s (make-deterministic-task-node
                     "det-s" "ob-s" "ev-s" 'funflow-s "s"
                     effect-class: 'pure-cas read-footprint: '("s.ss") write-footprint: '()))
             (g-s (make-obligation-graph "g-s" cut: 4 obligations: (list ob-s) evidence: '() det-tasks: (list det-s)))
             (h1 (make-competing-hypothesis "H1" "Hypothesis A" contradictions: '("c1") open-questions: '("q1")))
             (h2 (make-competing-hypothesis "H2" "Hypothesis B" contradictions: '() open-questions: '("q2")))
             (b1 (make-hypothesis-branch-proposal "B1" "Probe artifact"))
             (fleet1 (fleet-spawn-sibling-from-detour
                      fleet0 "task-parent" "task-sibling" "Sibling Investigation" g-s
                      sibling-apex-id: "ob-s"
                      sibling-hypotheses: (list h1 h2)
                      sibling-branches: (list b1)))
             ;; Put parent back into `blocker-active` detour so parent stays active/halted while sibling settles & auto-archives!
             (p-st (car (.ref fleet1 'active-drivers)))
             (s-st (cadr (.ref fleet1 'active-drivers)))
             (p-blk (.ref (graph-enter-task-actor-detour (.ref p-st 'actor) 'blocker-active "blk-parent") 'actor))
             (fleet2 (make-graph-fleet-state
                      (list (make-unified-driver-state p-blk (.ref p-st 'obligation-graph) (.ref p-st 'governed-context))
                            s-st)
                      peek-set: '("task-sibling")))
             (run (run-graph-fleet-to-quiescence fleet2 pump auto-archive?: #t))
             (proj (project-fleet->workbench-projection run)))
        ;; Sibling inherited parent's frozen Zone-1 KV-Prefix digest!
        (check (.ref (.ref (.ref s-st 'actor) 'trunk) 'kv-prefix-digest) => "sha256:fleet-zone1-shared-prefix")
        ;; Parent remains active (halted on blocker-active), while Sibling settled and auto-archived!
        (check (.ref run 'active-task-ids) => '("task-parent"))
        (check (.ref run 'settled-task-ids) => '("task-sibling"))
        (check (.ref run 'authorizes-effect?) => #f)
        ;; WorkbenchTabProjection renders: pinned `index`, active `task-parent` (blocker-active), and read-only peek `task-sibling`!
        (check (.ref proj 'visible-tab-ids) => '(index "task-parent" "task-sibling"))
        (check (.ref (car (.ref proj 'dynamic-tabs)) 'detour-mode) => 'blocker-active)
        (check (.ref (cadr (.ref proj 'dynamic-tabs)) 'mode) => 'peek-readonly)
        (displayln "GRAPH-ENGINE-FLEET-ORCHESTRATOR-OK")))

    (test-case "Bounded Repair Cycle halts fail-closed on oscillation and budget exhaustion, entering blocker-active + human-inbox"
      (let* ((env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '(host-egress) egress-allowed?: #f))
             (ob (make-obligation "ob-fix" title: "Build Gate" required-evidence-ids: '("ev-build")))
             (sb-task (make-deterministic-task-node
                       "sb-build" "ob-fix" "ev-build" 'funflow-sb "cargo test"
                       effect-class: 'fenced-effect
                       read-footprint: '("src/") write-footprint: '()))
             (g0 (make-obligation-graph "g-fix" cut: 1 obligations: (list ob) evidence: '() det-tasks: (list sb-task)))
             (tr0 (make-context-trunk "tr-fix" "ob-fix" g0 env shared-context-cut: 1 kv-prefix-digest: "sha256:fix"))
             (actor0 (graph-make-task-actor "task-fix-01" tr0 '("scope-main") title: "Repair SCC"))
             (st0 (make-unified-driver-state actor0 g0 (make-fleet-ctx) repair-budget: 3))
             ;; Repeating identical stderr triggers immediate oscillation detection on attempt 2!
             (osc-pump (lambda (effs)
                         (map (lambda (e)
                                (make-sandbox-exited-receipt (.ref e 'effect-id) 1 "" stderr: "E0425: same error"))
                              effs)))
             (run-osc (run-unified-driver-to-quiescence st0 osc-pump max-rounds: 6))
             (proj-osc (project-driver-state->workbench-projection run-osc))
             (tab-osc (car (.ref proj-osc 'dynamic-tabs))))
        (check (.ref run-osc 'final-phase) => 'cycle-repair-halted-blocker)
        (check (.ref tab-osc 'detour-mode) => 'blocker-active)
        (check (length (.ref tab-osc 'human-inbox)) => 1)
        (check (.ref (car (.ref tab-osc 'human-inbox)) 'kind) => 'cycle-oscillation-detected)
        ;; Distinct failures exhaust repair-budget=2 cleanly into `cycle-budget-exhausted`!
        (let* ((counter 0)
               (st-b (make-unified-driver-state actor0 g0 (make-fleet-ctx) repair-budget: 2))
               (budget-pump (lambda (effs)
                              (set! counter (+ counter 1))
                              (map (lambda (e)
                                     (make-sandbox-exited-receipt
                                      (.ref e 'effect-id) 1 ""
                                      stderr: (string-append "err-distinct-" (number->string counter))))
                                   effs)))
               (run-b (run-unified-driver-to-quiescence st-b budget-pump max-rounds: 6))
               (tab-b (car (.ref (project-driver-state->workbench-projection run-b) 'dynamic-tabs))))
          (check (.ref run-b 'final-phase) => 'cycle-repair-halted-blocker)
          (check (.ref (car (.ref tab-b 'human-inbox)) 'kind) => 'cycle-budget-exhausted))))

    (test-case "Bitemporal defeater/human-approval events and Fleet CAS snapshot round-trip preserve exact state"
      (let* ((cas-table (make-hash-table))
             (pump (make-in-memory-cas-pump cas-table))
             (env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '(host-egress) egress-allowed?: #f))
             (ob (make-obligation "ob-bt" title: "Audit" required-evidence-ids: '("ev-bt")))
             (g0 (make-obligation-graph "g-bt" cut: 1 obligations: (list ob) evidence: '() det-tasks: '()))
             (tr0 (make-context-trunk "tr-bt" "ob-bt" g0 env shared-context-cut: 1 kv-prefix-digest: "sha256:bt-zone1"))
             (actor0 (graph-make-task-actor "task-bt-01" tr0 '("scope-main") title: "Bitemporal Actor"))
             (h1 (make-competing-hypothesis "H1" "Hypothesis 1" contradictions: '("c1") open-questions: '("q1")))
             (fl0 (make-graph-fleet-state
                   (list (make-unified-driver-state
                          actor0 g0 (make-fleet-ctx)
                          competing-hypotheses: (list h1)))))
             ;; 1. Inject `defeater-discovered` -> auto blocker-active + L3 disclosure + human-inbox entry!
             (def-ev (.o bind-these: #f
                         event-kind: 'defeater-discovered
                         obligation-id: "ob-bt"
                         defeater-id: "def-cve-99"))
             (fl-def (fleet-apply-bitemporal-event fl0 "task-bt-01" def-ev))
             (st-def (car (.ref fl-def 'active-drivers)))
             ;; 2. Checkpoint entire Fleet via canonical `CasPutEffect.`, then restore via `cas-hit`!
             (put-eff (plan-fleet-cas-checkpoint fl-def "fleet:checkpoint:bt"))
             (_stored (pump (list put-eff)))
             (get-rcpt (car (pump (list (make-cas-get-effect "get-fl" "fleet:checkpoint:bt")))))
             (fl-restored (restore-fleet-from-cas-receipt get-rcpt))
             (proj-restored (project-fleet->workbench-projection fl-restored))
             (tab-restored (car (.ref proj-restored 'dynamic-tabs)))
             ;; 3. Inject `human-approved` resolving defeater -> exits blocker-active back to mainline!
             (ok-ev (.o bind-these: #f
                        event-kind: 'human-approved
                        resolve-defeater-id: "def-cve-99"))
             (fl-ok (fleet-apply-bitemporal-event fl-restored "task-bt-01" ok-ev))
             (st-ok (car (.ref fl-ok 'active-drivers))))
        (check (.ref (.ref st-def 'actor) 'detour-mode) => 'blocker-active)
        (check (.ref (.ref st-def 'governed-context) 'disclosure-depth) => 'L3)
        (check (.ref (.ref st-def 'governed-context) 'has-active-defeater?) => #t)
        ;; Checkpoint payload is a real pure UTF-8 wire string (zero Gambit heap pointers!)
        (check (string? (.ref put-eff 'payload)) => #t)
        ;; Restored Fleet preserves blocker-active, active defeater, human-inbox, and competing hypotheses!
        (check (.ref tab-restored 'detour-mode) => 'blocker-active)
        (check (.ref tab-restored 'active-defeaters-count) => 1)
        (check (length (.ref tab-restored 'human-inbox)) => 1)
        (check (length (.ref tab-restored 'competing-hypotheses)) => 1)
        ;; Human approval exits blocker-active back to mainline cleanly!
        (check (.ref (.ref st-ok 'actor) 'detour-mode) => 'mainline)
        (displayln "GRAPH-ENGINE-BITEMPORAL-REPAIR-CAS-OK")))

    (test-case "Round S8: Bounded hypothesis branch proposal re-evaluates full HxB matrix without re-running CAS and shared defeater propagation isolates unrelated actors"
      (let* ((cas-table (make-hash-table))
             (pump (make-in-memory-cas-pump cas-table))
             (env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '(host-egress) egress-allowed?: #f))
             ;; Actor A watches shared premise "prem-cert-chain" with 2 competing hypotheses and 1 initial branch
             (ob-a (make-obligation "ob-a" title: "Verify Cert Chain" required-evidence-ids: '("ev-a") premise-ids: '("prem-cert-chain")))
             (det-a (make-deterministic-task-node "det-a" "ob-a" "ev-a" 'f-a "a" effect-class: 'pure-cas read-footprint: '("a") write-footprint: '()))
             (g-a (make-obligation-graph "g-a" cut: 1 obligations: (list ob-a) evidence: '() det-tasks: (list det-a)))
             (tr-a (make-context-trunk "tr-a" "ob-a" g-a env shared-context-cut: 1 kv-prefix-digest: "sha256:s8-zone1"))
             (act-a (graph-make-task-actor "task-s8-a" tr-a '("scope-main") title: "Cert Audit"))
             (h1 (make-competing-hypothesis "H1" "Compromised intermediate CA" evidence-lineage: '("ev:crl") contradictions: '("ocsp-valid") open-questions: '("hsm-log?")))
             (h2 (make-competing-hypothesis "H2" "Clock skew on verifier" evidence-lineage: '("ev:ntp") contradictions: '() open-questions: '("chrony-drift?")))
             (b1 (make-hypothesis-branch-proposal "B1" "Inspect OCSP stapling"))
             ;; Actor B also watches "prem-cert-chain"
             (ob-b (make-obligation "ob-b" title: "Dependent Release" required-evidence-ids: '("ev-b") premise-ids: '("prem-cert-chain")))
             (g-b (make-obligation-graph "g-b" cut: 1 obligations: (list ob-b) evidence: '() det-tasks: '()))
             (tr-b (make-context-trunk "tr-b" "ob-b" g-b env shared-context-cut: 1 kv-prefix-digest: "sha256:s8-zone1"))
             (act-b (graph-make-task-actor "task-s8-b" tr-b '("scope-main") title: "Release Gate"))
             ;; Actor C is completely independent (does NOT watch "prem-cert-chain")
             (ob-c (make-obligation "ob-c" title: "Unrelated Docs" required-evidence-ids: '("ev-c") premise-ids: '("prem-docs")))
             (g-c (make-obligation-graph "g-c" cut: 1 obligations: (list ob-c) evidence: '() det-tasks: '()))
             (tr-c (make-context-trunk "tr-c" "ob-c" g-c env shared-context-cut: 1 kv-prefix-digest: "sha256:s8-zone1"))
             (act-c (graph-make-task-actor "task-s8-c" tr-c '("scope-main") title: "Docs Cleanup"))
             (fl0 (make-graph-fleet-state
                   (list (make-unified-driver-state act-a g-a (make-fleet-ctx)
                                                    competing-hypotheses: (list h1 h2)
                                                    branch-proposals: (list b1))
                         (make-unified-driver-state act-b g-b (make-fleet-ctx))
                         (make-unified-driver-state act-c g-c (make-fleet-ctx)))))
             ;; Run #1 to quiescence without auto-archiving: det-a (1 cold LLM + 1 CAS put) + HxB1 (2 LLM)
             (run1 (run-graph-fleet-to-quiescence fl0 pump auto-archive?: #f))
             (fl1 (.ref run1 'final-fleet))
             (m1 (.ref (car (.ref fl1 'active-drivers)) 'hypothesis-matrix))
             ;; Propose bounded branch B2 on task-s8-a -> resets ONLY hypothesis-matrix (NOT det-a!)
             (b2 (make-hypothesis-branch-proposal "B2" "Cross-check offline HSM signature log"))
             (fl2 (fleet-propose-hypothesis-branch fl1 "task-s8-a" b2 max-branches: 4))
             ;; Run #2 to quiescence: ZERO deterministic re-execution, full 2x2=4 HxB evaluation!
             (run2 (run-graph-fleet-to-quiescence fl2 pump auto-archive?: #f))
             (fl3 (.ref run2 'final-fleet))
             (m2 (.ref (car (.ref fl3 'active-drivers)) 'hypothesis-matrix))
             ;; Propagate shared defeater on "prem-cert-chain" -> blocks A and B, leaves C untouched in mainline!
             (fl4 (fleet-propagate-shared-defeater fl3 "def-cert-revoked" "prem-cert-chain"))
             (da (car (.ref fl4 'active-drivers)))
             (db (cadr (.ref fl4 'active-drivers)))
             (dc (caddr (.ref fl4 'active-drivers))))
        ;; Run #1 produced 2x1=2 non-authorizing cells
        (check (length (.ref m1 'cells)) => 2)
        (check (.ref m1 'favored-path-collapsed?) => #f)
        (check (.ref m1 'authorizes-effect?) => #f)
        (check (.ref m1 'authenticates-evidence?) => #f)
        ;; Run #2 evaluated full 2x2=4 cells with 0 CAS puts (det-a was preserved!)
        (check (.ref run2 'total-llm-calls) => 4)
        (check (.ref run2 'total-cas-puts) => 0)
        (check (length (.ref m2 'cells)) => 4)
        (check (.ref m2 'preserved-hypothesis-count) => 2)
        (check (.ref m2 'missing-claim-likelihood-inferred?) => #f)
        (check (.ref m2 'establishes-attribution?) => #f)
        ;; Bounded branch limit enforced fail-closed
        (check-exception (fleet-propose-hypothesis-branch fl3 "task-s8-a"
                           (make-hypothesis-branch-proposal "B3" "Overflow") max-branches: 2)
                         error-object?)
        ;; Shared defeater propagation blocked A & B (blocker-active + L3 + human-inbox), leaving C in mainline!
        (check (.ref (.ref da 'actor) 'detour-mode) => 'blocker-active)
        (check (.ref (.ref db 'actor) 'detour-mode) => 'blocker-active)
        (check (.ref (.ref dc 'actor) 'detour-mode) => 'mainline)
        (check (length (.ref (.ref da 'obligation-graph) 'human-inbox)) => 1)
        (check (length (.ref (.ref db 'obligation-graph) 'human-inbox)) => 1)
        (check (length (.ref (.ref dc 'obligation-graph) 'human-inbox)) => 0)
        (displayln "GRAPH-ENGINE-S8-HYPOTHESIS-BRANCH-DEFEATER-PROPAGATION-OK")))))
