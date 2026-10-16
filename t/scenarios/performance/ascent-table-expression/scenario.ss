;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness using the same 512-pair input and ASP benchmark fixture.
;;; Both implementation modules are compiled with gxc -O before this run.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :poo-flow/modules/workflow/qualification/ascent-table-expression
                 poo-flow-ascent-table-expression-prototype)
        (only-in :poo-flow/t/scenarios/performance/ascent-table-expression/baseline
                 ascent-table-expression-baseline))

(def fixture
  (call-with-input-file
   "t/scenarios/performance/ascent-table-expression/benchmark.ss" read))

(def radix 256)
(def pairs
  (.call UIntTrieSet .<-list
         (let loop ((node 0) (values []))
           (if (= node radix)
             values
             (loop (+ node 1)
                   (cons (+ (* node radix) (modulo (+ node 2) radix))
                         (cons (+ (* node radix) (modulo (+ node 1) radix))
                               values)))))))

(def (candidate-projection pairs-value pair-radix)
  (.ref (.mix poo-flow-ascent-table-expression-prototype
              (.o (source-pairs pairs-value) (radix pair-radix)))
        'at-most-two-hop-pairs))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASCENT benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result
               fixture (lambda () (ascent-table-expression-baseline pairs radix)))))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result
                 fixture (lambda () (candidate-projection pairs radix)))))
    (unless (equal? baseline-value candidate-value)
      (error "ASCENT relation projection changed its pair set"
             baseline-value candidate-value))
    (unless (= (length candidate-value) 1024)
      (error "ASCENT relation projection produced the wrong pair count"
             (length candidate-value)))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "ASCENT relation projection exceeded the benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'p95Ns)
               (benchmark-fixture-ref baseline-receipt 'p95Ns))
      (error "ASCENT indexed projection did not improve the persistent baseline"
             baseline-receipt candidate-receipt))
    (display "[poo-flow-benchmark] ascent-table-expression baseline-p95=")
    (display (benchmark-fixture-ref baseline-receipt 'elapsed))
    (display " candidate-p95=")
    (display (benchmark-fixture-ref candidate-receipt 'elapsed))
    (displayln " semanticEquivalent=#t")
    (force-output)))
