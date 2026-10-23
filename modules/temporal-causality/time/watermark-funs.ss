;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Structural coverage claims never authenticate a source's inventory or
;;; perform cut publication. A caller must bind the named coverage receipt.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
                 agentic-ai-lab-temporal-bounded-observation?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs
                 agentic-ai-lab-temporal-bounded-observation-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/watermark-types
                 agentic-ai-lab-temporal-watermark?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/watermark-objects
                 agentic-ai-lab-temporal-watermark-value))

(export agentic-ai-lab-temporal-watermark
        agentic-ai-lab-temporal-watermark-replay
        agentic-ai-lab-temporal-watermark-cut-claim)

(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256 (string->utf8
             (call-with-output-string
              (lambda (port) (write datum port))))))))

(def (agentic-ai-lab-temporal-watermark
      identity-value source-value partition-value first-value last-value
      observation-value issuer-value coverage-value policy-value receipt-value)
  (unless (agentic-ai-lab-temporal-bounded-observation? observation-value)
    (error "watermark requires a bounded time observation"))
  (let* ((observation (agentic-ai-lab-temporal-bounded-observation-replay observation-value))
         (semantic
          (digest (list 'agentic-ai-lab.temporal-watermark.v1 identity-value
                        source-value partition-value first-value last-value
                        (.ref observation 'semantic-digest) issuer-value
                        coverage-value policy-value receipt-value))))
    (agentic-ai-lab-temporal-watermark-value
     identity-value semantic source-value partition-value first-value
     last-value observation issuer-value coverage-value policy-value
     receipt-value)))

(def (agentic-ai-lab-temporal-watermark-replay watermark)
  (unless (agentic-ai-lab-temporal-watermark? watermark)
    (error "invalid temporal watermark"))
  (let (canonical
        (agentic-ai-lab-temporal-watermark
         (.ref watermark 'identity) (.ref watermark 'source-identity)
         (.ref watermark 'partition-identity)
         (.ref watermark 'first-sequence) (.ref watermark 'last-sequence)
         (.ref watermark 'time-observation) (.ref watermark 'issuer-identity)
         (.ref watermark 'coverage-identity)
         (.ref watermark 'late-policy-identity)
         (.ref watermark 'receipt-identity)))
    (unless (equal? (.ref canonical 'semantic-digest)
                    (.ref watermark 'semantic-digest))
      (error "temporal watermark digest mismatch"))
    canonical))

;;; 'coverage-claimed is deliberately weaker than a closed cut. An issuer's
;;; coverage identity must be verified separately, and late events may still
;;; require correction or reconciliation under the named policy.
(def (agentic-ai-lab-temporal-watermark-cut-claim
      watermark source partition sequence boundary)
  (unless (and (string? source) (string? partition)
               (exact-integer? sequence) (>= sequence 0)
               (agentic-ai-lab-temporal-instant? boundary)
               (eq? (.ref boundary 'modality) 'observed))
    (error "invalid watermark cut query"))
  (agentic-ai-lab-temporal-watermark-replay watermark)
  (cond
   ((or (not (equal? source (.ref watermark 'source-identity)))
        (not (equal? partition (.ref watermark 'partition-identity)))
        (< sequence (.ref watermark 'first-sequence))
        (> sequence (.ref watermark 'last-sequence))) 'outside-scope)
   (else
    (let* ((observation (.ref watermark 'time-observation))
           (lower (.ref observation 'earliest))
           (upper (.ref observation 'latest))
           (position (.ref boundary 'coordinate)))
      (cond
       ((not (equal? (.ref lower 'domain-identity)
                     (.ref boundary 'domain-identity))) 'incomparable)
       ((>= (.ref lower 'coordinate) position) 'coverage-claimed)
       ((< (.ref upper 'coordinate) position) 'not-covered)
       (else 'unknown))))))
