;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignCase)
(def DesignCase
  (.o identity: 'org-durable-declarations audience: 'young-novice primary: 'same-slot width: 1500
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org"
    inputs: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.qnt" "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.lean")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.sysml" "dev/d2/examples/org-durable-declarations/view.sysml")
    view: "OrgDurableView::teaching"
    title: "A note says what to watch. What makes it run?"
    intro: "An Org heading and a clock supply different clues."
    questions: (list (.o identity: 'same-slot audience: 'young-novice subject: 'activation
      text: "Who accepts the check, and why is the same clock slot accepted only once?"))
    choices: (list (.o source-ref: "OrgDurableDeclarations::boundary" caption: "Admit an Org monitor" glyph: "" role: "default"
      rationale: "A declaration and an occurrence are separate inputs to admission."))
    teaching: (list
      (.o identity: 'heading question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'source referent: 'heading
        glyph: "dev/d2/examples/org-durable-declarations/assets/heading.svg" title: "Watch the workspace" explanation: "An Org heading names a read."
        representation: (.o family: 'heading state: 'current intent: 'state action: "The heading declares a registered observation.")
        rationale: "The heading declares a registered observation." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "A heading describes what should be checked or run")
      (.o identity: 'slot question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'occurrence referent: 'slot
        glyph: "dev/d2/examples/org-durable-declarations/assets/slot.svg" title: "A clock slot comes due" explanation: "A late wakeup keeps 10:05."
        representation: (.o family: 'slot state: 'current intent: 'state action: "The clock identifies the nominal slot.")
        rationale: "The clock identifies the nominal slot." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "For a schedule this is the nominal slot, not delivery time")
      (.o identity: 'owner question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'authority referent: 'owner
        glyph: "dev/d2/examples/org-durable-declarations/assets/owner.svg" title: "Durable owner checks" explanation: "Current binding and permission."
        representation: (.o family: 'owner state: 'current intent: 'state action: "A guarded owner checks the trigger against the current binding.")
        rationale: "A guarded owner checks the trigger against the current binding." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The owner compares a delivery with the current binding and authority")
      (.o identity: 'journal question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'acceptance referent: 'journal
        glyph: "dev/d2/examples/org-durable-declarations/assets/journal.svg" title: "One acceptance record" explanation: "Repeats find the same record."
        representation: (.o family: 'journal state: 'current intent: 'state action: "The journal retains the slot and frozen input.")
        rationale: "The journal retains the slot and frozen input." source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "Delivery\nretries and owner restarts find the same acceptance record.")
    ) facet-needs: (list
      (.o question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'source)
      (.o question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'occurrence)
      (.o question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'authority)
      (.o question: 'same-slot target: "OrgDurableDeclarations::boundary" facet: 'acceptance)
    ) mechanism: (.o links: (list
      (.o identity: 'binding from: 'heading to: 'owner role: 'basis
        label: "What to check" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "The owner compares a delivery with the current binding and authority")
      (.o identity: 'wake from: 'slot to: 'owner role: 'basis
        label: "When to check" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "A trigger is a reason to observe.")
      (.o identity: 'accept from: 'owner to: 'journal role: 'basis
        label: "Record once" style: "support" meaning: (.o) propagates?: #t
        source: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/org-durable-declarations.org" excerpt: "then atomically records the activation key and its frozen input.")
    ) requirements: (list
      (.o question: 'same-slot from: 'heading to: 'owner role: 'basis)
      (.o question: 'same-slot from: 'slot to: 'owner role: 'basis)
      (.o question: 'same-slot from: 'owner to: 'journal role: 'basis)
    ) traces: '())))
