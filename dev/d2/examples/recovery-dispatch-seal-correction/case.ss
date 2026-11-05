;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-dispatch-seal-correction audience: 'young-novice primary: 'what-survives width: 1350
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-dispatch-seal-correction/view.sysml")
    view: "DispatchSealCorrectionView::teaching"
    title: "What changes when a seal is revoked?"
    intro: "Same dispatch window. R42 and R43 name distinct replay events."
    questions: (list (.o identity: 'what-survives audience: 'young-novice subject: 'coverage
      text: "What survives the B correction and what must be counted again?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Seal correction" glyph: "" role: "default"
      rationale: "One recovery scenario across dispatch evidence cuts."))
    teaching: (list
      (.o identity: 'prior question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'prior-basis referent: 'dispatch-window
        glyph: "dev/d2/examples/recovery-dispatch-seal-correction/assets/prior.svg" title: "Prior exact count" explanation: "Keep v3 in history."
        representation: (.o family: 'dispatch-window state: 'prior intent: 'state action: "Keep v3 in history.")
        rationale: "Keep v3 in history." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The old\nsnapshot and its basis remain in history.")
      (.o identity: 'gap question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'corrected-basis referent: 'dispatch-window
        glyph: "dev/d2/examples/recovery-dispatch-seal-correction/assets/gap.svg" title: "B seal revoked" explanation: "A verified. Count open."
        representation: (.o family: 'dispatch-window state: 'corrected intent: 'state action: "A verified. Count open.")
        rationale: "A verified. Count open." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "At least one replay can be assessed and selected")
      (.o identity: 'closed question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'new-basis referent: 'dispatch-window
        glyph: "dev/d2/examples/recovery-dispatch-seal-correction/assets/closed.svg" title: "B seal restored" explanation: "Two distinct replays."
        representation: (.o family: 'dispatch-window state: 'resealed intent: 'state action: "Two distinct replays.")
        rationale: "Two distinct replays." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The exact-one gate refuses; an exact-two claim needs its own assessment")
    ) facet-needs: (list
      (.o question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'prior-basis)
      (.o question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'corrected-basis)
      (.o question: 'what-survives target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'new-basis)
    ) mechanism: (.o links: (list
      (.o identity: 'correct from: 'prior to: 'gap role: 'state-change
        label: "Seal correction" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The current dispatch selection is cleared as the new cut is opened.")
      (.o identity: 'reseal from: 'gap to: 'closed role: 'state-change
        label: "Fresh seal" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The new B receipt must cover\nthe corrected interval and complete the authoritative inventory.")
    ) requirements: (list
      (.o question: 'what-survives from: 'prior to: 'gap role: 'state-change)
      (.o question: 'what-survives from: 'gap to: 'closed role: 'state-change)
    ) traces: '())))
