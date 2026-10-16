;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

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
   "t/scenarios/performance/ascent-reachability-closure/benchmark.ss" read))

(def radix 32)
(def edges
  (.call UIntTrieSet .<-list
         (map (lambda (node) (+ (* node radix) (+ node 1))) (iota 19))))

(def expected-pairs
  (let outer ((origin 0) (result []))
    (if (= origin 19)
      (reverse result)
      (outer (+ origin 1)
             (let inner ((target (+ origin 1)) (result result))
               (if (= target 20)
                 result
                 (inner (+ target 1)
                        (cons (+ (* origin radix) target) result))))))))

(def (candidate-closure)
  (.ref (.mix poo-flow-ascent-table-expression-prototype
              (.o (source-pairs edges) (radix 32)))
        'closure-pairs))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASCENT closure benchmark fixture" fixture))
(unless (= (length expected-pairs) 190)
  (error "invalid ASCENT closure expected set"))

(let-values (((receipt actual)
              (benchmark-run/result fixture candidate-closure)))
  (unless (equal? actual expected-pairs)
    (error "ASCENT closure changed the complete chain relation"))
  (unless (benchmark-receipt-pass? receipt)
    (error "ASCENT closure exceeded the benchmark budget" receipt))
  (display "[poo-flow-benchmark] ascent-reachability-closure p95=")
  (display (benchmark-fixture-ref receipt 'elapsed))
  (displayln " pairs=190 semanticEquivalent=#t")
  (force-output))
