;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/evidence/types
                 PooFlowEvidenceRetrieval PooFlowEvidenceUse
                 PooFlowEvidenceAssessment
                 PooFlowEvidenceDependency PooFlowEvidenceLineage
                 PooFlowEvidenceUseAudit PooFlowEvidenceImpactFrontier))
(export poo-flow-evidence-retrieval-value poo-flow-evidence-use-value
        poo-flow-evidence-assessment-value
        poo-flow-evidence-dependency-value poo-flow-evidence-lineage-value
        poo-flow-evidence-use-audit-value
        poo-flow-evidence-impact-frontier-value)

(def (poo-flow-evidence-retrieval-value id-value digest-value query-value
                                         evidence-value source-value)
  (validate PooFlowEvidenceRetrieval
    (.o kind: 'poo-flow.temporal-causality.evidence-retrieval
        identity: id-value semantic-digest: digest-value
        query-identity: query-value evidence-identity: evidence-value
        source-digest: source-value)))

(def (poo-flow-evidence-use-value id-value digest-value evidence-value
                                   claim-value source-value claim-digest-value)
  (validate PooFlowEvidenceUse
    (.o kind: 'poo-flow.temporal-causality.evidence-use
        identity: id-value semantic-digest: digest-value
        evidence-identity: evidence-value claim-identity: claim-value
        source-digest: source-value claim-digest: claim-digest-value)))

(def (poo-flow-evidence-assessment-value id-value digest-value use-value
                                          use-digest-value assessor-value
                                          method-value verdict-value basis-value)
  (validate PooFlowEvidenceAssessment
    (.o kind: 'poo-flow.temporal-causality.evidence-assessment
        identity: id-value semantic-digest: digest-value
        use-identity: use-value use-digest: use-digest-value
        assessor-identity: assessor-value method-identity: method-value
        verdict: verdict-value basis-digest: basis-value)))

(def (poo-flow-evidence-dependency-value id-value digest-value source-value
                                          dependent-value)
  (validate PooFlowEvidenceDependency
    (.o kind: 'poo-flow.temporal-causality.evidence-dependency
        identity: id-value semantic-digest: digest-value
        source-claim-identity: source-value
        dependent-claim-identity: dependent-value)))

(def (poo-flow-evidence-lineage-value id-value digest-value retrievals-value
                                      uses-value assessments-value
                                      dependencies-value)
  (validate PooFlowEvidenceLineage
    (.o kind: 'poo-flow.temporal-causality.evidence-lineage
        identity: id-value semantic-digest: digest-value
        retrievals: retrievals-value uses: uses-value
        assessments: assessments-value
        dependencies: dependencies-value)))

(def (poo-flow-evidence-use-audit-value id-value digest-value lineage-value
                                        unused-value unretrieved-value
                                        unreviewed-value supported-value
                                        refuted-value uncertain-value
                                        contested-value status-value)
  (validate PooFlowEvidenceUseAudit
    (.o kind: 'poo-flow.temporal-causality.evidence-use-audit
        identity: id-value semantic-digest: digest-value
        lineage-digest: lineage-value
        retrieved-unused-evidence: unused-value
        cited-unretrieved-evidence: unretrieved-value
        unreviewed-use-identities: unreviewed-value
        supported-use-identities: supported-value
        refuted-use-identities: refuted-value
        uncertain-use-identities: uncertain-value
        contested-use-identities: contested-value
        status: status-value)))

(def (poo-flow-evidence-impact-frontier-value id-value digest-value
                                               lineage-value seeds-value
                                               claims-value)
  (validate PooFlowEvidenceImpactFrontier
    (.o kind: 'poo-flow.temporal-causality.evidence-impact-frontier
        identity: id-value semantic-digest: digest-value
        lineage-digest: lineage-value seed-evidence-identities: seeds-value
        reachable-claim-identities: claims-value
        actual-impact-admitted?: #f)))
