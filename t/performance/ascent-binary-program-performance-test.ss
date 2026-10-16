;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? test-case test-suite)
        (only-in :clan/poo/object .o .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :poo-flow/modules/workflow/qualification/ascent-binary-program
                 poo-flow-ascent-binary-relation
                 poo-flow-ascent-binary-copy-rule
                 poo-flow-ascent-binary-join-rule
                 poo-flow-ascent-evaluate-binary-program))

(export ascent-binary-program-performance-test)

(def fixture
  (call-with-input-file
   "t/scenarios/performance/ascent-binary-program/benchmark.ss" read))

(def width 32)
(def edges
  (.call UIntTrieSet .<-list
         (map (lambda (from) (+ (* from width) (+ from 1))) (iota 19))))
(def program
  (.o (radix width)
      (relations
       (list (poo-flow-ascent-binary-relation 'edge edges)
             (poo-flow-ascent-binary-relation 'reach
                                             (.ref UIntTrieSet '.empty))))
      (rules
       (list (poo-flow-ascent-binary-copy-rule 'reach 'edge)
             (poo-flow-ascent-binary-join-rule 'reach 'reach 'edge)))
      (max-input-facts 19) (max-derived-pairs 400)
      (max-output-pairs 400)))

(def (candidate-evaluation)
  (poo-flow-ascent-evaluate-binary-program program))

(def (expected-chain-pairs)
  (let from-loop ((from 0) (acc []))
    (if (= from 19)
      (reverse acc)
      (let to-loop ((to (+ from 1)) (acc acc))
        (if (= to 20)
          (from-loop (+ from 1) acc)
          (to-loop (+ to 1) (cons (+ (* from width) to) acc)))))))

(def ascent-binary-program-performance-test
  (test-suite "ASCENT Scheme binary program performance"
    (test-case "twenty-node chain within standard fixture"
      (check-equal? (benchmark-fixture-contract-pass? fixture) #t)
      (let-values (((receipt actual)
                    (benchmark-run/result fixture candidate-evaluation)))
        (let (reach ((.ref actual 'pair-list-of) 'reach))
          (check-equal? (length reach) 190)
          (check-equal? reach (expected-chain-pairs)))
        (display "[poo-flow-benchmark] ascent-binary-program p95=")
        (displayln (benchmark-fixture-ref receipt 'elapsed))
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
