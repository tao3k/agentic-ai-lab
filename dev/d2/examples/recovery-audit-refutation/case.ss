;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts for the audit design.
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'recovery-audit-refutation audience: 'young-novice primary: 'what-changed width: 1050
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-audit-refutation/view.sysml")
    view: "RecoveryAuditRefutationView::teaching"
    title: "A replay found. One commit."
    intro: "ASCENT settles fact reviews. Temporal selects the revision."
    questions: (list (.o identity: 'what-changed audience: 'young-novice subject: 'summary
      text: "What does one replay change in the summary?"))
    choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Recovery audit" glyph: "" role: "default"
      rationale: "One audit fixture connects claim dispositions to the revised summary."))
    teaching: (list
      (.o identity: 'storage question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'commit-support referent: 'storage
        glyph: "dev/d2/examples/recovery-audit-refutation/assets/storage.svg" title: "Storage audit" explanation: "W1-v2 supports the append"
        representation: (.o family: 'storage state: 'current intent: 'state action: "One commit and two retained claims."
          expressions: (list (.o identity: 'commit-count kind: 'number token: "1"
            role-label: "Storage audit" quantity-label: "Commit" meaning: "The complete audit verified one commit." use: 'evidence scale: 'quantity)))
        rationale: "One commit and two retained claims." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The complete storage audit counts one matching commit in scope")
      (.o identity: 'dispatch question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'replay-refutation referent: 'dispatch
        glyph: "dev/d2/examples/recovery-audit-refutation/assets/dispatch.svg" title: "Dispatch journal" explanation: "Withdraw zero replay"
        representation: (.o family: 'dispatch state: 'current intent: 'state action: "A replay event crosses out the old absence claim."
          expressions: (list (.o identity: 'replay-witness kind: 'number token: "1"
            role-label: "Dispatch journal" quantity-label: "Replay seen" meaning: "One observed replay refutes zero without proving the exact total." use: 'evidence scale: 'quantity)))
        rationale: "A replay event crosses out the old absence claim." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "An admitted matching replay event contradicts zero")
      (.o identity: 'revision question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign"
        facet: 'admission-history referent: 'revision
        glyph: "dev/d2/examples/recovery-audit-refutation/assets/revision.svg" title: "Revised summary" explanation: "Exact rewrite needs full coverage."
        representation: (.o family: 'revision state: 'current intent: 'outcome action: "A revision and a separately archived B snapshot.")
        rationale: "A revision and a separately archived B snapshot." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The new summary adds an immutable version and a predecessor reference to B.")
    )
    facet-needs: (list
      (.o question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'commit-support)
      (.o question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'replay-refutation)
      (.o question: 'what-changed target: "ContextRepeatedRecovery::interruptedWriteDesign" facet: 'admission-history)
    )
    mechanism: (.o links: (list
      (.o identity: 'storage-basis from: 'storage to: 'revision role: 'basis
        label: "" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "The complete storage audit counts one matching commit in scope")
      (.o identity: 'dispatch-basis from: 'dispatch to: 'revision role: 'basis
        label: "" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org" excerpt: "An admitted matching replay event contradicts zero")
    ) requirements: (list
      (.o question: 'what-changed from: 'storage to: 'revision role: 'basis)
      (.o question: 'what-changed from: 'dispatch to: 'revision role: 'basis)
    ) traces: '())))
