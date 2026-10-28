;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Shared native Gerbil benchmark functions. Scenario runners own only values.

(import :gerbil/runtime/gambit
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/misc/process run-process))

(export benchmark-temporary-root
        benchmark-gerbil
        benchmark-command
        benchmark-measure
        benchmark-sample-ref
        benchmark-warm-p50
        benchmark-series-compile-count
        benchmark-classification
        benchmark-write-receipt)

(def (benchmark-temporary-root name)
  (let (root
        (path-expand
         (string-append name "." (number->string (current-jiffy)))
         (getenv "RUNNER_TEMP" (getenv "TMPDIR" "/tmp"))))
    (create-directory* root)
    root))

(def (benchmark-gerbil)
  (path-expand "bin/gerbil" (getenv "GERBIL_PREFIX" "/opt/homebrew")))

(def (benchmark-command image timeout arguments)
  (append
   ["env"
    (string-append "GERBIL_PATH=" image)
    (string-append "GERBIL_BUILD_CORES="
                   (getenv "GERBIL_BUILD_CORES" "1"))
    (string-append "GERBIL_BUILD_VERBOSE="
                   (getenv "GERBIL_BUILD_VERBOSE" "1"))
    "gtimeout" "--signal=TERM" "--kill-after=3s" timeout]
   arguments))

(def (benchmark-compile-count output)
  (length
   (filter (lambda (line) (string-prefix? "... compile " line))
           (string-split output #\newline))))

(def (benchmark-measure label image directory arguments
                        timeout: (timeout "30s"))
  (displayln "[std-make-benchmark] phase=" label " event=process-start")
  (force-output)
  (let* ((started (current-jiffy))
         (exit-status 0)
         (output
          (run-process (benchmark-command image timeout arguments)
                       directory: directory
                       stderr-redirection: #t
                       coprocess: read-all-as-string
                       check-status:
                       (lambda (status _)
                         (set! exit-status status))))
         (elapsed-ns
          (quotient (* (- (current-jiffy) started) 1000000000)
                    (jiffies-per-second)))
         (sample
          `((phase . ,label)
            (elapsedNs . ,elapsed-ns)
            (exitStatus . ,exit-status)
            (compileCount . ,(benchmark-compile-count output)))))
    (display output)
    (displayln "[std-make-benchmark] phase=" label
               " event=process-returned elapsed-ns=" elapsed-ns
               " exit-status=" exit-status
               " compile-count=" (cdr (assq 'compileCount sample)))
    (force-output)
    (unless (zero? exit-status)
      (error "native std/make benchmark process failed" label exit-status))
    sample))

(def (benchmark-sample-ref sample key)
  (cdr (assq key sample)))

(def (benchmark-warm-p50 samples)
  (list-ref
   (list-sort <
              (map (lambda (sample)
                     (benchmark-sample-ref sample 'elapsedNs))
                   samples))
   (quotient (length samples) 2)))

(def (benchmark-series-compile-count samples)
  (apply + (map (lambda (sample)
                  (benchmark-sample-ref sample 'compileCount))
                samples)))

(def (benchmark-classification warm-p50-ns)
  (let ((floor-ns 13000000000)
        (band-ceiling-ns 19000000000)
        (budget-ns
         (* (string->number (getenv "WARM_BUDGET_SECONDS" "19"))
            1000000000)))
    (cond
     ((< warm-p50-ns floor-ns) 'below-prior-13s-floor)
     ((<= warm-p50-ns band-ceiling-ns) 'prior-13-19s-band-persists)
     ((<= warm-p50-ns budget-ns) 'above-prior-band-within-budget)
     (else 'warm-budget-exceeded))))

(def (benchmark-write-receipt path receipt)
  (call-with-output-file path
    (lambda (port) (pretty-print receipt port))))
