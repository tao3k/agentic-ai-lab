;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Read this bounded native receipt check. Return only the
;;; S-expression written by main. A complete receipt concerns one
;;; source generation and candidate; it does not prove user intent.
(import (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-status reasoning-receipt-rows
                 reasoning-verify-finite-receipt
                 reasoning-verify-stratified-receipt))
(export main)

(def candidate
  '(candidate
     (relation path 2)
     (rule (path ?x ?y) (edge ?x ?y))
     (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
     (query path ?x ?y)
     (limits 16 64 128)))

(def (main . _)
  (let* ((first
          (reasoning-source-snapshot 'graph 1 '((edge 2 ((0 1) (1 2))))))
         (changed
          (reasoning-source-snapshot 'graph 2 '((edge 2 ((0 1))))))
         (receipt (reasoning-attempt first candidate 100000 20000)))
    (write (list 'answer
                 (list (reasoning-receipt-status receipt)
                       (reasoning-verify-finite-receipt
                        receipt first candidate 20000)
                       (reasoning-verify-stratified-receipt
                        receipt first candidate 20000))
                 (reasoning-receipt-rows receipt)
                 (list 'changed
                       (reasoning-verify-stratified-receipt
                        receipt changed candidate 20000))))
    (newline)))
