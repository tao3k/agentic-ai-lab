;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario-ab)
 (schema . agentic-ai-lab.domain-case-runtime-base-override.v1)
 (sourcePath . "t/scenarios/performance/domain-case-runtime-base-override/scenario.ss")
 (feature . domain-case-instance-composition)
 (baseline . "Gerbil POO three-parent .mix")
 (candidate . "Gerbil POO make-object single-allocation base/override")
 (sampleCount . 20)
 (agentCount . 500)
 (sharedSlotCount . 64)
 (semanticGate . ".ref values, .slot?, and .all-slots surfaces are equivalent")
 (performanceGate . "candidate complete-sample p95 is below baseline p95")
 (tags poo domain-case composition runtime-base-override performance))
