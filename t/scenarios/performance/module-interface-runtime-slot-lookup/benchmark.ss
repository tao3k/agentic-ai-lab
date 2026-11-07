;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 10ms)
 (regression_budget . 90ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "POO slot-table lookup stays below the scenario budget")
 (sampleCount . 20)
 (rule . module-interface-runtime-slot-lookup)
 (feature . module-interface-runtime-slot-lookup)
 (optimizationFocus . "remove projected-slot scans and generic Module wrappers")
 (inputShape . "1000 POO slots with 1000 present and one missing query")
 (expectedOutcome . "runtime .slot? preserves presence semantics and beats the projected scan")
 (measurementPhases . (baseline-lookup candidate-lookup assert-semantic-gate assert-time-gate observe-runtime-memory))
 (baseline . "project all slot names and linearly scan once per presence check")
 (candidate . "query gerbil-poo runtime slot table with .slot?")
 (tags module-system interface poo runtime-slot lookup performance))
