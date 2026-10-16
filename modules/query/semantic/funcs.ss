;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Shared indexing algorithms for semantic models.

(import (only-in :std/list/list delete-duplicates/hash))

(export poo-flow-semantic-index-by poo-flow-semantic-subset?
        poo-flow-semantic-unique-count
        poo-flow-semantic-adjacent-duplicate-identities)

;; Keep the leftmost value so indexing preserves prior duplicate resolution.
(def (poo-flow-semantic-index-by identity-of values)
  (let (index (make-hash-table))
    (for-each
     (lambda (value)
       (let (identity (identity-of value))
         (unless (hash-key? index identity)
           (hash-put! index identity value))))
     values)
    index))

(def (poo-flow-semantic-subset? child parent)
  (let (parent-index (make-hash-table))
    (for-each (lambda (value) (hash-put! parent-index value #t)) parent)
    (andmap (lambda (value) (hash-key? parent-index value)) child)))

(def (poo-flow-semantic-unique-count values)
  (length (delete-duplicates/hash values)))

;; The caller supplies sorted values. Empty and singleton collections are
;; valid; each adjacent duplicate preserves the former diagnostic cardinality.
(def (poo-flow-semantic-adjacent-duplicate-identities identity-of values)
  (let loop ((rest values) (present? #f) (previous #f) (duplicates-rev '()))
    (if (null? rest)
      (reverse duplicates-rev)
      (let (identity (identity-of (car rest)))
        (loop (cdr rest) #t identity
              (if (and present? (equal? previous identity))
                (cons identity duplicates-rev)
                duplicates-rev))))))
