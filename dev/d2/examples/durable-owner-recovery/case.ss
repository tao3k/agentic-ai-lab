;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism CaseNeeds))
(export DesignCase)
(def DesignCase (.o identity: 'durable-owner-recovery audience: 'young-novice primary: 'what-survives-an-owner width: 1600
 org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
 inputs: '("dev/d2/examples/durable-owner-recovery/teaching.ss" "modules/durable/interface.ss" "modules/durable/recovery-decision.ss" "dev/durable/emit-recovery-projection.ss" "packages/proofs/lean/AgenticAILabProof/PooC4/RecoveryPolicyAuthorization.lean" "core/feature-system/model.ss" "core/feature-system/composition.ss" "core/feature-system/adapter-projection-binding.ss")
 models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/durable-owner-recovery/view.sysml")
 view: "DurableTeachingView::teaching" title: "Two kinds of extension. One unfinished Attempt." intro: "Core connects the modules. Durable uses its own policies to decide what recovery can do."
 teaching: TeachingItems mechanism: TeachingMechanism facet-needs: CaseNeeds
 questions: (list (.o identity: 'what-survives-an-owner audience: 'young-novice subject: 'durable text: "Two kinds of extension. One unfinished Attempt."))
 choices: (list (.o source-ref: "ContextRepeatedRecovery::recoveryExtensionLayers" caption: "Existing Durable design" glyph: "" role: "default" rationale: "An existing design package supplies the native objects; this view does not execute verification cases."))))
