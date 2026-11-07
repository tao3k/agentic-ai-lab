;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism RecoveryNeeds))
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-first-observation
    inputs: '("dev/d2/examples/recovery-first-observation/teaching.ss"
              "modules/ai-agentic-context/recovery-observation.ss")
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/33-recovery-first-observation.org"
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/33-recovery-first-observation.sysml"
              "dev/d2/examples/recovery-first-observation/view.sysml")
    view: "RecoveryFirstObservationView::teaching" audience: 'young-novice primary: 'what-can-we-know width: 1800
    title: "The file says fast. Did our edit do it?"
    intro: "A crash happened before the receipt was saved. What can a fresh read tell us, and what stays unknown?"
    teaching: TeachingItems mechanism: TeachingMechanism facet-needs: RecoveryNeeds
    questions: (list (.o identity: 'what-can-we-know audience: 'young-novice subject: 'recovery
      text: "If the file matches our plan but no receipt survived, what can we know and what must remain open?"))
    choices: (list (.o source-ref: "RecoveryFirstObservation::fixture" caption: "Recovery Context"
      glyph: "" role: "default" rationale: "One semantic fixture anchors six explanatory facets, not six fabricated runtime occurrences."))))
