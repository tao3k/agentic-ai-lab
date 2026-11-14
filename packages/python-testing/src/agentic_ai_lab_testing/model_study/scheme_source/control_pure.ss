;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read this self-contained Scheme program. Return only the one
;;; S-expression written by main; no prose or Markdown.
(export main)

(def (main . _)
  (let* ((weights '((1 4) (1 6) (2 3)))
         (kept (filter (lambda (row) (even? (cadr row))) weights))
         (doubled (map (lambda (row)
                         (list (car row) (+ (cadr row) (cadr row))))
                       kept)))
    (write (list 'answer doubled))
    (newline)))
