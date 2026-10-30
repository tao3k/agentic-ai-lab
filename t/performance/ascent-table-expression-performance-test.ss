;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Standard ASP benchmark gate for the POO relation-expression qualification.

(import (only-in :std/test check-equal? test-case test-suite)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :clan/poo/mop element?)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run benchmark-elapsed-us)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-table-expression
                 agentic-ai-lab-ascent-table-expression-prototype))

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
  (.ref (.mix agentic-ai-lab-ascent-table-expression-prototype
              (.o (source-pairs pairs) (radix pair-radix)))
        'at-most-two-hop-pairs))

;; Failure-only diagnosis leaves the original timed workload and gate intact.
;; The raw backing fold isolates traversal cost; it grants no Set admission and
;; is never used by the candidate algorithm or by an acceptance decision.
(def (relation-failure-costs pairs)
  (def table (.ref UIntTrieSet 'Table))
  (list
   (cons 'set-recognition-us
     (benchmark-elapsed-us (lambda () (element? UIntTrieSet pairs))))
   (cons 'native-shape-us
     (benchmark-elapsed-us (lambda () (.call table .validate-shape pairs))))
   (cons 'public-set-fold-us
     (benchmark-elapsed-us
       (lambda () (.call UIntTrieSet .foldl (lambda (_ count) (+ count 1)) 0 pairs))))
   (cons 'backing-fold-without-set-admission-us
     (benchmark-elapsed-us
       (lambda () (.call table .foldl (lambda (_key _value count) (+ count 1)) 0 pairs))))))

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
        (display "[agentic-ai-lab-benchmark] ascent-table-expression p95=")
        (display (cdr (assoc 'elapsed receipt)))
        (newline)
        (display "[agentic-ai-lab-benchmark] ascent-table-expression ")
        (write receipt)
        (newline)
        (force-output)
        ;; Preserve the rejected native receipt before the strict assertion raises.
        (unless (benchmark-receipt-pass? receipt)
          (display "[agentic-ai-lab-benchmark-refused] ")
          (write receipt)
          (newline)
          (display "[agentic-ai-lab-benchmark-costs] ")
          (write (relation-failure-costs pairs))
          (newline)
          (force-output))
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
