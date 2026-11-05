;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 scene facts.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-dispatch-coverage audience: 'young-novice primary: 'when-can-we-count width: 1260
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-dispatch-coverage/view.sysml")
    view: "RecoveryDispatchCoverageView::teaching"
    title: "A replay found. When can we say exactly one?"
    intro: "Same window. Required logs: A and B. Filled blocks are sealed."
    questions: (list (.o identity: 'when-can-we-count audience: 'young-novice subject: 'coverage
      text: "What does the missing log prevent us from claiming?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Dispatch coverage" glyph: "" role: "default"
      rationale: "The same recovery fixture compares coverage and summary versions."))
    teaching: (list
      (.o identity: 'gap question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'missing-range referent: 'dispatch-window
        glyph: "dev/d2/examples/recovery-dispatch-coverage/assets/gap.svg" title: "B log missing" explanation: "Zero refuted. Count open."
        representation: (.o family: 'dispatch-window state: 'open intent: 'state action: "A replay witness in A and dashed missing ranges for B.")
        rationale: "A replay witness in A and dashed missing ranges for B." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The fixture has two dispatchers, A and B.")
      (.o identity: 'closed question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'sealed-range referent: 'dispatch-window
        glyph: "dev/d2/examples/recovery-dispatch-coverage/assets/closed.svg" title: "Coverage closed" explanation: "One distinct replay."
        representation: (.o family: 'dispatch-window state: 'closed intent: 'state action: "Both logs are sealed and the same replay marker remains.")
        rationale: "Both logs are sealed and the same replay marker remains." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Exact cardinality\nrequires an admitted complete manifest, a unique qualified receipt for every\nrequired range, and deduplication by authoritative dispatch identity.")
      (.o identity: 'summary question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'version-history referent: 'summary-lineage
        glyph: "dev/d2/examples/recovery-dispatch-coverage/assets/summary.svg" title: "Exact-one revision" explanation: "Keep B and v2."
        representation: (.o family: 'summary-lineage state: 'selected intent: 'outcome action: "The selected exact revision sits beside the retained historical sheets.")
        rationale: "The selected exact revision sits beside the retained historical sheets." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "B and the prior v2 remain queryable with their own bases.")
    )
    facet-needs: (list
      (.o question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'missing-range)
      (.o question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'sealed-range)
      (.o question: 'when-can-we-count target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'version-history)
    )
    mechanism: (.o links: (list
      (.o identity: 'fill-gap from: 'gap to: 'closed role: 'state-change
        label: "B sealed" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The four distinct required slots are sealed for the same scope and cut.")
      (.o identity: 'basis from: 'closed to: 'summary role: 'basis
        label: "Count assessed" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "It then admits v3 with the exact-one claim after the separate assessment.")
    ) requirements: (list
      (.o question: 'when-can-we-count from: 'gap to: 'closed role: 'state-change)
      (.o question: 'when-can-we-count from: 'closed to: 'summary role: 'basis)
    ) traces: '())))
