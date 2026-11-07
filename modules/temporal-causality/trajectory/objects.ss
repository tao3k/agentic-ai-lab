;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 AgenticAILabTemporalTrajectorySample
                 AgenticAILabTemporalTrajectorySeries))
(export agentic-ai-lab-temporal-trajectory-sample
        agentic-ai-lab-temporal-trajectory-series-value)

(def (agentic-ai-lab-temporal-trajectory-sample instant-value outcome-value)
  (validate AgenticAILabTemporalTrajectorySample
    (.o kind: 'agentic-ai-lab.temporal-causality.trajectory-sample
        instant: instant-value outcome: outcome-value)))

(def (agentic-ai-lab-temporal-trajectory-series-value
      identity-value digest-value subject-value scenario-value outcome-value
      unit-value cut-value projection-value domain-value modality-value
      samples-value)
  (validate AgenticAILabTemporalTrajectorySeries
    (.o kind: 'agentic-ai-lab.temporal-causality.trajectory-series
        identity: identity-value semantic-digest: digest-value
        subject-identity: subject-value scenario-identity: scenario-value
        outcome-identity: outcome-value unit-identity: unit-value
        source-cut-digest: cut-value source-projection-digest: projection-value
        time-domain-identity: domain-value modality: modality-value
        samples: samples-value)))
