;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def result
  (let* ((session
          (relational-open-program-session
           (relational-program
            (relation edge (from to) edge-data)
            (relation blocked (from to) blocked-data)
            (relation allowed (from to))
            (rule (allowed ?x ?y) (edge ?x ?y) (not (blocked ?x ?y)))
            (limits 32 64 128))))
         (first (relational-program-session-run session)))
    (relational-program-replace-source! session 'blocked replacement-data)
    (let (second (relational-program-session-run session))
      (list (canonical (relational-program-query first 'allowed))
            (canonical (relational-program-query second 'allowed))))))
