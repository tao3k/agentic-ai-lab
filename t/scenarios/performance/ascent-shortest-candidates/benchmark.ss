;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 2000us)
 (target_total . 1000us)
 (regression_budget . 1000us)
 (expected_over_input_budget . 0us)
 (sampleCount . 20)
 (targetRationale . "Measure complete Scheme Dual shortest-distance closure and source support candidates over a 20-node chain.")
 (unit . "us")
 (sourcePath . "t/performance/ascent-shortest-candidates-performance-test.ss")
 (rule . GERBIL-SCHEME-AGENT-R031)
 (feature . ascent-shortest-candidates)
 (optimizationFocus . "indexed source joins, strict minimum-distance frontier updates, and per-origin deterministic support")
 (inputShape . "19 labelled source facts on a 20-node chain encoded with radix 32")
 (expectedOutcome . "190 sorted candidates with exact shortest distances and supports")
 (expectedRepair . "reuse the indexed Scheme relation and standard POO collections before adding another evaluator abstraction")
 (baseline . "POO binary closure plus per-origin support reconstruction")
 (candidate . "Scheme Dual minimum-distance projection plus per-origin support reconstruction")
 (measurementPhases candidate-evaluation assert-semantic-gate assert-time-gate)
 (tags poo ascent lattice support stdlib performance))
