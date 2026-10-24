;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read this program. Return only the one S-expression written by main;
;;; no prose or Markdown. Public contract: candidate rules are inert data.
;;; A rule (head ...) (body1 ...) (body2 ...) joins matching rows on shared
;;; variables. Recursive rules iterate to a finite fixed point. Query
;;; variables determine the output columns. Output rows are bare tuples;
;;; relation names are not included in those tuples.
(import (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-rows))
(export main)

(def (main . _)
  (let* ((source (reasoning-source-snapshot
                  'graph 1 '((edge 2 ((0 1) (1 2))))))
         (candidate
          '(candidate
             (relation path 2)
             (rule (path ?x ?y) (edge ?x ?y))
             (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
             (query path ?x ?y)
             (limits 16 64 64))))
    (write (list 'answer
                 (reasoning-receipt-rows
                  (reasoning-attempt source candidate))))
    (newline)))
