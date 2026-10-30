;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 8ms)
 (sampleCount . 20)
 (targetRationale . "durable policy projection is a shared hot path: session, memory, workflow, sandbox, and artifact policies must lower to fixed receipts before runtime handoff.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/durable-policy-batch-projection/benchmark.ss")
 (purpose . "observe POO durable policy batch projection into struct receipts and bounded alist ABI rows")
 (feature . durable-policy-batch-projection)
 (rule . AGENTIC-AI-LAB-DURABLE-POLICY-PERFORMANCE-001)
 (optimizationFocus . "POO durable authoring with defstruct runtime receipts and one bounded serialization pass")
 (inputShape . "sixty-four POO durable policy objects projected to struct receipts and bounded alists")
 (expectedOutcome . "the durable-policy-batch-projection scenario preserves its declared semantic result under the ASP P95 gate")
 (expectedRepair . "keep durable policy validation/projection batched; do not make runtime consumers traverse POO object graphs")
 (nativePooAuthoring . #t)
 (receiptRepresentation . defstruct)
 (adapterBoundary . "durable policy receipts are structs until ABI alist projection")
 (hotPathExemption . durable-policy-batch-projection)
 (hotPathEvidence native-poo-authoring
                  defstruct-runtime-receipt
                  durable-policy
                  batch-projection
                  bounded-alist-boundary
                  benchmark-contract)
 (expectedQualitySignals batch-projection
                         struct-durable-receipts
                         bounded-abi-rows
                         durable-performance-gate)
 (measurementPhases collect-before
                    policy-before
                    collect-after
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags poo durable performance receipt-projection))
