;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" tao3k/agentic-ai-lab/dev/d2.init.exports))
(export d2-scene-test)
(def Scope (.get tao3k/agentic-ai-lab/dev/d2.init.exports modules d2))
(def (node name ref) (.o identity: name source-ref: ref kind: 'source label: ref))
(def native (.o nodes: (list (node 'a "root") (node 'b "root/hidden") (node 'c "root/hidden/subject") (node 'd "root/other"))
               parents: '((b a) (c b) (d a))))
(def (choice ref asset) (.o source-ref: ref caption: ref glyph: asset role: "example" rationale: "What this learner needs to see"))
(def choices (list (choice "root" "") (choice "root/hidden/subject" "first.svg") (choice "root/other" "other.svg")))
(def needs (list (.o question: 'new-reader-question facet: 'new-distinction target: "root/hidden/subject")))
(def (scene source-value choice-values need-values) ((.get Scope scene) source-value choice-values need-values))
(def d2-scene-test
  (test-suite "Reusable reader-relative source scene, with no layout table"
    (test-case "a needed source occurrence and its chosen ancestors define the view"
      (def value (scene native choices needs))
      (check-equal? (length (.ref value 'nodes)) 2)
      (check-equal? (.ref value 'parents) '((c a)))
      (check-equal? (.ref value 'missing-choices) '()))
    (test-case "new reader needs can select a different occurrence without a domain rule"
      (def value (scene native choices (list (.o question: 'another facet: 'other target: "root/other"))))
      (check-equal? (length (.ref value 'nodes)) 2)
      (check-equal? (.ref value 'parents) '((d a))))
    (test-case "the same source can use a new model-chosen image"
      (def value (scene native (list (choice "root" "") (choice "root/hidden/subject" "new-metaphor.svg")) needs))
      (check (member "new-metaphor.svg" (map (lambda (n) (.ref n 'glyph)) (.ref value 'nodes))) ? pair?))
    (test-case "unknown source and cyclic ownership cannot be invented by a visual proposal"
      (check-exception (scene native (list (choice "invented" "x.svg")) needs) (lambda (_) #t))
      (def cyclic (.o (:: @ native) parents: '((b a) (a c) (c b))))
      (check-exception (scene cyclic choices needs) (lambda (_) #t)))
    (test-case "a missing image for a required object is exposed rather than silently substituted"
      (def value (scene native (list (choice "root" "")) needs))
      (check-equal? (.ref value 'missing-choices) '((c))))))
