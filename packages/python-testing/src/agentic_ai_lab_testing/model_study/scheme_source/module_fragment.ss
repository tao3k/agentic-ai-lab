;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read the Gerbil module use below. Return only the S-expression
;;; written by main. The export name reach refers to private path.
(import (only-in :gerbil-ascent/program/interface
                 relational-fragment relational-compose relational-admit
                 relational-solve relational-query))
(export main)

(def graph
  (relational-fragment
   (import)
   (source (edge (from to) '((0 1) (1 2))))
   (private (path (from to)))
   (export (reach path))
   (rule (path ?x ?y) (edge ?x ?y))
   (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))))

(def (main . _)
  (let (result
        (relational-solve
         (relational-admit
          (relational-compose (list graph) 16 64 128))))
    (write (list 'answer (relational-query result graph 'reach)))
    (newline)))
