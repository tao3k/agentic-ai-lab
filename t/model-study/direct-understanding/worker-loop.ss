;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Appended to trusted task thunks. Only inert candidate files are read.
(def (observe-prediction expected candidate-path)
  (if (not (string? candidate-path))
    (hash (readable #f) (correct #f))
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
(displayln "HARNESS-OK worker-ready") (force-output)
(let loop ()
  (let (line (read-line))
    (if (eof-object? line)
      (begin (displayln "HARNESS-OK worker-closed") (displayln "OK")
             (force-output) (exit 0))
      (let* ((request (parameterize ((current-json-read-options
                                     (JSONReadOptions object-as-hash: #t)))
                        (string->json line)))
             (case (hash-get request "case"))
             (candidate-path (hash-get request "candidate"))
             (thunk (hash-get computations case)))
        (unless thunk (error "unknown frozen task" case))
        (let* ((expected (thunk))
               (actual (call-with-output-string
                         (lambda (port) (write expected port) (newline port))))
               (observation (observe-prediction expected candidate-path)))
          (hash-put! observation 'case case)
          (hash-put! observation 'nativeDatum actual)
          (displayln (json->string observation)) (force-output))
        (loop)))))
