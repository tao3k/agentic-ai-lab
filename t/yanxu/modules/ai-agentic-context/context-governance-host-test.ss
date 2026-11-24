;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list filter-map)
        (only-in :orgize/languages/org/modules/org-contract/config OrgDirectoryProfile.)
        (only-in :orgize/languages/org/modules/org-contract/directory-runtime org-directory-validate)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/objects
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-governance-graph
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-subtree-mediation
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/query-provider
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/governance-host)
(export context-governance-host-test)

(def governance-templates-dir
  "modules/ai-agentic-context/org-contract/templates/governance")

(def (read-template name)
  (call-with-input-file (path-expand name governance-templates-dir)
    (lambda (port) (read-line port #f))))

(def (rejected? thunk)
  (with-catch (lambda (_) #t) (lambda () (thunk) #f)))

(def context-governance-host-test
  (test-suite "POO Org Contract schemas, governance templates, and live catalog host"
    (yuanxu-test-case "POO OrgContractSchema. hierarchy enforces root and section obligations and supports catalog refinement"
      (check (.ref TopologyOrgContractSchema. 'identity) => "context.gitops.topology.v1")
      (check (.ref GovernedWorkOrgContractSchema. 'identity) => "context.governance.work.v1")
      (check (.ref GovernedTaskOrgContractSchema. 'identity) => "context.governance.task.v1")
      (check (.ref CrossRepoTopologyOrgContractSchema. 'identity) => "context.gitops.cross-repo.v1")
      ;; Missing PROJECT_ID on topology contract is rejected.
      (check (rejected?
              (lambda ()
                (context-org-source
                 "bad-topo.org" 1
                 ":PROPERTIES:\n:ID: t1\n:CONTRACT_ID: context.gitops.topology.v1\n:CONTRACT_REVISION: 1\n:END:\n")))
             => #t)
      ;; Component headline without ENTRY_SOURCE is rejected.
      (check (rejected?
              (lambda ()
                (context-org-source
                 "bad-comp.org" 1
                 (string-append
                  ":PROPERTIES:\n:ID: t1\n:CONTRACT_ID: context.gitops.topology.v1\n:CONTRACT_REVISION: 1\n:PROJECT_ID: p1\n:END:\n"
                  "* Comp\n:PROPERTIES:\n:ID: c1\n:ARCH_COMPONENT: deck\n:END:\n"))))
             => #t)
      ;; Governed task headline with AGENT_ID but missing TASK_ID is rejected.
      (check (rejected?
              (lambda ()
                (context-org-source
                 "bad-task.org" 1
                 (string-append
                  ":PROPERTIES:\n:ID: w1\n:CONTRACT_ID: context.governance.task.v1\n:CONTRACT_REVISION: 1\n:PROJECT_ID: p1\n:END:\n"
                  "* Work\n:PROPERTIES:\n:ID: s1\n:AGENT_ID: agent/a1\n:END:\n"))))
             => #t)
      ;; Cross-repo topology inherits TopologyOrgContractSchema. and requires RELATES_PROJECT.
      (check (rejected?
              (lambda ()
                (context-org-source
                 "bad-cross.org" 1
                 ":PROPERTIES:\n:ID: x1\n:CONTRACT_ID: context.gitops.cross-repo.v1\n:CONTRACT_REVISION: 1\n:PROJECT_ID: p1\n:END:\n")))
             => #t)
      (let (ok-cross
            (context-org-source
             "ok-cross.org" 1
             (string-append
              ":PROPERTIES:\n:ID: x1\n:CONTRACT_ID: context.gitops.cross-repo.v1\n:CONTRACT_REVISION: 1\n"
              ":PROJECT_ID: marlin-agent-core\n:RELATES_PROJECT: agentic-ai-lab\n:END:\n"
              "* Lab Bridge\n:PROPERTIES:\n:ID: c-lab\n:ARCH_COMPONENT: lab-bridge\n:ENTRY_SOURCE: bridge.org\n:END:\n")))
        (check (.ref ok-cross 'contract-identity) => "context.gitops.cross-repo.v1"))
      ;; Downstream POO catalog extension without modifying core elements.ss.
      (let* ((AuditSchema.
              (.o (:: @ OrgContractSchema.)
                  family: "context.audit.trail"
                  required-root-any: '(("AUDIT_EPOCH"))))
             (ext-catalog (.o (:: @ DefaultOrgContractCatalog)
                              audit: AuditSchema.)))
        (check (rejected?
                (lambda ()
                  (context-org-source
                   "missing-epoch.org" 1
                   ":PROPERTIES:\n:ID: a1\n:CONTRACT_ID: context.audit.trail.v1\n:CONTRACT_REVISION: 1\n:END:\n"
                   #t ext-catalog)))
               => #t)
        (check (.ref (context-org-source
                      "ok-epoch.org" 1
                      ":PROPERTIES:\n:ID: a1\n:CONTRACT_ID: context.audit.trail.v1\n:CONTRACT_REVISION: 1\n:AUDIT_EPOCH: 42\n:END:\n"
                      #t ext-catalog)
                     'contract-identity)
               => "context.audit.trail.v1")))

    (yuanxu-test-case "Orgize org-directory-validate passes on governance topology.org and work.org templates"
      (let* ((profile (.o (:: @ OrgDirectoryProfile.) directory: governance-templates-dir))
             (result (org-directory-validate profile))
             (contracts (filter-map
                         (lambda (row)
                           (let (id (.ref row 'contract-id))
                             (and (not (equal? id "orgize.directory.document-root.v1"))
                                  (list (path-strip-directory (.ref row 'path)) id))))
                         (.ref result 'evaluations))))
        (check (.ref result 'complete?) => #t)
        (check (.ref result 'passed?) => #t)
        (check (length (.ref result 'files)) => 2)
        (check contracts => '(("topology.org" "context.gitops.topology.v1")
                              ("work.org" "context.governance.work.v1")))))

    (yuanxu-test-case "context-governance-host commits concurrent disjoint subtrees into context-query-host and invalidates stale ASCENT observations"
      (let* ((qhost (context-query-host))
             (ghost (context-governance-host qhost "gov-seed-01" "sha256:gov-policy-v1"))
             (events '())
             (observer
              (.o kind: 'temporal.source-observer.v1
                  .prepare:
                  (lambda (_obs ev)
                    (.o kind: 'temporal.source-propagation-batch.v1
                        .publish!:
                        (lambda (_batch)
                          (set! events
                            (append events (list (list (.ref ev 'identity) (.ref ev 'generation))))))))))
             (_watch (context-query-watch! qhost observer))
             (topo1 (context-governance-enroll-source!
                     ghost (context-org-source "topology.org" 1 (read-template "topology.org"))))
             (work1 (context-governance-enroll-source!
                     ghost (context-org-source "work.org" 1 (read-template "work.org"))))
             ;; Layer 1 GQL entry discovery from topology.org -> work.org
             (entries (agentic-ai-lab-ai-agentic-context-topology-entries
                       (context-governance-live-graph ghost) "marlin-deck-runtime"))
             (entry-source (caddar (.ref entries 'rows)))
             ;; Execute real ASCENT-backed descendants query on generation 1
             (obs1 (context-query-execute
                    qhost entry-source (context-org-descendants-query work1 "sec-arch" 4 16)))
             (arch-dig1 (agentic-ai-lab-ai-agentic-context-org-subtree-digest work1 "sec-arch"))
             (rust-dig1 (agentic-ai-lab-ai-agentic-context-org-subtree-digest work1 "sec-rust"))
             (prop-a (.o (:: @ AiAgenticContextSubtreeProposal.)
                         source-id: "work.org" base-generation: 1
                         target-property-id: "sec-arch"
                         agent-id: "agent/architect-01" task-id: "task/write-arch"
                         session-id: "sess-arch"
                         expected-subtree-digest: arch-dig1
                         replacement-body: "Finalized multi-worktree git-common-dir context design.\n"
                         nonce: "gov-host-nonce-a" lease-id: "lease-arch-1"))
             (prop-b (.o (:: @ AiAgenticContextSubtreeProposal.)
                         source-id: "work.org" base-generation: 1
                         target-property-id: "sec-rust"
                         agent-id: "agent/rust-worker-02" task-id: "task/write-rust"
                         session-id: "sess-rust"
                         expected-subtree-digest: rust-dig1
                         replacement-body: "Implemented single-VM serialized rebase commit path.\n"
                         nonce: "gov-host-nonce-b" lease-id: "lease-rust-1"))
             (tok-a (context-governance-issue-token ghost prop-a 10 100))
             (tok-b (context-governance-issue-token ghost prop-b 10 100)))
        (check entry-source => "work.org")
        (check (context-query-current? qhost obs1) => #t)
        (check (.ref tok-a 'accepted?) => #t)
        (check (.ref tok-b 'accepted?) => #t)
        ;; Commit Agent A (gen 1 -> 2) and Agent B (gen 1 -> 3 via automatic structural rebase!)
        (let* ((res-a (context-governance-commit-subtree! ghost prop-a (.ref tok-a 'token) 15))
               (res-b (context-governance-commit-subtree! ghost prop-b (.ref tok-b 'token) 16))
               (work3 (context-query-current-source qhost "work.org")))
          (check (.ref res-a 'accepted?) => #t)
          (check (.ref res-a 'committed-generation) => 2)
          (check (.ref res-a 'rebased?) => #f)
          (check (.ref res-b 'accepted?) => #t)
          (check (.ref res-b 'committed-generation) => 3)
          (check (.ref res-b 'rebased?) => #t)
          (check (.ref work3 'generation) => 3)
          ;; Watcher received both monotonic source updates on change-feed
          (check events => '(("work.org" 2) ("work.org" 3)))
          ;; Generation 1 ASCENT query observation is automatically invalidated!
          (check (context-query-current? qhost obs1) => #f)
          ;; Replaying consumed token-a fails closed and does NOT advance generation 3
          (let (replay (context-governance-commit-subtree! ghost prop-a (.ref tok-a 'token) 17))
            (check (.ref replay 'accepted?) => #f)
            (check (.ref (context-query-current-source qhost "work.org") 'generation) => 3))
          ;; Fresh ASCENT-backed queries on generation 3 are current and contain both edits
          (let ((obs3-arch (context-query-execute
                            qhost "work.org" (context-org-descendants-query work3 "sec-arch" 4 16)))
                (obs3-rust (context-query-execute
                            qhost "work.org" (context-org-descendants-query work3 "sec-rust" 4 16))))
            (check (context-query-current? qhost obs3-arch) => #t)
            (check (context-query-current? qhost obs3-rust) => #t)))))))
