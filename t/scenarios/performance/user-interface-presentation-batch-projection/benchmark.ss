;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-e2e)
 (max_total . 100ms)
 (target_total . 25ms)
 (regression_budget . 75ms)
 (expected_over_input_budget . 8ms)
 (sampleCount . 20)
 (targetRationale . "user-interface presentation batch projection is a hot path: repeated loop-engine receipts must stay below the shared 100ms hard ceiling.")
 (maxRssMb . 512)
 (memoryMetric . resident-set-size)
 (memoryUnit . "MB")
 (iterations . 3)
 (unit . "ms")
 (purpose . "observe user-interface presentation projection over repeated loop-engine modules")
 (feature . user-interface-presentation-batch-projection)
 (rule . AGENTIC-AI-LAB-USER-INTERFACE-PERFORMANCE-001)
 (optimizationFocus . "single Gerbil :clan/poo loop-engine-only presentation projection with batch field extraction")
 (inputShape . "eight real custom loop-engine user-interface module declarations projected through agenticAiLabUserConfigPresentation")
 (expectedOutcome . "the user-interface-presentation-batch-projection scenario preserves its declared semantic result under the ASP P95 gate")
 (expectedRepair . "use focused POO presentation owners so loop-engine-only configs do not force unrelated CI/CD, session, sandbox, or workflow projection families")
 (nativePooAuthoring . #t)
 (receiptRepresentation . defstruct)
 (adapterBoundary . "presentation loop-engine capability receipts are structs; runtime handoff capability receipts are alists")
 (hotPathExemption . user-interface-presentation-batch-projection)
 (hotPathEvidence native-poo-authoring
                  defstruct-runtime-receipt
                  user-interface-presentation
                  clan-poo-object-fun-projection
                  batch-field-projection
                  scalar-summary
                  adapter-boundary
                  benchmark-contract)
 (optimizerVisibility . "presentation-config routes loop-engine-only configs through :clan/poo object<-fun caching, shares row-family projections with Gerbil promises, and performs one batch projection per row family")
 (expectedQualitySignals batch-field-projection
                         struct-capability-receipts
                         serialized-runtime-handoff-boundary
                         clan-poo-object-fun-projection
                         user-interface-performance-gate)
 (learnedStyleSources
  "agent-semantic-protocols/languages/gerbil-scheme-language-project-harness/t/scenarios/policy/list-random-access-loop-performance/benchmark.ss"
  "agent-semantic-protocols/languages/gerbil-scheme-language-project-harness/t/scenarios/policy/poo-real-dashboard-workflow-performance/benchmark.ss"
  "agent-semantic-protocols/languages/gerbil-scheme-language-project-harness/t/scenarios/policy/poo-marlin-config-interface-large-object-performance/benchmark.ss")
 (styleRewriteBoundary . "do not reintroduce per-slot repeated scans over loop-engine-intent-rows or workflow-cicd check rows without tightening this benchmark")
 (measurementPhases collect-before
                    collect-after
                    policy-before
                    policy-after
                    assert-time-gate
                    observe-runtime-memory)
 (tags poo user-interface presentation performance))
