;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant-kind
                 agentic-ai-lab-temporal-interval-kind
                 agentic-ai-lab-temporal-axes-kind
                 AgenticAILabTemporalInstant AgenticAILabTemporalInterval
                 AgenticAILabTemporalAxes))

(export agentic-ai-lab-temporal-instant agentic-ai-lab-temporal-interval
        agentic-ai-lab-temporal-axes)

(def (agentic-ai-lab-temporal-instant identity-value domain-value coordinate-value
                                provenance-value modality-value)
  (validate AgenticAILabTemporalInstant
    (.o kind: agentic-ai-lab-temporal-instant-kind
        identity: identity-value domain-identity: domain-value
        coordinate: coordinate-value
        provenance-identity: provenance-value modality: modality-value)))

(def (agentic-ai-lab-temporal-interval identity-value start-value end-value
                                 start-closed-value end-closed-value)
  (validate AgenticAILabTemporalInterval
    (.o kind: agentic-ai-lab-temporal-interval-kind
        identity: identity-value start: start-value end: end-value
        start-closed?: start-closed-value end-closed?: end-closed-value)))

(def (agentic-ai-lab-temporal-axes identity-value event-value ingress-value
                              processing-value)
  (validate AgenticAILabTemporalAxes
    (.o kind: agentic-ai-lab-temporal-axes-kind identity: identity-value
        event-instant: event-value ingress-instant: ingress-value
        processing-instant: processing-value)))
