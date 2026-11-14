;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" tao3k/agentic-ai-lab/dev/d2.init.exports))
(export d2-explanation-test)
(def Scope (.get tao3k/agentic-ai-lab/dev/d2.init.exports modules d2))
(def Representation. (.get Scope prototypes Representation))
(def (example)
  (.o views: (list (.o identity: 'explanation revision: 'r1 audience: 'beginner))
      object-states: (list (.o view: 'explanation revision: 'r1 subject: 'idea state: 'open))
      goals: (list (.o view: 'explanation revision: 'r1 subject: 'idea concept: 'competing-explanations))
      prerequisites: (list (.o concept: 'competing-explanations premise: 'evidence-support))
      audience-gaps: (list (.o audience: 'beginner concept: 'competing-explanations)
                           (.o audience: 'beginner concept: 'evidence-support))
      distinctions: (list (.o concept: 'competing-explanations facet: 'alternatives-remain-open)
                          (.o concept: 'evidence-support facet: 'support-is-not-proof))
      candidates: (list (.o (:: @ Representation.) identity: 'plain-box subject: 'idea state: 'open asset-ref: "box.svg")
                        (.o (:: @ Representation.) identity: 'branch-scene subject: 'idea state: 'open asset-ref: "branch.svg"))
      makes-visible: (list (.o candidate: 'branch-scene facet: 'alternatives-remain-open)
                           (.o candidate: 'branch-scene facet: 'support-is-not-proof))
      meaning-reviews: (list (.o view: 'explanation revision: 'r1 candidate: 'plain-box)
                             (.o view: 'explanation revision: 'r1 candidate: 'branch-scene))
      critiques: '() goal-inventories: (list (.o view: 'explanation revision: 'r1))))
(def (rows input relation) ((.ref ((.get Scope plan) input) 'rows-of) relation))
(def d2-explanation-test
  (test-suite "ASCENT explanation needs precede visual choice"
    (test-case "a labeled box does not communicate the required distinctions"
      (check-equal? (length (rows (example) 'ExplanationNeed)) 2)
      (check-equal? (length (rows (example) 'MissingFacet)) 2)
      (check-equal? (rows (example) 'CandidateForReview)
                    '((explanation r1 idea branch-scene "branch.svg"))))
    (test-case "reader critique reopens a representation despite declared coverage"
      (def base (example))
      (def criticized (.o (:: @ base)
                        critiques: (list (.o view: 'explanation revision: 'r1
                                             candidate: 'branch-scene reason: 'reader-cannot-follow))))
      (check-equal? (rows criticized 'CandidateForReview) '()))
    (test-case "a model can supply a new metaphor without adding a rule or glyph kind"
      (def base (example))
      (def extended (.o (:: @ base)
                      candidates: (list (.o (:: @ Representation.) identity: 'new-analogy
                                           subject: 'idea state: 'open asset-ref: "new-model-asset.svg"))
                      makes-visible: (list (.o candidate: 'new-analogy facet: 'alternatives-remain-open)
                                           (.o candidate: 'new-analogy facet: 'support-is-not-proof))
                      meaning-reviews: (list (.o view: 'explanation revision: 'r1 candidate: 'new-analogy))))
      (check-equal? (rows extended 'CandidateForReview)
                    '((explanation r1 idea new-analogy "new-model-asset.svg"))))
    (test-case "a different reader need not receive the same explanation"
      (def base (example))
      (def experienced (.o (:: @ base) views: (list (.o identity: 'explanation revision: 'r1 audience: 'experienced))))
      (check-equal? (rows experienced 'ExplanationNeed) '())
      (check-equal? (rows experienced 'CandidateForReview) '()))))
