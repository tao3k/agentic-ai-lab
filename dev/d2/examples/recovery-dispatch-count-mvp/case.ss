;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-dispatch-count-mvp audience: 'young-novice primary: 'same-question width: 1250
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-dispatch-count-mvp/view.sysml")
    view: "DispatchCountMvpView::teaching"
    title: "Does one more record mean one more replay?"
    intro: "One attempt, one effect, one window. One question."
    questions: (list (.o identity: 'same-question audience: 'young-novice subject: 'coverage
      text: "Which evidence leaves the count alone, which reopens it, and which makes it exact?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "One replay count question" glyph: "" role: "default"
      rationale: "Three evidence conditions relate to the same scoped responsibility."))
    teaching: (list
      (.o identity: 'copies question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'same-dispatch referent: 'copies
        glyph: "dev/d2/examples/recovery-dispatch-count-mvp/assets/copies.svg" title: "Known copy" explanation: "Another record, same dispatch."
        representation: (.o family: 'copies state: 'current intent: 'state action: "One record overlays another with the same dispatch identity.")
        rationale: "One record overlays another with the same dispatch identity." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The canonical set, assessment, count duty and selected answer stay put.")
      (.o identity: 'witness question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'changed-basis referent: 'witness
        glyph: "dev/d2/examples/recovery-dispatch-count-mvp/assets/witness.svg" title: "Old count loses support" explanation: "Either can overturn an exact count."
        representation: (.o family: 'witness state: 'current intent: 'state action: "R43 can remove a false contribution; independent R44 can add a missing one.")
        rationale: "R43 can remove a false contribution; independent R44 can add a missing one." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Context withdraws the contradicted exact answer and ASCENT reopens the existing count duty.")
      (.o identity: 'coverage question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'exact-basis referent: 'coverage
        glyph: "dev/d2/examples/recovery-dispatch-count-mvp/assets/coverage.svg" title: "Every range checked" explanation: "Exactly R42 and R44."
        representation: (.o family: 'coverage state: 'current intent: 'state action: "The complete set is supported by four checked ranges.")
        rationale: "The complete set is supported by four checked ranges." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "if they exhaust\n{R42, R44}, the answer is exactly two.")
      (.o identity: 'review question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'one-question referent: 'review
        glyph: "dev/d2/examples/recovery-dispatch-count-mvp/assets/review.svg" title: "Same ASCENT count question" explanation: "Keep the answer and its reasons."
        representation: (.o family: 'review state: 'current intent: 'state action: "The same question card stays in view; earlier evidence remains behind it.")
        rationale: "The same question card stays in view; earlier evidence remains behind it." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The current answer and the evidence history are different views.")
    ) facet-needs: (list
      (.o question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'same-dispatch)
      (.o question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'changed-basis)
      (.o question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'exact-basis)
      (.o question: 'same-question target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'one-question)
    ) mechanism: (.o links: (list
      (.o identity: 'copy from: 'copies to: 'review role: 'basis
        label: "No change" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The canonical set, assessment, count duty and selected answer stay put.")
      (.o identity: 'refutation from: 'witness to: 'review role: 'basis
        label: "Reopens check" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Context withdraws the contradicted exact answer and ASCENT reopens the existing count duty.")
      (.o identity: 'reassessment from: 'coverage to: 'review role: 'basis
        label: "Closes check" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "ASCENT can close the count duty on a fresh exact assessment. Temporal selects it only against a still-current basis.")
    ) requirements: (list
      (.o question: 'same-question from: 'copies to: 'review role: 'basis)
      (.o question: 'same-question from: 'witness to: 'review role: 'basis)
      (.o question: 'same-question from: 'coverage to: 'review role: 'basis)
    ) traces: '())))
