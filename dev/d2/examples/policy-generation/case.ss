;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism PolicyNeeds))
(export DesignCase)
(def DesignCase
  (.o identity: 'policy-generation
    inputs: '("dev/d2/examples/policy-generation/teaching.ss")
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/21-runtime-policy-transition.org"
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/21-policy-transition.sysml"
              "dev/d2/examples/policy-generation/view.sysml")
    view: "PolicyGenerationView::teaching" audience: 'beginner primary: 'why-refuse width: 1800
    title: "The words match. Why stop the request?"
    intro: "A request keeps a snapshot. A deadline changes the live record. Find the difference that stops this new update."
    teaching: TeachingItems mechanism: TeachingMechanism facet-needs: PolicyNeeds
    questions: (list (.o identity: 'why-refuse audience: 'beginner subject: 'policy
      text: "If the policy bytes are unchanged, why must the old command be refused?"))
    choices: (list (.o source-ref: "ContextPolicyTransition::fixture" caption: "Policy Transition contract"
      glyph: "" role: "default" rationale: "One native fixture anchors multiple explanatory views; no extra native occurrences are invented."))))
