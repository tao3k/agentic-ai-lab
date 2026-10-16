;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: indexed dependency analysis for workflow CI/CD checks.
;;; Invariant: graph algorithms emit report facts and never schedule commands.

(import (only-in :clan/poo/object .ref)
        (only-in :std/hash/misc hash-ensure-modify!)
        (only-in :std/struct/queue dequeue! enqueue! make-Queue queue-empty?)
        (only-in :core/graph/types-core
                 poo-flow-graph
                 poo-flow-graph-edge
                 poo-flow-graph-node)
        (only-in :core/graph/algorithms
                 poo-flow-graph-loop-analysis-receipt)
        (only-in :core/utilities/functional
                 poo-flow-filter-map
                 poo-flow-stable-duplicates)
        :poo-flow/modules/workflow/types
        :poo-flow/modules/workflow/objects
        :poo-flow/modules/workflow/cicd-projection-syntax)

(export poo-flow-cicd-check-map->dependency-graph)

(defstruct poo-flow-cicd-graph-index
  (node-names node-index dependents indegrees edges unresolved-rev)
  transparent: #t)

(def (poo-flow-cicd-checks-names checks)
  (map poo-flow-cicd-check-name checks))

(def (poo-flow-cicd-index-checks checks)
  (let ((node-names (poo-flow-cicd-checks-names checks))
        (node-index (make-hash-table-eq))
        (dependents (make-hash-table-eq))
        (indegrees (make-hash-table-eq)))
    (for-each
     (lambda (check)
       (let (name (poo-flow-cicd-check-name check))
         ;; First-match ownership stays deterministic when duplicate names are
         ;; later reported as invalid graph input.
         (unless (hash-key? node-index name) (hash-put! node-index name #t))
         (hash-put! indegrees name 0)))
     checks)
    (let ((edges-rev '()) (unresolved-rev '()))
      (for-each
       (lambda (check)
         (let (target (poo-flow-cicd-check-name check))
           (for-each
            (lambda (source)
              (set! edges-rev (cons (cons source target) edges-rev))
              ;; Missing sources still block the target.  They are diagnosed
              ;; below and deliberately have no dependent frontier to release.
              (hash-put! indegrees target (+ 1 (hash-get indegrees target)))
              (if (hash-key? node-index source)
                (begin
                  (hash-ensure-modify!
                   dependents source (lambda () '())
                   (lambda (values) (cons target values))))
                (set! unresolved-rev (cons source unresolved-rev))))
            (poo-flow-cicd-check-dependency-refs check))))
       checks)
      (make-poo-flow-cicd-graph-index
       node-names node-index dependents indegrees
       (reverse edges-rev) unresolved-rev))))

(def (poo-flow-cicd-index-ready-order index)
  (let ((pending (make-Queue))
        (indegrees (poo-flow-cicd-graph-index-indegrees index))
        (dependents (poo-flow-cicd-graph-index-dependents index)))
    (for-each
     (lambda (name)
       (when (zero? (hash-get indegrees name)) (enqueue! pending name)))
     (poo-flow-cicd-graph-index-node-names index))
    (let loop ((order-rev '()))
      (if (queue-empty? pending)
        (reverse order-rev)
        (let (name (dequeue! pending))
          (for-each
           (lambda (dependent)
             (let (next (- (hash-get indegrees dependent) 1))
               (hash-put! indegrees dependent next)
               (when (zero? next) (enqueue! pending dependent))))
           ;; Edges were indexed by cons; one reverse restores declaration order.
           (reverse (or (hash-get dependents name) '())))
          (loop (cons name order-rev)))))))

(def (poo-flow-cicd-index-generic-graph check-map index)
  (let ((node-index (poo-flow-cicd-graph-index-node-index index)))
    (poo-flow-graph
     (poo-flow-cicd-check-map-name check-map)
     (map (lambda (name) (poo-flow-graph-node name))
          (poo-flow-cicd-graph-index-node-names index))
     (poo-flow-filter-map
      (lambda (edge)
        (and (hash-key? node-index (car edge))
             (poo-flow-graph-edge (car edge) (cdr edge))))
      (poo-flow-cicd-graph-index-edges index)))))

(def (poo-flow-cicd-index-cycle-nodes check-map index)
  (let* ((analysis
          (poo-flow-graph-loop-analysis-receipt
           (poo-flow-cicd-index-generic-graph check-map index)))
         (cycle-index (make-hash-table-eq)))
    (for-each
     (lambda (component)
       (for-each (lambda (name) (hash-put! cycle-index name #t)) component))
     (.ref analysis 'cyclic-components))
    (poo-flow-filter-map
     (lambda (name) (and (hash-key? cycle-index name) name))
     (poo-flow-cicd-graph-index-node-names index))))

(def (poo-flow-cicd-index-edge-rows index)
  (map (lambda (edge)
         (poo-flow-cicd-field-rows (from (car edge)) (to (cdr edge))))
       (poo-flow-cicd-graph-index-edges index)))

(def (poo-flow-cicd-index-unordered-nodes index ready-order)
  (let (ready-index (make-hash-table-eq))
    (for-each (lambda (name) (hash-put! ready-index name #t)) ready-order)
    (poo-flow-filter-map
     (lambda (name) (and (not (hash-key? ready-index name)) name))
     (poo-flow-cicd-graph-index-node-names index))))

(def (poo-flow-cicd-dependency-graph-diagnostics duplicate-nodes unresolved cycle-nodes)
  (poo-flow-filter-map
   (lambda (row) (and (pair? (car row)) (cdr row)))
   (list (cons duplicate-nodes 'duplicate-nodes)
         (cons unresolved 'unresolved-dependency-refs)
         (cons cycle-nodes 'cycle-detected))))

(def (poo-flow-cicd-check-map->dependency-graph check-map)
  (poo-flow-cicd-require "cicd dependency graph requires a cicd check-map"
                         (poo-flow-cicd-check-map? check-map) check-map)
  (let* ((checks (poo-flow-cicd-check-map-checks check-map))
         (index (poo-flow-cicd-index-checks checks))
         (node-names (poo-flow-cicd-graph-index-node-names index))
         (duplicate-nodes (poo-flow-stable-duplicates node-names))
         (unresolved (reverse (poo-flow-cicd-graph-index-unresolved-rev index)))
         (cycle-nodes
          (if (null? duplicate-nodes)
            (poo-flow-cicd-index-cycle-nodes check-map index)
            '()))
         (diagnostics
          (poo-flow-cicd-dependency-graph-diagnostics
           duplicate-nodes unresolved cycle-nodes))
         (ready-order
          (if (null? duplicate-nodes)
            (poo-flow-cicd-index-ready-order index)
            '()))
         (unordered (poo-flow-cicd-index-unordered-nodes index ready-order)))
    (poo-flow-cicd-field-rows
     (kind 'poo-flow.workflow.cicd.dependency-graph)
     (check-map (poo-flow-cicd-check-map-name check-map))
     (order-policy 'declaration-topological-report)
     (nodes node-names)
     (duplicate-nodes duplicate-nodes)
     (edges (poo-flow-cicd-index-edge-rows index))
     (unresolved-dependency-refs unresolved)
     (cycle-nodes cycle-nodes)
     (ready-order ready-order)
     (unordered-nodes unordered)
     (blocked-order? (or (pair? diagnostics)
                         (not (= (length ready-order) (length node-names)))))
     (diagnostics diagnostics)
     (valid? (null? diagnostics))
     (runtime-executed #f))))
