;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared graph algorithms remain report-only POO projections.
;;; Invariant: graph tests must not schedule, run adapters, or write state.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .def .o .ref .slot?)
        :core/graph/types
        :core/graph/algorithms)

(export graph-algorithm-test)

;; : PooFlowGraph
(def graph-algorithm-sample
  (poo-flow-graph
   'build-pipeline
   (list (poo-flow-graph-node 'build)
         (poo-flow-graph-node 'test)
         (poo-flow-graph-node 'package)
         (poo-flow-graph-node 'docs))
   (list (poo-flow-graph-edge 'build 'test)
         (poo-flow-graph-edge 'test 'package)
         (poo-flow-graph-edge 'build 'docs))))

;; : PooFlowGraph
(def graph-algorithm-cycle-sample
  (poo-flow-graph
   'cycle-sample
   (list (poo-flow-graph-node 'a)
         (poo-flow-graph-node 'b)
         (poo-flow-graph-node 'c))
   (list (poo-flow-graph-edge 'a 'b)
         (poo-flow-graph-edge 'b 'c)
         (poo-flow-graph-edge 'c 'a))))

;; : PooFlowGraph
(def graph-algorithm-self-loop-sample
  (poo-flow-graph
   'self-loop-sample
   (list (poo-flow-graph-node 'a)
         (poo-flow-graph-node 'b))
   (list (poo-flow-graph-edge 'a 'a)
         (poo-flow-graph-edge 'a 'b))))

;; Two SCCs with two concrete edges that project to one condensation edge.
(def graph-algorithm-condensation-dedup-sample
  (poo-flow-graph
   'condensation-dedup-sample
   (list (poo-flow-graph-node 'a)
         (poo-flow-graph-node 'b)
         (poo-flow-graph-node 'c)
         (poo-flow-graph-node 'd))
   (list (poo-flow-graph-edge 'a 'b)
         (poo-flow-graph-edge 'b 'a)
         (poo-flow-graph-edge 'c 'd)
         (poo-flow-graph-edge 'd 'c)
         (poo-flow-graph-edge 'a 'c)
         (poo-flow-graph-edge 'b 'd))))

;; : PooFlowGraph
(.def (graph-declarative-slot-sample @ graph)
  (graph-id 'declarative-slot-graph)
  (node-declarations =>.+
   (.o source: (poo-flow-graph-node 'source 'Source)
       target: (poo-flow-graph-node 'target 'Target)))
  (edge-declarations =>.+
   (.o source-declares-target:
       (poo-flow-graph-edge 'source 'target 'declares))))

;; : TestSuite
(def graph-algorithm-test
  (test-suite "poo-flow graph algorithms"
    (poo-flow-test-case "Graph derives algorithm values from declarative POO slots"
      (check-equal? (.slot? graph-declarative-slot-sample
                            'node-declarations)
                    #t)
      (check-equal? (poo-flow-graph-node-ids graph-declarative-slot-sample)
                    '(source target))
      (check-equal? (poo-flow-graph-edge-pairs graph-declarative-slot-sample)
                    '((source target)))
      (check-equal?
       (poo-flow-graph-nodes
        (poo-flow-graph 'declarative-slot-graph '() '()))
       '()))

    (poo-flow-test-case "projects adjacency, frontiers, reachability, and topology"
      (let ((analysis (poo-flow-graph-analysis-receipt
                       graph-algorithm-sample)))
        (check-equal? (poo-flow-graph? graph-algorithm-sample) #t)
        (check-equal? (poo-flow-graph-node-ids graph-algorithm-sample)
                      '(build test package docs))
        (check-equal? (poo-flow-graph-edge-pairs graph-algorithm-sample)
                      '((build test) (test package) (build docs)))
        (check-equal? (poo-flow-graph-outgoing-ids
                       graph-algorithm-sample
                       'build)
                      '(test docs))
        (check-equal? (poo-flow-graph-incoming-ids
                       graph-algorithm-sample
                       'package)
                      '(test))
        (check-equal? (poo-flow-graph-outgoing-map
                       graph-algorithm-sample)
                      '((build test docs)
                        (test package)
                        (package)
                        (docs)))
        (check-equal? (poo-flow-graph-incoming-map
                       graph-algorithm-sample)
                      '((build)
                        (test build)
                        (package test)
                        (docs build)))
        (check-equal? (poo-flow-graph-root-ids graph-algorithm-sample)
                      '(build))
        (check-equal? (poo-flow-graph-terminal-ids graph-algorithm-sample)
                      '(package docs))
        (check-equal? (poo-flow-graph-reachable-ids
                       graph-algorithm-sample
                       '(build))
                      '(build test docs package))
        (check-equal? (poo-flow-graph-dependency-cone
                       graph-algorithm-sample
                       '(package))
                      '(package test build))
        (check-equal? (poo-flow-graph-topological-order
                       graph-algorithm-sample)
                      '(build test docs package))
        (check-equal? (poo-flow-graph-analysis? analysis) #t)
        (check-equal? (.ref analysis 'root-ids) '(build))
        (check-equal? (.ref analysis 'terminal-ids) '(package docs))
        (check-equal? (.ref analysis 'acyclic?) #t)
        (check-equal? (.ref analysis 'runtime-executed) #f)))
    (poo-flow-test-case "detects cycle paths without producing a topological order"
      (let ((analysis (poo-flow-graph-analysis-receipt
                       graph-algorithm-cycle-sample)))
        (check-equal? (poo-flow-graph-cycle-path
                       graph-algorithm-cycle-sample)
                      '(a b c a))
        (check-equal? (poo-flow-graph-acyclic?
                       graph-algorithm-cycle-sample)
                      #f)
        (check-equal? (poo-flow-graph-topological-order
                       graph-algorithm-cycle-sample)
                      #f)
        (check-equal? (.ref analysis 'cycle-path) '(a b c a))
        (check-equal? (.ref analysis 'acyclic?) #f)
        (check-equal? (.ref analysis 'diagnostics)
                      '((cycle-path a b c a)))))
    (poo-flow-test-case "keeps indexed cycle traversal state local and deterministic"
      (check-equal? (poo-flow-graph-cycle-path
                     graph-algorithm-cycle-sample)
                    '(a b c a))
      (check-equal? (poo-flow-graph-cycle-path
                     graph-algorithm-sample)
                    #f)
      (check-equal? (poo-flow-graph-cycle-path
                     graph-algorithm-cycle-sample)
                    '(a b c a)))
    (poo-flow-test-case "emits POO loop analysis receipts for DAGs"
      (let ((analysis (poo-flow-graph-loop-analysis-receipt
                       graph-algorithm-sample)))
        (check-equal? (poo-flow-graph-loop-analysis? analysis) #t)
        (check-equal? (.ref analysis 'components)
                      '((build) (test) (package) (docs)))
        (check-equal? (.ref analysis 'cyclic-components) '())
        (check-equal? (.ref analysis 'condensation-edges)
                      '((0 1) (1 2) (0 3)))
        (check-equal? (.ref analysis 'diagnostics) '())))
    (poo-flow-test-case "emits cyclic components before condensation"
      (let ((analysis (poo-flow-graph-loop-analysis-receipt
                       graph-algorithm-cycle-sample)))
        (check-equal? (.ref analysis 'component-count) 1)
        (check-equal? (.ref analysis 'cyclic-component-count) 1)
        (check-equal? (.ref analysis 'components) '((a b c)))
        (check-equal? (.ref analysis 'cyclic-components) '((a b c)))
        (check-equal? (.ref analysis 'condensation-edges) '())
        (check-equal? (.ref analysis 'diagnostics)
                      '((cyclic-components (a b c))))))
    (poo-flow-test-case "treats self loops as cyclic singleton components"
      (let ((analysis (poo-flow-graph-loop-analysis-receipt
                       graph-algorithm-self-loop-sample)))
        (check-equal? (.ref analysis 'components) '((a) (b)))
        (check-equal? (.ref analysis 'cyclic-components) '((a)))
        (check-equal? (.ref analysis 'condensation-edges) '((0 1)))))
    (poo-flow-test-case "deduplicates projected condensation edges"
      (let ((analysis
             (poo-flow-graph-loop-analysis-receipt
              graph-algorithm-condensation-dedup-sample)))
        (check-equal? (.ref analysis 'components) '((a b) (c d)))
        (check-equal? (.ref analysis 'cyclic-components) '((a b) (c d)))
        (check-equal? (.ref analysis 'condensation-edges) '((0 1)))))))
