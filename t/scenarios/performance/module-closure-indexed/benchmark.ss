;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 999ms)
 (target_total . 100ms)
 (regression_budget . 899ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "indexed module closure stays below the broad scenario budget")
 (sampleCount . 20)
 (rule . module-closure-indexed)
 (feature . module-closure-shared-admission-index)
 (optimizationFocus . "replace branch-local list scans with one traversal-owned runtime hash")
 (inputShape . "1000 distinct POO module descriptors")
 (expectedOutcome . "candidate preserves unique module order and beats baseline")
 (measurementPhases . (baseline-closure candidate-closure assert-semantic-gate assert-time-gate observe-runtime-memory))
 (baseline . "branch-local name lists with linear membership scans")
 (candidate . "one traversal-owned runtime hash index with explicit DFS frames")
 (tags module-system descriptor closure hash-index dfs performance))
