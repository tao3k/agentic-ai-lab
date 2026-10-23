;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Qualification owner: measure one Agentic AI Lab build through the unique
;;; build.ss entry and emit a generation-neutral Scheme receipt.  Keeping the
;;; observer independent of std/json lets the v18 and v19 jobs measure the
;;; build before the application compatibility boundary is evaluated.

(import :gerbil/runtime/gambit
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-elapsed-ms)
        (only-in :std/misc/process
                 run-process/batch))

(export main)

;; : (-> String String String Void)
(def (darwin-gerbil-build-scenario-run phase toolchain receipt-path)
  (let* ((elapsed-ms
          (benchmark-elapsed-ms
           (lambda ()
             (run-process/batch '("gerbil" "build")))))
         (receipt
          `((schema . agentic-ai-lab.darwin-gerbil-build-scenario.v1)
            (phase . ,phase)
            (toolchain . ,toolchain)
            (entrypoint . "build.ss")
            (measurement-owner . asp-gerbil-scheme/benchmark-api)
            (executor . "gerbil build")
            (elapsed-ms . ,(exact->inexact elapsed-ms))
            (status . 0))))
    (call-with-output-file
     receipt-path
     (lambda (port)
       (write receipt port)
       (newline port)))
    (display "[agentic-ai-lab-darwin-gerbil] ")
    (write receipt)
    (newline)))

;; : (-> [String] Void)
(def (main . args)
  (unless (= (length args) 3)
    (displayln
     "usage: gxi t/qualification/darwin-gerbil-build-scenario.ss PHASE TOOLCHAIN RECEIPT")
    (exit 64))
  (darwin-gerbil-build-scenario-run
   (car args)
   (cadr args)
   (caddr args)))
