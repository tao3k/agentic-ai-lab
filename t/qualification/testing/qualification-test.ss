;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Receipt controls use explicit synthetic output; real gates run separately.
(import :std/test :clan/poo/object
        (only-in :std/error Error? Error-message Error-irritants)
        (only-in :yuanxu/observability/testing-script TestingScript.)
        (only-in "./package-result.ss" admit-package-batches))
(export qualification-test)
(def files '("specialized-fixture-test.ss"))
(def (output count)
  (string-append
    (string-join (map (lambda (i) (string-append "CASE-OK case-" (number->string i)))
                      (iota count)) "\n")
    "\nMODULE-OK specialized-fixture-test.ss\nHARNESS-OK (\"specialized-fixture-test.ss\")\nOK\n"))
(def (receipt text) (.o status: 0 output: text))
(.def (Suite @ TestingScript.)
  source: (.o spec: files admit-current: void)
  case-count: 4)
(def qualification-test
  (test-suite "Specialized qualification receipts over Core execution"
    (test-case "case-count protocols retain native module and harness checks"
      (for-each
        (lambda (count)
          (def configured (.cc Suite 'case-count count))
          (def result (receipt (output count)))
          (check-equal? (eq? (.call configured .admit-result result) result) #t)
          (check-exception (.call configured .admit-result (receipt (output (+ count 1)))) error?))
        '(4 9 13 24 28 69)))
    (test-case "native completion cannot be replaced by successful-looking text"
      (for-each
        (lambda (text) (check-exception (.call Suite .admit-result (receipt text)) error?))
        (list "OK\n"
              (string-append (output 4) "ERROR MODULE hidden\n")
              (string-append (output 4) "*** ERROR hidden\n")
              (string-append (output 4) "WARNING -- Variable x is undefined\n"))))
    (test-case "named obligations are retained without a fixed case count"
      (def configured (.cc Suite 'case-count #f 'required-lines '("CASE-OK required")))
      (check-exception (.call configured .admit-result (receipt (output 4))) error?)
      (.call configured .admit-result (receipt (string-append "CASE-OK required\n" (output 4)))))
    (test-case "a cached parent validator does not bind the child's inherited receipt policy"
      (.def (Parent @ Suite) case-count: 1)
      (def parent-admit (.get Parent .admit-result))
      (parent-admit (receipt (output 1)))
      (.def (Child @ Parent) case-count: 2)
      (.call Child .admit-result (receipt (output 2)))
      (check-exception (.call Child .admit-result (receipt (output 1))) error?)
      (parent-admit (receipt (output 1)))
      (check-exception (parent-admit (receipt (output 2))) error?))
    (test-case "custom native harnesses require their exact receipt and module identity"
      (def configured (.cc Suite 'case-count #f 'harness "HARNESS-OK custom 7 suites"))
      (.call configured .admit-result
        (receipt "MODULE-OK specialized-fixture-test.ss\nHARNESS-OK custom 7 suites\nOK\n"))
      (for-each
        (lambda (text) (check-exception (.call configured .admit-result (receipt text)) error?))
        '("MODULE-OK another.ss\nHARNESS-OK custom 7 suites\nOK\n"
          "MODULE-OK specialized-fixture-test.ss\nHARNESS-OK custom 6 suites\nOK\n")))
    (test-case "package batching retains discovery, batch completion and every observed module"
      (def text
        (string-append
          "[asp-testing] phase=discovery-complete directory=t fileCount=1\n"
          "[asp-testing] phase=batch-start fileCount=1 firstFile=one-test.ss\n"
          "MODULE-OK one-test.ss\nHARNESS-OK (\"one-test.ss\")\n"
          "[asp-testing] phase=all-batches-complete fileCount=1\nOK\n"))
      (def result (receipt text))
      (check-equal? (eq? (admit-package-batches result) result) #t)
      (for-each
        (lambda (missing)
          (def reduced
            (string-join (filter (lambda (line) (not (string-prefix? missing line)))
                                (string-split text #\newline)) "\n"))
          (check-exception (admit-package-batches (receipt reduced)) error?))
        '("[asp-testing] phase=discovery-complete"
          "[asp-testing] phase=all-batches-complete"
          "MODULE-OK" "HARNESS-OK")))
    (test-case "Ops execution and a failed specialized obligation preserve final source checking"
      (def checks 0)
      (def configured
        (.cc Suite
          'source (.o spec: files admit-current: (lambda () (set! checks (+ checks 1))))
          'command (list "printf" "%s" (output 3))))
      (check-exception (.call configured .run)
        (lambda (failure)
          (and (Error? failure) (equal? (Error-message failure) "qualification case count mismatch"))))
      (check-equal? checks 2))
    (test-case "a real bounded child failure retains exit status and final source checking"
      (def checks 0)
      (def configured
        (.cc Suite
          'source (.o spec: files admit-current: (lambda () (set! checks (+ checks 1))))
          'command '("sleep" "2")
          'profile (.cc (.get Suite profile) 'max-duration-milliseconds 1000)))
      (check-exception (.call configured .run)
        (lambda (failure)
          (and (Error? failure) (equal? (Error-message failure) "Ops script failed")
               (equal? (car (Error-irritants failure)) 124))))
      (check-equal? checks 2))))
