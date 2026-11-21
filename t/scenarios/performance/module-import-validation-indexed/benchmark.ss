;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 999ms)
 (target_total . 100ms)
 (regression_budget . 899ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "indexed import validation stays below the broad scenario budget")
 (sampleCount . 20)
 (rule . module-import-validation-indexed)
 (feature . module-import-validation-name-index)
 (optimizationFocus . "replace repeated available-name scans with one runtime hash")
 (inputShape . "1000 modules with 999 named imports")
 (expectedOutcome . "candidate preserves missing-import diagnostics and beats baseline")
 (measurementPhases . (baseline-validation candidate-validation assert-semantic-gate assert-time-gate observe-runtime-memory))
 (baseline . "one linear available-name scan per named import")
 (candidate . "one traversal-owned runtime hash index for all named imports")
 (tags module-system descriptor import-validation hash-index performance))
