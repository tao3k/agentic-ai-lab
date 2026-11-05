;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 25ms)
 (target_total . 15ms)
 (regression_budget . 10ms)
 (expected_over_input_budget . 0ms)
 (sampleCount . 20)
 (targetRationale . "Object-family syntax removes repeated hand-written predicate, accessor, and projection families from large POO modules.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (sourcePath . "t/scenarios/performance/poo-object-family-syntax/benchmark.ss")
 (inputPath . "t/scenarios/performance/poo-object-family-syntax/input.ss")
 (expectedPath . "t/scenarios/performance/poo-object-family-syntax/expected.ss")
 (rule . GERBIL-SCHEME-AGENT-R045)
 (feature . poo-object-family-syntax)
 (purpose . "replace repeated hand-written stable POO object-family accessors with one bounded Gerbil macro declaration")
 (optimizationFocus . "generate stable POO object predicates, accessors, and projection boundaries")
 (inputShape . "1,000 POO object constructions and boundary projections with integer refs")
 (expectedRepair . "declare slots once with defpoo-object-family and let Gerbil generate repeated accessors/projections")
 (expectedOutcome . "one macro declaration supports 1,000 ordinary POO constructions, accessors, and boundary projections")
 (expectedQualitySignals generated-object-family-accessors
                         stable-poo-slot-access
                         bounded-boundary-projection
                         no-runtime-execution)
 (pooFormEvidence . (.o .def defpoo defpoo-object-family))
 (pooUsageCallEvidence . (.ref object<-alist))
 (runtimePooPrimary . #t)
 (adapterBoundary . "alist projection remains a boundary value; object access stays POO")
 (hotPathExemption . "no repeated hand-written slot traversal families in large object modules")
 (measurementPhases object-construction boundary-projection object-selection assert-time-gate observe-runtime-memory)
 (tags poo module-system performance macro object-family scenario))
