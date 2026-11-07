;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 5ms)
 (sampleCount . 20)
 (targetRationale . "Pinned to hash-backed policy-ref merge and batch validation against concrete POO tool specs.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/tool-core-catalog-policy-validation/benchmark.ss")
 (rule . GERBIL-SCHEME-AGENT-R031)
 (feature . tool-core-catalog-policy-validation)
 (optimizationFocus . "std/misc/list hash-backed agent and hook policy-ref merge before POO catalog validation")
 (inputShape . "160 tool specs and 160 session tool grants resolved through a catalog validation receipt")
 (expectedRepair . "retain first-seen policy-ref order with the upstream eq-hash algorithm; do not restore recursive member scans")
 (measurementPhases collect-before policy-before collect-after policy-after assert-time-gate observe-runtime-memory)
 (expectedOutcome
  .
  "One POO catalog validation receipt resolves tool grants without runtime execution.")
 (tags poo tool-core session policy catalog performance))
