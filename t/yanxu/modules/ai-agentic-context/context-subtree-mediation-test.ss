;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/types
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/objects
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-governance-graph
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-subtree-mediation)
(export context-subtree-mediation-test)

(def shared-org-v1
  (string-append
   ":PROPERTIES:\n"
   ":ID: shared-context-root\n"
   ":CONTRACT_ID: context.governance.work.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":PROJECT_ID: marlin-agent-core\n"
   ":WORKTREE_ID: main\n"
   ":END:\n\n"
   "* Architecture Spec\n"
   ":PROPERTIES:\n"
   ":ID: sec-arch\n"
   ":ARCH_COMPONENT: marlin-deck-runtime\n"
   ":AGENT_ID: agent/architect-01\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-09\n"
   ":TASK_ID: task/write-arch\n"
   ":END:\n"
   "Initial short spec.\n\n"
   "* Rust Async Implementation\n"
   ":PROPERTIES:\n"
   ":ID: sec-rust\n"
   ":ARCH_COMPONENT: marlin-deck-runtime\n"
   ":AGENT_ID: agent/rust-worker-02\n"
   ":REVIEWER_AGENT_ID: agent/architect-01\n"
   ":TASK_ID: task/write-rust\n"
   ":DEPENDS_ON: sec-arch\n"
   ":END:\n"
   "Initial Rust notes.\n"))

(def policy-dig "sha256:policy-v1")

(def context-subtree-mediation-test
  (test-suite "Governed Org `:ID:` subtree mediation and concurrent rebase"
    (yuanxu-test-case "two concurrent Agents prepared on gen 1 both commit cleanly (gen 1 -> 2 -> 3) via subtree rebase"
      (let* ((cut1 (context-org-source "shared.org" 1 shared-org-v1))
             (gov1 (agentic-ai-lab-ai-agentic-context-governance-graph 'gov (list cut1)))
             (med0 (agentic-ai-lab-ai-agentic-context-subtree-mediation-init "seed-1" 0))
             (arch-dig1 (agentic-ai-lab-ai-agentic-context-org-subtree-digest cut1 "sec-arch"))
             (rust-dig1 (agentic-ai-lab-ai-agentic-context-org-subtree-digest cut1 "sec-rust"))
             ;; Both Agent A and Agent B prepare proposals concurrently against generation 1!
             (prop-a (.o (:: @ AiAgenticContextSubtreeProposal.)
                         source-id: "shared.org" base-generation: 1
                         target-property-id: "sec-arch"
                         agent-id: "agent/architect-01" task-id: "task/write-arch"
                         session-id: "sess-a"
                         expected-subtree-digest: arch-dig1
                         replacement-body: "Expanded multi-line architecture specification with UTF-8 λ → ∀x multibyte symbols that shift all downstream byte offsets!\n- Point 1\n- Point 2\n\n"
                         nonce: "nonce-a-1" lease-id: "lease-sec-arch"))
             (prop-b (.o (:: @ AiAgenticContextSubtreeProposal.)
                         source-id: "shared.org" base-generation: 1
                         target-property-id: "sec-rust"
                         agent-id: "agent/rust-worker-02" task-id: "task/write-rust"
                         session-id: "sess-b"
                         expected-subtree-digest: rust-dig1
                         replacement-body: "Completed Tokio mpsc + Deck single-VM lease coordinator.\n"
                         nonce: "nonce-b-1" lease-id: "lease-sec-rust"))
             (issued-a (agentic-ai-lab-ai-agentic-context-subtree-issue-token
                        gov1 cut1 prop-a policy-dig 10 100 0))
             (issued-b (agentic-ai-lab-ai-agentic-context-subtree-issue-token
                        gov1 cut1 prop-b policy-dig 10 100 0)))
        (check (.ref issued-a 'accepted?) => #t)
        (check (.ref issued-b 'accepted?) => #t)
        ;; 1. Agent A commits first: gen 1 -> gen 2 (not rebased).
        (let* ((commit-a (agentic-ai-lab-ai-agentic-context-subtree-commit
                          med0 gov1 cut1 prop-a (.ref issued-a 'token) policy-dig 15))
               (cut2 (.ref commit-a 'next-source-cut))
               (gov2 (agentic-ai-lab-ai-agentic-context-governance-graph 'gov (list cut2)))
               (med1 (.ref commit-a 'mediation-state)))
          (check (agentic-ai-lab-ai-agentic-context-subtree-commit-receipt-shape? commit-a) => #t)
          (check (.ref commit-a 'accepted?) => #t)
          (check (.ref commit-a 'committed-generation) => 2)
          (check (.ref commit-a 'rebased?) => #f)
          ;; 2. Agent B commits second onto `cut2` (gen 2) even though `prop-b` was prepared on gen 1:
          ;;    succeeds with `rebased?: #t` -> gen 3, preserving both edits and both governance headers!
          (let* ((commit-b (agentic-ai-lab-ai-agentic-context-subtree-commit
                            med1 gov2 cut2 prop-b (.ref issued-b 'token) policy-dig 16))
                 (cut3 (.ref commit-b 'next-source-cut))
                 (med2 (.ref commit-b 'mediation-state)))
            (check (.ref commit-b 'accepted?) => #t)
            (check (.ref commit-b 'committed-generation) => 3)
            (check (.ref commit-b 'rebased?) => #t)
            (check (and (string-contains (.ref cut3 'source) "UTF-8 λ → ∀x") #t) => #t)
            (check (and (string-contains (.ref cut3 'source) "Completed Tokio mpsc") #t) => #t)
            (check (and (string-contains (.ref cut3 'source) ":AGENT_ID: agent/architect-01") #t) => #t)
            (check (and (string-contains (.ref cut3 'source) ":AGENT_ID: agent/rust-worker-02") #t) => #t)
            ;; 3. Replaying Agent B's spent token is strictly rejected (`token-reuse` or stale digest).
            (let* ((gov3 (agentic-ai-lab-ai-agentic-context-governance-graph 'gov (list cut3)))
                   ;; Even if someone tries to replay `issued-a` on a reverted/matching subtree, nonce is spent.
                   (prop-b-again (.o (:: @ AiAgenticContextSubtreeProposal.)
                                     source-id: "shared.org" base-generation: 1
                                     target-property-id: "sec-rust"
                                     agent-id: "agent/rust-worker-02" task-id: "task/write-rust"
                                     session-id: "sess-b"
                                     expected-subtree-digest: (.ref commit-b 'after-subtree-digest)
                                     replacement-body: "Completed Tokio mpsc + Deck single-VM lease coordinator.\n"
                                     nonce: "nonce-b-1" lease-id: "lease-sec-rust"))
                   (replay (agentic-ai-lab-ai-agentic-context-subtree-commit
                            med2 gov3 cut3 prop-b-again (.ref issued-b 'token) policy-dig 17)))
              (check (.ref replay 'accepted?) => #f))))))

    (yuanxu-test-case "unauthorized cross-section write and rogue `:PROPERTIES:` injection are refused"
      (let* ((cut1 (context-org-source "shared.org" 1 shared-org-v1))
             (gov1 (agentic-ai-lab-ai-agentic-context-governance-graph 'gov (list cut1)))
             (arch-dig1 (agentic-ai-lab-ai-agentic-context-org-subtree-digest cut1 "sec-arch"))
             ;; Agent 2 only has read `:DEPENDS_ON:` affinity on `sec-arch`, NOT write ownership!
             (cross-write (.o (:: @ AiAgenticContextSubtreeProposal.)
                              source-id: "shared.org" base-generation: 1
                              target-property-id: "sec-arch"
                              agent-id: "agent/rust-worker-02" task-id: "task/write-rust"
                              session-id: "sess-b"
                              expected-subtree-digest: arch-dig1
                              replacement-body: "Hijack!"
                              nonce: "nonce-hijack" lease-id: "lease-x"))
             ;; Owner tries to inject a new headline with a rogue `:ID:` / `:AGENT_ID:` drawer inside body!
             (smuggle-prop (.o (:: @ AiAgenticContextSubtreeProposal.)
                               source-id: "shared.org" base-generation: 1
                               target-property-id: "sec-arch"
                               agent-id: "agent/architect-01" task-id: "task/write-arch"
                               session-id: "sess-a"
                               expected-subtree-digest: arch-dig1
                               replacement-body: "Normal text\n* Injected Section\n:PROPERTIES:\n:ID: injected\n:AGENT_ID: attacker\n:END:\n"
                               nonce: "nonce-smuggle" lease-id: "lease-y")))
        (check (.ref (agentic-ai-lab-ai-agentic-context-subtree-issue-token
                      gov1 cut1 cross-write policy-dig 10 100 0) 'reason)
               => 'gql-write-ineligible)
        (check (.ref (agentic-ai-lab-ai-agentic-context-subtree-issue-token
                      gov1 cut1 smuggle-prop policy-dig 10 100 0) 'reason)
               => 'header-or-structure-escape)))))
