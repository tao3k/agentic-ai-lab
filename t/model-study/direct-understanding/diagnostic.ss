;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def result
  (let* ((report
          (relational-admit/report
           (relational-program
            (relation edge (from to) edge-data)
            (relation path (from to))
            (rule (path ?x ?z) (edge ?x ?y))
            (limits 8 8 16))))
         (diagnostic (relational-admission-report-diagnostic report)))
    (list (relational-diagnostic-code diagnostic)
          (relational-diagnostic-path diagnostic))))
