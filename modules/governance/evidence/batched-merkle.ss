;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Scheme POO canonically owns Batched Merkle evidence semantics.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))

(export poo-flow-batched-evidence-leaf
        poo-flow-batched-merkle-root
        poo-flow-batched-merkle-proof
        poo-flow-batched-merkle-proof-verify?)

;; : (-> Object String)
(def (canonical-field value)
  (cond
   ((string? value) value)
   ((symbol? value) (symbol->string value))
   ((and (integer? value) (>= value 0)) (number->string value))
   (else (error "non-canonical Batched Merkle field" value))))

;; : (-> String [Object] String)
(def (canonical-packet domain fields)
  (foldl
   (lambda (value packet)
     (let (text (canonical-field value))
       (string-append packet
                      (number->string (u8vector-length (string->utf8 text)))
                      ":" text)))
   domain
   fields))

;; : (-> String [Object] String)
(def (merkle-digest domain fields)
  (hex-encode (sha256 (string->utf8 (canonical-packet domain fields)))))

;; : (-> Symbol Integer String Integer Integer String String String String Symbol PooBatchedEvidenceLeaf)
(def (poo-flow-batched-evidence-leaf
      identity leaf-index token-nonce first-seq last-seq payload-hash
      semantic-hash previous-root observation-hash effect-outcome)
  (let* ((canonical
          (list 'poo-flow.batched-evidence-leaf.draft.1 identity leaf-index
                token-nonce first-seq last-seq payload-hash semantic-hash
                previous-root observation-hash effect-outcome))
         (leaf-hash
          (merkle-digest "poo-flow.batched-evidence-leaf.draft.1|"
                         (cdr canonical))))
    (.o (kind 'poo-flow-batched-evidence-leaf)
        (schema 'poo-flow.batched-evidence-leaf.draft.1)
        (leaf-id identity) (index leaf-index) (nonce token-nonce)
        (first-sequence first-seq) (last-sequence last-seq)
        (payload-digest payload-hash) (semantic-root semantic-hash)
        (previous-execution-root previous-root)
        (observation-digest observation-hash) (outcome effect-outcome)
        (digest leaf-hash))))

;; : (-> String String String)
(def (node-digest left right)
  (merkle-digest "poo-flow.batched-merkle-node.draft.1|" (list left right)))

;; : (-> [String] [String])
(def (next-level/reverse digests)
  (cond
   ((null? digests) '())
   ((null? (cdr digests))
    (list (node-digest (car digests) (car digests))))
   (else
    (cons (node-digest (car digests) (cadr digests))
          (next-level/reverse (cddr digests))))))

;; : (-> [String] [String])
(def (next-level digests)
  (next-level/reverse digests))

;; : (-> [String] String)
(def (root-digest digests)
  (cond
   ((null? digests) (error "Batched Merkle tree requires at least one leaf"))
   ((null? (cdr digests)) (car digests))
   (else (root-digest (next-level digests)))))

;; : (-> [PooBatchedEvidenceLeaf] PooBatchedMerkleRoot)
(def (poo-flow-batched-merkle-root leaves)
  (let* ((digests (map (lambda (leaf) (.ref leaf 'digest)) leaves))
         (root-hash (root-digest digests)))
    (.o (kind 'poo-flow-batched-merkle-root)
        (schema 'poo-flow.batched-merkle-root.draft.1)
        (leaf-count (length leaves))
        (digest root-hash))))

;; : (-> Symbol String PooBatchedMerkleProofStep)
(def (proof-step step-direction sibling)
  (.o (kind 'poo-flow-batched-merkle-proof-step)
      (direction step-direction) (sibling-digest sibling)))

;; : (-> [String] Integer PooBatchedMerkleProofStep)
(def (level-proof digests index)
  (let* ((count (length digests))
         (right? (even? index))
         (sibling-index
          (if right?
            (if (< (+ index 1) count) (+ index 1) index)
            (- index 1))))
    (proof-step (if right? 'right 'left)
                (list-ref digests sibling-index))))

;; poo-flow-batched-merkle-proof
;;   : (-> [PooBatchedEvidenceLeaf] Integer PooBatchedMerkleProof)
;;   | doc m%
;;       `poo-flow-batched-merkle-proof` derives the sibling path and root for one leaf.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-batched-merkle-proof leaves 0)
;;       ;; => proof for the first leaf
;;       ```
;;     %
(def (poo-flow-batched-merkle-proof leaves target-index)
  (let (leaf-count (length leaves))
    (unless (and (integer? target-index)
                 (>= target-index 0)
                 (< target-index leaf-count))
      (error "Batched Merkle proof index out of bounds" target-index))
    (let-values (((proof-steps proof-root)
                  (let loop ((digests
                              (map (lambda (leaf) (.ref leaf 'digest)) leaves))
                             (index target-index)
                             (proof-steps '()))
                    (if (null? (cdr digests))
                      (values (reverse proof-steps) (car digests))
                      (loop (next-level digests) (quotient index 2)
                            (cons (level-proof digests index) proof-steps))))))
      (let (leaf-count-value leaf-count)
        (.o (kind 'poo-flow-batched-merkle-proof)
          (schema 'poo-flow.batched-merkle-proof.draft.1)
          (leaf-index target-index) (leaf-count leaf-count-value)
          (steps proof-steps) (root-digest proof-root))))))

;; : (-> PooBatchedEvidenceLeaf PooBatchedMerkleProof Boolean)
(def (poo-flow-batched-merkle-proof-verify? leaf proof)
  (let ((computed
         (foldl
          (lambda (step current)
            (let (sibling (.ref step 'sibling-digest))
              (case (.ref step 'direction)
                ((left) (node-digest sibling current))
                ((right) (node-digest current sibling))
                (else #f))))
          (.ref leaf 'digest)
          (.ref proof 'steps))))
    (and computed (equal? computed (.ref proof 'root-digest)))))
