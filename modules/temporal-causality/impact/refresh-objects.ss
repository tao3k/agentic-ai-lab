;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/refresh-types
                 AgenticAILabTemporalImpactRefresh))
(export agentic-ai-lab-temporal-impact-refresh-value)

(def (agentic-ai-lab-temporal-impact-refresh-value
      identity-value digest-value previous-value revised-value
      left-delta-value right-delta-value left-series-value right-series-value
      action-value reason-value)
  (validate AgenticAILabTemporalImpactRefresh
    (.o kind: 'agentic-ai-lab.temporal-causality.impact-refresh
        identity: identity-value semantic-digest: digest-value
        previous-contrast: previous-value revised-contrast: revised-value
        left-delta-digest: left-delta-value
        right-delta-digest: right-delta-value
        revised-left-series-digest: left-series-value
        revised-right-series-digest: right-series-value
        action: action-value reason: reason-value
        causal-impact-admitted?: #f runtime-executed?: #f)))
