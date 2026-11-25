;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; End-to-End Pure Scheme Unified Execution Driver Tests
;;; (`t/yanxu/modules/graph-engine/unified-effect-driver-test.ss`):
;;;   1. Strict Deterministic-First Precedence (ASCENT + C4 Bernstein wave -> 0 LLM calls)
;;;   2. BlockerActive Detour halts trunk-mutating steps & settlement fail-closed
;;;   3. Competing Hypothesis Matrix evaluation after deterministic tasks drain,
;;;      preserving all hypotheses, contradictions, open questions, and authorizes-effect? = #f
;;;   4. Quiescent Fixed Point once hypotheses are preserved and detour returns to mainline.

(import :std/test
        (only-in :clan/poo/object .o .ref)
        :tao3k/agentic-ai-lab/modules/graph-engine/interface)

(export unified-effect-driver-test)

(def (make-base-ctx)
  (.o bind-these: #f
      context-cut: 3
      kv-prefix-digest: "sha256:unified-zone1-digest"
      disclosure-depth: 'L3
      has-active-defeater?: #f
      sandbox-admitted?: #t
      cedar-handoff-valid?: #t))

(def (make-actor-for-graph g)
  (let* ((env (make-capability-envelope
               "owner"
               allowed-caps: '(context-read)
               denied-caps: '(host-egress)
               egress-allowed?: #f))
         (trunk (make-context-trunk "trunk-uni" "ob-root" g env
                                    shared-context-cut: 3
                                    kv-prefix-digest: "sha256:unified-zone1-digest")))
    (graph-make-task-actor "task-uni-01" trunk '("scope-main") title: "Unified Driver")))

(def unified-effect-driver-test
  (test-suite "graph-engine-unified-effect-driver"

    (test-case "ASCENT enforces deterministic-first precedence (0 LLM calls), then evaluates competing hypotheses and halts on blocker-active detour"
      (let* ((ob (make-obligation "ob-root" title: "Root Check" required-evidence-ids: '("ev-det")))
             (det-task (make-deterministic-task-node
                        "det-scan-1"
                        "ob-root"
                        "ev-det"
                        'funflow-scan
                        "src/a.ss"
                        effect-class: 'pure-cas
                        read-footprint: '("src/a.ss")
                        write-footprint: '()))
             (h1 (make-competing-hypothesis
                  "H1" "Supply chain artifact tampering"
                  evidence-lineage: '("ev:hash-diff")
                  contradictions: '("build-repro-matched")
                  open-questions: '("check-builder-attestation?")))
             (h2 (make-competing-hypothesis
                  "H2" "Non-deterministic timestamp in archive header"
                  evidence-lineage: '("ev:mtime-delta")
                  contradictions: '()
                  open-questions: '("is-SOURCE_DATE_EPOCH-set?")))
             (b1 (make-hypothesis-branch-proposal "B1" "Inspect cosign bundle"))
             (b2 (make-hypothesis-branch-proposal "B2" "Diff tar headers"))
             (g-wave1 (make-obligation-graph
                       "g-uni-1" cut: 3
                       obligations: (list ob)
                       evidence: '()
                       det-tasks: (list det-task)))
             (actor0 (make-actor-for-graph g-wave1))
             (ctx (make-base-ctx))
             (st0 (make-unified-driver-state
                   actor0 g-wave1 ctx
                   competing-hypotheses: (list h1 h2)
                   branch-proposals: (list b1 b2)))
             ;; Wave 1: Deterministic task is ready -> MUST run FunFlow `cas-get` with 0 LLM calls!
             (step1 (drive-graph-actor-step st0)))
        (check (.ref step1 'phase) => 'deterministic-funflow-wave)
        (check (.ref step1 'llm-calls-emitted) => 0)
        (check (length (.ref step1 'effects)) => 1)
        (check (.ref (car (.ref step1 'effects)) 'kind) => 'cas-get)
        (check (.ref step1 'authorizes-effect?) => #f)

        ;; Wave 2: Deterministic task completed + evidence admitted -> competing hypothesis frontier fans out 2x2=4 parallel effects!
        (let* ((ev (make-evidence-fact "ev-det" "det-scan-verified" cut: 3))
               (g-wave2 (make-obligation-graph
                         "g-uni-2" cut: 3
                         obligations: (list ob)
                         evidence: (list ev)
                         det-tasks: (list det-task)
                         completed-tasks: '("det-scan-1")))
               (st1 (make-unified-driver-state
                     actor0 g-wave2 ctx
                     competing-hypotheses: (list h1 h2)
                     branch-proposals: (list b1 b2)))
               (step2 (drive-graph-actor-step st1)))
          (check (.ref step2 'phase) => 'evaluating-competing-hypotheses)
          (check (.ref step2 'llm-calls-emitted) => 4)
          (check (length (.ref step2 'effects)) => 4)
          (check (.ref step2 'authorizes-effect?) => #f)

          ;; Wave 3: Feed raw parallel receipts back while actor is in BlockerActive detour ->
          ;; CompetingHypothesisMatrix is preserved, AND blocker-active halts settlement!
          (let* ((detoured (.ref (graph-enter-task-actor-detour actor0 'blocker-active "det-blk-uni") 'actor))
                 (st2 (make-unified-driver-state
                       detoured g-wave2 ctx
                       competing-hypotheses: (list h1 h2)
                       branch-proposals: (list b1 b2)))
                 (rcpts (list (make-llm-completed-receipt "hyp:H1::br:B1" "attestation pending")
                              (make-llm-completed-receipt "hyp:H1::br:B2" "tar mtime differs")
                              (make-llm-completed-receipt "hyp:H2::br:B1" "sig matches builder")
                              (make-llm-completed-receipt "hyp:H2::br:B2" "SOURCE_DATE_EPOCH unset")))
                 (step3 (drive-graph-actor-step st2 rcpts))
                 (mat (.ref step3 'hypothesis-matrix)))
            (check (.ref step3 'phase) => 'blocker-detour-halting-settlement)
            (check (.ref step3 'effects) => '())
            (check (.ref mat 'preserved-hypothesis-count) => 2)
            (check (.ref mat 'favored-path-collapsed?) => #f)
            (check (.ref mat 'authorizes-effect?) => #f)

            ;; Wave 4: Exit detour via `absorb-and-continue` -> reaches quiescent-fixed-point cleanly!
            (let* ((exited (.ref (graph-exit-task-actor-detour detoured 'absorb-and-continue) 'actor))
                   (st3 (make-unified-driver-state
                         exited g-wave2 ctx
                         competing-hypotheses: (list h1 h2)
                         branch-proposals: (list b1 b2)
                         hypothesis-matrix: mat))
                   (step4 (drive-graph-actor-step st3)))
              (check (.ref step4 'phase) => 'quiescent-fixed-point)
              (check (.ref step4 'llm-calls-emitted) => 0)
              (check (.ref step4 'effects) => '())
              (displayln "GRAPH-ENGINE-UNIFIED-EFFECT-DRIVER-OK"))))))))
