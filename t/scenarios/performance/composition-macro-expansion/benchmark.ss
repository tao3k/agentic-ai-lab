;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: compiler-process benchmark for the production composition macro.

(import :std/misc/process
        (only-in :std/time/precise
                 current-time-precise
                 PreciseTime-seconds
                 PreciseTime-nseconds)
        (only-in :clan/poo/object .o .ref))

(export run-composition-macro-expansion-case
        run-composition-macro-expansion-benchmark
        composition-macro-expansion-benchmark->alist)

(def +composition-expansion-1000-source+
  "t/scenarios/performance/composition-macro-expansion/case-1000.ss")

(def +composition-expansion-5000-source+
  "t/scenarios/performance/composition-macro-expansion/case-5000.ss")

(def +composition-expansion-1000-output-directory+
  ".cache/composition-macro-expansion-1000")

(def +composition-expansion-5000-first-output-directory+
  ".cache/composition-macro-expansion-5000-first")

(def +composition-expansion-5000-second-output-directory+
  ".cache/composition-macro-expansion-5000-second")

(def +composition-expansion-max-elapsed-ms+ 20000.0)

;; : (-> Fixnum String String Flonum PooBenchmarkReceipt)
(def (run-composition-macro-expansion-case
      profile-count
      source
      output-directory
      max-elapsed-ms)
  (unless (file-exists? output-directory)
    (create-directory* output-directory))
  (let* ((started-at (current-time-precise))
         (ignored-output
          (run-process
           (list "gxc"
                 "-S"
                 "-d"
                 output-directory
                 source)
           stderr-redirection: #t))
         (finished-at (current-time-precise))
         (elapsed-nanos
          (+ (* (- (PreciseTime-seconds finished-at)
                   (PreciseTime-seconds started-at))
                1000000000)
             (- (PreciseTime-nseconds finished-at)
                (PreciseTime-nseconds started-at)))))
    (let (elapsed-ms (/ elapsed-nanos 1000000.0))
    (let ((source-value source)
          (profile-count-value profile-count)
          (elapsed-ms-value elapsed-ms)
          (max-elapsed-ms-value max-elapsed-ms)
          (pass-value (<= elapsed-ms max-elapsed-ms)))
      (.o (kind 'agentic-ai-lab.scenario.macro-expansion.benchmark)
          (source source-value)
          (profile-count profile-count-value)
          (generated-profile-expression-count profile-count-value)
          (generated-compose-reference-count profile-count-value)
          (compiler-mode 'gerbil-expansion-and-scheme-generation)
          (gsc-executed #f)
          (elapsed-ms elapsed-ms-value)
          (max-elapsed-ms max-elapsed-ms-value)
          (timing-source ":std/time/precise#current-time-precise")
          (pass pass-value))))))

;; : (-> PooBenchmarkSuiteReceipt)
(def (run-composition-macro-expansion-benchmark)
  (let* ((case-1000
          (run-composition-macro-expansion-case
           1000
           +composition-expansion-1000-source+
           +composition-expansion-1000-output-directory+
           +composition-expansion-max-elapsed-ms+))
         (case-5000-first
          (run-composition-macro-expansion-case
           5000
           +composition-expansion-5000-source+
           +composition-expansion-5000-first-output-directory+
           +composition-expansion-max-elapsed-ms+))
         (case-5000-second
          (run-composition-macro-expansion-case
           5000
           +composition-expansion-5000-source+
           +composition-expansion-5000-second-output-directory+
           +composition-expansion-max-elapsed-ms+)))
    (let ((case-1000-value case-1000)
          (case-5000-first-value case-5000-first)
          (case-5000-second-value case-5000-second)
          (pass-value
           (and (.ref case-1000 'pass)
                (.ref case-5000-first 'pass)
                (.ref case-5000-second 'pass))))
      (.o (kind 'agentic-ai-lab.scenario.macro-expansion.benchmark-suite)
          (case-1000 case-1000-value)
          (case-5000-first case-5000-first-value)
          (case-5000-second case-5000-second-value)
          (pass pass-value)))))

;; : (-> PooBenchmarkReceipt Alist)
(def (composition-macro-expansion-case->alist receipt)
  (list
   (cons 'profile-count (.ref receipt 'profile-count))
   (cons 'generated-profile-expression-count
         (.ref receipt 'generated-profile-expression-count))
   (cons 'generated-compose-reference-count
         (.ref receipt 'generated-compose-reference-count))
   (cons 'gsc-executed (.ref receipt 'gsc-executed))
   (cons 'elapsed-ms (.ref receipt 'elapsed-ms))
   (cons 'timing-source (.ref receipt 'timing-source))
   (cons 'pass (.ref receipt 'pass))))

;;; Project the POO receipt only at the subprocess test/report boundary.
;; : (-> PooBenchmarkSuiteReceipt Alist)
(def (composition-macro-expansion-benchmark->alist receipt)
  (list
   (cons 'case-1000
         (composition-macro-expansion-case->alist
          (.ref receipt 'case-1000)))
   (cons 'case-5000-first
         (composition-macro-expansion-case->alist
          (.ref receipt 'case-5000-first)))
   (cons 'case-5000-second
         (composition-macro-expansion-case->alist
          (.ref receipt 'case-5000-second)))
   (cons 'pass (.ref receipt 'pass))))
