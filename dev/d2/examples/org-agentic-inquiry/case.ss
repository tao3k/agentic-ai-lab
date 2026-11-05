;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'org-agentic-inquiry audience: 'young-novice primary: 'open-question width: 1550
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.sysml" "dev/d2/examples/org-agentic-inquiry/view.sysml")
    view: "OrgAgenticView::teaching"
    title: "A question stays open until evidence answers it"
    intro: "An interrupted write leaves something to find out."
    questions: (list (.o identity: 'open-question audience: 'young-novice subject: 'inquiry
      text: "How do intent, evidence and model choices change what can happen next?"))
    choices: (list (.o source-ref: "OrgDurableDeclarations::inquiryDesign" caption: "Context inquiry" glyph: "" role: "default"
      rationale: "Context relates the question, evidence and proposals."))
    teaching: (list
      (.o identity: 'intent question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'intent referent: 'intent
        glyph: "dev/d2/examples/org-agentic-inquiry/assets/intent.svg" title: "Org gives intent" explanation: "Did the write happen?"
        representation: (.o family: 'intent state: 'current intent: 'state action: "A named question is addressable in its source.")
        rationale: "A named question is addressable in its source." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "An Org heading is one way to put human intent in a source the Context\nEngine can locate and revisit.")
      (.o identity: 'context question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'question referent: 'context
        glyph: "dev/d2/examples/org-agentic-inquiry/assets/context.svg" title: "Context holds the question" explanation: "ASCENT finds the missing link."
        representation: (.o family: 'context state: 'current intent: 'state action: "An open question relates evidence and scope.")
        rationale: "An open question relates evidence and scope." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Derives what needs checking from current evidence and policy.")
      (.o identity: 'model question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'choice referent: 'model
        glyph: "dev/d2/examples/org-agentic-inquiry/assets/model.svg" title: "The model explores" explanation: "Check a receipt, or defer."
        representation: (.o family: 'model state: 'current intent: 'state action: "The branch represents alternatives the model may propose.")
        rationale: "The branch represents alternatives the model may propose." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Chooses what to investigate or defer.")
      (.o identity: 'durable question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'handoff referent: 'durable
        glyph: "dev/d2/examples/org-agentic-inquiry/assets/durable.svg" title: "Durable keeps the decision" explanation: "Checks permission. Keeps evidence."
        representation: (.o family: 'durable state: 'current intent: 'state action: "A recorded, guarded handoff survives restart.")
        rationale: "A recorded, guarded handoff survives restart." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Durable retains the admitted\ndecision and the exact input basis.")
    ) facet-needs: (list
      (.o question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'intent)
      (.o question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'question)
      (.o question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'choice)
      (.o question: 'open-question target: "OrgDurableDeclarations::inquiryDesign" facet: 'handoff)
    ) mechanism: (.o links: (list
      (.o identity: 'intent-source from: 'intent to: 'context role: 'basis
        label: "Scope and intent" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The declared\nquestion has one stable identity per Attempt, effect and scope.")
      (.o identity: 'working-view from: 'model to: 'context role: 'basis
        label: "Proposed checks" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Chooses what to investigate or defer.")
      (.o identity: 'selected-proposal from: 'context to: 'durable role: 'basis
        label: "Selected handoff" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "A proposal carries the question and a reference to the relevant Context\nbasis")
      (.o identity: 'finding from: 'durable to: 'context role: 'basis
        label: "Findings to assess" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "New observations\nreturn to Context as evidence candidates for Temporal assessment.")
    ) requirements: (list
      (.o question: 'open-question from: 'intent to: 'context role: 'basis)
      (.o question: 'open-question from: 'model to: 'context role: 'basis)
      (.o question: 'open-question from: 'context to: 'durable role: 'basis)
      (.o question: 'open-question from: 'durable to: 'context role: 'basis)
    ) traces: '())))
