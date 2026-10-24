;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared graph algorithms remain report-only POO projections.
;;; Invariant: graph tests must not schedule, run adapters, or write state.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .def .o .ref .slot?)
        :yuanxu/graph/types
        :yuanxu/graph/algorithms)

(export graph-algorithm-test)

;; : YuanxuGraph
(def graph-algorithm-sample
  (yuanxu-graph
   'build-pipeline
   (list (yuanxu-graph-node 'build)
         (yuanxu-graph-node 'test)
         (yuanxu-graph-node 'package)
         (yuanxu-graph-node 'docs))
   (list (yuanxu-graph-edge 'build 'test)
         (yuanxu-graph-edge 'test 'package)
         (yuanxu-graph-edge 'build 'docs))))

;; : YuanxuGraph
(def graph-algorithm-cycle-sample
  (yuanxu-graph
   'cycle-sample
   (list (yuanxu-graph-node 'a)
         (yuanxu-graph-node 'b)
         (yuanxu-graph-node 'c))
   (list (yuanxu-graph-edge 'a 'b)
         (yuanxu-graph-edge 'b 'c)
         (yuanxu-graph-edge 'c 'a))))

;; : YuanxuGraph
(def graph-algorithm-self-loop-sample
  (yuanxu-graph
   'self-loop-sample
   (list (yuanxu-graph-node 'a)
         (yuanxu-graph-node 'b))
   (list (yuanxu-graph-edge 'a 'a)
         (yuanxu-graph-edge 'a 'b))))

;; Two SCCs with two concrete edges that project to one condensation edge.
(def graph-algorithm-condensation-dedup-sample
  (yuanxu-graph
   'condensation-dedup-sample
   (list (yuanxu-graph-node 'a)
         (yuanxu-graph-node 'b)
         (yuanxu-graph-node 'c)
         (yuanxu-graph-node 'd))
   (list (yuanxu-graph-edge 'a 'b)
         (yuanxu-graph-edge 'b 'a)
         (yuanxu-graph-edge 'c 'd)
         (yuanxu-graph-edge 'd 'c)
         (yuanxu-graph-edge 'a 'c)
         (yuanxu-graph-edge 'b 'd))))

;; : YuanxuGraph
(.def (graph-declarative-slot-sample @ graph)
  (graph-id 'declarative-slot-graph)
  (node-declarations =>.+
   (.o source: (yuanxu-graph-node 'source 'Source)
       target: (yuanxu-graph-node 'target 'Target)))
  (edge-declarations =>.+
   (.o source-declares-target:
       (yuanxu-graph-edge 'source 'target 'declares))))

;; : TestSuite
(def graph-algorithm-test
  (test-suite "agentic-ai-lab graph algorithms"
    (yuanxu-test-case "Graph derives algorithm values from declarative POO slots"
      (check-equal? (.slot? graph-declarative-slot-sample
                            'node-declarations)
                    #t)
      (check-equal? (yuanxu-graph-node-ids graph-declarative-slot-sample)
                    '(source target))
      (check-equal? (yuanxu-graph-edge-pairs graph-declarative-slot-sample)
                    '((source target)))
      (check-equal?
       (yuanxu-graph-nodes
        (yuanxu-graph 'declarative-slot-graph '() '()))
       '()))

    (yuanxu-test-case "projects adjacency, frontiers, reachability, and topology"
      (let ((analysis (yuanxu-graph-analysis-receipt
                       graph-algorithm-sample)))
        (check-equal? (yuanxu-graph? graph-algorithm-sample) #t)
        (check-equal? (yuanxu-graph-node-ids graph-algorithm-sample)
                      '(build test package docs))
        (check-equal? (yuanxu-graph-edge-pairs graph-algorithm-sample)
                      '((build test) (test package) (build docs)))
        (check-equal? (yuanxu-graph-outgoing-ids
                       graph-algorithm-sample
                       'build)
                      '(test docs))
        (check-equal? (yuanxu-graph-incoming-ids
                       graph-algorithm-sample
                       'package)
                      '(test))
        (check-equal? (yuanxu-graph-outgoing-map
                       graph-algorithm-sample)
                      '((build test docs)
                        (test package)
                        (package)
                        (docs)))
        (check-equal? (yuanxu-graph-incoming-map
                       graph-algorithm-sample)
                      '((build)
                        (test build)
                        (package test)
                        (docs build)))
        (check-equal? (yuanxu-graph-root-ids graph-algorithm-sample)
                      '(build))
        (check-equal? (yuanxu-graph-terminal-ids graph-algorithm-sample)
                      '(package docs))
        (check-equal? (yuanxu-graph-reachable-ids
                       graph-algorithm-sample
                       '(build))
                      '(build test docs package))
        (check-equal? (yuanxu-graph-dependency-cone
                       graph-algorithm-sample
                       '(package))
                      '(package test build))
        (check-equal? (yuanxu-graph-topological-order
                       graph-algorithm-sample)
                      '(build test docs package))
        (check-equal? (yuanxu-graph-analysis? analysis) #t)
        (check-equal? (.ref analysis 'root-ids) '(build))
        (check-equal? (.ref analysis 'terminal-ids) '(package docs))
        (check-equal? (.ref analysis 'acyclic?) #t)
        (check-equal? (.ref analysis 'runtime-executed) #f)))
    (yuanxu-test-case "detects cycle paths without producing a topological order"
      (let ((analysis (yuanxu-graph-analysis-receipt
                       graph-algorithm-cycle-sample)))
        (check-equal? (yuanxu-graph-cycle-path
                       graph-algorithm-cycle-sample)
                      '(a b c a))
        (check-equal? (yuanxu-graph-acyclic?
                       graph-algorithm-cycle-sample)
                      #f)
        (check-equal? (yuanxu-graph-topological-order
                       graph-algorithm-cycle-sample)
                      #f)
        (check-equal? (.ref analysis 'cycle-path) '(a b c a))
        (check-equal? (.ref analysis 'acyclic?) #f)
        (check-equal? (.ref analysis 'diagnostics)
                      '((cycle-path a b c a)))))
    (yuanxu-test-case "keeps indexed cycle traversal state local and deterministic"
      (check-equal? (yuanxu-graph-cycle-path
                     graph-algorithm-cycle-sample)
                    '(a b c a))
      (check-equal? (yuanxu-graph-cycle-path
                     graph-algorithm-sample)
                    #f)
      (check-equal? (yuanxu-graph-cycle-path
                     graph-algorithm-cycle-sample)
                    '(a b c a)))
    (yuanxu-test-case "emits POO loop analysis receipts for DAGs"
      (let ((analysis (yuanxu-graph-loop-analysis-receipt
                       graph-algorithm-sample)))
        (check-equal? (yuanxu-graph-loop-analysis? analysis) #t)
        (check-equal? (.ref analysis 'components)
                      '((build) (test) (package) (docs)))
        (check-equal? (.ref analysis 'cyclic-components) '())
        (check-equal? (.ref analysis 'condensation-edges)
                      '((0 1) (1 2) (0 3)))
        (check-equal? (.ref analysis 'diagnostics) '())))
    (yuanxu-test-case "emits cyclic components before condensation"
      (let ((analysis (yuanxu-graph-loop-analysis-receipt
                       graph-algorithm-cycle-sample)))
        (check-equal? (.ref analysis 'component-count) 1)
        (check-equal? (.ref analysis 'cyclic-component-count) 1)
        (check-equal? (.ref analysis 'components) '((a b c)))
        (check-equal? (.ref analysis 'cyclic-components) '((a b c)))
        (check-equal? (.ref analysis 'condensation-edges) '())
        (check-equal? (.ref analysis 'diagnostics)
                      '((cyclic-components (a b c))))))
    (yuanxu-test-case "treats self loops as cyclic singleton components"
      (let ((analysis (yuanxu-graph-loop-analysis-receipt
                       graph-algorithm-self-loop-sample)))
        (check-equal? (.ref analysis 'components) '((a) (b)))
        (check-equal? (.ref analysis 'cyclic-components) '((a)))
        (check-equal? (.ref analysis 'condensation-edges) '((0 1)))))
    (yuanxu-test-case "deduplicates projected condensation edges"
      (let ((analysis
             (yuanxu-graph-loop-analysis-receipt
              graph-algorithm-condensation-dedup-sample)))
        (check-equal? (.ref analysis 'components) '((a b) (c d)))
        (check-equal? (.ref analysis 'cyclic-components) '((a b) (c d)))
        (check-equal? (.ref analysis 'condensation-edges) '((0 1)))))))
