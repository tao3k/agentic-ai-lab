;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? test-case test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-closure-candidates
                 agentic-ai-lab-ascent-closure-candidates))

(export ascent-shortest-candidates-performance-test)

(def fixture
  (call-with-input-file
   "t/scenarios/performance/ascent-shortest-candidates/benchmark.ss" read))

(def radix 32)
(def facts
  (map (lambda (from) (cons (+ (* from radix) (+ from 1)) from))
       (iota 19)))

(def (candidate-evaluation)
  (agentic-ai-lab-ascent-closure-candidates facts radix 19 400 400))

(def ascent-shortest-candidates-performance-test
  (test-suite "ASCENT Scheme shortest candidates performance"
    (test-case "twenty-node chain stays within the standard fixture"
      (check-equal? (benchmark-fixture-contract-pass? fixture) #t)
      (let-values (((receipt actual)
                    (benchmark-run/result fixture candidate-evaluation)))
        (let (items (.ref actual 'candidates))
          (check-equal? (.ref actual 'status) 'complete)
          (check-equal? (length items) 190)
          (check-equal? (.ref (list-ref items 18) 'pair) 19)
          (check-equal? (.ref (list-ref items 18) 'distance) 19)
          (check-equal? (.ref (list-ref items 18) 'support) (iota 19)))
        (check-equal? (benchmark-receipt-pass? receipt) #t)
        (display "[agentic-ai-lab-benchmark] ascent-shortest-candidates p95=")
        (displayln (benchmark-fixture-ref receipt 'elapsed))))))
