;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A source-scoped coverage assertion. Its receipt must be authenticated by
;;; the source owner before any runtime may use it to close a cut.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
                 agentic-ai-lab-temporal-bounded-observation?))

(export agentic-ai-lab-temporal-watermark-kind AgenticAILabTemporalWatermark
        agentic-ai-lab-temporal-watermark?)

(def agentic-ai-lab-temporal-watermark-kind
  'agentic-ai-lab.temporal-causality.watermark)

(def (text? value)
  (and (string? value) (> (string-length value) 0)))

(def (watermark-shape? value)
  (and (object? value)
       (every (lambda (name) (.slot? value name))
              '(kind identity semantic-digest source-identity
                     partition-identity first-sequence last-sequence
                     time-observation issuer-identity coverage-identity
                     late-policy-identity receipt-identity))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-watermark-kind)
       (every text? (list (.ref value 'identity)
                          (.ref value 'semantic-digest)
                          (.ref value 'source-identity)
                          (.ref value 'partition-identity)
                          (.ref value 'issuer-identity)
                          (.ref value 'coverage-identity)
                          (.ref value 'late-policy-identity)
                          (.ref value 'receipt-identity)))
       (exact-integer? (.ref value 'first-sequence))
       (>= (.ref value 'first-sequence) 0)
       (exact-integer? (.ref value 'last-sequence))
       (>= (.ref value 'last-sequence) (.ref value 'first-sequence))
       (agentic-ai-lab-temporal-bounded-observation? (.ref value 'time-observation))))

(define-type (AgenticAILabTemporalWatermark @ Type.)
  .element?: watermark-shape?)
(def (agentic-ai-lab-temporal-watermark? value)
  (element? AgenticAILabTemporalWatermark value))
