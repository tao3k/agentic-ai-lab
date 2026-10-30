;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 8ms)
 (sampleCount . 20)
 (targetRationale . "workflow presentation must reuse one native POO projection and must not require a second summary implementation")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/workflow-presentation-native-projection/benchmark.ss")
 (rule . AGENTIC-AI-LAB-USER-INTERFACE-PERFORMANCE-004)
 (feature . workflow-presentation-native-projection)
 (optimizationFocus . "Gerbil :clan/poo object<-fun slot cache plus Gerbil promises for shared workflow projections")
 (inputShape . "one real Funflow CI/CD user config with three runtime command manifests and one Marlin handoff ABI")
 (expectedOutcome . "one presentation constructor preserves workflow counts and remains below the shared 100ms P95 ceiling")
 (expectedRepair . "optimize the projection or its shared algorithms; do not restore a duplicate eager constructor or reduce samples")
 (nativePooAuthoring . #t)
 (runtimeExecuted . #f)
 (measurementPhases collect-before
                    collect-after
                    policy-before
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags poo user-interface workflow presentation performance))
