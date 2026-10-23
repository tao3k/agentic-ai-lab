;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read two invalid native Scheme programs. Return only the
;;; S-expression written by main, including diagnostic code and path.
(import (only-in :gerbil-ascent/program/interface
                 relational-program relational-admit/report
                 relational-admission-report-diagnostic
                 relational-diagnostic-code relational-diagnostic-path))
(export main)

(def (diagnostic-row program)
  (let (diagnostic
        (relational-admission-report-diagnostic
         (relational-admit/report program)))
    (cons (relational-diagnostic-code diagnostic)
          (relational-diagnostic-path diagnostic))))

(def (main . _)
  (let* ((missing-body
          (relational-program
           (relation edge (from to) '((1 2)))
           (relation path (from to))
           (rule (path ?x ?y) (edge ?x ?y) (missing ?y ?x))
           (limits 8 8 16)))
         (unbound-head
          (relational-program
           (relation edge (from to) '((1 2)))
           (relation path (from to))
           (rule (path ?x ?z) (edge ?x ?y))
           (limits 8 8 16))))
    (write (list 'answer
                 (list (diagnostic-row missing-body))
                 (list (diagnostic-row unbound-head))))
    (newline)))
