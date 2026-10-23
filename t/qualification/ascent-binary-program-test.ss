;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? check-exception test-case test-suite)
        (only-in :clan/poo/object .o .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-binary-program
                 agentic-ai-lab-ascent-binary-relation
                 agentic-ai-lab-ascent-binary-copy-rule
                 agentic-ai-lab-ascent-binary-join-rule
                 agentic-ai-lab-ascent-evaluate-binary-program))

(export ascent-binary-program-test)

(def (relation name encoded)
  (agentic-ai-lab-ascent-binary-relation name (.call UIntTrieSet .<-list encoded)))

(def (evaluate declarations clauses (limit 64) (input-limit 64)
               (output-limit 128))
  (agentic-ai-lab-ascent-evaluate-binary-program
   (.o (radix 8) (relations declarations) (rules clauses)
       (max-input-facts input-limit) (max-derived-pairs limit)
       (max-output-pairs output-limit))))

(def (pairs result name)
  ((.ref result 'pair-list-of) name))

(def ascent-binary-program-test
  (test-suite "ASCENT positive binary rules in Scheme"
    (test-case "recursive copy and join match the existing cyclic closure"
      (let* ((declarations (list (relation 'edge '(10 19 28 34 11))
                                 (relation 'reach '())))
             (rules (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge)
                          (agentic-ai-lab-ascent-binary-join-rule
                           'reach 'reach 'edge)))
             (result (evaluate declarations rules)))
        (check-equal? (pairs result 'reach)
                      '(10 11 12 18 19 20 26 27 28 34 35 36))
        (check-equal?
         (.call UIntTrieSet .list<- ((.ref result 'pairs-of) 'reach))
         (pairs result 'reach))
        (check-equal? (.ref result 'evaluation-path) 'transitive-closure)
        (check-equal? (pairs result 'edge) '(10 11 19 28 34))
        (check-equal? (pairs (evaluate declarations (reverse rules)) 'reach)
                      (pairs result 'reach))
        (check-equal? (pairs (evaluate
                             (list (relation 'edge '(10 19 28 11))
                                   (relation 'reach '())) rules)
                            'reach)
                      '(10 11 12 19 20 28))
        (check-equal? (pairs result 'reach)
                      '(10 11 12 18 19 20 26 27 28 34 35 36))))
    (test-case "diamond and support withdrawal match the Rust pair fixtures"
      (let* ((rules (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge)
                          (agentic-ai-lab-ascent-binary-join-rule
                           'reach 'reach 'edge)))
             (first (evaluate
                     (list (relation 'edge '(10 19 12 35))
                           (relation 'reach '())) rules))
             (withdrawn (evaluate
                         (list (relation 'edge '(10 12 35))
                               (relation 'reach '())) rules))
             (fully-withdrawn (evaluate
                               (list (relation 'edge '(10 12))
                                     (relation 'reach '())) rules)))
        (check-equal? (pairs first 'reach) '(10 11 12 19 35))
        (check-equal? (pairs withdrawn 'reach) '(10 11 12 35))
        (check-equal? (pairs fully-withdrawn 'reach) '(10 12))
        (check-equal? (pairs first 'reach) '(10 11 12 19 35))))
    (test-case "seeded recursive head preserves source facts and rule order"
      (let* ((declarations (list (relation 'edge '(10 19))
                                 (relation 'reach '(12))))
             (rules (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge)
                          (agentic-ai-lab-ascent-binary-join-rule
                           'reach 'reach 'edge)))
             (result (evaluate declarations rules 3 3 6)))
        (check-equal? (.ref result 'evaluation-path) 'semi-naive)
        (check-equal? (pairs result 'reach) '(10 11 12 19))
        (check-equal? (pairs (evaluate declarations (reverse rules) 3 3 6)
                             'reach)
                      (pairs result 'reach))
        (check-exception (evaluate declarations rules 2 3 6) true)))
    (test-case "two changing join inputs and multiple heads"
      (let* ((result
              (evaluate
               (list (relation 'edge '(10 19 28))
                     (relation 'left '()) (relation 'right '())
                     (relation 'joined '()) (relation 'output '()))
               (list (agentic-ai-lab-ascent-binary-copy-rule 'left 'edge)
                     (agentic-ai-lab-ascent-binary-copy-rule 'right 'edge)
                     (agentic-ai-lab-ascent-binary-join-rule
                      'joined 'left 'right)
                     (agentic-ai-lab-ascent-binary-copy-rule 'output 'joined)))))
        (check-equal? (pairs result 'joined) '(11 20))
        (check-equal? (.ref result 'evaluation-path) 'semi-naive)
        (check-equal? (pairs result 'output) '(11 20))))
    (test-case "sparse radix retains the same binary join semantics"
      (let* ((edges (.call UIntTrieSet .<-list '(515 1029)))
             (result
              (agentic-ai-lab-ascent-evaluate-binary-program
               (.o (radix 513)
                   (relations
                    (list (agentic-ai-lab-ascent-binary-relation 'edge edges)
                          (relation 'reach '())))
                   (rules
                    (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge)
                          (agentic-ai-lab-ascent-binary-join-rule
                           'reach 'reach 'edge)))
                   (max-input-facts 8) (max-derived-pairs 8)
                   (max-output-pairs 8)))))
        (check-equal? (pairs result 'reach) '(515 516 1029))
        (check-equal? (.ref result 'evaluation-path) 'semi-naive)))
    (test-case "invalid declarations and pair budget fail"
      (check-exception
       (evaluate (list (relation 'edge '(10)) (relation 'edge '())) '()) true)
      (check-exception
       (evaluate (list (relation 'edge '(64))) '()) true)
      (check-exception
       (evaluate (list (relation 'edge '(10)))
                 (list (agentic-ai-lab-ascent-binary-copy-rule 'missing 'edge))) true)
      (check-exception
       (evaluate (list (relation 'edge '(10 19 28))
                       (relation 'reach '()))
                 (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge)
                       (agentic-ai-lab-ascent-binary-join-rule
                        'reach 'reach 'edge)) 5) true)
      (check-exception
       (evaluate (list (relation 'edge '(10 19 28))) '() 64 2) true)
      (check-exception
       (evaluate (list (relation 'edge '(10 19 28))) '() 64 64 2)
       true)
      (check-exception
       (evaluate (list (relation 'edge '(10 19 28))
                       (relation 'reach '()))
                 (list (agentic-ai-lab-ascent-binary-copy-rule 'reach 'edge))
                 64 64 5)
       true))))
