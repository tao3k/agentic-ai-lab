;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Bounded binary-relation expression. The input is an official persistent
;;; UIntTrieSet snapshot; the indexed join uses local Scheme containers and
;;; publishes a canonical, distinct list of encoded pairs.

(import (only-in :clan/poo/object .o .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :clan/poo/support/base until))

(export poo-flow-ascent-table-expression-prototype
        poo-flow-ascent-relation-closure-bounded)

(def (relation-index pairs radix)
  (unless (and (exact-integer? radix) (> radix 1))
    (error "Ascent table radix must be an integer greater than one" radix))
  (let (index (make-vector radix []))
    (.call UIntTrieSet .foldl
           (lambda (pair _)
             (let ((source (quotient pair radix))
                   (target (modulo pair radix)))
               (when (>= source radix)
                 (error "Ascent table pair exceeds the declared radix" pair))
               (vector-set! index source
                            (cons target (vector-ref index source)))))
           (void) pairs)
    ;; The vector and its mutable lists stay private behind a visitor.
    (lambda (source visit)
      (for-each visit (vector-ref index source)))))

(def (relation-projection left neighbors-of radix include-source?)
  (let* ((dense? (<= radix 512))
         (bits (and dense? (make-u8vector (* radix radix) 0)))
         (sparse (and (not dense?) (make-hash-table)))
         (unique []))
    (def (add-pair! pair)
      (if dense?
        (when (= (u8vector-ref bits pair) 0)
          (u8vector-set! bits pair 1)
          (set! unique (cons pair unique)))
        (unless (hash-get sparse pair)
          (hash-put! sparse pair #t)
          (set! unique (cons pair unique)))))
    (.call UIntTrieSet .foldl
           (lambda (pair _)
             (let ((source (quotient pair radix))
                   (middle (modulo pair radix)))
               (when (>= source radix)
                 (error "Ascent table pair exceeds the declared radix" pair))
               (when include-source? (add-pair! pair))
               (neighbors-of
                middle
                (lambda (target)
                  (add-pair! (+ (* source radix) target))))))
           (void) left)
    (.o (contains?
         (lambda (pair)
           (and (exact-integer? pair) (<= 0 pair) (< pair (* radix radix))
                (if dense? (= (u8vector-ref bits pair) 1)
                    (hash-get sparse pair)))))
        (pairs (list-sort < unique)))))

(def (relation-compose left neighbors-of radix include-source?)
  (.ref (relation-projection left neighbors-of radix include-source?) 'pairs))

;;; Compose one frontier and retain only pairs absent from the accumulated
;;; relation. The caller owns repetition, bounds, and completion.
(def (relation-delta-step frontier accumulated neighbors-of radix)
  (let* ((candidates
          (.call UIntTrieSet .<-list
                 (relation-compose frontier neighbors-of radix #f)))
         ;; V19 Set .diff omits operands in its Table .merge forwarding.
         (delta
          (.call (.ref UIntTrieSet 'Table) .merge
                 (lambda (_ left right) (and (not right) left))
                 candidates accumulated))
         (combined (.call UIntTrieSet .union accumulated delta)))
    (.o (new-pairs delta) (all-pairs combined))))

;;; The finite-domain transitive closure for this binary relation, using the
;;; library's until combinator and set operations. This is a specific rule
;;; evaluation, not a second generic prototype fixed-point implementation.
(def (relation-closure source neighbors-of radix (max-pairs #f))
  (when (and max-pairs
             (not (and (exact-integer? max-pairs) (>= max-pairs 0))))
    (error "invalid ASCENT closure pair budget" max-pairs))
  (let* ((dense? (<= radix 512))
         (bits (and dense? (make-u8vector (* radix radix) 0)))
         (sparse (and (not dense?) (make-hash-table)))
         (frontier [])
         (all [])
         (count 0))
    (def (add-pair! pair)
      (if dense?
        (if (= (u8vector-ref bits pair) 1)
          #f
          (begin
            (when (and max-pairs (>= count max-pairs))
              (error "ASCENT derived pair budget exceeded" max-pairs))
            (u8vector-set! bits pair 1)
            (set! count (+ count 1))
            (set! all (cons pair all))
            #t))
        (if (hash-get sparse pair)
          #f
          (begin
            (when (and max-pairs (>= count max-pairs))
              (error "ASCENT derived pair budget exceeded" max-pairs))
            (hash-put! sparse pair #t)
            (set! count (+ count 1))
            (set! all (cons pair all))
            #t))))
    (.call UIntTrieSet .foldl
           (lambda (pair _)
             (when (add-pair! pair)
               (set! frontier (cons pair frontier))))
           (void) source)
    (until (null? frontier)
      (let (next [])
        (for-each
         (lambda (pair)
           (let ((origin (quotient pair radix))
                 (middle (modulo pair radix)))
             (neighbors-of
              middle
              (lambda (target)
                (let (candidate (+ (* origin radix) target))
                  (when (add-pair! candidate)
                    (set! next (cons candidate next))))))))
         frontier)
        (set! frontier next)))
    (.o (pairs (list-sort < all))
        (contains?
         (lambda (pair)
           (and (exact-integer? pair) (<= 0 pair) (< pair (* radix radix))
                (if dense? (= (u8vector-ref bits pair) 1)
                    (hash-get sparse pair))))))))

(def (poo-flow-ascent-relation-closure-bounded source radix max-pairs)
  (relation-closure source (relation-index source radix) radix max-pairs))

;;; The selected unit-weight Ascent path lattice: Dual<usize> joins competing
;;; paths by minimum distance. The frontier contains only newly discovered or
;;; improved pairs, and private storage is published through read-only slots.
(def (relation-shortest-distance-projection source neighbors-of radix)
  (let* ((dense? (<= radix 512))
         (distances (and dense? (make-vector (* radix radix) #f)))
         (sparse (and (not dense?) (make-hash-table)))
         (frontier [])
         (discovered []))
    (def (lookup-distance pair)
      (if dense? (vector-ref distances pair) (hash-get sparse pair)))
    (def (improve! pair depth)
      (let (previous (lookup-distance pair))
        (if (and previous (<= previous depth))
          #f
          (begin
            (unless previous (set! discovered (cons pair discovered)))
            (if dense? (vector-set! distances pair depth)
                (hash-put! sparse pair depth))
            #t))))
    (.call UIntTrieSet .foldl
           (lambda (pair _)
             (when (improve! pair 1)
               (set! frontier (cons pair frontier))))
           (void) source)
    (until (null? frontier)
      (let (next [])
        (for-each
         (lambda (pair)
           (let ((from (quotient pair radix))
                 (via (modulo pair radix))
                 (depth (lookup-distance pair)))
             (neighbors-of
              via
              (lambda (to)
                (let (candidate (+ (* from radix) to))
                  (when (improve! candidate (+ depth 1))
                    (set! next (cons candidate next))))))))
         frontier)
        (set! frontier next)))
    (.o (pairs (list-sort < discovered))
        (distance-of
         (lambda (pair)
           (and (exact-integer? pair) (<= 0 pair) (< pair (* radix radix))
                (lookup-distance pair)))))))

(def poo-flow-ascent-table-expression-prototype
  (.o (:: self [] source-pairs radix)
      (right-index (relation-index source-pairs radix))
      (compose-left
       (lambda (left-pairs)
         (relation-compose left-pairs (.ref self 'right-index) radix #f)))
      (delta-step
       (lambda (frontier accumulated)
         (relation-delta-step frontier accumulated
                              (.ref self 'right-index) radix)))
      (closure-projection
       (relation-closure source-pairs (.ref self 'right-index) radix))
      (closure-bounded
       (lambda (max-pairs)
         (relation-closure source-pairs
                           (.ref self 'right-index) radix max-pairs)))
      (closure-pairs
       (.ref (.ref self 'closure-projection) 'pairs))
      (closure-contains?
       (.ref (.ref self 'closure-projection) 'contains?))
      (closure-set
       (.call UIntTrieSet .<-list (.ref self 'closure-pairs)))
      (shortest-distance-projection
       (relation-shortest-distance-projection
        source-pairs (.ref self 'right-index) radix))
      (shortest-distance-pairs
       (.ref (.ref self 'shortest-distance-projection) 'pairs))
      (shortest-distance-of
       (.ref (.ref self 'shortest-distance-projection) 'distance-of))
      (two-hop-pairs
       ((.ref self 'compose-left) source-pairs))
      (at-most-two-hop-projection
       (relation-projection source-pairs (.ref self 'right-index) radix #t))
      (at-most-two-hop-contains?
       (.ref (.ref self 'at-most-two-hop-projection) 'contains?))
      (at-most-two-hop-pairs
       (.ref (.ref self 'at-most-two-hop-projection) 'pairs))))
