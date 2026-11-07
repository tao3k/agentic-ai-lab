;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/types
                 AgenticAILabTemporalImpactContrastPoint
                 AgenticAILabTemporalImpactContrast
                 AgenticAILabTemporalInterventionWindowAudit))
(export agentic-ai-lab-temporal-impact-contrast-point-value
        agentic-ai-lab-temporal-impact-contrast-value
        agentic-ai-lab-temporal-intervention-window-audit-value)

(def (agentic-ai-lab-temporal-impact-contrast-point-value
      coordinate-value left-instant-value right-instant-value
      level-delta-value rate-delta-value)
  (validate AgenticAILabTemporalImpactContrastPoint
    (.o kind: 'agentic-ai-lab.temporal-causality.impact-contrast-point
        coordinate: coordinate-value
        left-instant-identity: left-instant-value
        right-instant-identity: right-instant-value
        level-delta: level-delta-value rate-delta: rate-delta-value)))

(def (agentic-ai-lab-temporal-impact-contrast-value
      identity-value digest-value left-value right-value cut-value
      projection-value subject-value outcome-value unit-value domain-value
      status-value points-value)
  (validate AgenticAILabTemporalImpactContrast
    (.o kind: 'agentic-ai-lab.temporal-causality.impact-contrast
        identity: identity-value semantic-digest: digest-value
        left-series-digest: left-value right-series-digest: right-value
        source-cut-digest: cut-value source-projection-digest: projection-value
        subject-identity: subject-value outcome-identity: outcome-value
        unit-identity: unit-value time-domain-identity: domain-value
        status: status-value points: points-value
        causal-impact-admitted?: #f runtime-executed?: #f)))

(def (agentic-ai-lab-temporal-intervention-window-audit-value
      identity-value digest-value contrast-value intervention-value
      onset-value end-value cut-value projection-value subject-value
      outcome-value unit-value domain-value prefix-status-value
      prefix-count-value points-value cumulative-value mean-value)
  (validate AgenticAILabTemporalInterventionWindowAudit
    (.o kind: 'agentic-ai-lab.temporal-causality.intervention-window-audit
        identity: identity-value semantic-digest: digest-value
        contrast-digest: contrast-value
        intervention-identity: intervention-value
        onset-instant-identity: onset-value end-instant-identity: end-value
        source-cut-digest: cut-value
        source-projection-digest: projection-value
        subject-identity: subject-value outcome-identity: outcome-value
        unit-identity: unit-value time-domain-identity: domain-value
        prefix-status: prefix-status-value
        prefix-observed-count: prefix-count-value
        window-points: points-value cumulative-delta: cumulative-value
        mean-delta: mean-value
        causal-impact-admitted?: #f runtime-executed?: #f)))
