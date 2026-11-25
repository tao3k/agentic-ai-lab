;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Session-Free TaskActor, C4 Mid-Flight Steering (A->B->C->D->{D1,D2}->F->G->Apex),
;;; Dual Scope ('project / 'detached), Open-Focus Promotion & All-Terminal Index Tests
;;; (`t/yanxu/modules/graph-engine/task-actor-test.ss`).

(import :std/test
        (only-in :clan/poo/object .ref .slot?)
        :tao3k/agentic-ai-lab/modules/graph-engine/interface)

(export task-actor-test)

(def (make-sample-trunk trunk-id apex-id)
  (let* ((env (make-capability-envelope
               "actor-owner"
               allowed-caps: '(context-read repo-scan verify-build)
               denied-caps: '(host-egress shell-exec)
               egress-allowed?: #f))
         (ob-a (make-obligation "ob-a"
                                title: "Collect Context"
                                required-evidence-ids: '("ev-a")))
         (ob-apex (make-obligation apex-id
                                   title: "Converge Mission"
                                   required-evidence-ids: '("ev-a")
                                   depends-on: '("ob-a")))
         (g (make-obligation-graph
             (string-append "g-" trunk-id)
             cut: 1
             obligations: (list ob-a ob-apex)
             evidence: '()
             det-tasks: '())))
    (make-context-trunk trunk-id apex-id g env
                        shared-context-cut: 1
                        kv-prefix-digest: "sha256:shared-structural-kv-prefix")))

(def (converge-sample-trunk trunk)
  (let* ((sp (spawn-trunk-branch
              trunk "br-1" 'context-enrichment-detour
              '(context-read) "ob-a"
              c4-priority: 1 required-for-apex?: #t))
         (t1 (.ref sp 'trunk))
         (br (.ref sp 'branch))
         (ev (make-evidence-fact "ev-a" "scope-context-fact" cut: 1))
         (contrib (make-branch-contribution
                   br
                   exit-kind: 'completed
                   evidence-facts: (list ev)
                   completed-task-ids: '("det-scan-1")
                   summary: "context enriched"))
         (ab (absorb-branch-contribution t1 contrib))
         (t2 (.ref ab 'trunk))
         (cv (converge-trunk-to-apex t2)))
    (.ref cv 'trunk)))

(def task-actor-test
  (test-suite "Session-free TaskActor, C4 Mid-Flight Steering & All-Terminal Index Settlement"

    (test-case "Open-focus exploration promotes to Convergent TaskActor; Detached scope stays isolated"
      (let* ((env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '()))
             (focus (make-open-focus-actor "focus-1" '(scope/workspace) env title: "Explore Design"))
             (detached (make-open-focus-actor "adhoc-1" '(scope/detached) env
                                              title: "Unrelated Question"
                                              scope-mode: 'detached))
             (trunk (make-sample-trunk "trunk-p" "ob-apex"))
             (promoted (promote-focus->task-actor focus trunk))
             (idx0 (make-task-actor-index))
             (det-settled (settle-task-actor detached idx0 outcome: 'cancelled reason-note: "done")))
        (check (.ref focus 'actor-kind) => 'open-focus)
        (check (.ref focus 'session-free?) => #t)
        (check (.ref focus 'llm-sessions-spawned) => 0)
        (check (.ref promoted 'actor-kind) => 'convergent-task)
        (check (.ref promoted 'fencing-epoch) => 2)
        (check (.ref promoted 'trunk-id) => "trunk-p")
        ;; Detached actor settles cleanly WITHOUT polluting the project Index!
        (check (.ref det-settled 'settled?) => #t)
        (check (.ref det-settled 'reason) => 'settled-detached-no-project-pollution)
        (check (length (.ref (.ref det-settled 'index) 'entries)) => 0)))

    (test-case "C4 mid-flight steering: D -> {D1, D2} branches must re-converge at join node F before F->G->Apex"
      (let* ((trunk (make-sample-trunk "trunk-steer" "ob-apex"))
             (a0 (make-task-actor "task-dfg" trunk '(scope/core) title: "Main Trunk A->D->F->G"))
             (msg-d1 (make-steering-message
                      "steer-1" 'branch "Checklist task D1"
                      c4-priority: 1
                      anchor-node-id: "D"
                      join-node-id: "F"
                      branch-id: "D1"
                      branch-kind: 'subordinate-task
                      requested-caps: '(context-read)
                      target-obligation-id: "ob-a"))
             (msg-d2 (make-steering-message
                      "steer-2" 'branch "Checklist task D2"
                      c4-priority: 2
                      anchor-node-id: "D"
                      join-node-id: "F"
                      branch-id: "D2"
                      branch-kind: 'subordinate-task
                      requested-caps: '(context-read)
                      target-obligation-id: "ob-a"))
             (r1 (steer-task-actor a0 msg-d1))
             (a1 (.ref r1 'actor))
             (r2 (steer-task-actor a1 msg-d2))
             (a2 (.ref r2 'actor))
             (gate-while-running (can-continue-trunk-at-join? a2 "F"))
             ;; D1 completes, D2 hits a defeater -> continuation at F MUST stay blocked!
             (a3 (complete-anchored-branch a2 "D1" outcome: 'completed))
             (a3-defeated (complete-anchored-branch a3 "D2" outcome: 'defeated))
             (gate-defeated (can-continue-trunk-at-join? a3-defeated "F"))
             ;; When both D1 and D2 complete -> F->G->Apex continuation opens!
             (a4 (complete-anchored-branch a3 "D2" outcome: 'completed))
             (gate-ready (can-continue-trunk-at-join? a4 "F")))
        (check (.ref r1 'admitted?) => #t)
        (check (.ref r2 'admitted?) => #t)
        (check (.ref gate-while-running 'can-continue?) => #f)
        (check (.ref gate-while-running 'reason) => 'required-branches-still-in-flight)
        (check (.ref gate-defeated 'can-continue?) => #f)
        (check (.ref gate-defeated 'reason) => 'required-branch-failed-or-defeated)
        (check (.ref gate-defeated 'blocking-branch-ids) => '("D2"))
        (check (.ref gate-ready 'can-continue?) => #t)
        (check (.ref gate-ready 'reason) => 'all-required-branches-converged)
        ;; Steering the Main Trunk directly bumps fencing-epoch and supersedes stale in-flight branches!
        (let* ((msg-trunk (make-steering-message
                           "steer-trunk-override" 'trunk "Pivot trunk direction"
                           c4-priority: 0
                           supersede-stale-branches?: #t))
               (rt (steer-task-actor a2 msg-trunk))
               (a-pivoted (.ref rt 'actor))
               (gate-after-pivot (can-continue-trunk-at-join? a-pivoted "F")))
          (check (.ref rt 'admitted?) => #t)
          (check (.ref rt 'route) => 'trunk)
          (check (.ref a-pivoted 'fencing-epoch) => 2)
          (check (.ref gate-after-pivot 'can-continue?) => #t))))

    (test-case "All-terminal settlement (converged, cancelled, failed) populates Index by ID and peek-readonly Tab"
      (let* ((t-ok (converge-sample-trunk (make-sample-trunk "t-ok" "ob-apex-1")))
             (t-fail (make-sample-trunk "t-fail" "ob-apex-2"))
             (t-act (make-sample-trunk "t-act" "ob-apex-3"))
             (a-ok (make-task-actor "task-ok" t-ok '(scope/core) title: "Converged Task"))
             (a-fail (make-task-actor "task-fail" t-fail '(scope/core) title: "Failed Task"))
             (a-act (make-task-actor "task-act" t-act '(scope/ui) title: "Active Task"))
             (idx0 (make-task-actor-index))
             ;; Unconverged trunk refuses `'converged` outcome, but ALLOWS `'failed` / `'cancelled` for ID audit!
             (refused (settle-task-actor a-fail idx0 outcome: 'converged))
             (s-fail (settle-task-actor a-fail idx0 outcome: 'failed reason-note: "compile error"))
             (s-ok (settle-task-actor a-ok (.ref s-fail 'index) outcome: 'converged journal-epoch: 4))
             (idx2 (.ref s-ok 'index))
             (hit-fail (lookup-task-actor-by-id idx2 "task-fail"))
             (hit-ok (lookup-task-actor-by-id idx2 "task-ok"))
             (proj (project-task-actors->workbench-tabs
                    (list a-act (.ref s-fail 'actor) (.ref s-ok 'actor))
                    idx2
                    peek-set: '("task-fail"))))
        (check (.ref refused 'settled?) => #f)
        (check (.ref refused 'reason) => 'trunk-not-converged)
        (check (.ref s-fail 'settled?) => #t)
        (check (.ref s-ok 'settled?) => #t)
        (check (.ref (.ref s-ok 'handoff-intent) 'runtime-executed?) => #f)
        (check (.ref hit-fail 'found?) => #t)
        (check (.ref (.ref hit-fail 'entry) 'outcome) => 'failed)
        (check (.ref hit-fail 'actors-spawned) => 0)
        (check (.ref hit-ok 'found?) => #t)
        (check (.ref (.ref hit-ok 'entry) 'outcome) => 'converged)
        (check (.ref proj 'session-free?) => #t)
        (check (.ref proj 'visible-tab-ids) => '(index "task-act" "task-fail"))
        (let ((peek-tab (cadr (.ref proj 'dynamic-tabs))))
          (check (.ref peek-tab 'id) => "task-fail")
          (check (.ref peek-tab 'mode) => 'peek-readonly)
          (check (.ref peek-tab 'outcome) => 'failed))
        (displayln "GRAPH-ENGINE-SESSION-FREE-TASK-ACTOR-OK")))))
