;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export TeachingItems TeachingMechanism CaseNeeds)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/34-durable-task-real-source-case.org")
(def Fixture "DurableTaskSourceCase::fixture")
(def Known "The patch exists. That does not establish Task acceptance.")
(def Gap "The missing fact is whether the change satisfies the requested contract.")
(def Basis "The candidate patch and the existing architecture must be considered together.")
(def Open "The model can propose another explanation without changing the rule program.")
(def Duty "The Task remains open until its own acceptance basis is available.")
(def (item id-value facet-value title-value detail-value action-value quote-value intent-value)
  (.o identity: id-value question: 'is-the-work-finished target: Fixture facet: facet-value
    glyph: (string-append "dev/d2/examples/durable-task-source-case/assets/" (symbol->string id-value) ".svg")
    title: title-value explanation: detail-value rationale: action-value
    representation: (.o family: id-value state: 'current intent: intent-value action: action-value)
    source: Org excerpt: quote-value))
(def TeachingItems
  (list
    (item 'request 'task-request "What was asked" "Do not guess what happened."
      "A goal flag carries the retained request, not an execution step." Gap 'input)
    (item 'design 'design-basis "The existing design" "Each keeps its own responsibility."
      "An open architecture document links three existing responsibilities." Basis 'state)
    (item 'patch 'source-artifact "A real source change" "A saved patch is an artifact."
      "A source page names durable-owner.ss and highlights the recovery edit, not a fabricated code line." Known 'state)
    (item 'relate 'evidence-question "Context + ASCENT / relate" "Does the change meet the design?"
      "Two unlike source documents converge on an open contract question rather than a success stamp." Basis 'check)
    (item 'explore 'model-exploration "Model / follow a question" "Read, compare or reconsider."
      "A branching investigation names the changed source and its existing design as inquiry objects; another approach remains possible." Open 'object)
    (item 'duty 'task-responsibility "Task / still open" "What shows the design is met?"
      "An open task folder keeps responsibility visible without a pass count." Duty 'outcome)))
(def CaseNeeds (map (lambda (p) (.o question: 'is-the-work-finished target: Fixture facet: (.ref p 'facet))) TeachingItems))
(def (link id-value from-value to-value role-value label-value quote-value meaning-value)
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
    meaning: meaning-value propagates?: #t style: (if (eq? role-value 'basis) "support" "flow")
    source: Org excerpt: quote-value))
(def TeachingMechanism
  (.o links:
    (list (link 'goal 'request 'relate 'uncertainty "goal" Gap (.o input?: #t))
          (link 'contract 'design 'relate 'basis "design" Basis (.o))
          (link 'observed 'patch 'relate 'basis "patch" Known (.o))
          (link 'inquiry 'relate 'explore 'qualification "" Open (.o))
          (link 'responsibility 'relate 'duty 'obligation "" Duty (.o outcome?: #t)))
    requirements: (list (.o question: 'is-the-work-finished from: 'patch to: 'relate role: 'basis))
    traces: (list (.o question: 'is-the-work-finished from: 'request to: 'duty))))
