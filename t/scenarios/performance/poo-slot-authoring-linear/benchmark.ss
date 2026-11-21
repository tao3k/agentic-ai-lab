;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 10ms)
 (regression_budget . 90ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "linear POO slot observation stays below the scenario budget")
 (sampleCount . 20)
 (rule . poo-slot-authoring-linear)
 (feature . poo-slot-authoring-linear-traversal)
 (optimizationFocus . "replace recursive result append with tail-passing accumulation")
 (inputShape . "300-level nested POO object datum")
 (expectedOutcome . "candidate preserves source-order bindings and beats baseline")
 (measurementPhases . (baseline-traversal candidate-traversal assert-semantic-gate assert-time-gate observe-runtime-memory))
 (baseline . "recursive append of complete child binding lists")
 (candidate . "tail-passing binding accumulation")
 (tags module-system observability poo scheme-reader linear-traversal performance))
