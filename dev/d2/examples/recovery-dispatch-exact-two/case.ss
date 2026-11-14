;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-dispatch-exact-two audience: 'young-novice primary: 'second-dispatch width: 1350
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-dispatch-exact-two/view.sysml")
    view: "DispatchExactTwoView::teaching"
    title: "When does a second record count?"
    intro: "All four ranges sealed. Count dispatch identities across the whole window."
    questions: (list (.o identity: 'second-dispatch audience: 'young-novice subject: 'coverage
      text: "What lets R43 count as a second dispatch and what happens to v3?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Exact two" glyph: "" role: "default"
      rationale: "Identity, assessment and publication are distinct objects."))
    teaching: (list
      (.o identity: 'identities question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'identity-scope referent: 'identities
        glyph: "dev/d2/examples/recovery-dispatch-exact-two/assets/identities.svg" title: "Two verified bindings" explanation: "Same Attempt, effect and window."
        representation: (.o family: 'identities state: 'current intent: 'state action: "Two log tickets inside one verified scope.")
        rationale: "Two log tickets inside one verified scope." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Both attestations bind the original durable Attempt, exact append effect and replay relation.")
      (.o identity: 'assessed question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'count-closure referent: 'assessed
        glyph: "dev/d2/examples/recovery-dispatch-exact-two/assets/assessed.svg" title: "Exactly two" explanation: "ASCENT closes the count."
        representation: (.o family: 'assessed state: 'current intent: 'state action: "Two independent dispatch identities with a verified count.")
        rationale: "Two independent dispatch identities with a verified count." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "ASCENT closes the original count responsibility when the exact-two\nassessment is admitted on this complete basis.")
      (.o identity: 'summary question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'publication-history referent: 'summary
        glyph: "dev/d2/examples/recovery-dispatch-exact-two/assets/summary.svg" title: "Temporal admits v4" explanation: "Keep v3 and its basis."
        representation: (.o family: 'summary state: 'current intent: 'state action: "Two immutable summary versions with a distinct current choice.")
        rationale: "Two immutable summary versions with a distinct current choice." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "v3's exact-one text and old evidence\nstay queryable as history.")
    ) facet-needs: (list
      (.o question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'identity-scope)
      (.o question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'count-closure)
      (.o question: 'second-dispatch target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'publication-history)
    ) mechanism: (.o links: (list
      (.o identity: 'identity-basis from: 'identities to: 'assessed role: 'basis
        label: "Distinct IDs" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The two canonical IDs differ, and they are exactly the set of replay IDs across the complete qualified range inventory.")
      (.o identity: 'publication-basis from: 'assessed to: 'summary role: 'basis
        label: "Basis current" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "Temporal may select the new summary only while\nits assessment still names the current cut, exact manifest, qualified\nrange snapshot and identity pair.")
    ) requirements: (list
      (.o question: 'second-dispatch from: 'identities to: 'assessed role: 'basis)
      (.o question: 'second-dispatch from: 'assessed to: 'summary role: 'basis)
    ) traces: '())))
