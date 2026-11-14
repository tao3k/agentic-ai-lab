;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-dispatch-alias-correction audience: 'young-novice primary: 'copy-count width: 1350
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-dispatch-alias-correction/view.sysml")
    view: "DispatchAliasCorrectionView::teaching"
    title: "When two records point to one dispatch"
    intro: "The copy breaks v4's count. Recheck the whole window."
    questions: (list (.o identity: 'copy-count audience: 'young-novice subject: 'coverage
      text: "Why does a copy reopen the count, and what proves exactly one?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Corrected replay count" glyph: "" role: "default"
      rationale: "Identity correction, count review and summary selection have distinct evidence conditions."))
    teaching: (list
      (.o identity: 'forward question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'copy-identity referent: 'forward
        glyph: "dev/d2/examples/recovery-dispatch-alias-correction/assets/forward.svg" title: "R43 is a copy" explanation: "Both point to R42."
        representation: (.o family: 'forward state: 'current intent: 'state action: "A forwarded ticket points back to the original dispatch.")
        rationale: "A forwarded ticket points back to the original dispatch." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "It authenticates a forward\nof the A/early dispatch R42")
      (.o identity: 'review question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'reopened-count referent: 'review
        glyph: "dev/d2/examples/recovery-dispatch-alias-correction/assets/review.svg" title: "ASCENT checks the count" explanation: "Context withdraws “exactly two.”"
        representation: (.o family: 'review state: 'current intent: 'state action: "A magnifier shows that the original count question is open.")
        rationale: "A magnifier shows that the original count question is open." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "ASCENT reopens\nthe count responsibility at withdrawal")
      (.o identity: 'coverage question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'fresh-count referent: 'coverage
        glyph: "dev/d2/examples/recovery-dispatch-alias-correction/assets/coverage.svg" title: "Four ranges rechecked" explanation: "Only R42 in the window."
        representation: (.o family: 'coverage state: 'current intent: 'state action: "Four checked ranges support the singleton dispatch set.")
        rationale: "Four checked ranges support the singleton dispatch set." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The complete, deduplicated replay set\nmust be exactly {R42}.")
      (.o identity: 'versions question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'published-history referent: 'versions
        glyph: "dev/d2/examples/recovery-dispatch-alias-correction/assets/versions.svg" title: "Temporal admits v5" explanation: "Exactly one. Keep v3 and v4."
        representation: (.o family: 'versions state: 'current intent: 'state action: "Two archived records sit alongside a newly admitted summary.")
        rationale: "Two archived records sit alongside a newly admitted summary." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Temporal rechecks the current basis at publication and admits a new\nsummary, v5")
    ) facet-needs: (list
      (.o question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'copy-identity)
      (.o question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'reopened-count)
      (.o question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'fresh-count)
      (.o question: 'copy-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'published-history)
    ) mechanism: (.o links: (list
      (.o identity: 'withdrawal from: 'forward to: 'review role: 'basis
        label: "Reopens review" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Context withdraws the current exact-two claim as soon as Temporal admits\nthis scoped correction against the selected v4 basis.")
      (.o identity: 'reassessment from: 'coverage to: 'review role: 'basis
        label: "Closes review" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "ASCENT closes the count responsibility on the fresh exact-one assessment.")
      (.o identity: 'admission from: 'coverage to: 'versions role: 'basis
        label: "Basis still current" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Temporal rechecks the current basis at publication and admits a new\nsummary, v5")
    ) requirements: (list
      (.o question: 'copy-count from: 'forward to: 'review role: 'basis)
      (.o question: 'copy-count from: 'coverage to: 'review role: 'basis)
      (.o question: 'copy-count from: 'coverage to: 'versions role: 'basis)
    ) traces: '())))
