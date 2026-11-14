;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 50ms)
 (target_total . 20ms)
 (regression_budget . 30ms)
 (expected_over_input_budget . 0ms)
 (targetRationale . "ASP records 40 independent end-to-end samples and admits P95 while the selected result proves cold, warm, and traced POO semantics under the unchanged 50ms hard gate.")
 (sampleCount . 40)
 (sourcePath . "t/scenarios/performance/poo-observability-slot-guard/benchmark.ss")
 (rule . GERBIL-SCHEME-AGENT-R046)
 (feature . poo-observability-slot-guard)
 (optimizationFocus . "POO lazy-slot observability cold and warm phase separation")
 (inputShape . "validated debug policy, guarded one-slot receivers, cached reads, and bounded redacted Clan tracing")
 (expectedOutcome . "prototype lookup is hoisted, non-emitting demand avoids receipt construction, warm demand remains cached, and traced demand retains bounded receipts")
 (expectedRepair . "install the guard before first demand, hoist stable prototype lookup, and keep receipt construction out of the non-emitting admitted path")
 (pooFormEvidence . (.o .def defpoo))
 (pooUsageCallEvidence . (.ref .get .mix .o .def .putdefault! .setslot! setslots! .all-slots))
 (measurementPhases prototype-resolution guard-construction first-demand warm-cache traced-first-demand assert-time-gate observe-runtime-memory)
 (tags poo observability debug performance cold warm))
