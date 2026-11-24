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
                 OrchestratorStrategy.
                 ParallelFrontierStrategy.
                 TieredModelStrategy.
                 DurableGovernedStrategy.
                 strategy-admit-node
                 funflow-dag-node
                 funflow-dag-build
                 funflow-resume-plan
                 funflow-replan-epoch)
        (only-in :tao3k/agentic-ai-lab/modules/durable/orchestrator
                 DurableTaskPolicy.
                 RepoNode.
                 WorktreeNode.
                 TaskNode.
                 SubTaskNode.
                 define-repo!
                 define-worktree!
                 define-durable-task!
                 define-orchestrator-strategy!
                 node-effective-rules
                 task-artifact-path
                 task-funflow-dag
                 task-orchestration-plan
                 task-archive-transition
                 project-workbench-tabs
                 durable-orchestrator-record-cas!
                 durable-orchestrator-completed-cas
                 durable-orchestrator-commit-archive!
                 durable-orchestrator-reopen!
                 durable-orchestrator-recover))

(export durable-funflow-orchestrator-test)

(define-repo! TestRepo.
  repo-id: "marlin-agent-core"
  index-path: "index.org"
  policy: (.o (:: @ DurableTaskPolicy.)
              focused-tab-archive: 'on-blur
              max-concurrency: 2))

(define-worktree! TestWorktree. TestRepo.
  worktree: "wt/auth-refactor"
  branch: "feat/auth-refactor"
  source-cut: "sha256:cut-100"
  policy: (.o (:: @ DurableTaskPolicy.)
              require-sod-reviewer: #t
              focused-tab-archive: 'on-blur
              max-concurrency: 2))

(define-orchestrator-strategy! StrictCustomStrategy. DurableGovernedStrategy.
  name: 'strict-custom
  require-sod-reviewer: #t
  (.admit-node =>
    (lambda (base-admit)
      (lambda (node context)
        (and (base-admit node context)
             (not (eq? (.ref node 'id) 'forbidden-node)))))))

(define-durable-task! AuthRefactorTask. TestWorktree.
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
            (when (file-exists? jpath) (delete-file jpath))))))))
