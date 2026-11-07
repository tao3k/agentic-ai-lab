;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def result
  (let ((calls 0) (selected first-label))
    (let* ((program
            (relational-program
             (relation tag (value) (list (list first-label) (list second-label)))
             (relation chosen (value))
             (rule (chosen (value (begin (set! calls (+ calls 1)) selected)))
               (tag (value selected)))
             (limits 8 8 16)))
           (admission (relational-admit program)))
      (set! selected second-label)
      (list calls (relational-query-name (relational-solve admission) 'chosen)))))
