;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Open model-authored lesson facts; no ASCENT rules or execution policy.
(import :clan/poo/object "./history.ss")
(export illustration-context)
(def (illustration-context scope-value revision-id)
  (def Context. (.get scope-value prototypes AuthoringContext))
  (def current-view (.o identity: 'context-lesson revision: revision-id source-cut: 'window-example-v1 audience: 'beginner))
  (def plan-input
    (.o views: (list current-view)
        object-states: (map (lambda (object-value)
          (.o view: 'context-lesson revision: revision-id subject: (.ref object-value 'subject)
              state: (.ref object-value 'state))) (.ref illustration-history 'subjects))
        goals: (map (lambda (goal-value)
          (.o view: 'context-lesson revision: revision-id subject: (.ref goal-value 'subject)
              concept: (.ref goal-value 'concept))) (.ref illustration-history 'learning-goals))
        prerequisites: '()
        audience-gaps: (.ref illustration-history 'audience-gaps)
        distinctions: (.ref illustration-history 'distinctions)
        candidates: (.ref illustration-history 'representations)
        makes-visible: (.ref illustration-history 'makes-visible)
        meaning-reviews: (.ref illustration-history 'meaning-reviews)
        critiques: '() goal-inventories: (list (.o view: 'context-lesson revision: revision-id))))
  (def context-input
    (.o (:: @ Context.) views: (list current-view)
        proposals: (.ref illustration-history 'proposals) renders: (.ref illustration-history 'renders)
        observations: (.ref illustration-history 'observations) feedback: (.ref illustration-history 'feedback)
        questions: (.ref illustration-history 'questions)
        needs: (.ref illustration-history 'needs)
        explanations: (.ref illustration-history 'explanations)
        explanation-plan: plan-input
        question-inventories: (list (.o view: 'context-lesson revision: revision-id source-cut: 'window-example-v1))))
  context-input)
