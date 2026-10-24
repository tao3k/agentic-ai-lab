;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/types
                 agentic-ai-lab-temporal-evidence-revision-kind
                 agentic-ai-lab-temporal-evidence-journal-kind
                 agentic-ai-lab-temporal-evidence-snapshot-kind
                 AgenticAILabTemporalEvidenceRevision AgenticAILabTemporalEvidenceJournal
                 AgenticAILabTemporalEvidenceSnapshot))

(export agentic-ai-lab-temporal-evidence-revision
        agentic-ai-lab-temporal-evidence-journal-value
        agentic-ai-lab-temporal-evidence-snapshot-value)

(def (agentic-ai-lab-temporal-evidence-revision
      identity-value subject-value operation-value predecessor-value
      admission-value valid-value content-value)
  (validate AgenticAILabTemporalEvidenceRevision
    (.o kind: agentic-ai-lab-temporal-evidence-revision-kind
        identity: identity-value subject-identity: subject-value
        operation: operation-value predecessor-identity: predecessor-value
        admission-instant: admission-value valid-interval: valid-value
        content-identity: content-value)))

(def (agentic-ai-lab-temporal-evidence-journal-value
      identity-value digest-value domain-value revisions-value)
  (validate AgenticAILabTemporalEvidenceJournal
    (.o kind: agentic-ai-lab-temporal-evidence-journal-kind
        identity: identity-value semantic-digest: digest-value
        admission-domain-identity: domain-value revisions: revisions-value)))

(def (agentic-ai-lab-temporal-evidence-snapshot-value
      journal-digest-value cut-digest-value projection-digest-value
      as-of-value valid-at-value valid-at-digest-value
      active-value retracted-value conflicted-value outside-value
      uncertain-value incomparable-value visible-value future-value)
  (validate AgenticAILabTemporalEvidenceSnapshot
    (.o kind: agentic-ai-lab-temporal-evidence-snapshot-kind
        journal-digest: journal-digest-value cut-digest: cut-digest-value
        projection-digest: projection-digest-value
        as-of-instant-identity: as-of-value
        valid-at-instant-identity: valid-at-value
        valid-at-instant-digest: valid-at-digest-value
        active-revision-identities: active-value
        retracted-subject-identities: retracted-value
        conflicted-subject-identities: conflicted-value
        outside-valid-subject-identities: outside-value
        uncertain-subject-identities: uncertain-value
        incomparable-subject-identities: incomparable-value
        visible-revision-identities: visible-value
        future-revision-identities: future-value
        runtime-executed?: #f)))
