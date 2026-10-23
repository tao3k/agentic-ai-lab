;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for the removed generic Module wrapper. ASP owns sampling, GC,
;;; p95 admission, memory observations, budgets, and receipt projection.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .all-slots .slot? object<-alist))

(def +slot-count+ 1000)

(def fixture
  (call-with-input-file
   "t/scenarios/performance/module-interface-native-slot-lookup/benchmark.ss"
   read))

(def slot-rows
  (let loop ((index 0) (rows-rev '()))
    (if (= index +slot-count+)
      (reverse rows-rev)
      (loop (+ index 1)
            (cons
             (cons (string->symbol
                    (string-append "slot-" (number->string index)))
                   index)
             rows-rev)))))

(def interface-object (object<-alist slot-rows))
(def slot-queries
  (append (map car slot-rows) (list 'missing-slot)))

(def (baseline-presence)
  (map (lambda (slot-name)
         (and (member slot-name (.all-slots interface-object)) #t))
       slot-queries))

(def (candidate-presence)
  (map (lambda (slot-name) (.slot? interface-object slot-name))
       slot-queries))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result fixture baseline-presence)))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result fixture candidate-presence)))
    (unless (equal? baseline-value candidate-value)
      (error "native POO slot lookup changed presence semantics"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "native POO slot lookup exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "native POO slot lookup did not improve repeated presence checks"
             baseline-receipt candidate-receipt))
    (display "[agentic-ai-lab-benchmark] module-interface-native-slot-lookup baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
