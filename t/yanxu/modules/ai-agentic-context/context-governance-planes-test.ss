;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/types
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-trust-lattice
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-epistemic-consolidation)
(export context-governance-planes-test)

(def context-governance-planes-test
  (test-suite "Org-as-Context Six-Plane Governance (Slices 40-45)"
    (yuanxu-test-case "Slice 40: Trust lattice blocks unendorsed/self-endorsed/stale-cut promotion and meets restrictions"
      (let* ((endorsement (agentic-ai-lab-ai-agentic-context-endorsement-receipt
                           "sha256:payload-1" "cut-1" "agent-proposer" "sec-reviewer" 'user-intent))
             (env-a (agentic-ai-lab-ai-agentic-context-restriction-envelope
                     "sec-domain" '("agent-a" "agent-b") '("model-v1" "tui")
                     '("org-read" "org-write") 10 100 'user-intent '("retain-defeaters")))
             (env-b (agentic-ai-lab-ai-agentic-context-restriction-envelope
                     "sec-domain" '("agent-b" "agent-c") '("model-v1")
                     '("org-read") 20 80 'model-proposal '("audit-log")))
             (met (agentic-ai-lab-ai-agentic-context-restriction-meet (list env-a env-b))))
        (check (agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape? endorsement) => #t)
        ;; Self-endorsement is rejected at construction (`T-CTX-01`).
        (check-exception
         (agentic-ai-lab-ai-agentic-context-endorsement-receipt
          "sha256:payload-1" "cut-1" "agent-proposer" "agent-proposer" 'user-intent)
         true)
        ;; Non-escalating needs no endorsement; unendorsed escalation fails closed.
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-trust-promotion
                      'model-proposal 'observed-fact "sha256:payload-1" "cut-1" "agent-proposer")
                     'accepted?) => #t)
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-trust-promotion
                      'untrusted-data 'user-intent "sha256:payload-1" "cut-1" "agent-proposer")
                     'reason) => 'unendorsed-trust-escalation)
        ;; Valid live-cut endorsement promotes; cut drift (`cut-2`) immediately invalidates (`T-CTX-07`).
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-trust-promotion
                      'untrusted-data 'user-intent "sha256:payload-1" "cut-1" "agent-proposer" endorsement)
                     'accepted?) => #t)
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-trust-promotion
                      'untrusted-data 'user-intent "sha256:payload-1" "cut-2" "agent-proposer" endorsement)
                     'reason) => 'stale-endorsement-cut)
        ;; Restriction meet (`sqcap`) narrows readers/destinations/capabilities/lease/trust and unions obligations (`T-CTX-02`).
        (check (.ref met 'readers) => '("agent-b"))
        (check (.ref met 'destinations) => '("model-v1"))
        (check (.ref met 'capabilities) => '("org-read"))
        (check (.ref met 'lease-start) => 20)
        (check (.ref met 'lease-end) => 80)
        (check (.ref met 'trust-ceiling) => 'model-proposal)
        (check (.ref met 'obligations) => '("audit-log" "retain-defeaters"))
        ;; Gate 4: Active critical threat blocks handoff (`T-CTX-06`); cross-domain KV reuse is blocked (`T-CTX-04`).
        (check (.ref (agentic-ai-lab-ai-agentic-context-handoff-assess
                      "cut-1" "cut-1" #t met 'observed-fact 50 'critical 'exposed)
                     'reason) => 'active-high-or-critical-threat)
        (check (.ref (agentic-ai-lab-ai-agentic-context-handoff-assess
                      "cut-1" "cut-1" #t met 'observed-fact 50 'critical 'latent)
                     'handoff-ready?) => #t)
        (check (.ref (agentic-ai-lab-ai-agentic-context-kv-prefix-admit
                      "tenant-a" "agent-b" (.ref met 'semantic-digest) "tok-prefix-1"
                      "tenant-b" "agent-b" (.ref met 'semantic-digest) "tok-prefix-1")
                     'reason) => 'cross-domain-kv-blocked)))

    (yuanxu-test-case "Slices 41 & 43: Non-droppable defeater kernel, OmittedAlternativesReceipt and asymmetric ASCENT branch gate"
      (let* ((hyps (list (.o id: "h1_ci_key" cost: 2 defeaters: '("D1_net_policy"))
                         (.o id: "h2_webhook" cost: 2 defeaters: '())
                         (.o id: "h3_benign_canary" cost: 2 defeaters: '())))
             ;; Tight budget 3 cannot fit restriction(1) + h1(2) + D1(1) = 4 -> fails closed rather than stripping D1!
             (too-tight (agentic-ai-lab-ai-agentic-context-project-epistemic
                         "inq-43" "sha256:r1" 1 hyps '("h1_ci_key") 3))
             ;; Budget 6 fits h1(2) + D1(1) + h2(2) + r(1) = 6, omitting h3_benign_canary with receipt!
             (partial (agentic-ai-lab-ai-agentic-context-project-epistemic
                       "inq-43" "sha256:r1" 1 hyps '("h1_ci_key" "h2_webhook") 6))
             ;; Budget 8 fits all three -> exhaustive!
             (full (agentic-ai-lab-ai-agentic-context-project-epistemic
                    "inq-43" "sha256:r1" 1 hyps '("h1_ci_key" "h2_webhook" "h3_benign_canary") 8))
             (b1-read (.o id: "b1-audit" branch-kind: 'read-discriminator
                          evaluated-hypotheses: '("h1_ci_key" "h2_webhook")
                          scope-grant-active?: #t
                          used-missing-claim-shortcut?: #f
                          used-hypothetical-fit-shortcut?: #f))
             (b2-quarantine (.o id: "b2-quarantine" branch-kind: 'destructive-remediation
                                evaluated-hypotheses: '("h1_ci_key" "h2_webhook" "h3_benign_canary")
                                scope-grant-active?: #t
                                used-missing-claim-shortcut?: #f
                                used-hypothetical-fit-shortcut?: #f)))
        (check (.ref too-tight 'admitted?) => #f)
        (check (.ref too-tight 'status) => 'refused-over-budget)
        (check (.ref partial 'admitted?) => #t)
        (check (.ref partial 'retained-defeaters) => '("D1_net_policy"))
        (check (.ref partial 'claims-exhaustive?) => #f)
        (check (agentic-ai-lab-ai-agentic-context-omitted-alternatives-receipt-shape?
                (.ref partial 'omission-receipt)) => #t)
        (check (.ref (.ref partial 'omission-receipt) 'omitted-hypotheses) => '("h3_benign_canary"))
        ;; Read-discriminator B1 is admitted under partial view; destructive B2 is blocked until H3 is included!
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-security-branch partial b1-read) 'admitted?) => #t)
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-security-branch partial b2-quarantine) 'reason)
               => 'destructive-branch-blocked-by-omitted-alternatives)
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-security-branch full b2-quarantine) 'admitted?) => #t)))

    (yuanxu-test-case "Slice 42: Cross-repo controlled declassification blocks ambient raw leaks and enforces 3-party SoD"
      (let (cert (agentic-ai-lab-ai-agentic-context-declassification-cert
                  "repo-core" "repo-sdk" "c1" "s1"
                  "sha256:raw-exploit" "sha256:redacted-invariant" #t
                  "agent-coord" "sec-declassifier" "agent-sdk"
                  'observed-fact 'observed-fact))
        (check (agentic-ai-lab-ai-agentic-context-declassification-cert-shape? cert) => #t)
        ;; Delivering raw digest is strictly blocked even with an active cert!
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-declassification
                      #t #t cert "c1" "s1" "agent-sdk" "sha256:raw-exploit")
                     'reason) => 'raw-payload-leak-blocked)
        ;; Delivering redacted digest at live cuts succeeds; cut drift (`c2`) withdraws eligibility!
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-declassification
                      #t #t cert "c1" "s1" "agent-sdk" "sha256:redacted-invariant")
                     'admitted?) => #t)
        (check (.ref (agentic-ai-lab-ai-agentic-context-admit-declassification
                      #t #t cert "c2" "s1" "agent-sdk" "sha256:redacted-invariant")
                     'reason) => 'cross-repo-cut-drifted)))

    (yuanxu-test-case "Slices 44 & 45: Causal-survival memory quotient (zero unused-retrieval debt) and receipt-unique provider join"
      (let* ((base-req (.o insight-id: "mem-q1"
                           proposer: "agent-1" evidence-owner: "host-ev" approver: "reviewer-2"
                           outcome-receipt-digest: "sha256:outcome-1" outcome-supported?: #t
                           cited-premises: '("prem-used-1" "prem-used-2")
                           defeat-conditions: '("if-timeout-recurs")
                           raw-cost: 120 quotient-cost: 24
                           audit-hook-id: "hook-rev-dep-1"
                           uses-why-not?: #t watermark-covered?: #t
                           promote-to-org?: #t org-write-grant?: #t))
             (admitted (agentic-ai-lab-ai-agentic-context-admit-consolidation base-req)))
        (check (agentic-ai-lab-ai-agentic-context-consolidation-receipt-shape? admitted) => #t)
        (check (.ref admitted 'admitted?) => #t)
        (check (.ref admitted 'org-promoted?) => #t)
        ;; Retracting an exploratory `prem-unused-99` leaves `quotient-survives?` TRUE (zero invalidation burden);
        ;; retracting `prem-used-2` immediately withdraws active survival while retaining audit history!
        (check (.ref (agentic-ai-lab-ai-agentic-context-quotient-survives?
                      admitted #t #t '("prem-used-1" "prem-used-2") '("prem-used-1" "prem-used-2"))
                     'survives?) => #t)
        (let (withdrawn (agentic-ai-lab-ai-agentic-context-quotient-survives?
                         admitted #t #t '("prem-used-1") '("prem-used-1" "prem-used-2")))
          (check (.ref withdrawn 'survives?) => #f)
          (check (.ref withdrawn 'reason) => 'cited-premise-retracted-or-uncertain)
          (check (.ref withdrawn 'historical-audit-retained?) => #t))
        ;; Slice 45: Multi-provider GQL + ASCENT join rejects conflicting retry at same generation!
        (let ((r-gql (.o provider: 'org-gql generation: 2 result-digest: "d1" complete?: #t))
              (r-asc-ok (.o provider: 'ascent generation: 2 result-digest: "d2" complete?: #t))
              (r-asc-bad-retry (.o provider: 'ascent generation: 2 result-digest: "d2" complete?: #f)))
          (check (.ref (agentic-ai-lab-ai-agentic-context-join-provider-receipts
                        2 '(org-gql ascent) (list r-gql r-asc-ok))
                       'published?) => #t)
          (check (.ref (agentic-ai-lab-ai-agentic-context-join-provider-receipts
                        2 '(org-gql ascent) (list r-gql r-asc-ok r-asc-bad-retry))
                       'reason) => 'conflicting-same-generation-provider-retry))))))
