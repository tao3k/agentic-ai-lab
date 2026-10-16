;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: exclusive end-to-end complexity gate for graph control receipts.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :core/graph/types-core
        :core/graph/control-analysis)

(export graph-control-performance-test)

(def +graph-control-performance-fixture-path+
  "t/scenarios/performance/graph-control-linear-dag/benchmark.ss")

(def +graph-control-performance-fixture+
  (call-with-input-file +graph-control-performance-fixture-path+ read))

(def (graph-control-performance-linear-dag node-count)
  (poo-flow-graph
   'graph-control/performance
   (map poo-flow-graph-node (iota node-count))
   (map (lambda (index)
          (poo-flow-graph-edge index (+ index 1)))
        (iota (- node-count 1)))))

(def (graph-control-performance-summary graph-value)
  (let (receipt (poo-flow-graph-control-analysis-receipt graph-value))
    (list (cons 'node-count (.ref receipt 'node-count))
          (cons 'edge-count (.ref receipt 'edge-count))
          (cons 'reachable-count (length (.ref receipt 'reachable-ids)))
          (cons 'dependency-count (length (.ref receipt 'dependency-cone)))
          (cons 'diagnostic-count (length (.ref receipt 'diagnostics)))
          (cons 'runtime-executed (.ref receipt 'runtime-executed)))))

(def (graph-control-performance-ref row key)
  (cdr (assoc key row)))

(def (graph-control-performance-display-receipt receipt)
  (display "[poo-flow-benchmark] graph-control-linear-dag ")
  (write receipt)
  (newline)
  (force-output))

(def graph-control-performance-test
  (test-suite "graph control performance"
    (poo-flow-test-case "projects a 1000-node linear DAG control receipt"
      (let* ((node-count 1000)
             (graph-value
              (graph-control-performance-linear-dag node-count))
             (summary (graph-control-performance-summary graph-value))
             (receipt
              (benchmark-run
               +graph-control-performance-fixture+
               (lambda ()
                 (graph-control-performance-summary graph-value)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          +graph-control-performance-fixture+)
         #t)
        (check-equal? (graph-control-performance-ref summary 'node-count)
                      node-count)
        (check-equal? (graph-control-performance-ref summary 'edge-count)
                      (- node-count 1))
        (check-equal?
         (graph-control-performance-ref summary 'reachable-count)
         node-count)
        (check-equal?
         (graph-control-performance-ref summary 'dependency-count)
         node-count)
        (check-equal?
         (graph-control-performance-ref summary 'diagnostic-count)
         0)
        (check-equal?
         (graph-control-performance-ref summary 'runtime-executed)
         #f)
        (graph-control-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
