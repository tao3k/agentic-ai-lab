;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Executable contracts for POO Search composition.

(import :std/test
        (only-in :clan/poo/object .ref)
        :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/search-engine/interface
        (only-in :agentic-ai-lab/modules/temporal-causality/funs
                 agentic-ai-lab-causal-event-graph))

(export agentic-ai-lab-search-framework-test)

(def consumer-acquisition-role
  (poo-core-role-object
   (slots ((consumer 'fixture)
           (backend-capability 'lexical-candidates)))
   (supers agentic-ai-lab-search-acquisition-role)))

(def consumer-refinement-role
  (poo-core-role-object
   (slots ((consumer 'fixture)
           (backend-capability 'rank-candidates)))
   (supers agentic-ai-lab-search-refinement-role)))

(def source-stage
  (agentic-ai-lab-search-stage 'source 'fixture-source '()
                     'workspace 'candidate-set
                     consumer-acquisition-role))

(def rank-stage
  (agentic-ai-lab-search-stage 'rank 'fixture-rank '()
                     'candidate-set 'ranked-candidate-set
                     consumer-refinement-role))

(def (raises? thunk)
  (with-catch
   (lambda (_) #t)
   (lambda () (thunk) #f)))

(def agentic-ai-lab-search-framework-test
  (test-suite "backend-neutral POO Search framework"
    (test-case "consumer roles extend the abstract POO stage roles"
      (check-equal? (.ref source-stage 'kind) 'search-stage)
      (check-equal? (.ref source-stage 'search/stage-role)
                    'acquisition)
      (check-equal? (.ref source-stage 'consumer) 'fixture)
      (check-equal? (.ref source-stage 'backend-capability)
                    'lexical-candidates))
    (test-case "factor observations reuse Agentic AI Lab temporal causality"
      (let* ((acquired
              (agentic-ai-lab-search-factor-observation
               "event-acquired" "request-one" source-stage "candidate-one"
               1 "runtime-generation-one" '() 'observed #t))
             (refined
              (agentic-ai-lab-search-factor-observation
               "event-refined" "request-one" rank-stage "candidate-one"
               2 "runtime-generation-one" '("event-acquired") 'derived #t))
             (graph
              (agentic-ai-lab-causal-event-graph
               "request-one" (list refined acquired))))
        (check-equal? (.ref acquired 'event-kind) 'source)
        (check-equal? (.ref refined 'event-kind) 'rank)
        (check-equal? (.ref graph 'complete?) #t)))
    (test-case "typed sequential composition produces an inert strategy"
      (let* ((chain (agentic-ai-lab-search-chain 'candidate-ranking
                                       (list source-stage rank-stage)))
             (strategy (agentic-ai-lab-search-strategy
                        'fixture-search chain
                        '((limit . 20) (precision-at-k . required)))))
        (check-equal? (agentic-ai-lab-search-node-input-domain chain) 'workspace)
        (check-equal? (agentic-ai-lab-search-node-output-domain chain)
                      'ranked-candidate-set)
        (check-equal? (.ref chain 'mode) 'sequential)
        (check-equal? (.ref strategy 'policy)
                      '((limit . 20) (precision-at-k . required)))
        (check-equal? (.ref strategy 'execution-owner)
                      'consumer-runtime)
        (check (pair? (.ref strategy 'dag-receipt)) => #t)))
    (test-case "mismatched sequential domains fail closed"
      (let (invalid
            (agentic-ai-lab-search-stage 'invalid 'fixture-invalid '()
                               'evidence-graph 'public-result
                               agentic-ai-lab-search-projection-role))
        (check
         (raises? (lambda ()
                    (agentic-ai-lab-search-chain 'invalid-chain
                                       (list source-stage invalid)))) => #t)))
    (test-case "parallel branches share one input domain"
      (let ((other
             (agentic-ai-lab-search-stage 'other 'fixture-other '()
                                'workspace 'structural-candidates
                                consumer-acquisition-role))
            (wrong
             (agentic-ai-lab-search-stage 'wrong 'fixture-wrong '()
                                'candidate-set 'structural-candidates
                                consumer-acquisition-role)))
        (let (parallel (agentic-ai-lab-search-parallel 'independent-candidates
                                             (list source-stage other)))
          (check-equal? (.ref parallel 'mode) 'parallel)
          (check-equal? (agentic-ai-lab-search-node-input-domain parallel) 'workspace))
        (check
         (raises? (lambda ()
                    (agentic-ai-lab-search-parallel 'invalid-parallel
                                          (list source-stage wrong)))) => #t)))
    (test-case "parallel aggregation is an explicit consumer-owned stage"
      (let* ((other
              (agentic-ai-lab-search-stage 'other 'fixture-other '()
                                 'workspace 'structural-candidates
                                 consumer-acquisition-role))
             (parallel
              (agentic-ai-lab-search-parallel 'independent-candidates
                                    (list source-stage other)))
             (merge
              (agentic-ai-lab-search-stage 'merge 'fixture-merge '()
                                 (agentic-ai-lab-search-node-output-domain parallel)
                                 'candidate-set
                                 consumer-refinement-role))
             (merged (agentic-ai-lab-search-merge 'explicit-merge parallel merge)))
        (check-equal? (.ref merged 'mode) 'merge)
        (check-equal? (agentic-ai-lab-search-node-input-domain merged) 'workspace)
        (check-equal? (agentic-ai-lab-search-node-output-domain merged) 'candidate-set)
        (check
         (raises? (lambda ()
                    (agentic-ai-lab-search-merge 'invalid-merge parallel rank-stage))) => #t)))))
