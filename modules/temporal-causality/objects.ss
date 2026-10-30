;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native causal-trajectory and structural-analysis values.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/types
                 agentic-ai-lab-relation-trajectory-witness-kind
                 agentic-ai-lab-structural-impact-receipt-kind
                 agentic-ai-lab-temporal-observation-kind
                 agentic-ai-lab-causal-event-kind
                 agentic-ai-lab-causal-event-graph-kind
                 agentic-ai-lab-causal-trajectory-contract-kind
                 agentic-ai-lab-causal-trajectory-assessment-kind
                 agentic-ai-lab-causal-cut-kind
                 agentic-ai-lab-temporal-classification-receipt-kind
                 agentic-ai-lab-temporal-clock-domain-kind
                 agentic-ai-lab-temporal-model-observation-kind
                 agentic-ai-lab-temporal-constraint-kind
                 agentic-ai-lab-temporal-hypothesis-kind
                 agentic-ai-lab-temporal-model-kind
                 agentic-ai-lab-temporal-query-kind
                 agentic-ai-lab-temporal-model-receipt-kind
                 AgenticAILabRelationTrajectoryWitness
                 AgenticAILabStructuralImpactReceipt
                 AgenticAILabTemporalObservation
                 AgenticAILabCausalEvent
                 AgenticAILabCausalEventGraph
                 AgenticAILabCausalTrajectoryContract
                 AgenticAILabCausalTrajectoryAssessment
                 AgenticAILabCausalCut
                 AgenticAILabTemporalClassificationReceipt
                 AgenticAILabTemporalClockDomain
                 AgenticAILabTemporalModelObservation
                 AgenticAILabTemporalConstraint
                 AgenticAILabTemporalHypothesis
                 AgenticAILabTemporalModel
                 AgenticAILabTemporalQuery
                 AgenticAILabTemporalModelReceipt))

(export agentic-ai-lab-relation-trajectory-witness
        agentic-ai-lab-structural-impact-receipt
        agentic-ai-lab-temporal-observation
        agentic-ai-lab-causal-event
        agentic-ai-lab-causal-event-graph-value
        agentic-ai-lab-causal-trajectory-contract
        agentic-ai-lab-causal-trajectory-assessment
        agentic-ai-lab-causal-cut-value
        agentic-ai-lab-temporal-classification-receipt
        agentic-ai-lab-temporal-clock-domain
        agentic-ai-lab-temporal-model-observation
        agentic-ai-lab-temporal-constraint
        agentic-ai-lab-temporal-hypothesis
        agentic-ai-lab-temporal-model-value
        agentic-ai-lab-temporal-query
        agentic-ai-lab-temporal-model-receipt)

(def (agentic-ai-lab-relation-trajectory-witness
      target-node-id-value node-path-value relation-path-value)
  (validate
   AgenticAILabRelationTrajectoryWitness
   (.o kind: agentic-ai-lab-relation-trajectory-witness-kind
       target-node-id: target-node-id-value
       node-path: node-path-value
       relation-path: relation-path-value)))

(def (agentic-ai-lab-structural-impact-receipt
      status-value graph-id-value changed-node-ids-value direction-value
      selected-relations-value affected-node-ids-value trajectories-value
      unresolved-edges-value)
  (validate
   AgenticAILabStructuralImpactReceipt
   (.o kind: agentic-ai-lab-structural-impact-receipt-kind
       status: status-value
       scope: 'structural-snapshot
       graph-id: graph-id-value
       changed-node-ids: changed-node-ids-value
       direction: direction-value
       selected-relations: selected-relations-value
       affected-node-ids: affected-node-ids-value
       relation-trajectories: trajectories-value
       unresolved-edges: unresolved-edges-value
       temporal-impact-assessed?: #f
       release-authorized?: #f
       runtime-executed?: #f)))

(def (agentic-ai-lab-temporal-observation
      identity-value clock-role-value logical-position-value
      provenance-identity-value)
  (validate
   AgenticAILabTemporalObservation
   (.o kind: agentic-ai-lab-temporal-observation-kind
       identity: identity-value
       clock-role: clock-role-value
       logical-position: logical-position-value
       provenance-identity: provenance-identity-value
       immutable?: #t
       runtime-executed?: #f)))

(def (agentic-ai-lab-causal-event
      identity-value subject-value event-kind-value observation-value
      payload-identity-value causal-parent-identities-value modality-value
      committed-value)
  (validate
   AgenticAILabCausalEvent
   (.o kind: agentic-ai-lab-causal-event-kind
       identity: identity-value
       subject: subject-value
       event-kind: event-kind-value
       observation: observation-value
       payload-identity: payload-identity-value
       causal-parent-identities: causal-parent-identities-value
       modality: modality-value
       committed?: committed-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-causal-event-graph-value
      identity-value subject-value events-value event-index-value
      missing-parent-identities-value temporal-order-violations-value)
  (validate
   AgenticAILabCausalEventGraph
   (.o kind: agentic-ai-lab-causal-event-graph-kind
       identity: identity-value
       subject: subject-value
       events: events-value
       event-index: event-index-value
       missing-parent-identities: missing-parent-identities-value
       temporal-order-violations: temporal-order-violations-value
       complete?: (and (null? missing-parent-identities-value)
                       (null? temporal-order-violations-value))
       runtime-executed?: #f)))

(def (agentic-ai-lab-causal-trajectory-contract
      identity-value trigger-event-id-value intended-event-ids-value
      error-event-paths-value intended-impact-event-ids-value
      error-impact-event-ids-value)
  (validate
   AgenticAILabCausalTrajectoryContract
   (.o kind: agentic-ai-lab-causal-trajectory-contract-kind
       identity: identity-value
       trigger-event-id: trigger-event-id-value
       intended-event-ids: intended-event-ids-value
       error-event-paths: error-event-paths-value
       intended-impact-event-ids: intended-impact-event-ids-value
       error-impact-event-ids: error-impact-event-ids-value)))

(def (agentic-ai-lab-causal-trajectory-assessment
      status-value contract-value event-graph-value diagnostics-value)
  (validate
   AgenticAILabCausalTrajectoryAssessment
   (.o kind: agentic-ai-lab-causal-trajectory-assessment-kind
       status: status-value
       accepted?: (eq? status-value 'causal-trajectory-admitted)
       contract-identity: (.ref contract-value 'identity)
       event-graph-identity: (.ref event-graph-value 'identity)
       diagnostics: diagnostics-value
       intended-event-ids: (.ref contract-value 'intended-event-ids)
       error-event-paths: (.ref contract-value 'error-event-paths)
       intended-impact-event-ids:
       (.ref contract-value 'intended-impact-event-ids)
       error-impact-event-ids: (.ref contract-value 'error-impact-event-ids)
       assurance-closed?: #f
       release-authorized?: #f
       runtime-executed?: #f)))

(def (agentic-ai-lab-causal-cut-value
      identity-value event-graph-identity-value subject-value
      events-value event-index-value
      missing-parent-identities-value temporal-order-violations-value
      as-of-position-value)
  (validate
   AgenticAILabCausalCut
   (.o kind: agentic-ai-lab-causal-cut-kind
       identity: identity-value
       event-graph-identity: event-graph-identity-value
       subject: subject-value
       events: events-value
       event-index: event-index-value
       missing-parent-identities: missing-parent-identities-value
       temporal-order-violations: temporal-order-violations-value
       complete?: (and (null? missing-parent-identities-value)
                       (null? temporal-order-violations-value))
       as-of-position: as-of-position-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-temporal-classification-receipt
      status-value event-graph-identity-value cut-identity-value
      trigger-event-id-value
      as-of-position-value horizon-value past-event-ids-value
      current-event-ids-value future-event-ids-value
      hypothesized-event-ids-value
      counterfactual-event-ids-value outside-horizon-event-ids-value
      unknown-frontier-value trajectories-value structural-impact-value)
  (validate
   AgenticAILabTemporalClassificationReceipt
   (.o kind: agentic-ai-lab-temporal-classification-receipt-kind
       status: status-value
       event-graph-identity: event-graph-identity-value
       cut-identity: cut-identity-value
       trigger-event-id: trigger-event-id-value
       as-of-position: as-of-position-value
       horizon: horizon-value
       past-event-ids: past-event-ids-value
       current-event-ids: current-event-ids-value
       future-event-ids: future-event-ids-value
       hypothesized-event-ids: hypothesized-event-ids-value
       counterfactual-event-ids: counterfactual-event-ids-value
       outside-horizon-event-ids: outside-horizon-event-ids-value
       unknown-frontier: unknown-frontier-value
       relation-trajectories: trajectories-value
       structural-impact: structural-impact-value
       assurance-closed?: #f
       release-authorized?: #f
       runtime-executed?: #f)))

(def (agentic-ai-lab-temporal-clock-domain identity-value role-value)
  (validate AgenticAILabTemporalClockDomain
    (.o kind: agentic-ai-lab-temporal-clock-domain-kind
        identity: identity-value clock-role: role-value)))

(def (agentic-ai-lab-temporal-model-observation
      identity-value domain-id-value position-value provenance-value modality-value)
  (validate AgenticAILabTemporalModelObservation
    (.o kind: agentic-ai-lab-temporal-model-observation-kind
        identity: identity-value domain-identity: domain-id-value
        logical-position: position-value provenance-identity: provenance-value
        modality: modality-value)))

(def (agentic-ai-lab-temporal-constraint
      identity-value relation-value left-id-value right-id-value)
  (validate AgenticAILabTemporalConstraint
    (.o kind: agentic-ai-lab-temporal-constraint-kind
        identity: identity-value relation: relation-value
        left-observation-id: left-id-value
        right-observation-id: right-id-value)))

(def (agentic-ai-lab-temporal-hypothesis
      identity-value cause-id-value effect-id-value constraints-value)
  (validate AgenticAILabTemporalHypothesis
    (.o kind: agentic-ai-lab-temporal-hypothesis-kind
        identity: identity-value
        cause-observation-id: cause-id-value
        effect-observation-id: effect-id-value
        constraints: constraints-value)))

(def (agentic-ai-lab-temporal-model-value
      identity-value digest-value domains-value observations-value
      hypotheses-value family-complete-value semantics-value)
  (validate AgenticAILabTemporalModel
    (.o kind: agentic-ai-lab-temporal-model-kind
        identity: identity-value semantic-digest: digest-value
        domains: domains-value observations: observations-value
        hypotheses: hypotheses-value
        family-complete?: family-complete-value
        family-semantics: semantics-value)))

(def (agentic-ai-lab-temporal-query
      identity-value hypothesis-id-value exploration-limit-value)
  (validate AgenticAILabTemporalQuery
    (.o kind: agentic-ai-lab-temporal-query-kind
        identity: identity-value
        hypothesis-identity: hypothesis-id-value
        exploration-limit: exploration-limit-value)))

(def (agentic-ai-lab-temporal-model-receipt
      model-value query-value classification-value admitted-value refuted-value
      unknown-value unexplored-value exhausted-value)
  (validate AgenticAILabTemporalModelReceipt
    (.o kind: agentic-ai-lab-temporal-model-receipt-kind
        model-digest: (.ref model-value 'semantic-digest)
        query-identity: (.ref query-value 'identity)
        classification: classification-value
        admissible-hypothesis-ids: admitted-value
        refuted-hypothesis-ids: refuted-value
        unknown-hypothesis-ids: unknown-value
        unexplored-hypothesis-ids: unexplored-value
        exhausted?: exhausted-value
        family-complete?: (.ref model-value 'family-complete?)
        assumption: (.ref model-value 'family-semantics)
        runtime-executed?: #f)))
