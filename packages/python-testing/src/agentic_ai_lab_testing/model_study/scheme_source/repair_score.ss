;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Independent finite expectations from the pinned Rust/Scheme corpus.
;;; Read receipt data; never evaluate model text.
(export main)

(def (read-one path)
  (call-with-input-file path
    (lambda (port)
      (let ((datum (read port)))
        (if (eof-object? (read port)) datum #f)))))

(def (valid-row? actual name expected)
  (and (list? actual)
       (= (length actual) 8)
       (eq? (car actual) name)
       (eq? (cadr actual) 'complete)
       (equal? (caddr actual) expected)
       (eq? (list-ref actual 3) #t)
       (eq? (list-ref actual 4) 'complete)
       (eq? (list-ref actual 5) 'valid)
       (eq? (list-ref actual 6) 'valid)
       (null? (list-ref actual 7))))

(def (main . paths)
  (unless (= (length paths) 1) (error "expected one receipt path"))
  (let (receipt (read-one (car paths)))
    (write
     (list 'score
           (list 'exact
                 (and (list? receipt)
                      (= (length receipt) 5)
                      (eq? (car receipt) 'receipt)
                      (valid-row? (cadr receipt) 'blocked '((1 1)))
                      (valid-row? (caddr receipt) 'unblocked '((1 2)))
                      (valid-row? (list-ref receipt 3)
                                  'duplicate-edge '((1 2)))
                      (equal? (list-ref receipt 4) '(stale invalid))))))
    (newline)))
