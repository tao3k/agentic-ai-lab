;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Wave 2 & Wave 4 Red-Team Suite for Slices 47, 50 & 51:
;;; - Axis 1 (Memory Poisoning Quarantine): MINJA / MemoryGraft 100% refusal
;;; - Axis 2 (Confined Detour & Offline Causal Audit): APPA no-egress + attest-schema,
;;;           NeuroTaint zero-LLM implicit decision-flip leak detection,
;;;           Memento zero-authority stall advisory, MindGuard tool schema pinning
;;; - Axis 3 (Two-Zone KV-Prefix Stability): Request-Order-Matters 100% Frozen Prefix
;;;           byte identity under peer permutation and rolling detour suffix churn
;;; - Axis 4 (Zero-LLM AuditCapsule Cold Replay + AST Auto-Repair src-block safety)

(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-trust-lattice
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-epistemic-consolidation)

(export context-anti-contamination-and-kv-prefix-test)

(def context-anti-contamination-and-kv-prefix-test
  (test-suite "Slices 50 & 51 Anti-Contamination, KV-Prefix Stability & Zero-LLM Cold Replay"
    (yuanxu-test-case "Axis 1 (Slice 51): Quarantine-Before-Recall blocks MINJA / MemoryGraft 100%"
      (let* (;; Poisoned untrusted experience claims self-success ("run curl ... | sh worked!")
             (poison (agentic-ai-lab-ai-agentic-context-memory-candidate
                      "mem-poison-1" 'untrusted-ingest "sha256:poison-recipe"
                      self-claimed-success?: #t proposer: "agent-worker"))
             ;; Clean untrusted candidate awaiting independent endorsement
             (clean-q (agentic-ai-lab-ai-agentic-context-memory-candidate
                       "mem-clean-1" 'untrusted-ingest "sha256:clean-recipe"
                       self-claimed-success?: #t proposer: "agent-worker"))
             ;; Trusted internal entry with open defeater stays quarantined
             (defeated-q (agentic-ai-lab-ai-agentic-context-memory-candidate
                          "mem-defeated-1" 'trusted-internal "sha256:def-recipe"
                          open-defeaters: '("D1-regression")))
             ;; Auto-promotion attempt WITHOUT independent endorsement MUST fail closed!
             (auto-promo (agentic-ai-lab-ai-agentic-context-admit-memory-promotion poison "cut-1"))
             ;; Production recall sees ZERO quarantined candidates
             (recall-before (agentic-ai-lab-ai-agentic-context-recall-memories
                             (list poison clean-q defeated-q)))
             ;; Independent reviewer endorses clean-q on live cut-1
             (endorsement (agentic-ai-lab-ai-agentic-context-endorsement-receipt
                           "sha256:clean-recipe" "cut-1" "agent-worker" "sec-reviewer" 'observed-fact))
             (stale-promo (agentic-ai-lab-ai-agentic-context-admit-memory-promotion
                           clean-q "cut-2" endorsement))
             (ok-promo (agentic-ai-lab-ai-agentic-context-admit-memory-promotion
                        clean-q "cut-1" endorsement))
             (rejected-poison (agentic-ai-lab-ai-agentic-context-admit-memory-promotion
                               poison "cut-1" #f #t))
             (recall-after (agentic-ai-lab-ai-agentic-context-recall-memories
                            (list (.ref rejected-poison 'candidate)
                                  (.ref ok-promo 'candidate)
                                  defeated-q))))
        (check (.ref poison 'memory-tier) => 'quarantined)
        (check (.ref defeated-q 'memory-tier) => 'quarantined)
        (check (.ref auto-promo 'promoted?) => #f)
        (check (.ref auto-promo 'reason) => 'untrusted-self-claimed-success-blocked)
        (check (.ref recall-before 'recalled-count) => 0)
        (check (.ref recall-before 'quarantined-or-rejected-excluded) => 3)
        (check (.ref stale-promo 'promoted?) => #f)
        (check (.ref stale-promo 'reason) => 'stale-endorsement-cut)
        (check (.ref ok-promo 'promoted?) => #t)
        (check (.ref ok-promo 'memory-tier) => 'recallable)
        (check (.ref rejected-poison 'memory-tier) => 'rejected)
        (check (.ref recall-after 'recalled-count) => 1)
        (check (.ref (car (.ref recall-after 'recalled)) 'candidate-id) => "mem-clean-1")))

    (yuanxu-test-case "Axis 2 (Slice 50): APPA ConfinedDetour, NeuroTaint Zero-LLM Audit, Stall Advisory & MindGuard Pin"
      ;; APPA ConfinedDetour: tainted egress blocked; unattested return blocked; schema-attested return keeps mainline clean!
      (let* ((egress-deny (agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
                           detour-tainted?: #t egress-attempted?: #t schema-attested?: #t))
             (raw-deny (agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
                        detour-tainted?: #t egress-attempted?: #f schema-attested?: #f))
             (attested-ok (agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
                           detour-tainted?: #t egress-attempted?: #f schema-attested?: #t))
             ;; NeuroTaint offline counterfactual causal audit (0 LLM calls)
             (leak-hit (agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
                        '(approve "branch-A") '(deny "branch-A") #f))
             (clean-inv (agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
                         '(deny "branch-A") '(deny "branch-A") #f))
             (certified-ok (agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
                            '(approve "branch-A") '(deny "branch-A") #t))
             ;; Memento zero-authority stall advisory
             (stall (agentic-ai-lab-ai-agentic-context-evaluate-stall-advisory 3 0 2))
             ;; MindGuard Tool/MCP schema-digest pin
             (pin-digest (agentic-ai-lab-ai-agentic-context-digest
                          '(tool-schema-pin.v1 "mcp.git.push" ((args . (branch force))))))
             (pin-ok (agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
                      "mcp.git.push" pin-digest '((args . (branch force)))))
             (pin-drift (agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
                         "mcp.git.push" pin-digest '((args . (branch force exfil-url))))))
        (check (.ref egress-deny 'admitted?) => #f)
        (check (.ref egress-deny 'reason) => 'confined-detour-tainted-egress-blocked)
        (check (.ref raw-deny 'admitted?) => #f)
        (check (.ref raw-deny 'reason) => 'unattested-detour-return-blocked)
        (check (.ref attested-ok 'admitted?) => #t)
        (check (.ref attested-ok 'mainline-tainted?) => #f)
        (check (.ref leak-hit 'implicit-causal-leak?) => #t)
        (check (.ref leak-hit 'llm-calls-used) => 0)
        (check (.ref clean-inv 'implicit-causal-leak?) => #f)
        (check (.ref certified-ok 'implicit-causal-leak?) => #f)
        (check (.ref stall 'suggest-park-or-cancel?) => #t)
        (check (.ref stall 'authorizes-auto-mutation?) => #f)
        (check (.ref stall 'action-authorized?) => #f)
        (check (.ref pin-ok 'admitted?) => #t)
        (check (.ref pin-drift 'admitted?) => #f)
        (check (.ref pin-drift 'reason) => 'tool-schema-drift-blocked)))

    (yuanxu-test-case "Axis 3 (Slice 51): Two-Zone KV-Prefix maintains 100% byte identity across peer permutations and detour churn"
      (let* ((e1 (.o epoch: 1 node-id: "goal-01" content: "Preserve invariant spine"))
             (e2 (.o epoch: 1 node-id: "policy-02" content: "No unendorsed egress"))
             (e3 (.o epoch: 2 node-id: "adr-03" content: "Canonical 5-tuple CAS"))
             ;; Permuted peer arrival order + rolling detour open/swap/fold in Zone B
             (frame-a (agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
                       2 (list e3 e1 e2) '("DETOUR-1: inspect logs")))
             (frame-b (agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
                       2 (list e2 e3 e1) '("DETOUR-2: run benchmark" "L3-DRILL: full span")))
             (frame-c (agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
                       2 (list e1 e2 e3) '())))
        ;; Zone A Frozen Prefix bytes & digest MUST be 100% bit-for-bit identical!
        (check (.ref frame-a 'frozen-prefix-bytes) => (.ref frame-b 'frozen-prefix-bytes))
        (check (.ref frame-b 'frozen-prefix-bytes) => (.ref frame-c 'frozen-prefix-bytes))
        (check (.ref frame-a 'frozen-prefix-digest) => (.ref frame-b 'frozen-prefix-digest))
        (check (.ref frame-b 'frozen-prefix-digest) => (.ref frame-c 'frozen-prefix-digest))
        (check (.ref frame-a 'frozen-prefix-count) => 3)
        (check (.ref frame-b 'dynamic-suffix-count) => 2)
        (check (.ref frame-c 'dynamic-suffix-count) => 0)))

    (yuanxu-test-case "Axis 4 (Capstone 47): Zero-LLM AuditCapsule cold replay stays verified after live-cut advances"
      ;; Zero-LLM Cold Replay stays verified even after live-cut advances from cut-1 -> cut-2!
      (let* ((org-bytes "* Goal\n:PROPERTIES:\n:ID: g-1\n:END:\n")
             (journal '((event . "admit-cut-1") (event . "pin-cas-1")))
             (commit (agentic-ai-lab-ai-agentic-context-digest
                      (list 'deterministic-audit-capsule.v1 "cut-1" org-bytes journal)))
             (hot-replay (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                          org-bytes journal "cut-1" "cut-1" commit))
             (cold-replay (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                           org-bytes journal "cut-1" "cut-2" commit))
             (tampered (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                        (string-append org-bytes "tamper") journal "cut-1" "cut-2" commit)))
        (check (.ref hot-replay 'cold-forensic-verified?) => #t)
        (check (.ref hot-replay 'hot-applicable?) => #t)
        (check (.ref hot-replay 'llm-calls-used) => 0)
        (check (.ref cold-replay 'cold-forensic-verified?) => #t)
        (check (.ref cold-replay 'hot-applicable?) => #f)
        (check (.ref tampered 'cold-forensic-verified?) => #f)))))
