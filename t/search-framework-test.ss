;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Executable contracts for POO Search composition.

(import :std/test
        (only-in :clan/poo/object .ref)
        :core/object-family/role-syntax
        :poo-flow/modules/search-engine/interface
        (only-in :poo-flow/modules/temporal-causality/funs
                 poo-flow-causal-event-graph))

(export poo-flow-search-framework-test)

(def consumer-acquisition-role
  (poo-core-role-object
   (slots ((consumer 'fixture)
           (backend-capability 'lexical-candidates)))
   (supers poo-flow-search-acquisition-role)))

(def consumer-refinement-role
  (poo-core-role-object
   (slots ((consumer 'fixture)
           (backend-capability 'rank-candidates)))
   (supers poo-flow-search-refinement-role)))

(def source-stage
  (poo-flow-search-stage 'source 'fixture-source '()
                     'workspace 'candidate-set
                     consumer-acquisition-role))

(def rank-stage
  (poo-flow-search-stage 'rank 'fixture-rank '()
                     'candidate-set 'ranked-candidate-set
                     consumer-refinement-role))

(def (raises? thunk)
  (with-catch
   (lambda (_) #t)
   (lambda () (thunk) #f)))

(def poo-flow-search-framework-test
  (test-suite "backend-neutral POO Search framework"
    (test-case "consumer roles extend the abstract POO stage roles"
      (check-equal? (.ref source-stage 'kind) 'search-stage)
      (check-equal? (.ref source-stage 'search/stage-role)
                    'acquisition)
      (check-equal? (.ref source-stage 'consumer) 'fixture)
      (check-equal? (.ref source-stage 'backend-capability)
                    'lexical-candidates))
    (test-case "factor observations reuse POO Flow temporal causality"
      (let* ((acquired
              (poo-flow-search-factor-observation
               "event-acquired" "request-one" source-stage "candidate-one"
               1 "runtime-generation-one" '() 'observed #t))
             (refined
              (poo-flow-search-factor-observation
               "event-refined" "request-one" rank-stage "candidate-one"
               2 "runtime-generation-one" '("event-acquired") 'derived #t))
             (graph
              (poo-flow-causal-event-graph
               "request-one" (list refined acquired))))
        (check-equal? (.ref acquired 'event-kind) 'source)
        (check-equal? (.ref refined 'event-kind) 'rank)
        (check-equal? (.ref graph 'complete?) #t)))
    (test-case "typed sequential composition produces an inert strategy"
      (let* ((chain (poo-flow-search-chain 'candidate-ranking
                                       (list source-stage rank-stage)))
             (strategy (poo-flow-search-strategy
                        'fixture-search chain
                        '((limit . 20) (precision-at-k . required)))))
        (check-equal? (poo-flow-search-node-input-domain chain) 'workspace)
        (check-equal? (poo-flow-search-node-output-domain chain)
                      'ranked-candidate-set)
        (check-equal? (.ref chain 'mode) 'sequential)
        (check-equal? (.ref strategy 'policy)
                      '((limit . 20) (precision-at-k . required)))
        (check-equal? (.ref strategy 'execution-owner)
                      'consumer-runtime)
        (check (pair? (.ref strategy 'dag-receipt)) => #t)))
    (test-case "mismatched sequential domains fail closed"
      (let (invalid
            (poo-flow-search-stage 'invalid 'fixture-invalid '()
                               'evidence-graph 'public-result
                               poo-flow-search-projection-role))
        (check
         (raises? (lambda ()
                    (poo-flow-search-chain 'invalid-chain
                                       (list source-stage invalid)))) => #t)))
    (test-case "parallel branches share one input domain"
      (let ((other
             (poo-flow-search-stage 'other 'fixture-other '()
                                'workspace 'structural-candidates
                                consumer-acquisition-role))
            (wrong
             (poo-flow-search-stage 'wrong 'fixture-wrong '()
                                'candidate-set 'structural-candidates
                                consumer-acquisition-role)))
        (let (parallel (poo-flow-search-parallel 'independent-candidates
                                             (list source-stage other)))
          (check-equal? (.ref parallel 'mode) 'parallel)
          (check-equal? (poo-flow-search-node-input-domain parallel) 'workspace))
        (check
         (raises? (lambda ()
                    (poo-flow-search-parallel 'invalid-parallel
                                          (list source-stage wrong)))) => #t)))
    (test-case "parallel aggregation is an explicit consumer-owned stage"
      (let* ((other
              (poo-flow-search-stage 'other 'fixture-other '()
                                 'workspace 'structural-candidates
                                 consumer-acquisition-role))
             (parallel
              (poo-flow-search-parallel 'independent-candidates
                                    (list source-stage other)))
             (merge
              (poo-flow-search-stage 'merge 'fixture-merge '()
                                 (poo-flow-search-node-output-domain parallel)
                                 'candidate-set
                                 consumer-refinement-role))
             (merged (poo-flow-search-merge 'explicit-merge parallel merge)))
        (check-equal? (.ref merged 'mode) 'merge)
        (check-equal? (poo-flow-search-node-input-domain merged) 'workspace)
        (check-equal? (poo-flow-search-node-output-domain merged) 'candidate-set)
        (check
         (raises? (lambda ()
                    (poo-flow-search-merge 'invalid-merge parallel rank-stage))) => #t)))))
