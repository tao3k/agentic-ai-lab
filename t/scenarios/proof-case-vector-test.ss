;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/proof/projections/generated/proof-case-vector-v1
        :poo-flow/modules/proof/projections/proof-case-vector)

(export proof-case-vector-test
        canonical-proof-case)

(def (hex-byte byte)
  (let (digits "0123456789abcdef")
    (string (string-ref digits (arithmetic-shift byte -4))
            (string-ref digits (bitwise-and byte #x0f)))))

(def (digest-byte byte)
  (let (pair (hex-byte byte))
    (apply string-append (make-list 32 pair))))

(def (make-proof-case token-digest-value)
  (.o (kind 'poo-flow-authorized-effect-proof-case)
      (token-digest token-digest-value)
      (policy-revision (digest-byte #x22))
      (effect-digest (digest-byte #x33))
      (semantic-root (digest-byte #x44))
      (execution-root (digest-byte #x55))
      (batch-root #f)
      (subject-binding (digest-byte #x66))
      (resource-binding (digest-byte #x77))
      (action-binding (digest-byte #x88))
      (previous-evidence-root (digest-byte #x99))
      (nonce 11)
      (epoch 4)
      (sequence 19)
      (required-obligation-mask 255)
      (present-obligation-mask 255)
      (obligation-count 8)
      (outcome 'committed)
      (durability 'strict)))

(def canonical-proof-case
  (make-proof-case (digest-byte #x11)))

(def proof-case-vector-test
  (test-suite "AC-09 Scheme native proof vector"
    (poo-flow-test-case "caller-owned write follows the canonical layout"
      (let ((vector (make-u8vector poo-flow-proof-case-vector-size #xff))
            (repeated (make-u8vector poo-flow-proof-case-vector-size #x5a)))
        (check (poo-flow-proof-case-vector-write! canonical-proof-case vector)
               => vector)
        (poo-flow-proof-case-vector-write! canonical-proof-case repeated)
        (check vector => repeated)
        (check (poo-flow-proof-case-vector-digest vector)
               => (poo-flow-proof-case-vector-digest repeated))
        (check (u8vector-length vector) => 424)
        (check (u8vector-ref vector poo-flow-proof-field-abi-version-offset) => 1)
        (check (u8vector-ref vector poo-flow-proof-field-case-kind-offset) => 1)
        (check (u8vector-ref vector poo-flow-proof-field-token-digest-offset)
               => #x11)
        (check (u8vector-ref vector poo-flow-proof-field-subject-binding-offset)
               => #x66)
        (check (u8vector-ref vector poo-flow-proof-field-resource-binding-offset)
               => #x77)
        (check (u8vector-ref vector poo-flow-proof-field-action-binding-offset)
               => #x88)
        (check (u8vector-ref vector poo-flow-proof-field-reserved-offset) => 0)
        (check (poo-flow-proof-case-vector-digest vector)
               => "970eaffbfaae38970e2107b89fa11258c6211a5c293a1e400a464527b7a0e44a")))
    (poo-flow-test-case "wrong target size and malformed digests fail closed"
      (let* ((short-target (make-u8vector 423 0))
             (wrong-size
              (with-catch
               (lambda (failure) 'rejected)
               (lambda ()
                 (poo-flow-proof-case-vector-write!
                  canonical-proof-case short-target)
                 'accepted)))
             (malformed (make-proof-case (make-string 62 #\1)))
             (wrong-digest
              (with-catch
               (lambda (failure) 'rejected)
               (lambda ()
                 (poo-flow-proof-case-vector-write!
                  malformed (make-u8vector 424 0))
                 'accepted))))
        (check wrong-size => 'rejected)
        (check wrong-digest => 'rejected)))))
