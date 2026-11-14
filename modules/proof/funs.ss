;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure Proof indexing, freshness and admission functions.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list every)
        (only-in :std/encoding/hex hex-encode)
        "types.ss")

(export agentic-ai-lab-proof-digest
        agentic-ai-lab-proof-artifact-index
        agentic-ai-lab-proof-receipt-index
        agentic-ai-lab-proof-refinement-current?
        agentic-ai-lab-proof-assurance)

(def (agentic-ai-lab-proof-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write value port))))))))

(def (proof-index values identity-slot label)
  (let (index (make-hash-table))
    (for-each
     (lambda (value)
       (let (identity (.ref value identity-slot))
         (when (hash-get index identity)
           (error "duplicate Proof identity" label identity))
         (hash-put! index identity value)))
     values)
    index))

(def (agentic-ai-lab-proof-artifact-index artifacts)
  (unless (every agentic-ai-lab-proof-artifact? artifacts)
    (error "invalid Proof artifact collection"))
  (proof-index artifacts 'identity 'artifact))

(def (agentic-ai-lab-proof-receipt-index receipts)
  (unless (every agentic-ai-lab-proof-receipt? receipts)
    (error "invalid Proof receipt collection"))
  (proof-index receipts 'identity 'receipt))

(def (agentic-ai-lab-proof-refinement-current? binding artifact-index receipt-index)
  (and (agentic-ai-lab-proof-refinement-binding? binding)
       (let* ((upstream
               (hash-get artifact-index
                         (.ref binding 'upstream-artifact-identity)))
              (downstream
               (hash-get artifact-index
                         (.ref binding 'downstream-artifact-identity)))
              (receipt
               (hash-get receipt-index (.ref binding 'receipt-identity)))
              (impact (.ref binding 'impact-binding)))
         (and upstream downstream receipt
              (equal? (.ref upstream 'content-digest)
                      (.ref binding 'upstream-content-digest))
              (equal? (.ref downstream 'content-digest)
                      (.ref binding 'downstream-content-digest))
              (equal? (.ref receipt 'artifact-identity)
                      (.ref downstream 'identity))
              (equal? (.ref receipt 'artifact-content-digest)
                      (.ref downstream 'content-digest))
              (.ref receipt 'admitted?)
              (.ref binding 'admitted?)
              (equal? (.ref impact 'upstream-content-digest)
                      (.ref upstream 'content-digest))
              (equal? (.ref impact 'downstream-content-digest)
                      (.ref downstream 'content-digest))
              (eq? (.ref impact 'stale-downstream-policy) 'reject)))))

(def (agentic-ai-lab-proof-assurance identity-value artifact-values receipt-values
                               refinement-values)
  (unless (and (agentic-ai-lab-proof-text? identity-value)
               (pair? artifact-values) (pair? receipt-values)
               (pair? refinement-values)
               (every agentic-ai-lab-proof-artifact? artifact-values)
               (every agentic-ai-lab-proof-receipt? receipt-values)
               (every agentic-ai-lab-proof-refinement-binding? refinement-values))
    (error "Proof assurance requires artifacts, receipts and refinements"
           identity-value))
  (let* ((artifact-index-value
          (agentic-ai-lab-proof-artifact-index artifact-values))
         (receipt-index-value
          (agentic-ai-lab-proof-receipt-index receipt-values))
         (current-value
          (every
           (lambda (binding)
             (agentic-ai-lab-proof-refinement-current?
              binding artifact-index-value receipt-index-value))
           refinement-values))
         (digest-value
          (agentic-ai-lab-proof-digest
           (list
            'agentic-ai-lab.proof-assurance.v1 identity-value
            (map (lambda (artifact)
                   (list (.ref artifact 'identity)
                         (.ref artifact 'content-digest)))
                 artifact-values)
            (map (lambda (receipt)
                   (list (.ref receipt 'identity)
                         (.ref receipt 'artifact-content-digest)
                         (.ref receipt 'evidence-digest)
                         (.ref receipt 'admitted?)))
                 receipt-values)
            (map (lambda (binding)
                   (list (.ref binding 'identity)
                         (.ref binding 'upstream-content-digest)
                         (.ref binding 'downstream-content-digest)
                         (.ref binding 'receipt-identity)))
                 refinement-values)))))
    (validate
     AgenticAILabProofAssurance
     (.o kind: +agentic-ai-lab-proof-assurance-kind+
         identity: identity-value
         artifacts: artifact-values
         receipts: receipt-values
         refinements: refinement-values
         artifact-index: artifact-index-value
         receipt-index: receipt-index-value
         current?: current-value
         admitted?: current-value
         assurance-digest: digest-value
         runtime-executed?: #f))))
