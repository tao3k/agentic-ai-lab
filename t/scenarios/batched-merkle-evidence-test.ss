;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/governance/evidence/batched-merkle)


(def (leaf index)
  (poo-flow-batched-evidence-leaf
   (string-append "leaf-" (number->string index)) index
   (string->symbol (string-append "nonce-" (number->string index)))
   (+ index 1) (+ index 1)
   (string-append "payload-" (number->string index))
   "semantic-root" "execution-root"
   (string-append "observation-" (number->string index)) 'committed))

(def leaves (map leaf '(0 1 2 3 4)))

(def batched-merkle-evidence-test
  (test-suite "AC-08 Batched Merkle evidence"
    (poo-flow-test-case "five-leaf odd tree is deterministic"
      (let ((left (poo-flow-batched-merkle-root leaves))
            (right (poo-flow-batched-merkle-root leaves)))
        (check (.ref left 'leaf-count) => 5)
        (check (.ref left 'digest) => (.ref right 'digest))))
    (poo-flow-test-case "every canonical leaf verifies its logarithmic proof"
      (for-each
       (lambda (index)
         (let (proof (poo-flow-batched-merkle-proof leaves index))
           (check (poo-flow-batched-merkle-proof-verify?
                   (list-ref leaves index) proof) => #t)))
       '(0 1 2 3 4)))
    (poo-flow-test-case "same leaf produces the same inclusion receipt"
      (let ((left (poo-flow-batched-merkle-proof leaves 2))
            (right (poo-flow-batched-merkle-proof leaves 2)))
        (check (.ref left 'root-digest) => (.ref right 'root-digest))
        (check (.ref left 'leaf-count) => (.ref right 'leaf-count))
        (check (map (lambda (step)
                      (list (.ref step 'direction)
                            (.ref step 'sibling-digest)))
                    (.ref left 'steps))
               =>
               (map (lambda (step)
                      (list (.ref step 'direction)
                            (.ref step 'sibling-digest)))
                    (.ref right 'steps)))))
    (poo-flow-test-case "reorder omission and substitution change or reject proof"
      (let* ((canonical (poo-flow-batched-merkle-root leaves))
             (reordered (poo-flow-batched-merkle-root
                         (list (list-ref leaves 1) (list-ref leaves 0)
                               (list-ref leaves 2) (list-ref leaves 3)
                               (list-ref leaves 4))))
             (omitted (poo-flow-batched-merkle-root (cdr leaves)))
             (proof (poo-flow-batched-merkle-proof leaves 2)))
        (check (equal? (.ref canonical 'digest) (.ref reordered 'digest)) => #f)
        (check (equal? (.ref canonical 'digest) (.ref omitted 'digest)) => #f)
        (check (poo-flow-batched-merkle-proof-verify? (leaf 99) proof) => #f)))))
