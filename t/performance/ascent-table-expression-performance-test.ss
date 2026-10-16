;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Standard ASP benchmark gate for the POO relation-expression qualification.

(import (only-in :std/test check-equal? test-case test-suite)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        (only-in :poo-flow/modules/workflow/qualification/ascent-table-expression
                 poo-flow-ascent-table-expression-prototype))

(export ascent-table-expression-performance-test)

(def ascent-table-expression-fixture-path
  "t/scenarios/performance/ascent-table-expression/benchmark.ss")

(def ascent-table-expression-fixture
  (call-with-input-file ascent-table-expression-fixture-path read))

(def (source-pair-set radix)
  (.call UIntTrieSet .<-list
         (let loop ((node 0) (pairs []))
           (if (= node radix)
               pairs
               (loop (+ node 1)
                     (cons (+ (* node radix) (modulo (+ node 2) radix))
                           (cons (+ (* node radix) (modulo (+ node 1) radix))
                                 pairs)))))))

(def (relation-expression-projection pairs pair-radix)
  (.ref (.mix poo-flow-ascent-table-expression-prototype
              (.o (source-pairs pairs) (radix pair-radix)))
        'at-most-two-hop-pairs))

(def ascent-table-expression-performance-test
  (test-suite "ASCENT table expression performance"
    (test-case "indexes and composes 512 source pairs through standard benchmark gate"
      (let* ((radix 256)
             (pairs (source-pair-set radix))
             (projected (relation-expression-projection pairs radix))
             (receipt
              (benchmark-run
               ascent-table-expression-fixture
               (lambda () (relation-expression-projection pairs radix)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          ascent-table-expression-fixture)
         #t)
        (check-equal? (.call UIntTrieSet .count pairs) 512)
        (check-equal? (length projected) 1024)
        (display "[poo-flow-benchmark] ascent-table-expression p95=")
        (display (cdr (assoc 'elapsed receipt)))
        (newline)
        (display "[poo-flow-benchmark] ascent-table-expression ")
        (write receipt)
        (newline)
        (force-output)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
