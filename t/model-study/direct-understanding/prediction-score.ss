;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/encoding/json "prediction-core.ss")
(displayln "MODULE-OK :std/encoding/json")
(force-output)
(export main)
(def (main expected-path candidate-path)
  (let ((expected (read-one expected-path)))
    (displayln
     (json->string
      (with-catch
       (lambda (failure)
         (hash (readable #f) (correct #f)
               (readerDiagnostic (call-with-output-string
                                  (lambda (port) (display-exception failure port))))))
       (lambda ()
         (let (candidate (read-one candidate-path))
           (hash (readable #t) (correct (equal? expected candidate))
                 (witness (call-with-output-string
                           (lambda (port)
                             (write (first-difference expected candidate '(result)) port))))))))))
    (displayln "HARNESS-OK model-understanding-score")
    (displayln "OK")
    (force-output)))
