;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? check-exception test-case test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :poo-flow/modules/workflow/qualification/ascent-closure-candidates
                 poo-flow-ascent-closure-candidates))

(export ascent-closure-candidates-test)

(def (evaluate facts (max-input 16) (max-pairs 64) (max-results 64))
  (poo-flow-ascent-closure-candidates facts 8
                                      max-input max-pairs max-results))

(def (candidate receipt pair)
  (let loop ((items (.ref receipt 'candidates)))
    (cond ((null? items) #f)
          ((= (.ref (car items) 'pair) pair) (car items))
          (else (loop (cdr items))))))

(def diamond
  ;; Same four facts and labels as mrr-ascent's Ada/Bob/Dan/Cy fixture.
  (list (cons 10 100) (cons 19 101)
        (cons 12 99) (cons 35 103)))

(def ascent-closure-candidates-test
  (test-suite "ASCENT Scheme closure candidates"
    (test-case "shortest support and canonical tie selection"
      (let ((receipt (evaluate diamond)))
        (check-equal? (.ref receipt 'status) 'complete)
        (check-equal? (length (.ref receipt 'candidates)) 5)
        (check-equal? (.ref (candidate receipt 11) 'distance) 2)
        (check-equal? (.ref (candidate receipt 11) 'support) '(99 103))
        (check-equal? (.ref (candidate receipt 11) 'rule) 'transitive)
        (check-equal? (.ref (candidate receipt 10) 'support) '(100))
        (check-equal? (.ref (candidate receipt 10) 'rule) 'base)))
    (test-case "withdrawal selects surviving support and then removes result"
      (let* ((once (evaluate (list (cons 10 100) (cons 19 101)
                                   (cons 12 99))))
             (twice (evaluate (list (cons 10 100) (cons 12 99)))))
        (check-equal? (.ref (candidate once 11) 'support) '(100 101))
        (check-equal? (candidate twice 11) #f))
      (let ((once (evaluate (list (cons 10 100) (cons 19 101)
                                  (cons 12 99)))))
        (check-equal? (length (.ref once 'candidates)) 4)))
    (test-case "cycle has finite shortest reflexive support"
      (let* ((facts (append diamond (list (cons 25 104))))
             (receipt (evaluate facts)))
        ;; Cy -> Ada, then the lexically first equal-length route back.
        (check-equal? (.ref (candidate receipt 9) 'support) '(99 103 104))
        (check-equal? (.ref (candidate receipt 9) 'distance) 3)))
    (test-case "bounded result truncates after complete closure"
      (let ((receipt (evaluate diamond 16 64 2)))
        (check-equal? (.ref receipt 'status) 'output-truncated)
        (check-equal? (map (lambda (item) (.ref item 'pair))
                           (.ref receipt 'candidates))
                      '(10 11))))
    (test-case "input and theoretical pair budgets reject early"
      (check-exception (evaluate diamond 3 64 64) true)
      (check-exception (evaluate diamond 16 4 64) true))))
