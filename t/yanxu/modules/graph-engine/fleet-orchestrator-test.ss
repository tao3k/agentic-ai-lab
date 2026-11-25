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
        ;; Restored Fleet preserves blocker-active, active defeater, human-inbox, and competing hypotheses!
        (check (.ref tab-restored 'detour-mode) => 'blocker-active)
        (check (.ref tab-restored 'active-defeaters-count) => 1)
        (check (length (.ref tab-restored 'human-inbox)) => 1)
        (check (length (.ref tab-restored 'competing-hypotheses)) => 1)
        ;; Human approval exits blocker-active back to mainline cleanly!
        (check (.ref (.ref st-ok 'actor) 'detour-mode) => 'mainline)
        (displayln "GRAPH-ENGINE-BITEMPORAL-REPAIR-CAS-OK")))))
