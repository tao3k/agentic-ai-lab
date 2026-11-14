;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 5ms)
 (sampleCount . 20)
 (targetRationale . "Guards the high-performance macro style matrix for user-facing composition declarations.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 1000)
 (unit . "ms")
 (purpose . "Guard declarative profile macros, grouped profile macros, local override macros, hook override macros, and POO reuse macros as one composition style matrix.")
 (sourcePath . "t/scenarios/performance/poo-composition-macro-style-matrix/benchmark.ss")
 (feature . poo-composition-macro-style-matrix)
 (input . ((styleCount . 5)
           (styles . (declarative-profile
                      grouped-profiles
                      local-override
                      hook-override
                      poo-reuse))
           (profileProjection . direct-poo-payload)
           (macroExpansionShape . shallow-hygienic)))
 (expect . ((validCount . 1)
            (constructionCount . 1)
            (gatePass . #t)
            (forbiddenAdapters . (alist-record-adapter raw-lambda-hook))))
 (rule . GERBIL-SCHEME-AGENT-R051)
 (optimizationFocus . "high-performance hygienic composition macro expansion and direct POO payload projection")
(inputShape . "declarative profile forms, grouped profiles forms, local override forms, hook override forms, and runtime object reuse forms")
(expectedOutcome . "all supported composition macro styles expand to equivalent POO object reuse")
(expectedRepair . "keep macro expansion shallow, hygienic, and POO; avoid generated alist adapters and repeated syntax traversals")
 (pooFormEvidence . (.o .def defpoo))
 (pooUsageCallEvidence . (.ref .get .mix .o .def .putdefault! .setslot! setslots! .all-slots))
 (measurementPhases declarative-profile grouped-profiles local-override hook-override runtime-reuse assert-time-gate observe-runtime-memory)
 (tags poo composition macro hygienic declarative local-macro performance))
