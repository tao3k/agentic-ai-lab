;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def result
  (canonical
   (relational-query-name
    (relational-solve
     (relational-admit
      (relational-program
       (relation edge (from to) edge-data)
       (relation joined (from to))
       (rule (joined ?x ?z) (edge ?x ?y) (edge ?y ?z))
       (limits 32 64 128))))
    'joined)))
