;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO proof values project into the canonical native vector.
;;; Invariant: the hot path writes once into caller-owned storage; no JSON.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list iota)
        (only-in :std/encoding/hex hex-decode hex-encode)
        :agentic-ai-lab/modules/proof/projections/generated/proof-case-vector-v1)

(export agentic-ai-lab-proof-case-vector-write!
        agentic-ai-lab-proof-case-vector-digest)

(def (write-u32-le! target offset value)
  (unless (and (exact-integer? value) (<= 0 value #xffffffff))
    (error "proof vector u32 out of range" value))
  (for-each
   (lambda (index)
     (u8vector-set!
      target
      (+ offset index)
      (bitwise-and (arithmetic-shift value (- (* index 8))) #xff)))
   (iota 4)))

(def (write-u64-le! target offset value)
  (unless (and (exact-integer? value) (<= 0 value #xffffffffffffffff))
    (error "proof vector u64 out of range" value))
  (for-each
   (lambda (index)
     (u8vector-set!
      target
      (+ offset index)
      (bitwise-and (arithmetic-shift value (- (* index 8))) #xff)))
   (iota 8)))

(def (copy-u8vector! source target offset)
  (for-each
   (lambda (index)
     (u8vector-set! target (+ offset index) (u8vector-ref source index)))
   (iota (u8vector-length source))))

(def (digest32-bytes value field-name optional?: (optional? #f))
  (let (normalized
        (cond
         ((and optional? (not value)) (make-string 64 #\0))
         ((string? value) value)
         (else (.ref value 'digest))))
    (unless (= (string-length normalized) 64)
      (error "proof vector digest must contain 64 hex characters"
             field-name normalized))
    (let (bytes
          (with-catch
           (lambda (failure)
             (error "proof vector digest is not valid hex"
                    field-name normalized failure))
           (lambda () (hex-decode normalized))))
      (unless (= (u8vector-length bytes) 32)
        (error "proof vector digest must decode to 32 bytes" field-name))
      bytes)))

(def (write-digest! proof-case slot target offset
                    optional?: (optional? #f))
  (copy-u8vector!
   (digest32-bytes (.ref proof-case slot) slot optional?: optional?)
   target offset))

(def (mediation-tag outcome)
  (case outcome
    ((committed allow) agentic-ai-lab-proof-mediation-allow)
    ((denied deny) agentic-ai-lab-proof-mediation-deny)
    ((invalid-token) agentic-ai-lab-proof-mediation-invalid-token)
    (else (error "unsupported proof mediation outcome" outcome))))

(def (durability-tag durability)
  (case durability
    ((strict) agentic-ai-lab-proof-durability-strict)
    ((batched) agentic-ai-lab-proof-durability-batched)
    ((diagnostic) agentic-ai-lab-proof-durability-diagnostic)
    (else (error "unsupported proof durability" durability))))

(def (agentic-ai-lab-proof-case-vector-write! proof-case target)
  (unless (eq? (.ref proof-case 'kind) 'agentic-ai-lab-authorized-effect-proof-case)
    (error "proof vector requires AuthorizedEffectProofCase" proof-case))
  (unless (= (u8vector-length target) agentic-ai-lab-proof-case-vector-size)
    (error "proof vector target has wrong size"
           (u8vector-length target) agentic-ai-lab-proof-case-vector-size))
  (u8vector-fill! target 0)
  (write-u32-le! target agentic-ai-lab-proof-field-abi-version-offset
                 agentic-ai-lab-proof-case-abi-version)
  (write-u32-le! target agentic-ai-lab-proof-field-case-kind-offset
                 agentic-ai-lab-proof-case-kind-authorized-effect-token)
  (copy-u8vector! (hex-decode agentic-ai-lab-proof-case-schema-fingerprint)
                  target agentic-ai-lab-proof-field-schema-fingerprint-offset)
  (write-digest! proof-case 'token-digest target
                 agentic-ai-lab-proof-field-token-digest-offset)
  (write-digest! proof-case 'policy-revision target
                 agentic-ai-lab-proof-field-policy-revision-offset)
  (write-digest! proof-case 'effect-digest target
                 agentic-ai-lab-proof-field-effect-digest-offset)
  (write-digest! proof-case 'semantic-root target
                 agentic-ai-lab-proof-field-semantic-root-offset)
  (write-digest! proof-case 'execution-root target
                 agentic-ai-lab-proof-field-execution-root-offset)
  (write-digest! proof-case 'batch-root target
                 agentic-ai-lab-proof-field-batch-root-offset optional?: #t)
  (write-digest! proof-case 'subject-binding target
                 agentic-ai-lab-proof-field-subject-binding-offset)
  (write-digest! proof-case 'resource-binding target
                 agentic-ai-lab-proof-field-resource-binding-offset)
  (write-digest! proof-case 'action-binding target
                 agentic-ai-lab-proof-field-action-binding-offset)
  (write-digest! proof-case 'previous-evidence-root target
                 agentic-ai-lab-proof-field-previous-evidence-root-offset)
  (write-u64-le! target agentic-ai-lab-proof-field-nonce-offset
                 (.ref proof-case 'nonce))
  (write-u64-le! target agentic-ai-lab-proof-field-epoch-offset
                 (.ref proof-case 'epoch))
  (write-u64-le! target agentic-ai-lab-proof-field-sequence-offset
                 (.ref proof-case 'sequence))
  (write-u64-le! target agentic-ai-lab-proof-field-required-obligation-mask-offset
                 (.ref proof-case 'required-obligation-mask))
  (write-u64-le! target agentic-ai-lab-proof-field-present-obligation-mask-offset
                 (.ref proof-case 'present-obligation-mask))
  (write-u32-le! target agentic-ai-lab-proof-field-obligation-count-offset
                 (.ref proof-case 'obligation-count))
  (write-u32-le! target agentic-ai-lab-proof-field-mediation-outcome-offset
                 (mediation-tag (.ref proof-case 'outcome)))
  (write-u32-le! target agentic-ai-lab-proof-field-durability-profile-offset
                 (durability-tag (.ref proof-case 'durability)))
  target)

(def (agentic-ai-lab-proof-case-vector-digest vector)
  (unless (= (u8vector-length vector) agentic-ai-lab-proof-case-vector-size)
    (error "proof vector digest requires canonical vector size"
           (u8vector-length vector)))
  (let* ((domain (string->utf8 agentic-ai-lab-proof-vector-digest-domain))
         (payload (make-u8vector (+ (u8vector-length domain) 1
                                    (u8vector-length vector)) 0)))
    (copy-u8vector! domain payload 0)
    (copy-u8vector! vector payload (+ (u8vector-length domain) 1))
    (hex-encode (sha256 payload))))
