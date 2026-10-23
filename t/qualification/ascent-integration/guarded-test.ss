;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? test-suite)
        (only-in :yuanxu/observability/testing-case
                 yuanxu-test-case)
        (only-in :clan/poo/object .o .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :gerbil-ascent/core/binary-program
                 gerbil-ascent-binary-relation
                 gerbil-ascent-binary-copy-rule
                 gerbil-ascent-binary-filter-rule
                 gerbil-ascent-binary-join-rule
                 gerbil-ascent-evaluate-binary-program))

(export ascent-integration-test)

(def (relation name pairs)
  (gerbil-ascent-binary-relation name (.call UIntTrieSet .<-list pairs)))

(def (evaluate edges)
  (gerbil-ascent-evaluate-binary-program
   (.o (radix 8)
       (relations (list (relation 'edge edges)
                        (relation 'selected '())
                        (relation 'copied '())
                        (relation 'twohop '())))
       (rules (list (gerbil-ascent-binary-filter-rule
                     'selected 'edge (lambda (from _to) (even? from)))
                    (gerbil-ascent-binary-copy-rule 'copied 'selected)
                    (gerbil-ascent-binary-join-rule
                     'twohop 'selected 'edge)))
       (max-input-facts 8)
       (max-derived-pairs 64)
       (max-output-pairs 64))))

(def ascent-integration-test
  (test-suite "Agentic AI Lab consumes gerbil-ascent"
    (yuanxu-test-case "guarded copy and join preserve source snapshots"
      (let* ((first (evaluate '(10 19 20 37 29)))
             (withdrawn (evaluate '(10 19 20 29)))
             (pairs-of (lambda (result name) ((.ref result 'pair-list-of) name))))
        (check-equal? (pairs-of first 'selected) '(19 20 37))
        (check-equal? (pairs-of first 'copied) '(19 20 37))
        (check-equal? (pairs-of first 'twohop) '(21))
        (check-equal? (pairs-of withdrawn 'selected) '(19 20))
        (check-equal? (pairs-of first 'selected) '(19 20 37))))))
