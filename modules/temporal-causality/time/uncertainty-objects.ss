;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
                 agentic-ai-lab-temporal-bounded-observation-kind
                 agentic-ai-lab-temporal-duration-assessment-kind
                 AgenticAILabTemporalBoundedObservation
                 AgenticAILabTemporalDurationAssessment))

(export agentic-ai-lab-temporal-bounded-observation-value
        agentic-ai-lab-temporal-duration-assessment-value)

(def (agentic-ai-lab-temporal-bounded-observation-value
      identity-value digest-value role-value source-value earliest-value
      latest-value precision-value acquisition-value receipt-value
      attestation-value attempt-value schema-value)
  (validate AgenticAILabTemporalBoundedObservation
    (.o kind: agentic-ai-lab-temporal-bounded-observation-kind
        identity: identity-value semantic-digest: digest-value
        clock-role: role-value source-identity: source-value
        earliest: earliest-value latest: latest-value
        precision: precision-value acquisition-instant: acquisition-value
        receipt-identity: receipt-value attestation-identity: attestation-value
        attempt-identity: attempt-value schema-identity: schema-value)))

(def (agentic-ai-lab-temporal-duration-assessment-value
      identity-value digest-value status-value start-value end-value
      domain-value minimum-value maximum-value)
  (validate AgenticAILabTemporalDurationAssessment
    (.o kind: agentic-ai-lab-temporal-duration-assessment-kind
        identity: identity-value semantic-digest: digest-value
        status: status-value start-observation-digest: start-value
        end-observation-digest: end-value domain-identity: domain-value
        minimum: minimum-value maximum: maximum-value)))
