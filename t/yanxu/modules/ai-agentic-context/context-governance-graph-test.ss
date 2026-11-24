;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/types
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-properties
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-governance-graph)
(export context-governance-graph-test)

;; Layer 1: GitOps Project topology & architecture entry map (eliminates blind search).
(def topology-org
  (string-append
   ":PROPERTIES:\n"
   ":ID: marlin-repo-topology\n"
   ":CONTRACT_ID: context.gitops.topology.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":GITOPS_PROJECT: marlin-agent-core\n"
   ":GITOPS_WORKTREE: main\n"
   ":GITOPS_SOURCE_CUT: commit-abc123\n"
   ":END:\n"
   "#+title: Marlin Repository Topology\n\n"
   "* Deck Runtime Component\n"
   ":PROPERTIES:\n"
   ":ID: topo-deck-runtime\n"
   ":ARCH_COMPONENT: marlin-deck-runtime\n"
   ":ENTRY_SOURCE: deck-work.org\n"
   ":END:\n"
   "Entry locator for Deck VM actor and async mailbox.\n\n"
   "* Context System Component\n"
   ":PROPERTIES:\n"
   ":ID: topo-context-system\n"
   ":ARCH_COMPONENT: marlin-agent-context\n"
   ":ENTRY_SOURCE: context-work.org\n"
   ":RELATED_PROJECT: agentic-ai-lab\n"
   ":END:\n"))

;; Layer 2: Self-contained business Org with inline Agent/Task/Dependency properties (Scheme A).
(def deck-work-org
  (string-append
   ":PROPERTIES:\n"
   ":ID: deck-work-root\n"
   ":CONTRACT_ID: context.governance.work.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":PROJECT_ID: marlin-agent-core\n"
   ":WORKTREE_ID: feat/org-shared-context\n"
   ":END:\n\n"
   "* Shared Spec Foundation\n"
   ":PROPERTIES:\n"
   ":ID: spec-region-lease\n"
   ":ARCH_COMPONENT: marlin-deck-runtime\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-09\n"
   ":TASK_ID: task/design-lease\n"
   ":END:\n"
   "Region lease specification.\n\n"
   "* Async Coordinator Implementation\n"
   ":PROPERTIES:\n"
   ":ID: impl-async-coordinator\n"
   ":ARCH_COMPONENT: marlin-deck-runtime\n"
   ":AGENT_ID: agent/rust-worker-02\n"
   ":REVIEWER_AGENT_ID: agent/architect-01\n"
   ":TASK_ID: task/impl-coordinator\n"
   ":DEPENDS_ON: spec-region-lease\n"
   ":END:\n"
   "Tokio mpsc -> single-VM Deck owner mediation.\n"))

(def context-work-org
  (string-append
   ":PROPERTIES:\n"
   ":ID: context-work-root\n"
   ":CONTRACT_ID: context.governance.work.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":PROJECT_ID: marlin-agent-core\n"
   ":WORKTREE_ID: feat/org-shared-context\n"
   ":END:\n\n"
   "* Self-Reviewed Section\n"
   ":PROPERTIES:\n"
   ":ID: bad-sod-section\n"
   ":AGENT_ID: agent/rogue-03\n"
   ":REVIEWER_AGENT_ID: agent/rogue-03\n"
   ":TASK_ID: task/self-approve\n"
   ":END:\n"))

(def context-governance-graph-test
  (test-suite "Layered GitOps Topology + Inline Org Governance GQL Graph"
    (yuanxu-test-case "sibling Org sections produce exact, disjoint half-open byte intervals"
      (let* ((props (agentic-ai-lab-ai-agentic-context-org-properties deck-work-org))
             (id-props (filter (lambda (p) (agentic-ai-lab-ai-agentic-context-org-property-key? p "ID")) props))
             (root-p (car id-props))
             (sec1-p (cadr id-props))
             (sec2-p (caddr id-props)))
        (check (every agentic-ai-lab-ai-agentic-context-org-property-shape? props) => #t)
        (check (.ref root-p 'value) => "deck-work-root")
        (check (.ref sec1-p 'value) => "spec-region-lease")
        (check (.ref sec2-p 'value) => "impl-async-coordinator")
        ;; Root OrgFile encloses both sections; sibling sections are strictly disjoint.
        (check (agentic-ai-lab-ai-agentic-context-org-property-contains? root-p sec1-p) => #t)
        (check (agentic-ai-lab-ai-agentic-context-org-property-contains? root-p sec2-p) => #t)
        (check (agentic-ai-lab-ai-agentic-context-org-property-disjoint? sec1-p sec2-p) => #t)
        (check (= (.ref sec1-p 'container-end) (.ref sec2-p 'container-start)) => #t)))

    (yuanxu-test-case "Layer 1 GQL resolves architecture component entry sources without blind search"
      (let* ((topo-cut (context-org-source "topology.org" 1 topology-org))
             (deck-cut (context-org-source "deck-work.org" 1 deck-work-org))
             (gov (agentic-ai-lab-ai-agentic-context-governance-graph
                   'marlin-gov (list topo-cut deck-cut)))
             (res (agentic-ai-lab-ai-agentic-context-topology-entries gov "marlin-deck-runtime")))
        (check (agentic-ai-lab-ai-agentic-context-governance-graph-shape? gov) => #t)
        (check (and (string-contains (.ref res 'gql) "ENTRY_SOURCE") #t) => #t)
        (check (.ref res 'rows)
               => '(("marlin-agent-core" "marlin-deck-runtime" "deck-work.org"
                     "deck-work-root" "context.governance.work.v1")))
        (check (.ref res 'action-authorized?) => #f)))

    (yuanxu-test-case "Layer 2 GQL traverses Agent -> Task -> OrgElement and scores 1-hop dependencies"
      (let* ((topo-cut (context-org-source "topology.org" 1 topology-org))
             (deck-cut (context-org-source "deck-work.org" 1 deck-work-org))
             (gov (agentic-ai-lab-ai-agentic-context-governance-graph
                   'marlin-gov (list topo-cut deck-cut)))
             (res (agentic-ai-lab-ai-agentic-context-agent-affinities
                   gov "agent/rust-worker-02" "marlin-agent-core" "feat/org-shared-context"))
             (items (.ref res 'affinities)))
        (check (and (string-contains (.ref res 'gql) "ASSIGNED_TO") #t) => #t)
        (check (and (string-contains (.ref res 'gql) "TARGETS_ANCHOR") #t) => #t)
        (check (length items) => 2)
        (check (every agentic-ai-lab-ai-agentic-context-agent-affinity-shape? items) => #t)
        ;; Primary owned anchor ranks first (10000 bps) and is write-eligible;
        ;; `:DEPENDS_ON:` upstream spec ranks second (7500 bps) as read-only context.
        (let ((first-item (car items))
              (second-item (cadr items)))
          (check (.ref first-item 'property-id) => "impl-async-coordinator")
          (check (.ref first-item 'score-bps) => 10000)
          (check (.ref first-item 'write-eligible?) => #t)
          (check (.ref second-item 'property-id) => "spec-region-lease")
          (check (.ref second-item 'score-bps) => 7500)
          (check (.ref second-item 'write-eligible?) => #f)
          ;; Concurrent disjointness holds directly on the affinity spans.
          (check (<= (.ref second-item 'container-end) (.ref first-item 'container-start)) => #t))))

    (yuanxu-test-case "Governance conflict check catches separation-of-duties violations"
      (let* ((topo-cut (context-org-source "topology.org" 1 topology-org))
             (deck-cut (context-org-source "deck-work.org" 1 deck-work-org))
             (bad-cut (context-org-source "context-work.org" 1 context-work-org))
             (clean-gov (agentic-ai-lab-ai-agentic-context-governance-graph
                         'clean (list topo-cut deck-cut)))
             (bad-gov (agentic-ai-lab-ai-agentic-context-governance-graph
                       'bad (list topo-cut deck-cut bad-cut)))
             (issues (agentic-ai-lab-ai-agentic-context-governance-conflicts bad-gov)))
        (check (agentic-ai-lab-ai-agentic-context-governance-conflicts clean-gov) => '())
        (check (length issues) => 1)
        (check (.ref (car issues) 'kind) => 'separation-of-duties)
        (check (.ref (car issues) 'property-id) => "bad-sod-section")
        (check (.ref (car issues) 'agent-id) => "agent/rogue-03")))))
