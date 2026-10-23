;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: finite structural analysis over one explicit Agentic AI Lab Graph.
;;; Invariant: the result is output-sensitive O(V + E + witness bytes), inert,
;;; and never promoted to temporal causality or action authority.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list every filter find delete-duplicates/hash)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/graph/types-core
                 yuanxu-graph yuanxu-graph-edge yuanxu-graph-node
                 yuanxu-graph? yuanxu-graph-id yuanxu-graph-nodes
                 yuanxu-graph-edges yuanxu-graph-node-id
                 yuanxu-graph-edge-from yuanxu-graph-edge-to
                 yuanxu-graph-edge-kind)
        (only-in :agentic-ai-lab/modules/temporal-causality/objects
                 agentic-ai-lab-relation-trajectory-witness
                 agentic-ai-lab-structural-impact-receipt
                 agentic-ai-lab-causal-event-graph-value
                 agentic-ai-lab-causal-trajectory-assessment
                 agentic-ai-lab-causal-cut-value
                 agentic-ai-lab-temporal-classification-receipt
                 agentic-ai-lab-temporal-model-value
                 agentic-ai-lab-temporal-model-receipt)
        (only-in :agentic-ai-lab/modules/temporal-causality/types
                 agentic-ai-lab-causal-event? agentic-ai-lab-causal-event-graph?
                 agentic-ai-lab-causal-trajectory-contract?
                 agentic-ai-lab-causal-trajectory-assessment?
                 agentic-ai-lab-causal-cut?
                 agentic-ai-lab-temporal-clock-domain?
                 agentic-ai-lab-temporal-model-observation?
                 agentic-ai-lab-temporal-hypothesis?
                 agentic-ai-lab-temporal-model?
                 agentic-ai-lab-temporal-query?))

(export agentic-ai-lab-structural-impact-analyze
        agentic-ai-lab-causal-event-graph
        agentic-ai-lab-causal-trajectory-assess
        agentic-ai-lab-causal-trajectory-assessment-digest
        agentic-ai-lab-causal-cut
        agentic-ai-lab-temporal-causal-classify
        agentic-ai-lab-temporal-model
        agentic-ai-lab-temporal-overlapping-model
        agentic-ai-lab-temporal-model-replay
        agentic-ai-lab-temporal-model-classify)

(def (temporal-causality-unique? values)
  (= (length values) (length (delete-duplicates/hash values))))

(def (agentic-ai-lab-structural-impact-analyze
      graph changed-node-ids selected-relations direction inventory-complete?)
  (unless (yuanxu-graph? graph)
    (error "structural Impact requires a Agentic AI Lab Graph" graph))
  (unless (and (list? changed-node-ids) (pair? changed-node-ids)
               (temporal-causality-unique? changed-node-ids)
               (list? selected-relations) (pair? selected-relations)
               (every symbol? selected-relations)
               (memq direction '(dependents dependencies))
               (boolean? inventory-complete?))
    (error "invalid structural Impact selection"))
  (let ((node-index (make-hash-table))
        (adjacency (make-hash-table))
        (unresolved '()))
    (for-each
     (lambda (node)
       (let (id (yuanxu-graph-node-id node))
         (when (hash-get node-index id)
           (error "duplicate graph node identity" id))
         (hash-put! node-index id node)))
     (yuanxu-graph-nodes graph))
    (for-each
     (lambda (changed)
       (unless (hash-get node-index changed)
         (error "changed node is absent from graph" changed)))
     changed-node-ids)
    (for-each
     (lambda (edge)
       (let ((relation (yuanxu-graph-edge-kind edge))
             (from (yuanxu-graph-edge-from edge))
             (to (yuanxu-graph-edge-to edge)))
         (when (memq relation selected-relations)
           (if (and (hash-get node-index from) (hash-get node-index to))
             (let* ((origin (if (eq? direction 'dependents) to from))
                    (destination (if (eq? direction 'dependents) from to))
                    (neighbors (or (hash-get adjacency origin) '())))
               (hash-put! adjacency origin
                          (cons (cons destination relation) neighbors)))
             (set! unresolved
                   (cons (list from relation to) unresolved))))))
     (yuanxu-graph-edges graph))
    (let ((witness-index (make-hash-table))
          (affected-reverse '()))
      (for-each
       (lambda (changed)
         (let (witness
               (agentic-ai-lab-relation-trajectory-witness
                changed (list changed) '()))
           (hash-put! witness-index changed witness)
           (set! affected-reverse (cons changed affected-reverse))))
       changed-node-ids)
      ;; A two-list queue avoids append-based quadratic traversal.  Witness
      ;; construction cost is proportional to the paths returned to callers.
      (let loop ((front changed-node-ids) (back '()))
        (cond
         ((pair? front)
          (let* ((current (car front))
                 (parent (hash-get witness-index current))
                 (next-back back))
            (for-each
             (lambda (neighbor+relation)
               (let ((neighbor (car neighbor+relation))
                     (relation (cdr neighbor+relation)))
                 (unless (hash-get witness-index neighbor)
                   (let (witness
                         (agentic-ai-lab-relation-trajectory-witness
                          neighbor
                          (append (.ref parent 'node-path) (list neighbor))
                          (append (.ref parent 'relation-path)
                                  (list relation))))
                     (hash-put! witness-index neighbor witness)
                     (set! affected-reverse
                           (cons neighbor affected-reverse))
                     (set! next-back (cons neighbor next-back))))))
             (reverse (or (hash-get adjacency current) '())))
            (loop (cdr front) next-back)))
         ((pair? back) (loop (reverse back) '()))
         (else
          (let* ((affected (reverse affected-reverse))
                 (trajectories
                  (map (lambda (id) (hash-get witness-index id)) affected))
                 (unresolved-edges (reverse unresolved))
                 (status
                  (cond
                   ((pair? unresolved-edges) 'invalid-inventory)
                   ((not inventory-complete?) 'partial-impact)
                   (else 'snapshot-scoped-impact))))
            (agentic-ai-lab-structural-impact-receipt
             status
             (yuanxu-graph-id graph)
             changed-node-ids
             direction
             selected-relations
             affected
             trajectories
             unresolved-edges))))))))

(def (temporal-causality-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write value port))))))))

;;; A model is one finite family of candidate explanations for the same
;;; effect. Input order does not change its semantic identity. Family
;;; semantics are explicit because a unique surviving candidate only implies
;;; necessity under an exclusive, complete explanation vocabulary.
(def (agentic-ai-lab-temporal-model
      identity domains observations hypotheses family-complete?)
  (temporal-model-build identity domains observations hypotheses
                        family-complete? 'exclusive-explanations))

(def (agentic-ai-lab-temporal-overlapping-model
      identity domains observations hypotheses family-complete?)
  (temporal-model-build identity domains observations hypotheses
                        family-complete? 'overlapping-mechanisms))

(def (temporal-model-build
      identity domains observations hypotheses family-complete? semantics)
  (unless (and (string? identity) (> (string-length identity) 0)
               (list? domains) (pair? domains)
               (every agentic-ai-lab-temporal-clock-domain? domains)
               (list? observations)
               (every agentic-ai-lab-temporal-model-observation? observations)
               (list? hypotheses) (pair? hypotheses)
               (every agentic-ai-lab-temporal-hypothesis? hypotheses)
               (boolean? family-complete?))
    (error "invalid temporal model inventory" identity))
  (def (identities values)
    (map (lambda (value) (.ref value 'identity)) values))
  (unless (and (temporal-causality-unique? (identities domains))
               (temporal-causality-unique? (identities observations))
               (temporal-causality-unique? (identities hypotheses)))
    (error "duplicate temporal model identity" identity))
  (let ((domain-index (make-hash-table))
        (effect-id (.ref (car hypotheses) 'effect-observation-id)))
    (for-each (lambda (domain)
                (hash-put! domain-index (.ref domain 'identity) #t))
              domains)
    (for-each
     (lambda (observation)
       (unless (hash-get domain-index (.ref observation 'domain-identity))
         (error "temporal observation has unknown clock domain"
                (.ref observation 'identity))))
     observations)
    (unless (every (lambda (hypothesis)
                     (equal? (.ref hypothesis 'effect-observation-id) effect-id))
                   hypotheses)
      (error "temporal hypothesis family has multiple effects" identity)))
  (let* ((by-id (lambda (left right)
                  (string<? (.ref left 'identity) (.ref right 'identity))))
         (canonical-constraints
          (lambda (hypothesis)
            (map (lambda (constraint)
                   (list (.ref constraint 'identity)
                         (.ref constraint 'relation)
                         (.ref constraint 'left-observation-id)
                         (.ref constraint 'right-observation-id)))
                 (list-sort by-id (.ref hypothesis 'constraints)))))
         (digest
          (temporal-causality-digest
           (list 'agentic-ai-lab.temporal-causality.model.v2
                 identity family-complete? semantics
                 (map (lambda (domain)
                        (list (.ref domain 'identity)
                              (.ref domain 'clock-role)))
                      (list-sort by-id domains))
                 (map (lambda (observation)
                        (list (.ref observation 'identity)
                              (.ref observation 'domain-identity)
                              (.ref observation 'logical-position)
                              (.ref observation 'provenance-identity)
                              (.ref observation 'modality)))
                      (list-sort by-id observations))
                 (map (lambda (hypothesis)
                        (list (.ref hypothesis 'identity)
                              (.ref hypothesis 'cause-observation-id)
                              (.ref hypothesis 'effect-observation-id)
                              (canonical-constraints hypothesis)))
                      (list-sort by-id hypotheses))))))
    (agentic-ai-lab-temporal-model-value
     identity digest
     (list-sort by-id domains)
     (list-sort by-id observations)
     (list-sort by-id hypotheses)
     family-complete? semantics)))

(def (agentic-ai-lab-temporal-model-replay model)
  (unless (agentic-ai-lab-temporal-model? model)
    (error "invalid temporal model"))
  (let (canonical
        (temporal-model-build
         (.ref model 'identity) (.ref model 'domains)
         (.ref model 'observations) (.ref model 'hypotheses)
         (.ref model 'family-complete?) (.ref model 'family-semantics)))
    (unless (equal? (.ref canonical 'semantic-digest)
                    (.ref model 'semantic-digest))
      (error "temporal model digest mismatch"))
    canonical))

(def (temporal-model-order-status left-id right-id relation observations)
  (let ((left (hash-get observations left-id))
        (right (hash-get observations right-id)))
    (cond
     ((not (and left right)) 'unknown)
     ((not (and (eq? (.ref left 'modality) 'observed)
                (eq? (.ref right 'modality) 'observed))) 'unknown)
     ((not (equal? (.ref left 'domain-identity)
                   (.ref right 'domain-identity))) 'unknown)
     ((case relation
        ((before) (< (.ref left 'logical-position)
                     (.ref right 'logical-position)))
        ((not-after) (<= (.ref left 'logical-position)
                         (.ref right 'logical-position)))
        (else #f)) 'admitted)
     (else 'refuted))))

(def (temporal-model-hypothesis-status hypothesis observations)
  (let (statuses
        (cons
         (temporal-model-order-status
          (.ref hypothesis 'cause-observation-id)
          (.ref hypothesis 'effect-observation-id)
          'before observations)
         (map (lambda (constraint)
                (temporal-model-order-status
                 (.ref constraint 'left-observation-id)
                 (.ref constraint 'right-observation-id)
                 (.ref constraint 'relation) observations))
              (.ref hypothesis 'constraints))))
    (cond ((memq 'refuted statuses) 'refuted)
          ((memq 'unknown statuses) 'unknown)
          (else 'admitted))))

;;; Classification evaluates only the declared candidate family. Unknown and
;;; unexplored members prevent necessity; overlapping mechanisms never imply
;;; necessity even if just one member survives the finite check.
(def (agentic-ai-lab-temporal-model-classify model query)
  (unless (and (agentic-ai-lab-temporal-model? model)
               (agentic-ai-lab-temporal-query? query))
    (error "temporal model classification requires a model and query"))
  (agentic-ai-lab-temporal-model-replay model)
  (let* ((hypotheses (.ref model 'hypotheses))
         (target (.ref query 'hypothesis-identity))
         (observations (make-hash-table)))
    (unless (find (lambda (hypothesis)
                    (equal? (.ref hypothesis 'identity) target)) hypotheses)
      (error "query hypothesis is absent from temporal model" target))
    (for-each (lambda (observation)
                (hash-put! observations (.ref observation 'identity)
                           observation))
              (.ref model 'observations))
    (let loop ((remaining hypotheses) (fuel (.ref query 'exploration-limit))
               (admitted '()) (refuted '()) (unknown '()))
      (if (or (null? remaining) (and fuel (= fuel 0)))
        (let* ((admitted (reverse admitted))
               (refuted (reverse refuted))
               (unknown (reverse unknown))
               (unexplored (map (lambda (hypothesis)
                                  (.ref hypothesis 'identity)) remaining))
               (exhausted? (null? remaining))
               (classification
                (cond
                 ((member target refuted) 'refuted)
                 ((member target admitted)
                  (if (and exhausted?
                           (.ref model 'family-complete?)
                           (eq? (.ref model 'family-semantics)
                                'exclusive-explanations)
                           (null? unknown)
                           (= (length admitted) 1))
                    'necessary 'possible))
                 (else 'unknown))))
          (agentic-ai-lab-temporal-model-receipt
           model query classification admitted refuted unknown unexplored
           exhausted?))
        (let* ((hypothesis (car remaining))
               (id (.ref hypothesis 'identity))
               (status (temporal-model-hypothesis-status
                        hypothesis observations)))
          (case status
            ((admitted) (loop (cdr remaining) (and fuel (- fuel 1))
                              (cons id admitted) refuted unknown))
            ((refuted) (loop (cdr remaining) (and fuel (- fuel 1))
                             admitted (cons id refuted) unknown))
            (else (loop (cdr remaining) (and fuel (- fuel 1))
                        admitted refuted (cons id unknown)))))))))

(def (causal-event-position event)
  (.ref (.ref event 'observation) 'logical-position))

(def (causal-event<? left right)
  (let ((left-position (causal-event-position left))
        (right-position (causal-event-position right)))
    (or (< left-position right-position)
        (and (= left-position right-position)
             (string<? (.ref left 'identity) (.ref right 'identity))))))

(def (causal-event-canonical event)
  (list (.ref event 'identity)
        (.ref event 'subject)
        (.ref event 'event-kind)
        (let (observation (.ref event 'observation))
          (list (.ref observation 'identity)
                (.ref observation 'clock-role)
                (.ref observation 'logical-position)
                (.ref observation 'provenance-identity)))
        (.ref event 'payload-identity)
        (list-sort string<? (.ref event 'causal-parent-identities))
        (.ref event 'modality)
        (.ref event 'committed?)))

(def (causal-events-analyze subject events)
  (unless (and (string? subject) (> (string-length subject) 0)
               (list? events) (pair? events)
               (every agentic-ai-lab-causal-event? events))
    (error "invalid causal event subject or inventory" subject))
  (let ((event-index (make-hash-table))
        (missing-index (make-hash-table))
        (missing-reverse '())
        (violations-reverse '()))
    (for-each
     (lambda (event)
       (let (identity (.ref event 'identity))
         (unless (equal? (.ref event 'subject) subject)
           (error "causal event belongs to another subject" identity))
         (unless (temporal-causality-unique?
                  (.ref event 'causal-parent-identities))
           (error "duplicate causal parent identity" identity))
         (when (hash-get event-index identity)
           (error "duplicate causal event identity" identity))
         (hash-put! event-index identity event)))
     events)
    (for-each
     (lambda (event)
       (let ((event-identity (.ref event 'identity))
             (event-position (causal-event-position event)))
         (for-each
          (lambda (parent-identity)
            (let (parent (hash-get event-index parent-identity))
              (if parent
                ;; A causal parent must precede its child. Equal positions
                ;; also admit same-time cycles, so they cannot be qualified.
                (when (>= (causal-event-position parent) event-position)
                  (set! violations-reverse
                        (cons (list parent-identity event-identity)
                              violations-reverse)))
                (unless (hash-get missing-index parent-identity)
                  (hash-put! missing-index parent-identity #t)
                  (set! missing-reverse
                        (cons parent-identity missing-reverse))))))
          (.ref event 'causal-parent-identities))))
     events)
    (values (list-sort causal-event<? events)
            event-index
            (reverse missing-reverse)
            (reverse violations-reverse))))

(def (agentic-ai-lab-causal-event-graph subject events)
  (let-values (((ordered event-index missing violations)
                (causal-events-analyze subject events)))
    (let (identity
          (temporal-causality-digest
           (list 'agentic-ai-lab.temporal-causality.causal-event-graph.v1
                 subject
                 (map causal-event-canonical ordered))))
      (agentic-ai-lab-causal-event-graph-value
       identity subject ordered event-index missing violations))))

(def (causal-trajectory-diagnostic code identity detail)
  (list code identity detail))

(def (causal-event-parent? event parent-identity)
  (if (member parent-identity (.ref event 'causal-parent-identities)) #t #f))

(def (causal-event-parent-in? event candidate-identities)
  (if (find (lambda (identity)
              (causal-event-parent? event identity))
            candidate-identities)
    #t #f))

;;; Build adjacency once, then use a two-list queue for each multi-root walk.
;;; Assessment remains O(V + E + declared trajectory members).
(def (causal-event-adjacency event-graph)
  (let (adjacency (make-hash-table))
    (for-each
     (lambda (event)
       (for-each
        (lambda (parent)
          (hash-put! adjacency parent
                     (cons (.ref event 'identity)
                           (or (hash-get adjacency parent) '()))))
        (.ref event 'causal-parent-identities)))
     (.ref event-graph 'events))
    adjacency))

(def (causal-descendant-index adjacency roots)
  (let (visited (make-hash-table))
    (for-each (lambda (root) (hash-put! visited root #t)) roots)
    (let loop ((front roots) (back '()))
      (cond
       ((pair? front)
        (let (next-back back)
          (for-each
           (lambda (child)
             (unless (hash-get visited child)
               (hash-put! visited child #t)
               (set! next-back (cons child next-back))))
           (or (hash-get adjacency (car front)) '()))
          (loop (cdr front) next-back)))
       ((pair? back) (loop (reverse back) '()))
       (else visited)))))

(def (agentic-ai-lab-causal-trajectory-assess contract event-graph)
  (unless (agentic-ai-lab-causal-trajectory-contract? contract)
    (error "invalid causal trajectory contract" contract))
  (unless (agentic-ai-lab-causal-event-graph? event-graph)
    (error "causal trajectory requires a causal event graph" event-graph))
  (let* ((event-index (.ref event-graph 'event-index))
         (trigger-id (.ref contract 'trigger-event-id))
         (intended-ids (.ref contract 'intended-event-ids))
         (error-paths (.ref contract 'error-event-paths))
         (error-ids (apply append error-paths))
         (intended-impact-ids
          (.ref contract 'intended-impact-event-ids))
         (error-impact-ids (.ref contract 'error-impact-event-ids))
         (all-ids
          (cons trigger-id
                (append intended-ids error-ids
                        intended-impact-ids error-impact-ids)))
         (diagnostics-reverse '()))
    (def (reject! code identity detail)
      (set! diagnostics-reverse
            (cons (causal-trajectory-diagnostic code identity detail)
                  diagnostics-reverse)))
    (unless (.ref event-graph 'complete?)
      (reject! 'incomplete-event-graph
               (.ref event-graph 'identity)
               (append (.ref event-graph 'missing-parent-identities)
                       (.ref event-graph 'temporal-order-violations))))
    (for-each
     (lambda (identity)
       (unless (hash-get event-index identity)
         (reject! 'missing-trajectory-event identity 'event-graph)))
     all-ids)
    (let (trigger (hash-get event-index trigger-id))
      (when (and trigger
                 (not (and (eq? (.ref trigger 'modality) 'observed)
                           (.ref trigger 'committed?))))
        (reject! 'invalid-trigger-modality trigger-id
                 (list (.ref trigger 'modality)
                       (.ref trigger 'committed?)))))
    (for-each
     (lambda (identity)
       (let (event (hash-get event-index identity))
         (when (and event
                    (not (memq (.ref event 'modality)
                               '(observed declared derived))))
           (reject! 'invalid-intended-modality identity
                    (.ref event 'modality)))))
     intended-ids)
    (for-each
     (lambda (identity)
       (let (event (hash-get event-index identity))
         (when (and event
                    (not (and (eq? (.ref event 'modality) 'counterfactual)
                              (not (.ref event 'committed?)))))
           (reject! 'invalid-error-modality identity
                    (and event
                         (list (.ref event 'modality)
                               (.ref event 'committed?)))))))
     error-ids)
    (for-each
     (lambda (identity)
       (let (event (hash-get event-index identity))
         (when (and event
                    (not (and (eq? (.ref event 'modality) 'hypothesized)
                              (not (.ref event 'committed?)))))
           (reject! 'invalid-impact-modality identity
                    (and event
                         (list (.ref event 'modality)
                               (.ref event 'committed?)))))))
     (append intended-impact-ids error-impact-ids))
    ;; Topology checks run only when every declared member resolves.
    (when (every (lambda (identity) (hash-get event-index identity)) all-ids)
      (let ((previous trigger-id))
        (for-each
         (lambda (identity)
           (let (event (hash-get event-index identity))
             (unless (causal-event-parent? event previous)
               (reject! 'broken-intended-trajectory identity previous))
             (set! previous identity)))
         intended-ids))
      (let (branch-points (cons trigger-id intended-ids))
        (for-each
         (lambda (path)
           (let ((first (car path)) (previous #f))
             (unless (causal-event-parent-in?
                      (hash-get event-index first) branch-points)
               (reject! 'detached-error-trajectory first branch-points))
             (for-each
              (lambda (identity)
                (when previous
                  (unless (causal-event-parent?
                           (hash-get event-index identity) previous)
                    (reject! 'broken-error-trajectory identity previous)))
                (set! previous identity))
              path)))
         error-paths))
      (let* ((adjacency (causal-event-adjacency event-graph))
             (intended-descendants
              (causal-descendant-index adjacency intended-ids))
             (error-descendants
              (causal-descendant-index adjacency error-ids)))
        (for-each
         (lambda (identity)
           (unless (hash-get intended-descendants identity)
             (reject! 'detached-intended-impact identity intended-ids)))
         intended-impact-ids)
        (for-each
         (lambda (identity)
           (unless (hash-get error-descendants identity)
             (reject! 'detached-error-impact identity error-ids)))
         error-impact-ids)))
    (let ((diagnostics (reverse diagnostics-reverse)))
      (agentic-ai-lab-causal-trajectory-assessment
       (if (null? diagnostics)
         'causal-trajectory-admitted
         'causal-trajectory-rejected)
       contract event-graph diagnostics))))

;;; Stable cross-engine identity for the exact declarative trajectory and its
;;; Scheme assessment. Quint, Lean and Cedar bind this digest; none of them
;;; reconstructs a second trajectory DSL.
(def (agentic-ai-lab-causal-trajectory-assessment-digest assessment)
  (unless (agentic-ai-lab-causal-trajectory-assessment? assessment)
    (error "invalid causal trajectory assessment" assessment))
  (temporal-causality-digest
   (list 'agentic-ai-lab.temporal-causality.causal-trajectory-assessment.v1
         (.ref assessment 'status)
         (.ref assessment 'accepted?)
         (.ref assessment 'contract-identity)
         (.ref assessment 'event-graph-identity)
         (.ref assessment 'diagnostics)
         (.ref assessment 'intended-event-ids)
         (.ref assessment 'error-event-paths)
         (.ref assessment 'intended-impact-event-ids)
         (.ref assessment 'error-impact-event-ids))))

(def (agentic-ai-lab-causal-cut event-graph as-of-position)
  (unless (agentic-ai-lab-causal-event-graph? event-graph)
    (error "causal cut requires a causal event graph" event-graph))
  (unless (and (exact-integer? as-of-position) (>= as-of-position 0))
    (error "invalid causal cut position" as-of-position))
  (let (committed-events
        (filter
         (lambda (event)
           (and (.ref event 'committed?)
                (<= (causal-event-position event) as-of-position)))
         (.ref event-graph 'events)))
    (unless (pair? committed-events)
      (error "causal cut has no committed event" as-of-position))
    (let-values (((ordered event-index missing violations)
                  (causal-events-analyze
                   (.ref event-graph 'subject) committed-events)))
      (let (identity
            (temporal-causality-digest
             (list 'agentic-ai-lab.temporal-causality.causal-cut.v1
                   (.ref event-graph 'identity)
                   as-of-position
                   (map (lambda (event) (.ref event 'identity)) ordered))))
        (agentic-ai-lab-causal-cut-value
         identity
         (.ref event-graph 'identity)
         (.ref event-graph 'subject)
         ordered event-index missing violations as-of-position)))))

(def (causal-event-graph->graph event-graph)
  (let ((events (.ref event-graph 'events)))
    (yuanxu-graph
     (list 'causal-event-graph (.ref event-graph 'identity))
     (map (lambda (event)
            (yuanxu-graph-node
             (.ref event 'identity)
             event
             (list (cons 'entity-kind 'causal-event)
                   (cons 'modality (.ref event 'modality)))))
          events)
     (apply append
            (map
             (lambda (event)
               (map (lambda (parent)
                      (yuanxu-graph-edge
                       parent (.ref event 'identity) 'CAUSAL_PARENT
                       (list (cons 'modality (.ref event 'modality)))))
                    (.ref event 'causal-parent-identities)))
             events))
     (list (cons 'causal-event-graph (.ref event-graph 'identity))
           (cons 'complete? (.ref event-graph 'complete?))))))

(def (temporal-causality-ordered-union left right)
  (let ((seen (make-hash-table))
        (result-reverse '()))
    (for-each
     (lambda (value)
       (unless (hash-get seen value)
         (hash-put! seen value #t)
         (set! result-reverse (cons value result-reverse))))
     (append left right))
    (reverse result-reverse)))

(def (agentic-ai-lab-temporal-causal-classify
      event-graph cut trigger-event-id horizon)
  (unless (agentic-ai-lab-causal-event-graph? event-graph)
    (error "temporal classification requires a causal event graph"
           event-graph))
  (unless (agentic-ai-lab-causal-cut? cut)
    (error "temporal classification requires a causal cut" cut))
  (unless (equal? (.ref cut 'event-graph-identity)
                  (.ref event-graph 'identity))
    (error "causal cut belongs to another event graph" cut))
  (let (as-of-position (.ref cut 'as-of-position))
    (unless (and (exact-integer? horizon) (>= horizon as-of-position))
      (error "invalid temporal classification horizon"
             as-of-position horizon)))
  (unless (hash-get (.ref cut 'event-index) trigger-event-id)
    (error "trigger event is absent from causal cut" trigger-event-id))
  (let* ((as-of-position (.ref cut 'as-of-position))
         (graph (causal-event-graph->graph event-graph))
         (structural
          (agentic-ai-lab-structural-impact-analyze
           graph (list trigger-event-id) '(CAUSAL_PARENT) 'dependencies
           (.ref event-graph 'complete?)))
         (affected-index (make-hash-table))
         (past-reverse '())
         (current-reverse '())
         (future-reverse '())
         (hypothesized-reverse '())
         (counterfactual-reverse '())
         (outside-reverse '()))
    (for-each
     (lambda (id) (hash-put! affected-index id #t))
     (.ref structural 'affected-node-ids))
    (for-each
     (lambda (event)
       (let ((identity (.ref event 'identity))
             (position (causal-event-position event))
             (modality (.ref event 'modality)))
         (when (hash-get affected-index identity)
           (cond
           ((eq? modality 'counterfactual)
             (set! counterfactual-reverse
                   (cons identity counterfactual-reverse)))
            ((eq? modality 'hypothesized)
             (set! hypothesized-reverse
                   (cons identity hypothesized-reverse)))
            ((< position as-of-position)
             (set! past-reverse (cons identity past-reverse)))
            ((= position as-of-position)
             (set! current-reverse (cons identity current-reverse)))
            ((<= position horizon)
             (set! future-reverse (cons identity future-reverse)))
            (else
             (set! outside-reverse (cons identity outside-reverse)))))))
     (.ref event-graph 'events))
    (let ((status
           (cond
            ((or (pair? (.ref event-graph 'temporal-order-violations))
                 (pair? (.ref cut 'temporal-order-violations)))
             'invalid-causal-cut)
            ((or (pair? (.ref event-graph 'missing-parent-identities))
                 (pair? (.ref cut 'missing-parent-identities)))
             'partial-temporal-classification)
            (else 'bounded-temporal-classification))))
      (agentic-ai-lab-temporal-classification-receipt
       status
       (.ref event-graph 'identity)
       (.ref cut 'identity)
       trigger-event-id
       as-of-position
       horizon
       (reverse past-reverse)
       (reverse current-reverse)
       (reverse future-reverse)
       (reverse hypothesized-reverse)
       (reverse counterfactual-reverse)
       (reverse outside-reverse)
       (temporal-causality-ordered-union
        (.ref cut 'missing-parent-identities)
        (.ref event-graph 'missing-parent-identities))
       (.ref structural 'relation-trajectories)
       structural))))
