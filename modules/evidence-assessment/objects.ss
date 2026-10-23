;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public values are POO objects; Ascent tuples are private projections.
(import (only-in :clan/poo/object .o))

(export AgenticAILabEvidenceAssessmentCase.
        agentic-ai-lab-evidence-reference
        agentic-ai-lab-evidence-claim
        agentic-ai-lab-evidence-step
        agentic-ai-lab-evidence-hypothesis
        agentic-ai-lab-evidence-branch)

(def AgenticAILabEvidenceAssessmentCase.
  (.o kind: 'agentic-ai-lab.evidence-assessment.case
      claims: '()
      steps: '()
      query: #f
      hypotheses: '()
      unresolved: '()))

(def (agentic-ai-lab-evidence-reference source-id source-uri
                                            independence-group-value
                                            (content-digest-value #f))
  (.o kind: 'agentic-ai-lab.evidence-assessment.evidence-reference
      source: source-id uri: source-uri
      independence-group: independence-group-value
      content-digest: content-digest-value))

(def (agentic-ai-lab-evidence-claim claim-id claim-value claim-source
                               (evidence-reference-value #f))
  (.o kind: 'agentic-ai-lab.evidence-assessment.claim
      identity: claim-id value: claim-value source: claim-source
      evidence-reference: evidence-reference-value))

(def (agentic-ai-lab-evidence-step from-node to-node first-claim second-claim
                            (join-mode 'presence))
  (.o kind: 'agentic-ai-lab.evidence-assessment.step
      from: from-node to: to-node first: first-claim
      second: second-claim join: join-mode))

(def (agentic-ai-lab-evidence-hypothesis hypothesis-id from-node to-node
                                   required-claim-ids)
  (.o kind: 'agentic-ai-lab.evidence-assessment.hypothesis
      identity: hypothesis-id from: from-node to: to-node
      required-claims: required-claim-ids))

(def (agentic-ai-lab-evidence-branch branch-id proposed-values withheld-identities
                                (reason-value 'unspecified))
  (.o kind: 'agentic-ai-lab.evidence-assessment.branch
      identity: branch-id
      proposed-claims: proposed-values
      withheld-claims: withheld-identities
      reason: reason-value))
