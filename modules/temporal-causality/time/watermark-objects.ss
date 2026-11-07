;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/watermark-types
                 agentic-ai-lab-temporal-watermark-kind AgenticAILabTemporalWatermark))

(export agentic-ai-lab-temporal-watermark-value)

(def (agentic-ai-lab-temporal-watermark-value
      identity-value digest-value source-value partition-value first-value
      last-value observation-value issuer-value coverage-value policy-value
      receipt-value)
  (validate AgenticAILabTemporalWatermark
    (.o kind: agentic-ai-lab-temporal-watermark-kind
        identity: identity-value semantic-digest: digest-value
        source-identity: source-value partition-identity: partition-value
        first-sequence: first-value last-sequence: last-value
        time-observation: observation-value issuer-identity: issuer-value
        coverage-identity: coverage-value late-policy-identity: policy-value
        receipt-identity: receipt-value)))
