;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'org-agenda-contract audience: 'young-novice primary: 'late-receipt width: 1560
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.sysml" "dev/d2/examples/org-agenda-contract/view.sysml")
    view: "AgendaContractView::teaching"
    title: "Bob’s receipt arrived late. Who needs an update?"
    intro: "Work now starts at 19:00."
    questions: (list (.o identity: 'late-receipt audience: 'young-novice subject: 'agenda
      text: "Why can Alice and Bob need a correction while Cara can get a first notice?"))
    choices: (list (.o source-ref: "OrgDurableDeclarations::agendaDesign" caption: "Agenda reschedule" glyph: "" role: "default"
      rationale: "Current intent and old receipts inform independent recipient decisions."))
    teaching: (list
      (.o identity: 'draft question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'current-plan referent: 'draft
        glyph: "dev/d2/examples/org-agenda-contract/assets/draft.svg" title: "Org keeps the plan" explanation: "Same appointment."
        representation: (.o family: 'draft state: 'current intent: 'state action: "The old notice and current commitment retain distinct times.")
        rationale: "The old notice and current commitment retain distinct times." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The 19:00 plan remains current.")
      (.o identity: 'late-receipt question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'receipt-match referent: 'late-receipt
        glyph: "dev/d2/examples/org-agenda-contract/assets/late-receipt.svg" title: "Bob’s receipt arrives" explanation: "Unknown to accepted."
        representation: (.o family: 'late-receipt state: 'current intent: 'state action: "The provider receipt is bound to Bob and the original payload.")
        rationale: "The provider receipt is bound to Bob and the original payload." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Bob's late receipt names his original 18:00 handoff.")
      (.o identity: 'authority question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'recipient-judgment referent: 'authority
        glyph: "dev/d2/examples/org-agenda-contract/assets/authority.svg" title: "ASCENT checks each person" explanation: "Old message or first notice?"
        representation: (.o family: 'authority state: 'current intent: 'state action: "The current commitment and each recipient’s evidence decide the candidate.")
        rationale: "The current commitment and each recipient’s evidence decide the candidate." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "It derives a correction question per affected recipient.")
      (.o identity: 'receipts question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'deduplication referent: 'receipts
        glyph: "dev/d2/examples/org-agenda-contract/assets/receipts.svg" title: "Durable sends if allowed" explanation: "One handoff per key."
        representation: (.o family: 'receipts state: 'current intent: 'state action: "Corrections and first notices retain separate stable keys.")
        rationale: "Corrections and first notices retain separate stable keys." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Durable atomically consumes that key once")
    ) facet-needs: (list
      (.o question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'current-plan)
      (.o question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'receipt-match)
      (.o question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'recipient-judgment)
      (.o question: 'late-receipt target: "OrgDurableDeclarations::agendaDesign" facet: 'deduplication)
    ) mechanism: (.o links: (list
      (.o identity: 'current-plan from: 'draft to: 'authority role: 'basis
        label: "Current time" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The 19:00 plan remains current.")
      (.o identity: 'receipt-match from: 'late-receipt to: 'authority role: 'basis
        label: "Matches old handoff" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The receipt settles provider acceptance of\nthat old payload.")
      (.o identity: 'authorized-send from: 'authority to: 'receipts role: 'basis
        label: "Check permission" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Durable checks the current plan, evidence, authorization, recipient and\nusefulness deadline.")
      (.o identity: 'returned-evidence from: 'receipts to: 'authority role: 'basis
        label: "Receipts return" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "preserves consumed decisions and returns findings for assessment.")
    ) requirements: (list
      (.o question: 'late-receipt from: 'draft to: 'authority role: 'basis)
      (.o question: 'late-receipt from: 'late-receipt to: 'authority role: 'basis)
      (.o question: 'late-receipt from: 'authority to: 'receipts role: 'basis)
      (.o question: 'late-receipt from: 'receipts to: 'authority role: 'basis)
    ) traces: '())))
