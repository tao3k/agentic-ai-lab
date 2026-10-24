;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; The native dependency boundary for ASCENT; relation closure stays in MRR.

(import (only-in :std/test check-equal? test-case test-suite)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet))

(export ascent-poo-primitives-test)

(def ascent-poo-primitives-test
  (test-suite "ASCENT native POO primitives"
    (test-case "late refinement supplies a demanded relation slot"
      (let* ((rule-prototype
              (.o (:: self [] edges)
                  (candidate-edges edges)))
             (input-prototype
              (.o (edges '((a b) (b c)))))
             (program (.mix rule-prototype input-prototype)))
        (check-equal? (.ref program 'candidate-edges)
                      '((a b) (b c)))))
    (test-case "C4 precedence composes a shared prototype once"
      (let* ((base (.o (origin 'base) (decision 'base)))
             (left (.o (:: self base) (decision 'left)))
             (right (.o (:: self base) (origin 'right)))
             (program (.mix left right)))
        (check-equal? (.ref program 'decision) 'left)
        (check-equal? (.ref program 'origin) 'right)))
    (test-case "standard persistent set builds independent source snapshots"
      ;; Integer labels stand only for fixture edge identities. MRR owns the
      ;; relation tuples, derivations, and admitted closure over each snapshot.
      (let* ((base-edges (.call UIntTrieSet .<-list '(12 23 14 43)))
             (source (.o (edge-ids base-edges)))
             (without-bob
              (.mix (.o (edge-ids (.call UIntTrieSet .remove base-edges 23)))
                    source))
             (with-extra
              (.mix (.o (edge-ids
                         (.call UIntTrieSet .union
                                (.ref without-bob 'edge-ids)
                                (.call UIntTrieSet .<-list '(14 34)))))
                    without-bob)))
        (check-equal? (.call UIntTrieSet .list<- (.ref source 'edge-ids))
                      '(12 14 23 43))
        (check-equal? (.call UIntTrieSet .list<- (.ref without-bob 'edge-ids))
                      '(12 14 43))
        (check-equal? (.call UIntTrieSet .list<- (.ref with-extra 'edge-ids))
                      '(12 14 34 43))
        (check-equal? (.call UIntTrieSet .count (.ref source 'edge-ids)) 4)))))
