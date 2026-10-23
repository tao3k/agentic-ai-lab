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
  (let* ((before (reasoning-source-snapshot
                  'graph 1 '((edge 2 ((0 1) (1 2))))))
         (after (reasoning-source-snapshot
                 'graph 2 '((edge 2 ((0 1))))))
         (candidate
          '(candidate
             (relation path 2)
             (rule (path ?x ?y) (edge ?x ?y))
             (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
             (query path ?x ?y)
             (limits 16 64 64))))
    (write (list 'answer
                 (reasoning-receipt-rows
                  (reasoning-attempt before candidate))
                 (reasoning-receipt-rows
                  (reasoning-attempt after candidate))))
    (newline)))
