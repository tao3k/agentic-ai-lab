;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A graph-free Scheme experiment: native Ascent candidate closure can revise
;;; a POO Agent society. Neither closure nor successor has MRR or Host authority.

(import (only-in :clan/poo/object .o .ref .call object?)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :agentic-ai-lab/modules/query/semantic/organization-bundle
                 agentic-ai-lab-organization-principal
                 agentic-ai-lab-organization-agent
                 agentic-ai-lab-organization-delegation
                 agentic-ai-lab-organization-context-projection
                 agentic-ai-lab-organization-organization-facet
                 agentic-ai-lab-organization-authority-facet
                 agentic-ai-lab-organization-context-facet
                 agentic-ai-lab-organization-bundle
                 agentic-ai-lab-organization-bundle?
                 agentic-ai-lab-organization-bundle-identity
                 agentic-ai-lab-organization-bundle-validate
                 agentic-ai-lab-organization-validation-accepted?))

(export agentic-ai-lab-ascent-prediction
        agentic-ai-lab-ascent-hypothesis-program
        agentic-ai-lab-ascent-hypothesis-specialize-source
        agentic-ai-lab-ascent-hypothesis-demand
        agentic-ai-lab-ascent-hypothesis-observe
        agentic-ai-lab-ascent-hypothesis-revise)

(def (valid-organization? value)
  (and (agentic-ai-lab-organization-bundle? value)
       (agentic-ai-lab-organization-validation-accepted?
        (agentic-ai-lab-organization-bundle-validate value))))

(def (source-pairs expression)
  (.call UIntTrieSet .list<- (.ref expression 'source-pairs)))

(def (agentic-ai-lab-ascent-prediction pair-value expected-value?)
  (unless (and (exact-integer? pair-value) (>= pair-value 0)
               (boolean? expected-value?))
    (error "Ascent prediction requires a pair and expected membership"))
  (.o kind: 'agentic-ai-lab.ascent-prediction.v1
      pair: pair-value
      expected-reachable?: expected-value?))

(def (prediction-projection predictions)
  (map (lambda (prediction)
         (list (.ref prediction 'pair)
               (.ref prediction 'expected-reachable?)))
       predictions))

(def (valid-prediction-projection? rows radix)
  (let loop ((remaining rows) (seen '()))
    (if (null? remaining)
      #t
      (let* ((row (car remaining))
             (pair-value (car row)))
        (and (exact-integer? pair-value)
             (<= 0 pair-value)
             (< pair-value (* radix radix))
             (boolean? (cadr row))
             (not (member pair-value seen))
             (loop (cdr remaining) (cons pair-value seen)))))))

(def (agentic-ai-lab-ascent-hypothesis-program identity-value source-id-value
                                         expression prediction-values
                                         organization-value limit-value)
  (unless (and (symbol? identity-value)
               (string? source-id-value)
               (> (string-length source-id-value) 0)
               (object? expression)
               (pair? prediction-values)
               (valid-organization? organization-value)
               (exact-integer? limit-value)
               (<= 1 limit-value 8))
    (error "Ascent hypothesis requires bounded POO inputs"))
  (let* ((radix-value (.ref expression 'radix))
         (pairs (source-pairs expression))
         (projection (prediction-projection prediction-values))
         (organization-digest-value
          (.ref (agentic-ai-lab-organization-bundle-identity organization-value)
                'digest)))
    (unless (and (exact-integer? radix-value)
                 (> radix-value 1)
                 (valid-prediction-projection? projection radix-value))
      (error "Ascent predictions must be distinct in the source radix"))
    (.o kind: 'agentic-ai-lab.ascent-hypothesis-candidate.v1
        identity: identity-value
        generation: 0
        predecessor-identity: #f
        source-identity: source-id-value
        source-pair-values: pairs
        radix: radix-value
        predictions: prediction-values
        prediction-projection: projection
        organization-digest: organization-digest-value
        max-derived-agents: limit-value
        external-effect-executed?: #f
        activation-authority?: #f
        mrr-admitted?: #f)))

;;; A source intervention here is a pure counterfactual program specialization.
;;; It neither changes the source owner nor admits a semantic result.
(def (agentic-ai-lab-ascent-hypothesis-specialize-source program source-id-value
                                                    expression organization)
  (unless (and (object? program)
               (eq? (.ref program 'kind)
                    'agentic-ai-lab.ascent-hypothesis-candidate.v1)
               (string? source-id-value)
               (> (string-length source-id-value) 0)
               (object? expression)
               (valid-organization? organization)
               (equal? (.ref (agentic-ai-lab-organization-bundle-identity organization)
                             'digest)
                       (.ref program 'organization-digest))
               (equal? (.ref expression 'radix) (.ref program 'radix)))
    (error "Ascent source specialization requires the exact candidate society"))
  (when (equal? source-id-value (.ref program 'source-identity))
    (error "Ascent source specialization requires a new source identity"))
  (let ((pairs (source-pairs expression)))
    (let* ((generation-value (+ 1 (.ref program 'generation)))
           (predecessor (.ref program 'identity)))
      (.o kind: 'agentic-ai-lab.ascent-hypothesis-candidate.v1
          identity: (list predecessor 'source-specialization
                          generation-value source-id-value pairs)
          generation: generation-value
          predecessor-identity: predecessor
          source-identity: source-id-value
          source-pair-values: pairs
          radix: (.ref program 'radix)
          predictions: (.ref program 'predictions)
          prediction-projection: (.ref program 'prediction-projection)
          organization-digest: (.ref program 'organization-digest)
          max-derived-agents: (.ref program 'max-derived-agents)
          source-specialization?: #t
          external-effect-executed?: #f
          activation-authority?: #f
          mrr-admitted?: #f))))

(def (agentic-ai-lab-ascent-hypothesis-demand program)
  (unless (and (object? program)
               (eq? (.ref program 'kind)
                    'agentic-ai-lab.ascent-hypothesis-candidate.v1))
    (error "Ascent demand requires a hypothesis program"))
  (let ((demand-id
         (list 'agentic-ai-lab.ascent-hypothesis-demand.v1
               (.ref program 'identity)
               (.ref program 'generation)
               (.ref program 'source-identity)
               (.ref program 'source-pair-values)
               (.ref program 'radix)
               (.ref program 'prediction-projection)
               (.ref program 'organization-digest)
               (.ref program 'max-derived-agents))))
    (.o kind: 'agentic-ai-lab.ascent-hypothesis-demand.v1
        identity: demand-id
        activation-authority?: #f)))

(def (derive-society base source-id generation-value failed-pairs limit)
  (let* ((organization-facet (.ref base 'organization))
         (authority-facet (.ref base 'authority))
         (context-facet (.ref base 'context))
         (agents
          (filter (lambda (value) (eq? (.ref value 'kind) 'agent))
                  (.ref organization-facet 'entities)))
         (roots (filter (lambda (value) (not (.ref value 'parent-id))) agents))
         (children (filter (lambda (value) (.ref value 'parent-id)) agents)))
    (unless (and (= (length roots) 1) (pair? children))
      (error "derived society requires a root and child template"))
    (let* ((root-id (.ref (car roots) 'id))
           (template (car children))
           (authorities (.ref template 'authorities))
           (visible (.ref template 'context-visible))
           (selected-pairs
            (let loop ((remaining failed-pairs) (index 0) (selected '()))
              (if (or (null? remaining) (= index limit))
                (reverse selected)
                (loop (cdr remaining) (+ index 1)
                      (cons (car remaining) selected)))))
           (agent-ids
            (map (lambda (pair-value)
                   (string-append "ascent-review/" source-id "/"
                                  (number->string generation-value) "/"
                                  (number->string pair-value)))
                 selected-pairs))
           (principal-ids
            (map (lambda (agent-id)
                   (string-append "principal/" agent-id))
                 agent-ids))
           (new-members
            (apply append
                   (map (lambda (agent-id principal-id)
                          (list
                           (agentic-ai-lab-organization-principal principal-id)
                           (agentic-ai-lab-organization-agent
                            agent-id principal-id (.ref template 'role-id)
                            root-id authorities visible)))
                        agent-ids principal-ids)))
           (new-delegations
            (apply append
                   (map (lambda (agent-id)
                          (map (lambda (capability-id)
                                 (agentic-ai-lab-organization-delegation
                                  root-id agent-id capability-id))
                               authorities))
                        agent-ids)))
           (new-contexts
            (map (lambda (agent-id)
                   (agentic-ai-lab-organization-context-projection agent-id visible))
                 agent-ids))
           (derived
            (agentic-ai-lab-organization-bundle
             (+ 1 (.ref base 'epoch))
             (agentic-ai-lab-organization-organization-facet
              (append (.ref organization-facet 'entities) new-members)
              (.ref organization-facet 'relations)
              (.ref organization-facet 'constraints))
             (agentic-ai-lab-organization-authority-facet
              (.ref authority-facet 'entities)
              (append (.ref authority-facet 'relations) new-delegations)
              (.ref authority-facet 'constraints))
             (agentic-ai-lab-organization-context-facet
              (append (.ref context-facet 'entities) new-contexts)
              (.ref context-facet 'constraints))
             (.ref base 'protocol)
             (.ref base 'evidence))))
      (unless (valid-organization? derived)
        (error "derived Ascent society failed Bundle validation"))
      derived)))

(def (candidate-observation-identity demand-id failed-pairs verdict)
  (list 'agentic-ai-lab.ascent-hypothesis-observation.v1
        demand-id failed-pairs verdict))

(def (agentic-ai-lab-ascent-hypothesis-observe program demand expression organization)
  (unless (and (object? program)
               (eq? (.ref program 'kind)
                    'agentic-ai-lab.ascent-hypothesis-candidate.v1)
               (object? demand)
               (eq? (.ref demand 'kind)
                    'agentic-ai-lab.ascent-hypothesis-demand.v1)
               (equal? (.ref demand 'identity)
                       (.ref (agentic-ai-lab-ascent-hypothesis-demand program)
                             'identity))
               (eq? (.ref demand 'activation-authority?) #f)
               (valid-organization? organization)
               (equal? (.ref (agentic-ai-lab-organization-bundle-identity organization)
                             'digest)
                       (.ref program 'organization-digest))
               (equal? (source-pairs expression)
                       (.ref program 'source-pair-values))
               (equal? (.ref expression 'radix) (.ref program 'radix)))
    (error "Ascent observation requires exact candidate source and society"))
  (let* ((contains? (.ref expression 'closure-contains?))
         (failures
          (filter (lambda (prediction)
                    (not (eq? (contains? (.ref prediction 'pair))
                              (.ref prediction 'expected-reachable?))))
                  (.ref program 'predictions)))
         (failed-pair-values
          (map (lambda (value) (.ref value 'pair)) failures))
         (verdict-value (if (null? failures) 'matched 'falsified)))
    (.o kind: 'agentic-ai-lab.ascent-hypothesis-observation.v1
        identity: (candidate-observation-identity
                   (.ref demand 'identity) failed-pair-values verdict-value)
        program-identity: (.ref program 'identity)
        demand-identity: (.ref demand 'identity)
        generation: (.ref program 'generation)
        source-identity: (.ref program 'source-identity)
        source-pair-values: (.ref program 'source-pair-values)
        radix: (.ref program 'radix)
        prediction-projection: (.ref program 'prediction-projection)
        organization-digest: (.ref program 'organization-digest)
        prediction-verdict: verdict-value
        failed-pairs: failed-pair-values
        external-effect-executed?: #f
        activation-authority?: #f
        mrr-admitted?: #f)))

(def (agentic-ai-lab-ascent-hypothesis-revise program demand observation organization)
  (unless (and (object? program)
               (eq? (.ref program 'kind)
                    'agentic-ai-lab.ascent-hypothesis-candidate.v1)
               (object? demand)
               (eq? (.ref demand 'kind)
                    'agentic-ai-lab.ascent-hypothesis-demand.v1)
               (equal? (.ref demand 'identity)
                       (.ref (agentic-ai-lab-ascent-hypothesis-demand program)
                             'identity))
               (object? observation)
               (eq? (.ref observation 'kind)
                    'agentic-ai-lab.ascent-hypothesis-observation.v1)
               (equal? (.ref observation 'program-identity)
                       (.ref program 'identity))
               (equal? (.ref observation 'demand-identity)
                       (.ref demand 'identity))
               (= (.ref observation 'generation)
                  (.ref program 'generation))
               (equal? (.ref observation 'source-identity)
                       (.ref program 'source-identity))
               (equal? (.ref observation 'source-pair-values)
                       (.ref program 'source-pair-values))
               (= (.ref observation 'radix) (.ref program 'radix))
               (equal? (.ref observation 'prediction-projection)
                       (.ref program 'prediction-projection))
               (eq? (.ref observation 'external-effect-executed?) #f)
               (eq? (.ref observation 'activation-authority?) #f)
               (eq? (.ref observation 'mrr-admitted?) #f)
               (valid-organization? organization)
               (equal? (.ref (agentic-ai-lab-organization-bundle-identity organization)
                             'digest)
                       (.ref observation 'organization-digest))
               (equal? (.ref observation 'organization-digest)
                       (.ref program 'organization-digest)))
    (error "Ascent revision requires an exact candidate observation"))
  (let* ((failed-pair-values (.ref observation 'failed-pairs))
         (predicted-pairs (map car (.ref program 'prediction-projection)))
         (ordered-failures
          (filter (lambda (pair-value) (member pair-value failed-pair-values))
                  predicted-pairs)))
    (unless (and (list? failed-pair-values)
                 (equal? failed-pair-values ordered-failures)
                 (eq? (.ref observation 'prediction-verdict)
                      (if (null? failed-pair-values) 'matched 'falsified))
                 (equal? (.ref observation 'identity)
                         (candidate-observation-identity
                          (.ref demand 'identity) failed-pair-values
                          (.ref observation 'prediction-verdict))))
      (error "Ascent observation failures must match predicted pairs"))
    (let* ((next-generation (+ 1 (.ref program 'generation)))
         (source-id (.ref program 'source-identity))
         (selected-organization
          (if (null? failed-pair-values)
            organization
            (derive-society organization source-id next-generation
                            failed-pair-values
                            (.ref program 'max-derived-agents))))
         (selected-digest
          (.ref (agentic-ai-lab-organization-bundle-identity selected-organization)
                'digest))
         (predecessor (.ref program 'identity))
         (source-values (.ref program 'source-pair-values))
         (radix-value (.ref program 'radix))
         (prediction-values (.ref program 'predictions))
         (prediction-rows (.ref program 'prediction-projection))
         (limit-value (.ref program 'max-derived-agents))
         (observation-id (.ref observation 'identity))
         (verdict-value (.ref observation 'prediction-verdict)))
      (values
       (.o kind: 'agentic-ai-lab.ascent-hypothesis-candidate.v1
           identity: (list predecessor next-generation observation-id)
           generation: next-generation
           predecessor-identity: predecessor
           cause-observation-identity: observation-id
           source-identity: source-id
           source-pair-values: source-values
           radix: radix-value
           predictions: prediction-values
           prediction-projection: prediction-rows
           prediction-verdict: verdict-value
           failed-pairs: failed-pair-values
           organization-digest: selected-digest
           max-derived-agents: limit-value
           external-effect-executed?: #f
           activation-authority?: #f
           mrr-admitted?: #f)
       selected-organization))))
