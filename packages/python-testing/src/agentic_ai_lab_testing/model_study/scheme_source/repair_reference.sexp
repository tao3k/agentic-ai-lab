;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(candidate
  (relation path 2)
  (relation allowed 2)
  (relation weighted 2)
  (relation summary 2)
  (rule (path ?x ?y) (edge ?x ?y))
  (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
  (rule (allowed ?x ?y) (path ?x ?y) (not (blocked ?x ?y)))
  (rule (weighted ?x ?v) (allowed ?x ?y) (weight ?y ?w)
        (where (even? ?w)) (compute ?v (+ ?w ?w)))
  (rule (summary ?r ?n) (root ?r)
        (reduce ?n (count) (weighted ?r ?v)))
  (query summary 1 ?n)
  (limits 16 64 128))
