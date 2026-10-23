;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/evidence/batched-merkle)


(def (leaf index)
  (agentic-ai-lab-batched-evidence-leaf
   (string-append "leaf-" (number->string index)) index
   (string->symbol (string-append "nonce-" (number->string index)))
   (+ index 1) (+ index 1)
   (string-append "payload-" (number->string index))
   "semantic-root" "execution-root"
   (string-append "observation-" (number->string index)) 'committed))

(def leaves (map leaf '(0 1 2 3 4)))

(def batched-merkle-evidence-test
  (test-suite "AC-08 Batched Merkle evidence"
    (yuanxu-test-case "five-leaf odd tree is deterministic"
      (let ((left (agentic-ai-lab-batched-merkle-root leaves))
            (right (agentic-ai-lab-batched-merkle-root leaves)))
        (check (.ref left 'leaf-count) => 5)
        (check (.ref left 'digest) => (.ref right 'digest))))
    (yuanxu-test-case "every canonical leaf verifies its logarithmic proof"
      (for-each
       (lambda (index)
         (let (proof (agentic-ai-lab-batched-merkle-proof leaves index))
           (check (agentic-ai-lab-batched-merkle-proof-verify?
                   (list-ref leaves index) proof) => #t)))
       '(0 1 2 3 4)))
    (yuanxu-test-case "same leaf produces the same inclusion receipt"
      (let ((left (agentic-ai-lab-batched-merkle-proof leaves 2))
            (right (agentic-ai-lab-batched-merkle-proof leaves 2)))
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
    (yuanxu-test-case "reorder omission and substitution change or reject proof"
      (let* ((canonical (agentic-ai-lab-batched-merkle-root leaves))
             (reordered (agentic-ai-lab-batched-merkle-root
                         (list (list-ref leaves 1) (list-ref leaves 0)
                               (list-ref leaves 2) (list-ref leaves 3)
                               (list-ref leaves 4))))
             (omitted (agentic-ai-lab-batched-merkle-root (cdr leaves)))
             (proof (agentic-ai-lab-batched-merkle-proof leaves 2)))
        (check (equal? (.ref canonical 'digest) (.ref reordered 'digest)) => #f)
        (check (equal? (.ref canonical 'digest) (.ref omitted 'digest)) => #f)
        (check (agentic-ai-lab-batched-merkle-proof-verify? (leaf 99) proof) => #f)))))
