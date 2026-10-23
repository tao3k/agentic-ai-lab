;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: domain-neutral temporal-causality analysis contracts.
;;; Invariant: structural reachability is never temporal proof or authority.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :yuanxu/graph/types-core yuanxu-graph-id?))

(export agentic-ai-lab-relation-trajectory-witness-kind
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
        AgenticAILabTemporalModelReceipt
        agentic-ai-lab-relation-trajectory-witness?
        agentic-ai-lab-structural-impact-receipt?
        agentic-ai-lab-temporal-observation?
        agentic-ai-lab-causal-event?
        agentic-ai-lab-causal-event-graph?
        agentic-ai-lab-causal-trajectory-contract?
        agentic-ai-lab-causal-trajectory-assessment?
        agentic-ai-lab-causal-cut?
        agentic-ai-lab-temporal-classification-receipt?
        agentic-ai-lab-temporal-clock-domain?
        agentic-ai-lab-temporal-model-observation?
        agentic-ai-lab-temporal-constraint?
        agentic-ai-lab-temporal-hypothesis?
        agentic-ai-lab-temporal-model?
        agentic-ai-lab-temporal-query?
        agentic-ai-lab-temporal-model-receipt?)

(def agentic-ai-lab-relation-trajectory-witness-kind
  'agentic-ai-lab.temporal-causality.relation-trajectory-witness)

(def agentic-ai-lab-structural-impact-receipt-kind
  'agentic-ai-lab.temporal-causality.structural-impact-receipt)

(def agentic-ai-lab-temporal-observation-kind
  'agentic-ai-lab.temporal-causality.temporal-observation)

(def agentic-ai-lab-causal-event-kind
  'agentic-ai-lab.temporal-causality.causal-event)

(def agentic-ai-lab-causal-event-graph-kind
  'agentic-ai-lab.temporal-causality.causal-event-graph)

(def agentic-ai-lab-causal-trajectory-contract-kind
  'agentic-ai-lab.temporal-causality.causal-trajectory-contract)

(def agentic-ai-lab-causal-trajectory-assessment-kind
  'agentic-ai-lab.temporal-causality.causal-trajectory-assessment)

(def agentic-ai-lab-causal-cut-kind
  'agentic-ai-lab.temporal-causality.causal-cut)

(def agentic-ai-lab-temporal-classification-receipt-kind
  'agentic-ai-lab.temporal-causality.temporal-classification-receipt)

(def (temporal-causality-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (relation-trajectory-witness-shape? value)
  (and (temporal-causality-has-slots?
        value '(kind target-node-id node-path relation-path))
       (eq? (.ref value 'kind) agentic-ai-lab-relation-trajectory-witness-kind)
       (yuanxu-graph-id? (.ref value 'target-node-id))
       (list? (.ref value 'node-path))
       (pair? (.ref value 'node-path))
       (every yuanxu-graph-id? (.ref value 'node-path))
       (equal? (.ref value 'target-node-id)
               (car (reverse (.ref value 'node-path))))
       (list? (.ref value 'relation-path))
       (every symbol? (.ref value 'relation-path))
       (= (length (.ref value 'relation-path))
          (- (length (.ref value 'node-path)) 1))))

(define-type (AgenticAILabRelationTrajectoryWitness @ Type.)
  .element?: relation-trajectory-witness-shape?)

(def (agentic-ai-lab-relation-trajectory-witness? value)
  (element? AgenticAILabRelationTrajectoryWitness value))

(def (structural-impact-receipt-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind status scope graph-id changed-node-ids direction
               selected-relations affected-node-ids relation-trajectories
               unresolved-edges temporal-impact-assessed?
               release-authorized? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-structural-impact-receipt-kind)
       (memq (.ref value 'status)
             '(snapshot-scoped-impact partial-impact invalid-inventory))
       (eq? (.ref value 'scope) 'structural-snapshot)
       (yuanxu-graph-id? (.ref value 'graph-id))
       (list? (.ref value 'changed-node-ids))
       (pair? (.ref value 'changed-node-ids))
       (every yuanxu-graph-id? (.ref value 'changed-node-ids))
       (memq (.ref value 'direction) '(dependents dependencies))
       (list? (.ref value 'selected-relations))
       (pair? (.ref value 'selected-relations))
       (every symbol? (.ref value 'selected-relations))
       (list? (.ref value 'affected-node-ids))
       (every yuanxu-graph-id? (.ref value 'affected-node-ids))
       (list? (.ref value 'relation-trajectories))
       (every agentic-ai-lab-relation-trajectory-witness?
              (.ref value 'relation-trajectories))
       (list? (.ref value 'unresolved-edges))
       (eq? (.ref value 'temporal-impact-assessed?) #f)
       (eq? (.ref value 'release-authorized?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStructuralImpactReceipt @ Type.)
  .element?: structural-impact-receipt-shape?)

(def (agentic-ai-lab-structural-impact-receipt? value)
  (element? AgenticAILabStructuralImpactReceipt value))

(def (temporal-causality-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (temporal-causality-position? value)
  (and (exact-integer? value) (>= value 0)))

(def (temporal-causality-unique? values)
  (= (length values) (length (delete-duplicates/hash values))))

(def (temporal-observation-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind identity clock-role logical-position provenance-identity
               immutable? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-observation-kind)
       (temporal-causality-text? (.ref value 'identity))
       (memq (.ref value 'clock-role)
             '(wall-clock monotonic logical-version authoritative-service))
       (temporal-causality-position? (.ref value 'logical-position))
       (temporal-causality-text? (.ref value 'provenance-identity))
       (eq? (.ref value 'immutable?) #t)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabTemporalObservation @ Type.)
  .element?: temporal-observation-shape?)

(def (agentic-ai-lab-temporal-observation? value)
  (element? AgenticAILabTemporalObservation value))

(def (causal-event-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind identity subject event-kind observation payload-identity
               causal-parent-identities modality committed?
               runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-causal-event-kind)
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'subject))
       (symbol? (.ref value 'event-kind))
       (agentic-ai-lab-temporal-observation? (.ref value 'observation))
       (temporal-causality-text? (.ref value 'payload-identity))
       (list? (.ref value 'causal-parent-identities))
       (every temporal-causality-text?
              (.ref value 'causal-parent-identities))
       (temporal-causality-unique?
        (.ref value 'causal-parent-identities))
       (memq (.ref value 'modality)
             '(observed declared derived hypothesized counterfactual))
       (boolean? (.ref value 'committed?))
       (if (eq? (.ref value 'modality) 'observed)
         (.ref value 'committed?)
         #t)
       (if (memq (.ref value 'modality) '(hypothesized counterfactual))
         (not (.ref value 'committed?))
         #t)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabCausalEvent @ Type.)
  .element?: causal-event-shape?)

(def (agentic-ai-lab-causal-event? value)
  (element? AgenticAILabCausalEvent value))

(def (causal-event-inventory-shape? value expected-kind extra-slots)
  (and (temporal-causality-has-slots?
        value
        (append
         '(kind identity subject events event-index missing-parent-identities
                temporal-order-violations complete? runtime-executed?)
         extra-slots))
       (eq? (.ref value 'kind) expected-kind)
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'subject))
       (list? (.ref value 'events))
       (pair? (.ref value 'events))
       (every agentic-ai-lab-causal-event? (.ref value 'events))
       (every (lambda (event)
                (equal? (.ref event 'subject) (.ref value 'subject)))
              (.ref value 'events))
       (temporal-causality-unique?
        (map (lambda (event) (.ref event 'identity))
             (.ref value 'events)))
       (hash-table? (.ref value 'event-index))
       (every
        (lambda (event)
          (eq? (hash-get (.ref value 'event-index)
                         (.ref event 'identity))
               event))
        (.ref value 'events))
       (list? (.ref value 'missing-parent-identities))
       (every temporal-causality-text?
              (.ref value 'missing-parent-identities))
       (list? (.ref value 'temporal-order-violations))
       (every
        (lambda (violation)
          (and (list? violation)
               (= (length violation) 2)
               (every temporal-causality-text? violation)))
        (.ref value 'temporal-order-violations))
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'complete?)
            (and (null? (.ref value 'missing-parent-identities))
                 (null? (.ref value 'temporal-order-violations))))
       (eq? (.ref value 'runtime-executed?) #f)))

(def (causal-event-graph-shape? value)
  (causal-event-inventory-shape?
   value agentic-ai-lab-causal-event-graph-kind '()))

(define-type (AgenticAILabCausalEventGraph @ Type.)
  .element?: causal-event-graph-shape?)

(def (agentic-ai-lab-causal-event-graph? value)
  (element? AgenticAILabCausalEventGraph value))

(def (causal-trajectory-contract-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind identity trigger-event-id intended-event-ids error-event-paths
               intended-impact-event-ids error-impact-event-ids))
       (eq? (.ref value 'kind) agentic-ai-lab-causal-trajectory-contract-kind)
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'trigger-event-id))
       (let ((intended (.ref value 'intended-event-ids))
             (error-paths (.ref value 'error-event-paths))
             (intended-impacts (.ref value 'intended-impact-event-ids))
             (error-impacts (.ref value 'error-impact-event-ids)))
         (and (list? intended) (pair? intended)
              (every temporal-causality-text? intended)
              (list? error-paths) (pair? error-paths)
              (every (lambda (path)
                       (and (list? path) (pair? path)
                            (every temporal-causality-text? path)))
                     error-paths)
              (list? intended-impacts)
              (every temporal-causality-text? intended-impacts)
              (list? error-impacts) (pair? error-impacts)
              (every temporal-causality-text? error-impacts)
              (let (all-identities
                    (cons (.ref value 'trigger-event-id)
                          (append intended
                                  (apply append error-paths)
                                  intended-impacts error-impacts)))
                (temporal-causality-unique? all-identities))))))

(define-type (AgenticAILabCausalTrajectoryContract @ Type.)
  .element?: causal-trajectory-contract-shape?)

(def (agentic-ai-lab-causal-trajectory-contract? value)
  (element? AgenticAILabCausalTrajectoryContract value))

(def (causal-trajectory-assessment-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind status accepted? contract-identity event-graph-identity
               diagnostics intended-event-ids error-event-paths
               intended-impact-event-ids error-impact-event-ids
               assurance-closed? release-authorized? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-causal-trajectory-assessment-kind)
       (memq (.ref value 'status)
             '(causal-trajectory-admitted causal-trajectory-rejected))
       (boolean? (.ref value 'accepted?))
       (eq? (.ref value 'accepted?)
            (eq? (.ref value 'status) 'causal-trajectory-admitted))
       (temporal-causality-text? (.ref value 'contract-identity))
       (temporal-causality-text? (.ref value 'event-graph-identity))
       (list? (.ref value 'diagnostics))
       (every (lambda (diagnostic)
                (and (list? diagnostic) (pair? diagnostic)
                     (symbol? (car diagnostic))))
              (.ref value 'diagnostics))
       (list? (.ref value 'intended-event-ids))
       (list? (.ref value 'error-event-paths))
       (list? (.ref value 'intended-impact-event-ids))
       (list? (.ref value 'error-impact-event-ids))
       (eq? (.ref value 'assurance-closed?) #f)
       (eq? (.ref value 'release-authorized?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabCausalTrajectoryAssessment @ Type.)
  .element?: causal-trajectory-assessment-shape?)

(def (agentic-ai-lab-causal-trajectory-assessment? value)
  (element? AgenticAILabCausalTrajectoryAssessment value))

(def (causal-cut-shape? value)
  (and (causal-event-inventory-shape?
        value agentic-ai-lab-causal-cut-kind
        '(event-graph-identity as-of-position))
       (temporal-causality-text? (.ref value 'event-graph-identity))
       (temporal-causality-position? (.ref value 'as-of-position))
       (every
        (lambda (event)
          (and (.ref event 'committed?)
               (<= (.ref (.ref event 'observation) 'logical-position)
                   (.ref value 'as-of-position))))
        (.ref value 'events))))

(define-type (AgenticAILabCausalCut @ Type.)
  .element?: causal-cut-shape?)

(def (agentic-ai-lab-causal-cut? value)
  (element? AgenticAILabCausalCut value))

(def (temporal-classification-receipt-shape? value)
  (and (temporal-causality-has-slots?
        value
        '(kind status event-graph-identity cut-identity trigger-event-id
               as-of-position horizon
               past-event-ids current-event-ids future-event-ids
               hypothesized-event-ids counterfactual-event-ids
               outside-horizon-event-ids
               unknown-frontier relation-trajectories structural-impact
               assurance-closed? release-authorized? runtime-executed?))
       (eq? (.ref value 'kind)
            agentic-ai-lab-temporal-classification-receipt-kind)
       (memq (.ref value 'status)
             '(bounded-temporal-classification
               partial-temporal-classification invalid-causal-cut))
       (every temporal-causality-text?
              (list (.ref value 'event-graph-identity)
                    (.ref value 'cut-identity)
                    (.ref value 'trigger-event-id)))
       (temporal-causality-position? (.ref value 'as-of-position))
       (temporal-causality-position? (.ref value 'horizon))
       (>= (.ref value 'horizon) (.ref value 'as-of-position))
       (every (lambda (slot)
                (let (ids (.ref value slot))
                  (and (list? ids) (every temporal-causality-text? ids))))
              '(past-event-ids current-event-ids future-event-ids
                hypothesized-event-ids counterfactual-event-ids
                outside-horizon-event-ids
                unknown-frontier))
       (temporal-causality-unique?
        (apply append
               (map (lambda (slot) (.ref value slot))
                    '(past-event-ids current-event-ids future-event-ids
                      hypothesized-event-ids counterfactual-event-ids
                      outside-horizon-event-ids
                      unknown-frontier))))
       (list? (.ref value 'relation-trajectories))
       (every agentic-ai-lab-relation-trajectory-witness?
              (.ref value 'relation-trajectories))
       (agentic-ai-lab-structural-impact-receipt?
        (.ref value 'structural-impact))
       (eq? (.ref value 'assurance-closed?) #f)
       (eq? (.ref value 'release-authorized?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabTemporalClassificationReceipt @ Type.)
  .element?: temporal-classification-receipt-shape?)

(def (agentic-ai-lab-temporal-classification-receipt? value)
  (element? AgenticAILabTemporalClassificationReceipt value))

;;; These contracts describe a finite family of candidate explanations. They
;;; do not convert temporal order into an observed causal edge.
(def agentic-ai-lab-temporal-clock-domain-kind
  'agentic-ai-lab.temporal-causality.clock-domain)
(def agentic-ai-lab-temporal-model-observation-kind
  'agentic-ai-lab.temporal-causality.model-observation)
(def agentic-ai-lab-temporal-constraint-kind
  'agentic-ai-lab.temporal-causality.constraint)
(def agentic-ai-lab-temporal-hypothesis-kind
  'agentic-ai-lab.temporal-causality.hypothesis)
(def agentic-ai-lab-temporal-model-kind
  'agentic-ai-lab.temporal-causality.model)
(def agentic-ai-lab-temporal-query-kind
  'agentic-ai-lab.temporal-causality.query)
(def agentic-ai-lab-temporal-model-receipt-kind
  'agentic-ai-lab.temporal-causality.model-receipt)

(def (temporal-model-shape? value kind slots)
  (and (temporal-causality-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (temporal-model-id-list? values)
  (and (list? values)
       (every temporal-causality-text? values)
       (= (length values) (length (delete-duplicates/hash values)))))

(def (temporal-clock-domain-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-clock-domain-kind
                              '(identity clock-role))
       (temporal-causality-text? (.ref value 'identity))
       (symbol? (.ref value 'clock-role))))
(define-type (AgenticAILabTemporalClockDomain @ Type.)
  .element?: temporal-clock-domain-shape?)
(def (agentic-ai-lab-temporal-clock-domain? value)
  (element? AgenticAILabTemporalClockDomain value))

(def (temporal-model-observation-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-model-observation-kind
                              '(identity domain-identity logical-position
                                provenance-identity modality))
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'domain-identity))
       (temporal-causality-position? (.ref value 'logical-position))
       (temporal-causality-text? (.ref value 'provenance-identity))
       (symbol? (.ref value 'modality))))
(define-type (AgenticAILabTemporalModelObservation @ Type.)
  .element?: temporal-model-observation-shape?)
(def (agentic-ai-lab-temporal-model-observation? value)
  (element? AgenticAILabTemporalModelObservation value))

(def (temporal-constraint-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-constraint-kind
                              '(identity relation left-observation-id
                                right-observation-id))
       (temporal-causality-text? (.ref value 'identity))
       (memq (.ref value 'relation) '(before not-after))
       (temporal-causality-text? (.ref value 'left-observation-id))
       (temporal-causality-text? (.ref value 'right-observation-id))))
(define-type (AgenticAILabTemporalConstraint @ Type.)
  .element?: temporal-constraint-shape?)
(def (agentic-ai-lab-temporal-constraint? value)
  (element? AgenticAILabTemporalConstraint value))

(def (temporal-hypothesis-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-hypothesis-kind
                              '(identity cause-observation-id
                                effect-observation-id constraints))
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'cause-observation-id))
       (temporal-causality-text? (.ref value 'effect-observation-id))
       (list? (.ref value 'constraints))
       (every agentic-ai-lab-temporal-constraint? (.ref value 'constraints))
       (temporal-model-id-list?
        (map (lambda (constraint) (.ref constraint 'identity))
             (.ref value 'constraints)))))
(define-type (AgenticAILabTemporalHypothesis @ Type.)
  .element?: temporal-hypothesis-shape?)
(def (agentic-ai-lab-temporal-hypothesis? value)
  (element? AgenticAILabTemporalHypothesis value))

(def (temporal-model-value-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-model-kind
                              '(identity semantic-digest domains observations
                                hypotheses family-complete? family-semantics))
       (every temporal-causality-text?
              (list (.ref value 'identity) (.ref value 'semantic-digest)))
       (list? (.ref value 'domains))
       (every agentic-ai-lab-temporal-clock-domain? (.ref value 'domains))
       (list? (.ref value 'observations))
       (every agentic-ai-lab-temporal-model-observation? (.ref value 'observations))
       (list? (.ref value 'hypotheses))
       (pair? (.ref value 'hypotheses))
       (every agentic-ai-lab-temporal-hypothesis? (.ref value 'hypotheses))
       (boolean? (.ref value 'family-complete?))
       (memq (.ref value 'family-semantics)
             '(exclusive-explanations overlapping-mechanisms))
       #t))
(define-type (AgenticAILabTemporalModel @ Type.)
  .element?: temporal-model-value-shape?)
(def (agentic-ai-lab-temporal-model? value)
  (element? AgenticAILabTemporalModel value))

(def (temporal-query-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-query-kind
                              '(identity hypothesis-identity exploration-limit))
       (temporal-causality-text? (.ref value 'identity))
       (temporal-causality-text? (.ref value 'hypothesis-identity))
       (or (not (.ref value 'exploration-limit))
           (and (exact-integer? (.ref value 'exploration-limit))
                (> (.ref value 'exploration-limit) 0)))))
(define-type (AgenticAILabTemporalQuery @ Type.)
  .element?: temporal-query-shape?)
(def (agentic-ai-lab-temporal-query? value)
  (element? AgenticAILabTemporalQuery value))

(def (temporal-model-receipt-shape? value)
  (and (temporal-model-shape? value agentic-ai-lab-temporal-model-receipt-kind
                              '(model-digest query-identity classification
                                admissible-hypothesis-ids refuted-hypothesis-ids
                                unknown-hypothesis-ids unexplored-hypothesis-ids
                                exhausted? family-complete? assumption
                                runtime-executed?))
       (every temporal-causality-text?
              (list (.ref value 'model-digest) (.ref value 'query-identity)))
       (memq (.ref value 'classification)
             '(possible necessary refuted unknown))
       (every (lambda (slot) (temporal-model-id-list? (.ref value slot)))
              '(admissible-hypothesis-ids refuted-hypothesis-ids
                unknown-hypothesis-ids unexplored-hypothesis-ids))
       (boolean? (.ref value 'exhausted?))
       (boolean? (.ref value 'family-complete?))
       (memq (.ref value 'assumption)
             '(exclusive-explanations overlapping-mechanisms))
       (or (not (eq? (.ref value 'classification) 'necessary))
           (eq? (.ref value 'assumption) 'exclusive-explanations))
       (eq? (.ref value 'runtime-executed?) #f)))
(define-type (AgenticAILabTemporalModelReceipt @ Type.)
  .element?: temporal-model-receipt-shape?)
(def (agentic-ai-lab-temporal-model-receipt? value)
  (element? AgenticAILabTemporalModelReceipt value))
