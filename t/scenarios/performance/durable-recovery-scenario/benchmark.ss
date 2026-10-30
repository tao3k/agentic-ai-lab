;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 5ms)
 (sampleCount . 20)
 (targetRationale . "durable recovery scenarios combine runtime-store, memory, session graph, communication, workflow, sandbox, and observability receipts before Marlin handoff.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/durable-recovery-scenario/benchmark.ss")
 (purpose . "observe crash/replay/repair scenario projection into bounded handoff rows")
 (feature . durable-recovery-scenario)
 (rule . AGENTIC-AI-LAB-DURABLE-RECOVERY-SCENARIO-PERFORMANCE-001)
 (optimizationFocus . "defstruct receipt projection with one bounded alist handoff")
 (inputShape . "ninety-six durable recovery scenario receipts projected from shared runtime-store and memory durable job rows")
 (expectedOutcome . "the durable-recovery-scenario scenario preserves its declared semantic result under the ASP P95 gate")
 (expectedRepair . "keep recovery projection batched; do not make runtime consumers traverse POO object graphs")
 (nativePooAuthoring . #t)
 (receiptRepresentation . defstruct)
 (adapterBoundary . "durable recovery scenario rows are report-only ABI alists at Marlin handoff")
 (hotPathExemption . durable-recovery-scenario)
 (hotPathEvidence durable-recovery
                  runtime-store-receipt
                  memory-durable-job
                  session-agent-graph
                  observability-rows
                  bounded-alist-boundary
                  benchmark-contract)
 (expectedQualitySignals batch-projection
                         valid-recovery-scenarios
                         recovery-observability
                         durable-recovery-performance-gate)
 (measurementPhases collect-before
                    policy-before
                    collect-after
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags durable recovery performance scenario receipt-projection))
