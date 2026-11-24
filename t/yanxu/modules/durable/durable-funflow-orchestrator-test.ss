;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Regression suite for:
;;; - gerbil-poo C4 linearization (Repo A -> Worktree B -> Task C -> SubTask/Extension D)
;;; - Doom-Emacs-style compile-time hygienic declaration macros
;;; - Tweag-inspired FunFlow CAS DAG, SCC cycle check, epoch-bounded dynamic replanning
;;; - Governance scope/SoD admission and disjoint-span parallel frontier waves
;;; - Lab Durable journal-backed CAS resume, atomic Auto-Archive, Plan-A index.org sync
;;; - Pure functional Task-as-Tab WorkbenchTabProjection (pinned Index + auto-hide + peek/reopen)

(import :std/test
        (only-in :std/io/tempfile make-temporary-file-name)
        (only-in :std/string/misc string-contains)
        (only-in :clan/poo/object .o .ref .def)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-open journal-close! journal-get)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 FunflowNode.
                 EffectClass.
                 PureCAS.
                 VerifiedEpistemic.
                 FencedEffect.
                 funflow-admit-node-effect
                 funflow-envelope-meet
                 WorkspaceTopology.
                 funflow-workspace-plan
                 funflow-invalidate-premises
                 OrchestratorStrategy.
                 ParallelFrontierStrategy.
                 TieredModelStrategy.
                 DurableGovernedStrategy.
                 strategy-admit-node
                 funflow-dag-node
                 funflow-dag-build
                 funflow-resume-plan
                 funflow-replan-epoch)
        (only-in :tao3k/agentic-ai-lab/modules/durable/work
                 DurableWorkPolicy.
                 RepoNode.
                 WorktreeNode.
                 TaskNode.
                 SubTaskNode.
                 DetourNode.
                 BlockerDetourNode.
                 SideQuestDetourNode.
                 CompletedExit.
                 ParkedExit.
                 CancelledExit.
                 PromotedToTaskExit.
                 MainlineStepAnchor.
                 durable-reconcile-detour-exit
                 work-apply-overlay
                 work-artifact-path
                 project-workbench-tabs
                 durable-work-record-cas!
                 durable-work-completed-cas)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/durable/org-adapter
                 org-work-funflow-dag
                 org-work-reanchor-mainline
                 org-work-archive-transition
                 org-work-commit-archive!
                 org-work-reopen!
                 org-work-recover
                 org-shared-context-perceive-claims
                 org-shared-context-assert-write-owner
                 org-shared-context-claim!
                 org-shared-context-extend!
                 org-shared-context-handover!)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/durable/objects
                 EnableContextDurable
                 ContextDurableFeatureContract
                 context-durable-effective-rules
                 context-durable-orchestration-plan))

(export durable-funflow-orchestrator-test)

(def node-effective-rules context-durable-effective-rules)
(def task-artifact-path work-artifact-path)
(def task-funflow-dag org-work-funflow-dag)
(def task-orchestration-plan context-durable-orchestration-plan)
(def task-archive-transition org-work-archive-transition)
(def durable-orchestrator-record-cas! durable-work-record-cas!)
(def durable-orchestrator-completed-cas durable-work-completed-cas)
(def durable-orchestrator-commit-archive! org-work-commit-archive!)
(def durable-orchestrator-reopen! org-work-reopen!)
(def durable-orchestrator-recover org-work-recover)
(def task-apply-org-overlay work-apply-overlay)
(def task-reanchor-mainline org-work-reanchor-mainline)
(def shared-context-perceive-claims org-shared-context-perceive-claims)
(def shared-context-assert-write-owner org-shared-context-assert-write-owner)
(def shared-context-claim! org-shared-context-claim!)
(def shared-context-extend! org-shared-context-extend!)
(def shared-context-handover! org-shared-context-handover!)
(def DurableTaskPolicy. DurableWorkPolicy.)

(.def (TestRepo. @ RepoNode.)
  repo-id: "marlin-agent-core"
  index-path: "index.org"
  policy: (.o (:: @ DurableTaskPolicy.)
              focused-tab-archive: 'on-blur
              max-concurrency: 2))

(.def (TestWorktree. @ [TestRepo. WorktreeNode.])
  worktree: "wt/auth-refactor"
  branch: "feat/auth-refactor"
  source-cut: "sha256:cut-100"
  policy: (.o (:: @ DurableTaskPolicy.)
              require-sod-reviewer: #t
              focused-tab-archive: 'on-blur
              max-concurrency: 2))

(.def (StrictCustomStrategy. @ DurableGovernedStrategy.)
  name: 'strict-custom
  require-sod-reviewer: #t
  (.admit-node =>
    (lambda (base-admit)
      (lambda (node context)
        (and (base-admit node context)
             (not (eq? (.ref node 'id) 'forbidden-node)))))))

(.def (AuthRefactorTask. @ [TestWorktree. TaskNode.])
  task-id: "task-auth-01"
  org-path: "work/task-auth-01.org"
  strategy: StrictCustomStrategy.)

(def sample-active-task-org
  (string-append
   ":PROPERTIES:\n"
   ":ORG_CONTRACT: context.session.seed.v1\n"
   ":ORG_CONTRACT_REVISION: 1\n"
   ":GITOPS_PROJECT: marlin-agent-core\n"
   ":GITOPS_WORKTREE: wt/auth-refactor\n"
   ":END:\n"
   "* IN_PROGRESS Refactor Auth Protocol [1/3]\n"
   ":PROPERTIES:\n"
   ":ID: task-auth-01\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n"
   "- [X] Draft invariant contract\n"
   "- [ ] Implement token rotation\n"
   "- [ ] Verify integration tests\n\n"
   "** DONE Design token boundary\n"
   ":PROPERTIES:\n"
   ":ID: step-design\n"
   ":MODEL_TIER: architect\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n\n"
   "** TODO Implement Rust gate\n"
   ":PROPERTIES:\n"
   ":ID: step-rust\n"
   ":DEPENDS_ON: step-design\n"
   ":MODEL_TIER: builder\n"
   ":AGENT_ID: agent/builder-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n\n"
   "** TODO Implement Scheme bindings\n"
   ":PROPERTIES:\n"
   ":ID: step-scheme\n"
   ":DEPENDS_ON: step-design\n"
   ":MODEL_TIER: builder\n"
   ":AGENT_ID: agent/builder-02\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n\n"
   "** TODO Run end-to-end verification\n"
   ":PROPERTIES:\n"
   ":ID: step-verify\n"
   ":DEPENDS_ON: step-rust step-scheme\n"
   ":MODEL_TIER: builder\n"
   ":AGENT_ID: agent/builder-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n"))

(def sample-completed-task-org
  (string-append
   ":PROPERTIES:\n"
   ":ORG_CONTRACT: context.session.seed.v1\n"
   ":ORG_CONTRACT_REVISION: 1\n"
   ":GITOPS_PROJECT: marlin-agent-core\n"
   ":GITOPS_WORKTREE: wt/auth-refactor\n"
   ":END:\n"
   "* DONE Refactor Auth Protocol [2/2]\n"
   ":PROPERTIES:\n"
   ":ID: task-auth-01\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n"
   "- [X] Implement token rotation\n"
   "- [X] Verify integration tests\n\n"
   "** DONE Design token boundary\n"
   ":PROPERTIES:\n"
   ":ID: step-design\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n\n"
   "** DONE Verify end-to-end\n"
   ":PROPERTIES:\n"
   ":ID: step-verify\n"
   ":DEPENDS_ON: step-design\n"
   ":AGENT_ID: agent/builder-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":END:\n"))

(def durable-funflow-orchestrator-test
  (test-suite "Durable FunFlow CAS DAG, C4 POO Derivation, and Task-as-Tab Orchestrator"

    (test-case "C4 POO inheritance derives Repo -> Worktree -> Task with Override and super Extension"
      (check-equal? (.ref AuthRefactorTask. 'repo-id) "marlin-agent-core")
      (check-equal? (.ref AuthRefactorTask. 'worktree) "wt/auth-refactor")
      (check-equal? (.ref AuthRefactorTask. 'source-cut) "sha256:cut-100")
      (check-equal? (.ref AuthRefactorTask. 'task-id) "task-auth-01")
      (let ((rules (node-effective-rules AuthRefactorTask. ""))
            (paths (task-artifact-path AuthRefactorTask.)))
        (check-equal? (.ref rules 'require-sod-reviewer) #t)
        (check-equal? (.ref rules 'focused-tab-archive) 'on-blur)
        (check-equal? (.ref paths 'index-path) "index.org")
        (check-equal? (.ref paths 'task-org-path) "work/task-auth-01.org"))
      ;; Test super Extension + SoD non-self-review admission on StrictCustomStrategy.
      (let ((good-node (funflow-dag-node 'step-ok
                                         scope: (.o actor: "agent/b1" reviewer-id: "agent/r1")))
            (self-rev-node (funflow-dag-node 'step-self
                                             scope: (.o actor: "agent/b1" reviewer-id: "agent/b1")))
            (forbidden (funflow-dag-node 'forbidden-node
                                         scope: (.o actor: "agent/b1" reviewer-id: "agent/r1"))))
        (check-equal? (strategy-admit-node StrictCustomStrategy. good-node (.o)) #t)
        (check-equal? (strategy-admit-node StrictCustomStrategy. self-rev-node (.o)) #f)
        (check-equal? (strategy-admit-node StrictCustomStrategy. forbidden (.o)) #f)))

    (test-case "FunFlow DAG rejects cycles, unresolved deps, and supports CAS resume + epoch replanning"
      ;; Cycle detection via Tarjan SCC
      (let* ((a (funflow-dag-node 'a needs: '(b)))
             (b (funflow-dag-node 'b needs: '(a)))
             (cyc-dag (funflow-dag-build (list a b))))
        (check-equal? (.ref cyc-dag 'valid?) #f)
        (check-equal? (> (length (.ref cyc-dag 'cycle-nodes)) 0) #t))
      ;; Unresolved dependency detection
      (let* ((x (funflow-dag-node 'x needs: '(missing-dep)))
             (bad-dag (funflow-dag-build (list x))))
        (check-equal? (.ref bad-dag 'valid?) #f)
        (check-equal? (length (.ref bad-dag 'unresolved-edges)) 1))
      ;; CAS resume skip + epoch-bounded dynamic replanning (injecting blocker d2b)
      (let* ((d1 (funflow-dag-node 'd1 source-cut: "cut-1" input-digest: "in-1" status: 'todo))
             (d2 (funflow-dag-node 'd2 needs: '(d1) source-cut: "cut-1" input-digest: "in-2" status: 'todo))
             (d3 (funflow-dag-node 'd3 needs: '(d2) source-cut: "cut-1" input-digest: "in-3" status: 'todo))
             (dag-g1 (funflow-dag-build (list d1 d2 d3)))
             (fp-d1 (cdr (assq 'd1 (.ref dag-g1 'fingerprints))))
             (cas-table (list (cons 'd1 fp-d1)))
             (plan-g1 (funflow-resume-plan dag-g1 completed-cas-table: cas-table)))
        (check-equal? (.ref dag-g1 'valid?) #t)
        (check-equal? (.ref plan-g1 'skipped-nodes) '(d1))
        (check-equal? (.ref plan-g1 'ready-frontier) '(d2))
        (check-equal? (.ref plan-g1 'blocked-nodes) '(d3))
        ;; Epoch g2: discover new blocker d2b inserted between d1 and d3
        (let* ((d2b (funflow-dag-node 'd2b needs: '(d1) source-cut: "cut-1" input-digest: "in-2b" status: 'todo))
               (d3-next (funflow-dag-node 'd3 needs: '(d2 d2b) source-cut: "cut-1" input-digest: "in-3" status: 'todo))
               (dag-g2 (funflow-dag-build (list d1 d2 d2b d3-next)))
               (replan (funflow-replan-epoch dag-g1 dag-g2 completed-cas-table: cas-table)))
          (check-equal? (.ref replan 'valid?) #t)
          (check-equal? (.ref replan 'preserved-cas-nodes) '(d1))
          (check-equal? (.ref replan 'added-nodes) '(d2b))
          (check-equal? (and (memq 'd3 (.ref replan 'invalidated-nodes)) #t) #t)
          (check-equal? (.ref (.ref replan 'resume-plan) 'skipped-nodes) '(d1))
          (check-equal? (.ref (.ref replan 'resume-plan) 'ready-frontier) '(d2 d2b))
          (check-equal? (.ref (.ref replan 'resume-plan) 'blocked-nodes) '(d3)))))

    (test-case "Org <-> FunFlow projection schedules parallel disjoint frontier and blocks premature Auto-Archive"
      (let* ((plan (task-orchestration-plan AuthRefactorTask. sample-active-task-org (.o))))
        (check-equal? (.ref (.ref (.ref plan 'dag-projection) 'dag) 'valid?) #t)
        ;; step-design is DONE, so disjoint siblings step-rust & step-scheme are ready in parallel
        (check-equal? (.ref plan 'ready-to-schedule) '(step-rust step-scheme))
        (check-equal? (.ref plan 'ready-to-auto-archive?) #f)
        (check-equal? (.ref plan 'tab-visible?) #t)))

    (test-case "Durable journal CAS resume, atomic Auto-Archive, Plan-A index.org sync, and Task-as-Tab projection"
      (let* ((jpath (make-temporary-file-name "durable-orch-journal-"))
             (journal (journal-open jpath)))
        (dynamic-wind void
          (lambda ()
            ;; 1. Record CAS for step-design and verify recovery snapshot picks it up
            (let* ((dag-proj (task-funflow-dag AuthRefactorTask. sample-active-task-org))
                   (dag (.ref dag-proj 'dag))
                   (fp-design (cdr (assq 'step-design (.ref dag 'fingerprints)))))
              (durable-orchestrator-record-cas! journal "task-auth-01" 'step-design fp-design "sha256:res-design")
              (let ((recov (durable-orchestrator-recover journal AuthRefactorTask. sample-active-task-org)))
                (check-equal? (.ref recov 'completed-cas-count) 1)
                (check-equal? (.ref (.ref (.ref recov 'plan) 'resume-plan) 'skipped-nodes) '(step-design))))
            ;; 2. Auto-archive MUST be refused when an in-flight attempt exists even if Org is all DONE
            (let ((refused (durable-orchestrator-commit-archive!
                            journal AuthRefactorTask. sample-completed-task-org ""
                            (.o in-flight-ids: '(step-verify))
                            "2026-11-24 Tue 00:05")))
              (check-equal? (.ref refused 'committed?) #f)
              (check-equal? (.ref refused 'reason) 'archive-guard-not-satisfied))
            ;; 3. Atomic Auto-Archive succeeds once Org is all DONE + journal quiescent
            (let ((committed (durable-orchestrator-commit-archive!
                              journal AuthRefactorTask. sample-completed-task-org ""
                              (.o)
                              "2026-11-24 Tue 00:06")))
              (check-equal? (.ref committed 'committed?) #t)
              (check-equal? (and (string-contains (.ref committed 'next-task-org) ":ARCHIVE:") #t) #t)
              (check-equal? (and (string-contains (.ref committed 'next-task-org) "CLOSED: [2026-11-24 Tue 00:06]") #t) #t)
              (check-equal? (and (string-contains (.ref committed 'next-index-org) ":ARCHIVE:") #t) #t)
              (check-equal? (and (string-contains (.ref committed 'next-index-org) "[2/2]") #t) #t)
              (check-equal? (object? (journal-get journal "orchestrator:archive:task-auth-01")) #t)
              ;; 4. Pure WorkbenchTabProjection: auto-hides unfocused archived tab, keeps focused on-blur, peeks on demand
              (let* ((records (list (.o task-id: "task-auth-01" title: "Refactor Auth Protocol"
                                        status: 'done archived?: #t checklist-done: 2 checklist-total: 2)
                                    (.o task-id: "task-ui-02" title: "Live Org Window"
                                        status: 'in-progress archived?: #f checklist-done: 1 checklist-total: 4)))
                     (tabs-unfocused (project-workbench-tabs TestWorktree. records (.o) '() "task-ui-02"))
                     (tabs-focused-arch (project-workbench-tabs TestWorktree. records (.o) '() "task-auth-01"))
                     (tabs-peek (project-workbench-tabs TestWorktree. records (.o) '("task-auth-01") "task-ui-02")))
                (check-equal? (.ref tabs-unfocused 'visible-tab-ids) '(index "task-ui-02"))
                (check-equal? (length (.ref tabs-unfocused 'archived-index)) 1)
                (check-equal? (.ref tabs-focused-arch 'visible-tab-ids) '(index "task-auth-01" "task-ui-02"))
                (check-equal? (.ref (car (.ref tabs-focused-arch 'dynamic-tabs)) 'mode) 'archived-pending-blur)
                (check-equal? (.ref tabs-peek 'visible-tab-ids) '(index "task-auth-01" "task-ui-02"))
                (check-equal? (.ref (car (.ref tabs-peek 'dynamic-tabs)) 'mode) 'peek-readonly))
              ;; 5. Durable Reopen removes :ARCHIVE: and restores TODO in both Task Org and index.org
              (let ((reopened (durable-orchestrator-reopen!
                               journal AuthRefactorTask.
                               (.ref committed 'next-task-org)
                               (.ref committed 'next-index-org)
                               "2026-11-24 Tue 00:10")))
                (check-equal? (.ref reopened 'reopened?) #t)
                (check-equal? (not (string-contains (.ref reopened 'next-task-org) ":ARCHIVE:")) #t)
                (check-equal? (and (string-contains (.ref reopened 'next-task-org) "* TODO") #t) #t)
                (check-equal? (not (string-contains (.ref reopened 'next-index-org) ":ARCHIVE:")) #t)
                (check-equal? (object? (journal-get journal "orchestrator:reopen:task-auth-01")) #t))))
          (lambda ()
            (journal-close! journal)
            (when (file-exists? jpath) (delete-file jpath))))))

    (test-case "Slice 49: Three-State CLOS Effect admission, monotonic OrgOverlay meet, premise invalidation, and WorkspaceTopology"
      (let* ((pure-node (funflow-dag-node 'parse-org effect-class: PureCAS. source-cut: "cut-1"
                                          premise-digests: '(("pkg" . "sha-v1"))))
             (ep-node (funflow-dag-node 'gen-patch needs: '(parse-org)
                                        effect-class: VerifiedEpistemic. source-cut: "cut-1"
                                        premise-digests: '(("pkg" . "sha-v1"))))
             (fenced-node (funflow-dag-node 'git-push needs: '(gen-patch)
                                            effect-class: FencedEffect. source-cut: "cut-1"
                                            idempotency-key: "push-cut-1"))
             (other-node (funflow-dag-node 'independent-doc effect-class: PureCAS. source-cut: "cut-1"
                                           premise-digests: '(("doc" . "sha-d1"))))
             (r-pure (funflow-admit-node-effect pure-node envelope: (.o bind-these: #f claims-exhaustive?: #f)))
             (r-ep-deny (funflow-admit-node-effect ep-node envelope: (.o bind-these: #f has-endorsement?: #f live-cut: "cut-1")))
             (r-ep-ok (funflow-admit-node-effect ep-node envelope: (.o bind-these: #f has-endorsement?: #t live-cut: "cut-1")))
             (r-fenced-unexh (funflow-admit-node-effect fenced-node
                               envelope: (.o bind-these: #f claims-exhaustive?: #f has-authorized-token?: #t has-endorsement?: #t live-cut: "cut-1")))
             (r-fenced-ok (funflow-admit-node-effect fenced-node
                            envelope: (.o bind-these: #f claims-exhaustive?: #t has-authorized-token?: #t has-endorsement?: #t live-cut: "cut-1")))
             (dag (funflow-dag-build (list pure-node ep-node fenced-node other-node)))
             (inv (funflow-invalidate-premises dag '(("pkg" . "sha-v2") ("doc" . "sha-d1"))))
             ;; Monotonic OrgOverlay(g) meet cannot escalate trust-ceiling or can-push?
             (parent-env (.o bind-these: #f domain: "marlin" trust-ceiling: 2 lease-start: 10 lease-end: 50 can-write?: #t can-push?: #f))
             (task-with-env (.o (:: @ AuthRefactorTask.) bind-these: #f restriction-envelope: parent-env))
             (overlay (.o bind-these: #f max-parallel: 6
                          restriction-envelope: (.o bind-these: #f trust-ceiling: 4 lease-start: 5 lease-end: 100 can-write?: #t can-push?: #t)))
             (overlaid (task-apply-org-overlay task-with-env overlay))
             (eff-env (.ref overlaid 'restriction-envelope))
             ;; Multi-repo WorkspaceTopology pin plan + remote drift probe
             (ws (.o (:: @ WorkspaceTopology.)
                     bind-these: #f
                     workspace-id: "tao3k-suite"
                     repos: (list (.o bind-these: #f repo-id: "yuanxu" local-head: "aaa")
                                  (.o bind-these: #f repo-id: "lab" local-head: "bbb")
                                  (.o bind-these: #f repo-id: "marlin" local-head: "ccc"))
                     pin-edges: '(("lab" . "yuanxu") ("marlin" . "lab"))))
             (ws-plan (funflow-workspace-plan ws remote-heads: '(("yuanxu" . "aaa") ("lab" . "bbb-remote") ("marlin" . "ccc")))))
        (check-equal? (.ref r-pure 'admitted?) #t)
        (check-equal? (.ref r-ep-deny 'admitted?) #f)
        (check-equal? (.ref r-ep-ok 'admitted?) #t)
        (check-equal? (.ref r-fenced-unexh 'admitted?) #f)
        (check-equal? (.ref r-fenced-unexh 'reason) 'fenced-effect-blocked-by-omitted-alternatives)
        (check-equal? (.ref r-fenced-ok 'admitted?) #t)
        (check-equal? (.ref inv 'stale-nodes) '(parse-org gen-patch git-push))
        (check-equal? (.ref inv 'unaffected-nodes) '(independent-doc))
        (check-equal? (.ref eff-env 'trust-ceiling) 2)
        (check-equal? (.ref eff-env 'lease-start) 10)
        (check-equal? (.ref eff-env 'lease-end) 50)
        (check-equal? (.ref eff-env 'can-push?) #f)
        ;; BUG-D1 regression: overlay max-parallel: 6 must stay monotonically clamped to parent max-concurrency: 2
        (check-equal? (.ref (.ref overlaid 'policy) 'max-concurrency) 2)
        (check-equal? (.ref ws-plan 'valid?) #t)
        (check-equal? (.ref ws-plan 'any-remote-drift?) #t)
        (check-equal? (.ref ws-plan 'push-order) '(yuanxu lab marlin))))

    (test-case "Slice 49: Scoped Detour 4-exit CLOS reconciler, 0-token re-anchor, and Zero-SubAgent shared-context ownership"
      (let* ((blocker-detour (.o (:: @ BlockerDetourNode.) bind-these: #f return-anchor: "step-scheme"))
             (side-detour (.o (:: @ SideQuestDetourNode.) bind-these: #f return-anchor: "step-scheme"))
             (anchor (.o (:: @ MainlineStepAnchor.) bind-these: #f anchor-id: "step-scheme"
                         mainline-counterexample-core: '("gambit-oN-rule")))
             (r-comp (durable-reconcile-detour-exit blocker-detour
                       (.o (:: @ CompletedExit.) bind-these: #f outcome-receipt-digest: "sha256:rec-1" defeat-conditions: '("poo-bind-these"))
                       anchor))
             (r-park (durable-reconcile-detour-exit side-detour
                       (.o (:: @ ParkedExit.) bind-these: #f custody-oid: "gitops-custody:oid-42")
                       anchor))
             (r-cancel-bad (durable-reconcile-detour-exit blocker-detour
                             (.o (:: @ CancelledExit.) bind-these: #f defeat-conditions: '())
                             anchor))
             (r-cancel-ok (durable-reconcile-detour-exit blocker-detour
                            (.o (:: @ CancelledExit.) bind-these: #f defeat-conditions: '("dead-end-api-v1"))
                            anchor))
             (r-promote (durable-reconcile-detour-exit blocker-detour
                          (.o (:: @ PromotedToTaskExit.) bind-these: #f promoted-task-id: "task-funflow-migration")
                          anchor))
             ;; 0-token re-anchor blocks Auto-Archive while blocker detour is open
             (detour-org
              (string-append
               "* IN_PROGRESS Mainline Task [1/2]\n"
               ":PROPERTIES:\n"
               ":ID: task-auth-01\n"
               ":END:\n"
               "** DONE Design\n"
               ":PROPERTIES:\n"
               ":ID: step-design\n"
               ":ROLE: mainline\n"
               ":END:\n"
               "** TODO Blocker Detour\n"
               ":PROPERTIES:\n"
               ":ID: detour-1\n"
               ":ROLE: detour\n"
               ":DETOUR_KIND: blocker\n"
               ":RETURN_ANCHOR: step-design\n"
               ":DETOUR_DEPTH: 3\n"
               ":END:\n"))
             (align (task-reanchor-mainline AuthRefactorTask. detour-org mainline-core: '("gambit-oN-rule") max-detour-depth: 2))
             ;; Zero-SubAgent shared-context `:ID:` ownership + Extend-Never-Overwrite + expiry takeover
             (jpath (string-append (make-temporary-file-name "marlin-claim-journal-") ".sqlite"))
             (journal (journal-open jpath)))
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            (check-equal? (.ref r-comp 'admitted?) #t)
            (check-equal? (.ref r-comp 'folded-disclosure-depth) 0)
            (check-equal? (.ref r-park 'admitted?) #t)
            (check-equal? (.ref r-park 'unblocks-mainline?) #t)
            (check-equal? (.ref r-cancel-bad 'admitted?) #f)
            (check-equal? (.ref r-cancel-ok 'admitted?) #t)
            (check-equal? (and (member "gambit-oN-rule" (.ref r-cancel-ok 'next-counterexample-core))
                               (member "dead-end-api-v1" (.ref r-cancel-ok 'next-counterexample-core)) #t)
                          #t)
            (check-equal? (.ref r-promote 'promoted-task-id) "task-funflow-migration")
            (check-equal? (.ref align 'auto-archive-blocked?) #t)
            (check-equal? (.ref align 'depth-guard-triggered?) #t)
            (check-equal? (.ref align 'return-anchor-id) "step-design")
            (let* ((claimed (shared-context-claim! journal "task-auth-01" "step-rust" "agent:alpha"
                                                   worktree: "wt/auth-refactor" now: 100 ttl: 60
                                                   org-source: sample-active-task-org))
                   (org1 (.ref claimed 'next-org-source))
                   (claims1 (shared-context-perceive-claims org1))
                   (beta-overwrite (shared-context-assert-write-owner org1 "step-rust" "agent:beta"))
                   (extended (shared-context-extend! journal "task-auth-01" "step-rust" "step-rust-ext-1"
                                                     "human:guangtao" "Human steering note"
                                                     body: "Keep Rust ABI zero-copy" role: "human-steering"
                                                     now: 110 org-source: org1))
                   (org2 (.ref extended 'next-org-source))
                   (still-alpha (shared-context-assert-write-owner org2 "step-rust" "agent:alpha"))
                   (early-takeover (shared-context-handover! journal "task-auth-01" "step-rust" "agent:beta"
                                                             now: 120 custody-oid: "custody:oid-1" org-source: org2))
                   (expired-takeover (shared-context-handover! journal "task-auth-01" "step-rust" "agent:beta"
                                                               now: 160 custody-oid: "custody:oid-1" org-source: org2)))
              (check-equal? (.ref claimed 'claimed?) #t)
              (check-equal? (length claims1) 1)
              (check-equal? (.ref (car claims1) 'owner-actor) "agent:alpha")
              (check-equal? (.ref beta-overwrite 'admitted?) #f)
              (check-equal? (.ref beta-overwrite 'reason) 'non-owner-overwrite-forbidden)
              (check-equal? (.ref extended 'extended?) #t)
              (check-equal? (.ref still-alpha 'admitted?) #t)
              (check-equal? (.ref early-takeover 'handed-over?) #f)
              (check-equal? (.ref early-takeover 'reason) 'active-lease-not-expired)
              (check-equal? (.ref expired-takeover 'handed-over?) #t)
              (check-equal? (.ref expired-takeover 'claim-lease-epoch) 2)
              (check-equal? (.ref expired-takeover 'next-owner) "agent:beta")))
          (lambda ()
            (journal-close! journal)
            (when (file-exists? jpath) (delete-file jpath)))))

    (test-case "Slice 54 BUG-D5 regression: CANCELLED :INVARIANT: stays unsatisfied and Org DAG forwards EffectClass/code/env digests"
      (let* ((bug-d5-org
              (string-append
               "* DONE Mainline With Cancelled Invariant [1/1]\n"
               ":PROPERTIES:\n"
               ":ID: task-d5\n"
               ":END:\n"
               "- [X] Done\n\n"
               "** CANCELLED Critical Safety Invariant\n"
               ":PROPERTIES:\n"
               ":ID: inv-1\n"
               ":INVARIANT: zero-data-loss\n"
               ":END:\n\n"
               "** CANCELLED Blocker Without Defeat Conditions\n"
               ":PROPERTIES:\n"
               ":ID: blk-1\n"
               ":ROLE: detour\n"
               ":DETOUR_KIND: blocker\n"
               ":END:\n\n"
               "** TODO Deploy Step\n"
               ":PROPERTIES:\n"
               ":ID: step-deploy\n"
               ":EFFECT_CLASS: FencedEffect\n"
               ":STEP_CODE_DIGEST: sha256:code-v2\n"
               ":ENV_DIGEST: sha256:nix-v2\n"
               ":PREMISE_DIGESTS: pkg=sha-v2\n"
               ":END:\n"))
             (align (task-reanchor-mainline AuthRefactorTask. bug-d5-org))
             (dag-proj (task-funflow-dag AuthRefactorTask. bug-d5-org))
             (deploy-node (hash-ref (.ref (.ref dag-proj 'dag) 'node-table) 'step-deploy)))
        (check-equal? (.ref align 'unsatisfied-invariants) '("inv-1"))
        (check-equal? (.ref align 'open-blocker-detours) '("blk-1"))
        (check-equal? (.ref align 'auto-archive-blocked?) #t)
        (check-equal? (.ref (.ref deploy-node 'effect-class) 'effect-kind) 'fenced-effect)
        (check-equal? (.ref deploy-node 'step-code-digest) "sha256:code-v2")
        (check-equal? (.ref deploy-node 'env-digest) "sha256:nix-v2")
        (check-equal? (.ref deploy-node 'premise-digests) '(("pkg" . "sha-v2"))))))))
