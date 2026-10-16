;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: end-to-end complexity gate for the shared graph algorithms.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :core/graph/types
        :core/graph/algorithms)

(export graph-algorithm-performance-test)

(def graph-algorithm-performance-fixture-path
  "t/scenarios/performance/graph-analysis-linear-dag/benchmark.ss")

(def graph-algorithm-performance-fixture
  (call-with-input-file graph-algorithm-performance-fixture-path read))

(def (graph-algorithm-performance-linear-dag node-count)
  (poo-flow-graph
   'graph-analysis/performance
   (map poo-flow-graph-node (iota node-count))
   (map (lambda (index)
          (poo-flow-graph-edge index (+ index 1)))
        (iota (- node-count 1)))))

(def (graph-algorithm-performance-summary graph-value)
  (let-values (((receipt loop-receipt)
                (poo-flow-graph-analysis-receipts graph-value)))
    (list (cons 'node-count (.ref receipt 'node-count))
          (cons 'edge-count (.ref receipt 'edge-count))
          (cons 'root-ids (.ref receipt 'root-ids))
          (cons 'terminal-ids (.ref receipt 'terminal-ids))
          (cons 'reachable-count (length (.ref receipt 'reachable-ids)))
          (cons 'dependency-count (length (.ref receipt 'dependency-cone)))
          (cons 'topological-count
                (length (.ref receipt 'topological-order)))
          (cons 'component-count (.ref loop-receipt 'component-count))
          (cons 'condensation-edge-count
                (length (.ref loop-receipt 'condensation-edges)))
          (cons 'acyclic? (.ref receipt 'acyclic?))
          (cons 'runtime-executed (.ref receipt 'runtime-executed)))))

(def (graph-algorithm-performance-ref row key)
  (cdr (assoc key row)))

(def (graph-algorithm-performance-display-receipt receipt)
  (display "[poo-flow-benchmark] graph-analysis-linear-dag ")
  (write receipt)
  (newline)
  (force-output))

(def graph-algorithm-performance-test
  (test-suite "graph algorithm performance"
    (poo-flow-test-case "analyzes and condenses a 1000-node linear DAG"
      (let* ((node-count 1000)
             (graph-value
              (graph-algorithm-performance-linear-dag node-count))
             (summary (graph-algorithm-performance-summary graph-value))
             (receipt
              (benchmark-run
               graph-algorithm-performance-fixture
               (lambda ()
                 (graph-algorithm-performance-summary graph-value)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          graph-algorithm-performance-fixture)
         #t)
        (check-equal? (graph-algorithm-performance-ref summary 'node-count)
                      node-count)
        (check-equal? (graph-algorithm-performance-ref summary 'edge-count)
                      (- node-count 1))
        (check-equal? (graph-algorithm-performance-ref summary 'root-ids) '(0))
        (check-equal? (graph-algorithm-performance-ref summary 'terminal-ids)
                      (list (- node-count 1)))
        (check-equal?
         (graph-algorithm-performance-ref summary 'reachable-count)
         node-count)
        (check-equal?
         (graph-algorithm-performance-ref summary 'dependency-count)
         node-count)
        (check-equal?
         (graph-algorithm-performance-ref summary 'topological-count)
         node-count)
        (check-equal?
         (graph-algorithm-performance-ref summary 'component-count)
         node-count)
        (check-equal?
         (graph-algorithm-performance-ref summary 'condensation-edge-count)
         (- node-count 1))
        (check-equal? (graph-algorithm-performance-ref summary 'acyclic?) #t)
        (check-equal?
         (graph-algorithm-performance-ref summary 'runtime-executed)
         #f)
        (graph-algorithm-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
