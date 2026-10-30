;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 500us)
 (target_total . 100us)
 (regression_budget . 400us)
 (expected_over_input_budget . 0us)
 (sampleCount . 20)
 (targetRationale . "A derived POO relation index answers repeated Agent pair decisions without rescanning materialized pairs.")
 (iterations . 1)
 (unit . "us")
 (sourcePath . "t/scenarios/performance/ascent-table-expression-membership/benchmark.ss")
 (rule . GERBIL-SCHEME-AGENT-R031)
 (feature . ascent-table-expression-membership)
 (optimizationFocus . "reuse one lazy POO projection index for 1280 pair membership decisions")
 (inputShape . "512 source pairs, 1024 projected pairs, and 1280 in-domain queries with hits and misses")
 (expectedOutcome . "candidate returns exactly the same ordered booleans as list membership")
 (baseline . "scan the canonical 1024-pair list for each decision")
 (candidate . "reuse the POO projection's private bounded byte-vector membership closure")
 (measurementPhases baseline-membership candidate-membership assert-semantic-gate assert-time-gate observe-runtime-memory)
 (tags poo ascent relation decision index stdlib performance big-o))
