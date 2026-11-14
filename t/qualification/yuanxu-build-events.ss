;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(export compile-events)

(def (compile-events output)
  (def target-prefix "... compile ")
  (def worker-prefix "... execute compile job ")
  (def (collect-target line events next)
    ;; Native workers can print a job record between the prefix and target
    ;; or directly after the target before Make prints its newline.
    (let* ((worker (string-contains line worker-prefix))
           (target (if worker (substring line 0 worker) line)))
      (if (string-empty? target)
        (next events #t)
        (next (cons target events) #f))))
  (call-with-input-string output
    (lambda (port)
      (let loop ((events '()) (pending? #f))
        (let (line (read-line port))
          (cond
           ((eof-object? line)
            (when pending? (error "missing target in native Make output"))
            (list-sort string<? events))
           ((string-prefix? worker-prefix line)
            (loop events pending?))
           ((string-prefix? target-prefix line)
            (when pending? (error "missing target in native Make output"))
            (collect-target (substring line (string-length target-prefix)
                                       (string-length line)) events loop))
           (pending? (collect-target line events loop))
           (else (loop events #f))))))))
