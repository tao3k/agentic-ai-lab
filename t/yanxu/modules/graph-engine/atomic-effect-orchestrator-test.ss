;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Scheme POO High-Order Orchestration over Marlin Thin Atomic Effects:
;;; FunFlow CAS purity/cache hit-miss, Two-Zone KV-Prefix verification, Scoped
;;; Detour blocker gating, Sandbox effect boundary, and Competing Hypothesis
;;; Branch Matrix evaluation (`t/yanxu/modules/graph-engine/atomic-effect-orchestrator-test.ss`).

(import :std/test
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/graph-engine/interface)

(export atomic-effect-orchestrator-test)

(def (make-test-actor-and-ctx)
  (let* ((env (make-capability-envelope
               "owner"
               allowed-caps: '(context-read)
               denied-caps: '(host-egress)
               egress-allowed?: #f))
         (ob (make-obligation "ob-1" title: "Verify" required-evidence-ids: '("ev-1")))
         (g (make-obligation-graph "g-eff" cut: 2 obligations: (list ob) evidence: '() det-tasks: '()))
         (trunk (make-context-trunk "trunk-eff" "ob-1" g env
                                    shared-context-cut: 2
                                    kv-prefix-digest: "sha256:frozen-zone1-digest"))
         (actor (graph-make-task-actor "task-eff-01" trunk '("scope-main") title: "Effect Orchestration"))
         (ctx (.o bind-these: #f
                  context-cut: 2
                  kv-prefix-digest: "sha256:frozen-zone1-digest"
                  disclosure-depth: 'L3
                  has-active-defeater?: #t
                  sandbox-admitted?: #t
                  cedar-handoff-valid?: #t)))
    (values actor ctx)))

(def atomic-effect-orchestrator-test
  (test-suite "graph-engine-atomic-effect-orchestrator"

    (test-case "Pure FunFlow step emits CasGet first, short-circuits on CasHit with 0 LLM calls, and enforces Two-Zone + L3 floor on CasMiss"
      (let-values (((actor ctx) (make-test-actor-and-ctx)))
        (let* ((step (make-funflow-step-spec
                      "step-analyze"
                      purity: 'pure-cas
                      input-digest: "sha256:in-01"
                      endpoint: "openai/gpt-marlin"))
               (plan (plan-funflow-step-effects step actor ctx)))
          (check (.ref plan 'admitted?) => #t)
          (check (length (.ref plan 'effects)) => 1)
          (check (.ref (car (.ref plan 'effects)) 'kind) => 'cas-get)

          ;; 1. CAS hit -> completed immediately with 0 LLM/sandbox effects!
          (let* ((hit-rcpt (make-cas-hit-receipt "cas-get:step-analyze" "cached-analysis-v1"))
                 (res-hit (reconcile-funflow-step-receipts step actor ctx (list hit-rcpt))))
            (check (.ref res-hit 'status) => 'completed)
            (check (.ref res-hit 'cache-hit?) => #t)
            (check (.ref res-hit 'output) => "cached-analysis-v1")
            (check (.ref res-hit 'next-effects) => '()))

          ;; 2. CAS miss with tampered KV-Prefix digest -> rejected fail-closed!
          (let* ((miss-rcpt (make-cas-miss-receipt "cas-get:step-analyze"))
                 (bad-prompt (make-two-zone-prompt-spec
                              "ZONE1" "sha256:tampered" "tail" disclosure-depth: 'L3))
                 (res-bad (reconcile-funflow-step-receipts
                           step actor ctx (list miss-rcpt) two-zone-prompt: bad-prompt)))
            (check (.ref res-bad 'status) => 'rejected)
            (check (.ref res-bad 'reason) => 'kv-prefix-digest-mismatch)
            (check (.ref res-bad 'next-effects) => '()))

          ;; 3. CAS miss with L1 below active-defeater L3 floor -> rejected fail-closed!
          (let* ((miss-rcpt (make-cas-miss-receipt "cas-get:step-analyze"))
                 (low-prompt (make-two-zone-prompt-spec
                              "ZONE1" "sha256:frozen-zone1-digest" "tail" disclosure-depth: 'L1))
                 (res-low (reconcile-funflow-step-receipts
                           step actor ctx (list miss-rcpt) two-zone-prompt: low-prompt)))
            (check (.ref res-low 'status) => 'rejected)
            (check (.ref res-low 'reason) => 'disclosure-floor-violation))

          ;; 4. CAS miss with valid Two-Zone L3 prompt -> emits LlmCompleteEffect, then CasPutEffect!
          (let* ((miss-rcpt (make-cas-miss-receipt "cas-get:step-analyze"))
                 (good-prompt (make-two-zone-prompt-spec
                               "ZONE1" "sha256:frozen-zone1-digest" "Analyze delta" disclosure-depth: 'L3))
                 (res-miss (reconcile-funflow-step-receipts
                            step actor ctx (list miss-rcpt) two-zone-prompt: good-prompt)))
            (check (.ref res-miss 'status) => 'awaiting-effect)
            (check (length (.ref res-miss 'next-effects)) => 1)
            (check (.ref (car (.ref res-miss 'next-effects)) 'kind) => 'llm-complete)
            (let* ((llm-rcpt (make-llm-completed-receipt "llm:step-analyze" "fresh-analysis-v2"))
                   (res-done (reconcile-funflow-step-receipts step actor ctx (list llm-rcpt))))
              (check (.ref res-done 'status) => 'completed)
              (check (.ref res-done 'output) => "fresh-analysis-v2")
              (check (length (.ref res-done 'next-effects)) => 1)
              (check (.ref (car (.ref res-done 'next-effects)) 'kind) => 'cas-put))))))

    (test-case "Sandboxed effect never skips via CAS and BlockerActive detour halts trunk-mutating effects"
      (let-values (((actor ctx) (make-test-actor-and-ctx)))
        (let* ((sb-step (make-funflow-step-spec
                         "step-run-build"
                         purity: 'sandboxed-effect
                         program: "cargo"
                         args: '("test")
                         mutates-trunk?: #t))
               (plan-ok (plan-funflow-step-effects sb-step actor ctx)))
          (check (.ref plan-ok 'admitted?) => #t)
          (check (.ref (car (.ref plan-ok 'effects)) 'kind) => 'sandbox-run)
          ;; Speculative CAS hit on a sandboxed step is strictly rejected!
          (let ((bad-cas (reconcile-funflow-step-receipts
                          sb-step actor ctx (list (make-cas-hit-receipt "sandbox:step-run-build" "fake")))))
            (check (.ref bad-cas 'status) => 'rejected)
            (check (.ref bad-cas 'reason) => 'sandboxed-effect-cannot-skip-via-cas))

          ;; BlockerActive Scoped Detour halts trunk-mutating sandbox step fail-closed!
          (let* ((detoured (.ref (graph-enter-task-actor-detour actor 'blocker-active "det-blk-1") 'actor))
                 (plan-blocked (plan-funflow-step-effects sb-step detoured ctx)))
            (check (.ref plan-blocked 'admitted?) => #f)
            (check (.ref plan-blocked 'reason) => 'blocker-detour-blocks-trunk-mutation)
            (check (.ref plan-blocked 'effects) => '())))))

    (test-case "Competing Hypothesis Frontier evaluates every branch against every hypothesis without collapsing or authorizing effects"
      (let-values (((actor ctx) (make-test-actor-and-ctx)))
        (let* ((h1 (make-competing-hypothesis
                    "H1" "Credential theft via compromised CI token"
                    evidence-lineage: '("log:ci-token-use")
                    contradictions: '("clock-skew-on-runner")
                    open-questions: '("was-token-rotated?")))
               (h2 (make-competing-hypothesis
                    "H2" "Benign misconfigured release automation"
                    evidence-lineage: '("commit:release-bot")
                    contradictions: '()
                    open-questions: '("who-approved-workflow?")))
               (b1 (make-hypothesis-branch-proposal
                    "B1" "Check runner audit trail"
                    evidence-refs: '("audit:runner-42")))
               (b2 (make-hypothesis-branch-proposal
                    "B2" "Compare artifact signature provenance"
                    evidence-refs: '("sig:cosign-01")))
               (plan (plan-competing-hypothesis-frontier actor (list h1 h2) (list b1 b2) ctx)))
          ;; 2 hypotheses x 2 branches = 4 parallel read-only atomic effects for Rust Tokio pump
          (check (.ref plan 'cell-count) => 4)
          (check (length (.ref plan 'effects)) => 4)
          (check (.ref plan 'authorizes-effect?) => #f)

          ;; Provide receipts for 3 of 4 cells (leaving 1 unobserved to verify missing claims become open questions, not likelihood!)
          (let* ((receipts
                  (list (make-llm-completed-receipt "hyp:H1::br:B1" "runner log aligns with CI window")
                        (make-llm-completed-receipt "hyp:H1::br:B2" "signature mismatch unresolved")
                        (make-llm-completed-receipt "hyp:H2::br:B1" "release bot invoked at same timestamp")))
                 (matrix (reconcile-competing-hypothesis-matrix (list h1 h2) (list b1 b2) receipts)))
            (check (.ref matrix 'preserved-hypothesis-count) => 2)
            (check (length (.ref matrix 'cells)) => 4)
            (check (.ref matrix 'favored-path-collapsed?) => #f)
            (check (.ref matrix 'missing-claim-likelihood-inferred?) => #f)
            (check (.ref matrix 'authenticates-evidence?) => #f)
            (check (.ref matrix 'establishes-attribution?) => #f)
            (check (.ref matrix 'authorizes-effect?) => #f)
            (displayln "GRAPH-ENGINE-ATOMIC-EFFECT-ORCHESTRATOR-OK")))))))
