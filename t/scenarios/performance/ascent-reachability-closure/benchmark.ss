;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 1000us)
 (target_total . 700us)
 (regression_budget . 300us)
 (expected_over_input_budget . 0us)
 (sampleCount . 20)
 (targetRationale . "Measure a complete demanded transitive closure, including POO expression construction, over a 20-node chain.")
 (unit . "us")
 (sourcePath . "t/scenarios/performance/ascent-reachability-closure/benchmark.ss")
 (rule . GERBIL-SCHEME-AGENT-R031)
 (feature . ascent-reachability-closure)
 (optimizationFocus . "one indexed source snapshot, private bounded deduplication, and one canonical closure projection")
 (inputShape . "19 source pairs on a 20-node chain encoded with radix 32")
 (expectedOutcome . "190 distinct reachable pairs in canonical order")
 (expectedRepair . "keep the finite-domain frontier operation and use standard POO/Scheme collection functions before adding a new evaluator abstraction")
 (baseline . "repeated persistent set materialization after every frontier step")
 (candidate . "indexed frontier with private deduplication and lazy POO closure projection")
 (measurementPhases candidate-closure assert-semantic-gate assert-time-gate)
 (tags poo ascent closure stdlib performance))
