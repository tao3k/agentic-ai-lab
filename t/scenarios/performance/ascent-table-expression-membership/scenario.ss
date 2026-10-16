;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; PR #31-style A/B witness for repeated decisions over one POO snapshot.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :poo-flow/modules/workflow/qualification/ascent-table-expression
                 poo-flow-ascent-table-expression-prototype))

(def fixture
  (call-with-input-file
   "t/scenarios/performance/ascent-table-expression-membership/benchmark.ss"
   read))

(def radix 256)
(def edge-pairs
  (.call UIntTrieSet .<-list
         (let loop ((node 0) (values []))
           (if (= node radix)
             values
             (loop (+ node 1)
                   (cons (+ (* node radix) (modulo (+ node 2) radix))
                         (cons (+ (* node radix) (modulo (+ node 1) radix))
                               values)))))))

(def expression
  (.mix poo-flow-ascent-table-expression-prototype
        (.o (source-pairs edge-pairs) (radix 256))))

(def projected (.ref expression 'at-most-two-hop-pairs))
(def contains-pair? (.ref expression 'at-most-two-hop-contains?))
(def queries
  (append projected (map (lambda (node) (* node (+ radix 1))) (iota radix))))

(def (baseline-values)
  (map (lambda (pair) (if (memq pair projected) #t #f)) queries))

(def (candidate-values)
  (map contains-pair? queries))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASCENT membership benchmark fixture" fixture))
(unless (and (= (length projected) 1024) (= (length queries) 1280))
  (error "invalid ASCENT membership workload"))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result fixture baseline-values)))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result fixture candidate-values)))
    (unless (equal? baseline-value candidate-value)
      (error "indexed membership changed ASCENT pair decisions"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "indexed membership exceeded the benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'p95Ns)
               (benchmark-fixture-ref baseline-receipt 'p95Ns))
      (error "indexed membership did not beat repeated list membership"
             baseline-receipt candidate-receipt))
    (display "[poo-flow-benchmark] ascent-membership baseline-p95=")
    (display (benchmark-fixture-ref baseline-receipt 'elapsed))
    (display " candidate-p95=")
    (display (benchmark-fixture-ref candidate-receipt 'elapsed))
    (displayln " semanticEquivalent=#t")
    (force-output)))
