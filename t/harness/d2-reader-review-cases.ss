;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object)
(export d2-reader-review-cases)
(def (d2-reader-review-cases review-procedure Question.)
(def (example)
  (.o views: (list (.o identity: 'picture revision: 'r1 audience: 'beginner))
      questions: (list (.o (:: @ Question.) identity: 'reader-question audience: 'beginner subject: 'relations
                           text: "Can I explain what the arrows mean?"))
      needs: (list (.o question: 'reader-question concept: 'relations))
      prerequisites: (list (.o concept: 'relations premise: 'arrow-meaning))
      explanations: (list (.o view: 'picture revision: 'r1 concept: 'relations element: 'graph))
      feedback: '() learner-checks: '()))
(def (rows input name) ((.ref (review-procedure input) 'rows-of) name))
  (test-suite "ASCENT reader questions drive diagram revision"
    (test-case "a missing prerequisite explanation opens a reader question"
      (check-equal? (rows (example) 'ExplanationGap) '((picture r1 reader-question arrow-meaning)))
      (check-equal? (rows (example) 'OpenQuestion) '((picture r1 reader-question))))
    (test-case "model approval does not establish observed learner understanding"
      (def base (example))
      (def reviewed (.o (:: @ base)
                      feedback: (list (.o identity: 'model-critique view: 'picture revision: 'r1
                                          question: 'reader-question verdict: 'understood producer: 'model))))
      (check-equal? (rows reviewed 'ReviewSupport) '((picture r1 reader-question model-critique)))
      (check-equal? (rows reviewed 'LearnerSupport) '())
      (check-equal? (rows reviewed 'OpenQuestion) '((picture r1 reader-question))))
    (test-case "old review cannot answer a changed view; new questions remain open"
      (def base (example))
      (def revised (.o (:: @ base)
                     views: (list (.o identity: 'picture revision: 'r2 audience: 'beginner))
                     questions: (cons (.o (:: @ Question.) identity: 'new-reader-question audience: 'beginner
                                           subject: 'objects text: "How do these blocks fit together?")
                                      (.ref base 'questions))
                     feedback: (list (.o identity: 'old-review view: 'picture revision: 'r1
                                         question: 'reader-question verdict: 'understood producer: 'learner))
                     learner-checks: (list (.o finding: 'old-review audience: 'beginner))))
      (check-equal? (rows revised 'LearnerSupport) '())
      (check-equal? (length (rows revised 'AwaitingReview)) 2))
    (test-case "an explicit matching learner check is retained without a general readability claim"
      (def base (example))
      (def checked (.o (:: @ base)
                     explanations: (cons (.o view: 'picture revision: 'r1 concept: 'arrow-meaning element: 'legend)
                                         (.ref base 'explanations))
                     feedback: (list (.o identity: 'learner-reading view: 'picture revision: 'r1
                                         question: 'reader-question verdict: 'understood producer: 'learner))
                     learner-checks: (list (.o finding: 'learner-reading audience: 'beginner))))
      (check-equal? (rows checked 'LearnerSupport) '((picture r1 reader-question learner-reading)))
      (check-equal? (rows checked 'OpenQuestion) '()))
    (test-case "uncertain model feedback keeps the question open"
      (def base (example))
      (def uncertain (.o (:: @ base)
                       feedback: (list (.o identity: 'uncertain-review view: 'picture revision: 'r1
                                           question: 'reader-question verdict: 'unknown producer: 'model))))
      (check-equal? (rows uncertain 'UnsettledFeedback) '((picture r1 reader-question uncertain-review)))
      (check-equal? (rows uncertain 'OpenQuestion) '((picture r1 reader-question))))))
