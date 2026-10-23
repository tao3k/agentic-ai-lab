;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/delta-types
                 AgenticAILabTemporalTrajectoryDelta))
(export agentic-ai-lab-temporal-trajectory-delta-value)

(def (agentic-ai-lab-temporal-trajectory-delta-value
      identity-value digest-value previous-value revised-value
      previous-digest-value revised-digest-value previous-cut-value
      revised-cut-value previous-projection-value revised-projection-value
      added-value removed-value changed-value status-value)
  (validate AgenticAILabTemporalTrajectoryDelta
    (.o kind: 'agentic-ai-lab.temporal-causality.trajectory-delta
        identity: identity-value semantic-digest: digest-value
        previous-series: previous-value revised-series: revised-value
        previous-series-digest: previous-digest-value
        revised-series-digest: revised-digest-value
        previous-cut-digest: previous-cut-value
        revised-cut-digest: revised-cut-value
        previous-projection-digest: previous-projection-value
        revised-projection-digest: revised-projection-value
        added-coordinates: added-value removed-coordinates: removed-value
        changed-coordinates: changed-value status: status-value)))
