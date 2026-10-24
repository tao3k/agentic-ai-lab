;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 8ms)
 (sampleCount . 20)
 (targetRationale . "custom user-interface scenario aggregation is the public acceptance surface for downstream POO-native cases and must stay bounded.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/user-interface-custom-scenario-batch/benchmark.ss")
 (rule . AGENTIC-AI-LAB-USER-INTERFACE-PERFORMANCE-002)
 (feature . user-interface-custom-scenario-batch)
 (optimizationFocus . "batch aggregation of custom user-interface scenario rows without executing runtime, sandbox, provider, tool, or durable store work")
 (inputShape . "custom/my-module scenarios spanning cicd, funflow, loop-engine, session transform/policy/topology/materialization, durable session memory, tool-core, memory-core, and durable recovery/store handoff cases")
 (expectedOutcome . pass)
 (expectedRepair . "keep scenario fixtures in t/scenarios/performance, keep user-interface declarations POO-native, and summarize final report rows without moving benchmark contracts into user modules")
 (nativePooAuthoring . #t)
 (runtimeExecuted . #f)
 (hotPathExemption . user-interface-custom-scenario-batch)
 (hotPathEvidence native-poo-authoring
                  custom-user-interface-scenarios
                  report-only-runtime-boundary
                  batch-scenario-aggregation
                  benchmark-contract)
 (measurementPhases collect-before
                    policy-before
                    collect-after
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags poo user-interface scenarios performance))
