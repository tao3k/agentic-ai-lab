;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read this Gerbil Scheme program. Return only the one S-expression
;;; written by main, with no prose or Markdown.
(import (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-rows))
(export main)

(def (main . _)
  (let* ((source
          (reasoning-source-snapshot
           'study-negation-count 1
           '((edge 2 ((1 2) (2 3)))
             (blocked 2 ((1 3)))
             (weight 2 ((2 4) (3 6)))
             (root 1 ((1))))))
         (candidate
          '(candidate
             (relation path 2)
             (relation allowed 2)
             (relation weighted 2)
             (relation summary 2)
             (rule (path ?x ?y) (edge ?x ?y))
             (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
             (rule (allowed ?x ?y)
                   (path ?x ?y) (not (blocked ?x ?y)))
             (rule (weighted ?x ?v)
                   (allowed ?x ?y) (weight ?y ?w)
                   (where (even? ?w))
                   (compute ?v (+ ?w ?w)))
             (rule (summary ?r ?n)
                   (root ?r)
                   (reduce ?n (count) (weighted ?r ?v)))
             (query summary 1 ?n)
             (limits 16 64 128))))
    (write (list 'answer
                 (reasoning-receipt-rows
                  (reasoning-attempt source candidate))))
    (newline)))
