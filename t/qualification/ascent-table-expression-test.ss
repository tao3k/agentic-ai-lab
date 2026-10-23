;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? check-exception test-case test-suite)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-table-expression
                 agentic-ai-lab-ascent-table-expression-prototype))

(export ascent-table-expression-test)

(def ascent-table-expression-test
  (test-suite "ASCENT table expression over native persistent tries"
    (test-case "indexed composition deduplicates the diamond's two-hop path"
      ;; Radix 8: 1->2=10, 2->3=19, 1->4=12, 4->3=35.
      (let* ((source
              (.o (source-pairs (.call UIntTrieSet .<-list '(10 19 12 35)))
                  (radix 8)))
             (expression (.mix agentic-ai-lab-ascent-table-expression-prototype
                               source)))
        (check-equal? (.ref expression 'two-hop-pairs)
                      '(11))
        (check-equal?
         ((.ref expression 'compose-left)
          (.call UIntTrieSet .singleton 10))
         '(11))
        (check-equal? (.ref expression 'at-most-two-hop-pairs)
                      '(10 11 12 19 35))
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) 11) #t)
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) 13) #f)
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) -1) #f)
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) 64) #f)
        (let* ((withdrawn
                (.mix (.o (source-pairs
                           (.call UIntTrieSet .remove
                                  (.ref source 'source-pairs) 19)))
                      agentic-ai-lab-ascent-table-expression-prototype source)))
          (check-equal? (.ref withdrawn 'two-hop-pairs)
                        '(11))
          (check-equal? ((.ref withdrawn 'at-most-two-hop-contains?) 19) #f)
          (check-equal? ((.ref expression 'at-most-two-hop-contains?) 19) #t)
          (check-equal? (.ref expression 'at-most-two-hop-pairs)
                        '(10 11 12 19 35)))))
    (test-case "a cycle produces only its bounded two-hop self pairs"
      (let* ((source (.o (source-pairs
                          (.call UIntTrieSet .<-list '(10 17)))
                         (radix 8)))
             (expression (.mix agentic-ai-lab-ascent-table-expression-prototype
                               source)))
        (check-equal? (.ref expression 'two-hop-pairs)
                      '(9 18))))
    (test-case "frontier steps deduplicate alternate paths and terminate on a cycle"
      (let* ((edges (.call UIntTrieSet .<-list '(10 19 28 34 11)))
             (expression
              (.mix agentic-ai-lab-ascent-table-expression-prototype
                    (.o (source-pairs edges) (radix 8))))
             (first ((.ref expression 'delta-step) edges edges))
             (second ((.ref expression 'delta-step)
                      (.ref first 'new-pairs) (.ref first 'all-pairs)))
             (third ((.ref expression 'delta-step)
                     (.ref second 'new-pairs) (.ref second 'all-pairs))))
        (check-equal? (.call UIntTrieSet .list<- (.ref first 'new-pairs))
                      '(12 20 26 35))
        (check-equal? (.call UIntTrieSet .list<- (.ref second 'new-pairs))
                      '(18 27 36))
        (check-equal? (.call UIntTrieSet .list<- (.ref third 'new-pairs))
                      '())
        (check-equal? (.call UIntTrieSet .list<- (.ref third 'all-pairs))
                      '(10 11 12 18 19 20 26 27 28 34 35 36))
        (check-equal? (.ref expression 'closure-pairs)
                      '(10 11 12 18 19 20 26 27 28 34 35 36))
        (check-equal? (.ref ((.ref expression 'closure-bounded) 12) 'pairs)
                      (.ref expression 'closure-pairs))
        (check-exception
         ((.ref expression 'closure-bounded) 11) true)
        (let* ((without-cycle-edge
                (.call UIntTrieSet .remove edges 34))
               (withdrawn
                (.mix agentic-ai-lab-ascent-table-expression-prototype
                      (.o (source-pairs without-cycle-edge) (radix 8)))))
          (check-equal? (.ref withdrawn 'closure-pairs)
                        '(10 11 12 19 20 28))
          (check-equal? (.ref expression 'closure-pairs)
                        '(10 11 12 18 19 20 26 27 28 34 35 36)))))
    (test-case "empty source has an empty closure"
      (let (expression
            (.mix agentic-ai-lab-ascent-table-expression-prototype
                  (.o (source-pairs (.ref UIntTrieSet '.empty))
                      (radix 8))))
        (check-equal? (.ref expression 'closure-pairs) '())))
    (test-case "Dual shortest-distance lattice keeps the minimum path"
      (let* ((edges (.call UIntTrieSet .<-list '(10 19 12 35)))
             (expression
              (.mix agentic-ai-lab-ascent-table-expression-prototype
                    (.o (source-pairs edges) (radix 8)))))
        (check-equal? (.ref expression 'shortest-distance-pairs)
                      (.ref expression 'closure-pairs))
        (check-equal? ((.ref expression 'shortest-distance-of) 11) 2)
        (check-equal? ((.ref expression 'shortest-distance-of) 10) 1)
        (check-equal? ((.ref expression 'shortest-distance-of) 13) #f)
        (let (direct
              (.mix agentic-ai-lab-ascent-table-expression-prototype
                    (.o (source-pairs
                         (.call UIntTrieSet .<-list '(10 11 12 19 35)))
                        (radix 8))))
          (check-equal? ((.ref direct 'shortest-distance-of) 11) 1)
          (check-equal? (.ref direct 'shortest-distance-pairs)
                        (.ref expression 'closure-pairs)))))
    (test-case "Dual lattice stabilizes on a cycle and a sparse radix"
      (let ((cycle
             (.mix agentic-ai-lab-ascent-table-expression-prototype
                   (.o (source-pairs
                        (.call UIntTrieSet .<-list '(10 19 28 34 11)))
                       (radix 8))))
            (sparse
             (.mix agentic-ai-lab-ascent-table-expression-prototype
                   (.o (source-pairs
                        (.call UIntTrieSet .<-list '(515 1029)))
                       (radix 513)))))
        (check-equal? (.ref cycle 'shortest-distance-pairs)
                      (.ref cycle 'closure-pairs))
        (check-equal? ((.ref cycle 'shortest-distance-of) 18) 3)
        (check-equal? ((.ref sparse 'shortest-distance-of) 516) 2)
        (check-equal? ((.ref sparse 'shortest-distance-of) 517) #f)))
    (test-case "larger radix retains sparse snapshot and membership behavior"
      (let* ((source (.o (source-pairs
                          (.call UIntTrieSet .<-list '(515 1029)))
                         (radix 513)))
             (expression (.mix agentic-ai-lab-ascent-table-expression-prototype
                               source)))
        (check-equal? (.ref expression 'at-most-two-hop-pairs)
                      '(515 516 1029))
        (check-equal? (.ref expression 'closure-pairs)
                      '(515 516 1029))
        (check-equal? (.call UIntTrieSet .count (.ref expression 'closure-set)) 3)
        (check-equal? ((.ref expression 'closure-contains?) 516) #t)
        (check-equal? ((.ref expression 'closure-contains?) 517) #f)
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) 516) #t)
        (check-equal? ((.ref expression 'at-most-two-hop-contains?) 517) #f)))
    (test-case "rejects a radix that would alias pair identities"
      (let (invalid
            (.mix agentic-ai-lab-ascent-table-expression-prototype
                  (.o (source-pairs (.call UIntTrieSet .<-list '(10)))
                      (radix 2))))
        (check-exception (.ref invalid 'right-index) true)))))
