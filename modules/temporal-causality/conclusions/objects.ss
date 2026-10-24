;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/types
                 AgenticAILabTemporalConclusionRevision
                 AgenticAILabTemporalConclusionJournal
                 AgenticAILabTemporalSelectionObservation
                 AgenticAILabTemporalSelectionPlan))

(export agentic-ai-lab-temporal-conclusion-revision-value
        agentic-ai-lab-temporal-conclusion-journal-value
        agentic-ai-lab-temporal-selection-observation
        agentic-ai-lab-temporal-selection-plan-value)

(def (agentic-ai-lab-temporal-conclusion-revision-value
      id-value subject-value scope-value cut-value projection-value
      policy-value generation-value
      operation-value predecessor-value result-value proof-value index-value)
  (validate AgenticAILabTemporalConclusionRevision
    (.o kind: 'agentic-ai-lab.temporal-causality.conclusion-revision
        identity: id-value subject-identity: subject-value
        scope-identity: scope-value cut-digest: cut-value
        projection-digest: projection-value
        policy-identity: policy-value generation-identity: generation-value
        operation: operation-value predecessor-identity: predecessor-value
        result-identity: result-value proof-identity: proof-value
        invalidation-index-digest: index-value)))

(def (agentic-ai-lab-temporal-conclusion-journal-value id-value digest-value entries-value)
  (validate AgenticAILabTemporalConclusionJournal
    (.o kind: 'agentic-ai-lab.temporal-causality.conclusion-journal
        identity: id-value semantic-digest: digest-value revisions: entries-value)))

(def (agentic-ai-lab-temporal-selection-observation
      id-value subject-value scope-value version-value selected-value)
  (validate AgenticAILabTemporalSelectionObservation
    (.o kind: 'agentic-ai-lab.temporal-causality.selection-observation
        identity: id-value subject-identity: subject-value
        scope-identity: scope-value version: version-value
        selected-revision-identity: selected-value)))

(def (agentic-ai-lab-temporal-selection-plan-value
      journal-value observation-value subject-value scope-value
      expected-version-value expected-revision-value proposed-version-value
      observed-version-value observed-revision-value
      proposed-revision-value proof-value status-value)
  (validate AgenticAILabTemporalSelectionPlan
    (.o kind: 'agentic-ai-lab.temporal-causality.selection-plan
        journal-digest: journal-value observation-identity: observation-value
        subject-identity: subject-value scope-identity: scope-value
        expected-version: expected-version-value
        expected-revision-identity: expected-revision-value
        observed-version: observed-version-value
        observed-revision-identity: observed-revision-value
        proposed-version: proposed-version-value
        proposed-revision-identity: proposed-revision-value
        change-proof-identity: proof-value status: status-value
        requires-atomic-cas?: #t runtime-executed?: #f)))
