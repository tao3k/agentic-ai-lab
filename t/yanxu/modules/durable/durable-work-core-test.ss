;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Durable Work Engine Core Test Suite:
;;; Verifies the entire domain-agnostic Durable Work engine with ZERO orgize,
;;; ZERO ai-agentic-context, and ZERO .org strings.

(import :std/test
        (only-in :std/io/tempfile make-temporary-file-name)
        (only-in :clan/poo/object .def .o .ref object?)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-open journal-close! journal-get)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 PureCAS. VerifiedEpistemic. FencedEffect.
                 funflow-dag-node
                 funflow-admit-node-effect
                 DurableGovernedStrategy.)
        (only-in :tao3k/agentic-ai-lab/modules/durable/work
                 DurableWorkPolicy.
                 make-checked-work-policy
                 make-checked-work-snapshot
                 RepoNode. WorktreeNode. TaskNode.
                 BlockerDetourNode. SideQuestDetourNode.
                 CompletedExit. ParkedExit. CancelledExit. PromotedToTaskExit.
                 MainlineStepAnchor.
                 durable-reconcile-detour-exit
                 work-apply-overlay
                 work-reanchor-mainline
                 work-assert-write-owner
                 work-claim!
                 work-extend!
                 work-handover!
                 work-orchestration-plan
                 project-workbench-tabs
                 durable-work-record-cas!
                 durable-work-commit-archive!
                 durable-work-reopen!
                 durable-work-recover))

(export durable-work-core-test)

(.def (PureRepo. @ RepoNode.)
  repo-id: "pure-work-repo"
  policy: (make-checked-work-policy max-concurrency: 2 require-sod-reviewer: #f))

(.def (PureWorktree. @ [PureRepo. WorktreeNode.])
  worktree: "wt/pure"
  branch: "main"
  source-cut: "cut-pure-1")

(.def (PureTask. @ [PureWorktree. TaskNode.])
  task-id: "work-01"
  strategy: DurableGovernedStrategy.)

(def durable-work-core-test
  (test-suite "Pure Durable Work Engine Core (Zero Org / Zero Context)"

    (test-case "Pure WorkSnapshot scheduling, CAS recovery, atomic archive, and reopen without any Org text"
      (let* ((jpath (string-append (make-temporary-file-name "pure-durable-work-") ".sqlite"))
             (journal (journal-open jpath))
             (n1 (funflow-dag-node 'build effect-class: PureCAS. status: 'done source-cut: "cut-pure-1"))
             (n2 (funflow-dag-node 'test needs: '(build) effect-class: PureCAS. status: 'todo source-cut: "cut-pure-1"))
             (snap-active (make-checked-work-snapshot
                           task-id: "work-01" root-id: "work-01" root-title: "Pure Build"
                           root-status: 'in-progress checklist-done: 1 checklist-total: 2
                           dag-nodes: (list n1 n2) mainline-done: 1 mainline-total: 2))
             (n2-done (funflow-dag-node 'test needs: '(build) effect-class: PureCAS. status: 'done source-cut: "cut-pure-1"))
             (snap-done (make-checked-work-snapshot
                         task-id: "work-01" root-id: "work-01" root-title: "Pure Build"
                         root-status: 'done checklist-done: 2 checklist-total: 2
                         dag-nodes: (list n1 n2-done) mainline-done: 2 mainline-total: 2))
             (snap-blocked (make-checked-work-snapshot
                            task-id: "work-01" root-id: "work-01" root-title: "Pure Build"
                            root-status: 'done checklist-done: 2 checklist-total: 2
                            dag-nodes: (list n1 n2-done)
                            open-blocker-detours: '("detour-1"))))
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            (let* ((plan1 (work-orchestration-plan PureTask. snap-active (.o)))
                   (fps (.ref (.ref (.ref plan1 'dag-projection) 'dag) 'fingerprint-table)))
              (check-equal? (.ref plan1 'ready-to-schedule) '(test))
              (check-equal? (.ref plan1 'ready-to-auto-archive?) #f)
              ;; Open blocker detour prevents Auto-Archive even when root/checklist are done
              (let ((plan-blocked (work-orchestration-plan PureTask. snap-blocked (.o))))
                (check-equal? (.ref plan-blocked 'ready-to-auto-archive?) #f))
              ;; Record CAS for 'test, then recover -> 'test is skipped from CAS
              (durable-work-record-cas! journal "work-01" 'test (hash-ref fps 'test) "sha256:test-ok")
              (let ((rec (durable-work-recover journal PureTask. snap-active)))
                (check-equal? (.ref rec 'completed-cas-count) 1)
                (check-equal? (.ref (.ref (.ref rec 'plan) 'resume-plan) 'skipped-nodes) '(test)))
              ;; Atomic Auto-Archive + Reopen on pure WorkSnapshot
              (let ((arch (durable-work-commit-archive! journal PureTask. snap-done (.o) "2026-11-24 Tue 13:00")))
                (check-equal? (.ref arch 'committed?) #t)
                (check-equal? (object? (journal-get journal "orchestrator:archive:work-01")) #t))
              (let ((reop (durable-work-reopen! journal PureTask. snap-done "2026-11-24 Tue 13:05")))
                (check-equal? (.ref reop 'reopened?) #t)
                (check-equal? (object? (journal-get journal "orchestrator:reopen:work-01")) #t))))
          (lambda ()
            (journal-close! journal)
            (when (file-exists? jpath) (delete-file jpath))))))

    (test-case "Pure ClaimTable ownership, Extend-Never-Overwrite, heartbeat takeover, and CLOS detour reconciliation"
      (let* ((jpath (string-append (make-temporary-file-name "pure-claims-") ".sqlite"))
             (journal (journal-open jpath)))
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            (let* ((c1 (work-claim! journal "work-01" '() "step-a" "agent:alpha" now: 10 ttl: 20))
                   (claims1 (.ref c1 'next-claims))
                   (deny (work-assert-write-owner claims1 "step-a" "agent:beta"))
                   (ext (work-extend! journal "work-01" claims1 "step-a" "step-a-ext" "human:guangtao" now: 15))
                   (claims2 (.ref ext 'next-claims))
                   (early (work-handover! journal "work-01" claims2 "step-a" "agent:beta" now: 20 custody-oid: "custody:1"))
                   (expired (work-handover! journal "work-01" claims2 "step-a" "agent:beta" now: 35 custody-oid: "custody:1"))
                   (detour (.o (:: @ BlockerDetourNode.) bind-these: #f return-anchor: "step-a"))
                   (anchor (.o (:: @ MainlineStepAnchor.) bind-these: #f anchor-id: "step-a" mainline-counterexample-core: '("c1")))
                   (cancelled (durable-reconcile-detour-exit detour
                                (.o (:: @ CancelledExit.) bind-these: #f defeat-conditions: '("c2"))
                                anchor)))
              (check-equal? (.ref c1 'claimed?) #t)
              (check-equal? (.ref deny 'admitted?) #f)
              (check-equal? (.ref deny 'reason) 'non-owner-overwrite-forbidden)
              (check-equal? (.ref ext 'extended?) #t)
              (check-equal? (length claims2) 2)
              (check-equal? (.ref early 'handed-over?) #f)
              (check-equal? (.ref early 'reason) 'active-lease-not-expired)
              (check-equal? (.ref expired 'handed-over?) #t)
               (check-equal? (.ref expired 'claim-lease-epoch) 2)
               (check-equal? (.ref cancelled 'admitted?) #t)
               (check-equal? (length (.ref cancelled 'next-counterexample-core)) 2)))
           (lambda ()
             (journal-close! journal)
             (when (file-exists? jpath) (delete-file jpath))))))

    (test-case "Slice 54 regressions: BUG-D1 monotonic overlay, BUG-D2 tainted CompletedExit, BUG-D3 authorized handover/CAS, BUG-D4 unclosed-attempt archive block"
      (let* ((jpath (string-append (make-temporary-file-name "slice54-durable-") ".sqlite"))
             (journal (journal-open jpath)))
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            ;; BUG-D1: hot overlay CANNOT escalate parent max-concurrency/retry-budget/max-detour-depth/drill-down
            (let* ((strict-task (.o (:: @ PureTask.)
                                    bind-these: #f
                                    policy: (make-checked-work-policy max-concurrency: 2 retry-budget: 1
                                                                      max-detour-depth: 1 allow-agent-drill-down: #f)))
                   (escalating-ov (.o bind-these: #f max-parallel: 10 retry-budget: 9
                                      max-detour-depth: 8 allow-agent-drill-down: #t))
                   (narrowed-ov (.o bind-these: #f max-parallel: 1 retry-budget: 1 max-detour-depth: 1))
                   (res-esc (work-apply-overlay strict-task escalating-ov))
                   (res-nar (work-apply-overlay strict-task narrowed-ov))
                   (pol-esc (.ref res-esc 'policy))
                   (pol-nar (.ref res-nar 'policy)))
              (check-equal? (.ref pol-esc 'max-concurrency) 2)
              (check-equal? (.ref pol-esc 'retry-budget) 1)
              (check-equal? (.ref pol-esc 'max-detour-depth) 1)
              (check-equal? (.ref pol-esc 'allow-agent-drill-down) #f)
              (check-equal? (.ref pol-nar 'max-concurrency) 1))
            ;; BUG-D2: tainted detour CompletedExit refuses unattested merge, admits with schema-attested? or 3-party cert
            (let* ((tainted-detour (.o (:: @ BlockerDetourNode.) bind-these: #f return-anchor: "step-a" tainted?: #t))
                   (anchor (.o (:: @ MainlineStepAnchor.) bind-these: #f anchor-id: "step-a"))
                   (r-deny (durable-reconcile-detour-exit tainted-detour
                             (.o (:: @ CompletedExit.) bind-these: #f outcome-receipt-digest: "sha256:raw-tainted")
                             anchor))
                   (r-schema (durable-reconcile-detour-exit tainted-detour
                               (.o (:: @ CompletedExit.) bind-these: #f outcome-receipt-digest: "sha256:attested" schema-attested?: #t)
                               anchor))
                   (r-self-cert (durable-reconcile-detour-exit tainted-detour
                                  (.o (:: @ CompletedExit.) bind-these: #f outcome-receipt-digest: "sha256:bad-cert"
                                      declassification-cert: (.o bind-these: #f proposer: "a" declassifier: "a" recipient: "b"))
                                  anchor))
                   (r-cert (durable-reconcile-detour-exit tainted-detour
                             (.o (:: @ CompletedExit.) bind-these: #f outcome-receipt-digest: "sha256:good-cert"
                                 declassification-cert: (.o bind-these: #f proposer: "a" declassifier: "rev" recipient: "b"))
                             anchor)))
              (check-equal? (.ref r-deny 'admitted?) #f)
              (check-equal? (.ref r-deny 'reason) 'tainted-detour-requires-attestation-or-declassification)
              (check-equal? (.ref r-schema 'admitted?) #t)
              (check-equal? (.ref r-self-cert 'admitted?) #f)
              (check-equal? (.ref r-cert 'admitted?) #t))
            ;; BUG-D3: force-explicit?: #t requires non-self endorsement; expected-epoch rejects ABA; expired owner fails check
            (let* ((c1 (work-claim! journal "work-54" '() "step-a" "agent:alpha" now: 10 ttl: 20))
                   (claims1 (.ref c1 'next-claims))
                   (hijack (work-handover! journal "work-54" claims1 "step-a" "agent:beta"
                                           now: 15 force-explicit?: #t custody-oid: "custody:1"))
                   (self-end (work-handover! journal "work-54" claims1 "step-a" "agent:beta"
                                             now: 15 force-explicit?: #t endorsed-by: "agent:beta" custody-oid: "custody:1"))
                   (stale-cas (work-handover! journal "work-54" claims1 "step-a" "agent:beta"
                                              now: 15 force-explicit?: #t endorsed-by: "human:rev"
                                              expected-epoch: 99 custody-oid: "custody:1"))
                   (good-ho (work-handover! journal "work-54" claims1 "step-a" "agent:beta"
                                            now: 15 force-explicit?: #t endorsed-by: "human:rev"
                                            expected-epoch: 1 custody-oid: "custody:1"))
                   (expired-owner (work-assert-write-owner claims1 "step-a" "agent:alpha" now: 35))
                   (stale-write (work-assert-write-owner claims1 "step-a" "agent:alpha" expected-epoch: 2)))
              (check-equal? (.ref hijack 'handed-over?) #f)
              (check-equal? (.ref hijack 'reason) 'explicit-early-handover-requires-non-self-endorsement)
              (check-equal? (.ref self-end 'handed-over?) #f)
              (check-equal? (.ref stale-cas 'handed-over?) #f)
              (check-equal? (.ref stale-cas 'reason) 'stale-lease-epoch-cas-mismatch)
              (check-equal? (.ref good-ho 'handed-over?) #t)
              (check-equal? (.ref good-ho 'claim-lease-epoch) 2)
              (check-equal? (.ref expired-owner 'admitted?) #f)
              (check-equal? (.ref expired-owner 'reason) 'active-lease-expired)
              (check-equal? (.ref stale-write 'admitted?) #f)
              (check-equal? (.ref stale-write 'reason) 'stale-lease-epoch-cas-mismatch))
            ;; BUG-D4: unclosed-attempts MUST block ready-to-auto-archive even when in-flight & pending-effects are empty
            (let* ((n1 (funflow-dag-node 'build effect-class: PureCAS. status: 'done source-cut: "cut-54"))
                   (snap-done (make-checked-work-snapshot
                               task-id: "work-54" root-id: "work-54" root-title: "Crash Quiescence"
                               root-status: 'done checklist-done: 1 checklist-total: 1
                               dag-nodes: (list n1) mainline-done: 1 mainline-total: 1))
                   (plan-unclosed (work-orchestration-plan PureTask. snap-done (.o unclosed-attempts: '("att-crashed-1"))))
                   (arch-denied (durable-work-commit-archive! journal PureTask. snap-done
                                                              (.o unclosed-attempts: '("att-crashed-1"))
                                                              "2026-11-24 Tue 14:00"))
                   (reopen-never-arch (durable-work-reopen! journal PureTask. snap-done "2026-11-24 Tue 14:05")))
              (check-equal? (.ref plan-unclosed 'needs-recovery) '("att-crashed-1"))
              (check-equal? (.ref plan-unclosed 'ready-to-auto-archive?) #f)
              (check-equal? (.ref arch-denied 'committed?) #f)
              (check-equal? (.ref reopen-never-arch 'reopened?) #f)
              (check-equal? (.ref reopen-never-arch 'reason) 'task-not-archived)))
          (lambda ()
            (journal-close! journal)
            (when (file-exists? jpath) (delete-file jpath))))))))
