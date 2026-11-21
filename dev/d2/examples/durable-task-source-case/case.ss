;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism CaseNeeds))
(export DesignCase)
(def DesignCase
  (.o identity: 'durable-task-source-case audience: 'young-novice primary: 'is-the-work-finished width: 1800
    org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/34-durable-task-real-source-case.org"
    inputs: '("dev/d2/examples/durable-task-source-case/teaching.ss" "modules/ai-agentic-context/durable-owner.ss")
    models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/34-durable-task-real-source-case.sysml"
              "dev/d2/examples/durable-task-source-case/view.sysml")
    view: "DurableTaskSourceCaseView::teaching"
    title: "The patch is saved. Is the task finished?"
    intro: "A real change to durable-owner.ss. Keep the request, the design and the evidence together."
    teaching: TeachingItems mechanism: TeachingMechanism facet-needs: CaseNeeds
    questions: (list (.o identity: 'is-the-work-finished audience: 'young-novice subject: 'task
      text: "What does a saved patch tell us, and what does it leave open?"))
    choices: (list (.o source-ref: "DurableTaskSourceCase::fixture" caption: "Durable source change case"
      glyph: "" role: "default" rationale: "One native design fixture supplies six explanatory facets."))))
