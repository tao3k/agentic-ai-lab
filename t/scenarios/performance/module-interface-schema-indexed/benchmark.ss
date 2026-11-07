;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 999ms)
 (target_total . 100ms)
 (regression_budget . 899ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "Interface-owned schema lookup stays below the broad scenario budget")
 (sampleCount . 20)
 (rule . module-interface-schema-indexed)
 (feature . module-interface-derived-schema-index-slot)
 (optimizationFocus . "derive one reusable lookup index from the effective Interface schemas slot")
 (inputShape . "1000 POO schema slots and 1000 ordered lookups")
 (expectedOutcome . "candidate preserves projected values and beats repeated list scans")
 (measurementPhases . (baseline-lookup candidate-lookup assert-semantic-gate assert-time-gate observe-runtime-memory))
 (baseline . "one linear projected-schema scan per option lookup")
 (candidate . "one Interface-owned runtime hash index reused by every lookup")
 (tags module-system interface poo slot schema hash-index performance))
