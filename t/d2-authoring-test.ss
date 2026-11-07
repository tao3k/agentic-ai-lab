;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" agentic-ai-lab/dev/d2.init.exports))
(export d2-authoring-test)
(def Scope (.get agentic-ai-lab/dev/d2.init.exports modules d2))
(def AuthoringContext. (.get Scope prototypes AuthoringContext))
(def (sample)
  (.o (:: @ AuthoringContext.)
    views: (list (.o identity: 'scene revision: 'r1 source-cut: 'cut1 audience: 'beginner))
    questions: (list (.o identity: 'why-late audience: 'beginner subject: 'evidence))
    needs: (list (.o question: 'why-late concept: 'known-time))
    explanations: (list (.o view: 'scene revision: 'r1 concept: 'known-time element: 'two-clocks))
    question-inventories: (list (.o view: 'scene revision: 'r1 source-cut: 'cut1))
    explanation-plan:
      (.o views: '() object-states: '() goals: '() prerequisites: '() audience-gaps: '()
          distinctions: '() candidates: '() makes-visible: '() meaning-reviews: '()
          critiques: '() goal-inventories: '())))
(def proposal (.o identity: 'drawing view: 'scene revision: 'r1 source-cut: 'cut1 asset-ref: "scene.svg" asset-sha: "asset1"))
(def render-value (.o proposal: 'drawing asset-sha: "asset1" image-sha: "pixels1"))
(def finding (.o identity: 'f1 view: 'scene revision: 'r1 source-cut: 'cut1 question: 'why-late
                  verdict: 'understood producer: 'model image-sha: "pixels1"))
(def observed (.o finding: 'f1 image-sha: "pixels1" producer: 'model))
(def (result input) ((.get Scope author) input))
(def (kinds input) (map (lambda (request) (.ref request 'kind)) (.ref (result input) 'requests)))
(def d2-authoring-test
  (test-suite "Image-bound, event-driven authoring"
    (test-case "facts can arrive together without traversing compulsory stages"
      (def base (sample))
      (check-equal? (kinds base) '(propose))
      (def complete (.o (:: @ base) proposals: (list proposal) renders: (list render-value)
                         feedback: (list finding) observations: (list observed)))
      (check-equal? (kinds complete) '())
      (check-equal? (.ref (result complete) 'reviewable) '((scene r1 cut1 drawing "pixels1"))))
    (test-case "unobserved and wrong-image model approval cannot close review"
      (def base (sample))
      (def unseen (.o (:: @ base) proposals: (list proposal) renders: (list render-value) feedback: (list finding)))
      (check-equal? (kinds unseen) '(inspect))
      (def wrong (.o (:: @ unseen) observations: (list (.o (:: @ observed) image-sha: "other-pixels"))))
      (check-equal? (kinds wrong) '(inspect)))
    (test-case "changing source or asset invalidates old findings"
      (def base (sample))
      (def changed (.o (:: @ base) proposals: (list (.o (:: @ proposal) asset-sha: "asset2"))
                        renders: (list render-value) feedback: (list finding) observations: (list observed)))
      (check-equal? (kinds changed) '(render))
      (def new-cut (.o (:: @ changed) views: (list (.o identity: 'scene revision: 'r1 source-cut: 'cut2 audience: 'beginner))))
      (check-equal? (kinds new-cut) '(propose)))
    (test-case "a new question reopens an already reviewed picture"
      (def base (sample))
      (def extended (.o (:: @ base) proposals: (list proposal) renders: (list render-value)
                         feedback: (list finding) observations: (list observed)
                         questions: (cons (.o identity: 'scope audience: 'beginner subject: 'knowledge)
                                          (.ref base 'questions))))
      (check-equal? (kinds extended) '(inspect))
      (check-equal? (.ref (result extended) 'reviewable) '()))
    (test-case "unclear and uncertain findings create different open obligations"
      (def base (sample))
      (def unclear (.o (:: @ base) proposals: (list proposal) renders: (list render-value)
                        observations: (list observed) feedback: (list (.o (:: @ finding) verdict: 'unclear))))
      (check-equal? (kinds unclear) '(reconsider))
      (def uncertain (.o (:: @ unclear) feedback: (list (.o (:: @ finding) verdict: 'uncertain))))
      (check-equal? (kinds uncertain) '(investigate)))
    (test-case "review approval cannot bypass an unmet explanation need"
      (def base (sample))
      (def plan-base (.ref base 'explanation-plan))
      (def unmet (.o (:: @ base) proposals: (list proposal) renders: (list render-value)
                      feedback: (list finding) observations: (list observed)
                      explanation-plan:
                        (.o (:: @ plan-base)
                          views: (list (.o identity: 'scene revision: 'r1 audience: 'beginner))
                          goals: (list (.o view: 'scene revision: 'r1 subject: 'evidence concept: 'two-times))
                          audience-gaps: (list (.o audience: 'beginner concept: 'two-times))
                          distinctions: (list (.o concept: 'two-times facet: 'event-versus-known)))))
      (check-equal? (kinds unmet) '(explain))
      (check-equal? (.ref (result unmet) 'reviewable) '()))))
