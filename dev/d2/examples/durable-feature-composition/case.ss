;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism CaseNeeds))
(export DesignCase)
(def DesignCase (.o identity: 'durable-feature-composition audience: 'young-novice primary: 'how-context-is-extended width: 1600
 org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/18-runtime-durable-source-commands.org"
 inputs: '("dev/d2/examples/durable-feature-composition/teaching.ss" "core/module-system/feature/model.ss" "core/module-system/feature/composition.ss" "core/module-system/feature/adapter-projection-binding.ss")
 models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/durable-feature-composition/view.sysml")
 view: "DurableTeachingView::teaching" title: "Give Context a new ability. Who supplies it?" intro: "Proposed Module boundary using the existing Core Feature System. A declaration does not start a running engine."
 teaching: TeachingItems mechanism: TeachingMechanism facet-needs: CaseNeeds
 questions: (list (.o identity: 'how-context-is-extended audience: 'young-novice subject: 'durable text: "Give Context a new ability. Who supplies it?"))
 choices: (list (.o source-ref: "ContextRepeatedRecovery::compositionDesign" caption: "Existing Durable design" glyph: "" role: "default" rationale: "An existing design package supplies the native objects; this view does not execute verification cases."))))
