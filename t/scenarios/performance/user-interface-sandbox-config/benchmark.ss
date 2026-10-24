;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 8ms)
 (sampleCount . 20)
 (targetRationale . "sandbox user-interface config is a public POO-native declaration surface and must stay bounded while proving no backend runtime is realized.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/user-interface-sandbox-config/benchmark.ss")
 (rule . AGENTIC-AI-LAB-USER-INTERFACE-PERFORMANCE-003)
 (feature . user-interface-sandbox-config)
 (optimizationFocus . "sandbox module feature lookup and default sandbox profile presentation without descriptor realization or backend execution")
 (inputShape . "kernel user profile selecting nono, cube, and docker sandbox modules plus default sandbox profile presentation")
 (expectedOutcome . pass)
 (expectedRepair . "keep sandbox declarations POO-native, keep benchmark contracts under t/scenarios/performance, and do not move benchmark payloads into user-interface modules")
 (nativePooAuthoring . #t)
 (runtimeExecuted . #f)
 (hotPathExemption . user-interface-sandbox-config)
 (hotPathEvidence native-poo-authoring
                  sandbox-config
                  default-profile-presentation
                  descriptor-not-realized
                  report-only-runtime-boundary
                  benchmark-contract)
 (measurementPhases collect-before
                    policy-before
                    collect-after
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags poo user-interface sandbox performance))
