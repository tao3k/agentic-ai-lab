;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; The preceding persistent-trie implementation (POO PR #34, 4ee113d3).
;;; Benchmark evidence only; this is not a second runtime path.

(import (only-in :clan/poo/object .ref .call)
        (only-in :clan/poo/number UInt)
        (only-in :clan/poo/trie SimpleTrie UIntTrieSet))

(export ascent-table-expression-baseline)

(def AdjacencyTable (SimpleTrie UInt UIntTrieSet))

(def (baseline-index pairs radix)
  (.call UIntTrieSet .foldl
         (lambda (pair index)
           (let* ((source (quotient pair radix))
                  (target (modulo pair radix))
                  (neighbors (.call AdjacencyTable .ref index source
                                    (lambda () (.ref UIntTrieSet '.empty)))))
             (.call AdjacencyTable .acons source
                    (.call UIntTrieSet .cons target neighbors)
                    index)))
         (.ref AdjacencyTable '.empty) pairs))

(def (baseline-compose pairs index radix)
  (.call UIntTrieSet .foldl
         (lambda (pair joined)
           (let* ((source (quotient pair radix))
                  (middle (modulo pair radix))
                  (destinations
                   (.call AdjacencyTable .ref index middle
                          (lambda () (.ref UIntTrieSet '.empty)))))
             (.call UIntTrieSet .foldl
                    (lambda (target output)
                      (.call UIntTrieSet .cons
                             (+ (* source radix) target) output))
                    joined destinations)))
         (.ref UIntTrieSet '.empty) pairs))

(def (ascent-table-expression-baseline pairs radix)
  (let* ((index (baseline-index pairs radix))
         (two-hop (baseline-compose pairs index radix)))
    (.call UIntTrieSet .list<-
           (.call UIntTrieSet .union pairs two-hop))))
