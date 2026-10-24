;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A pure Scheme selector for the single-node GQL syntax slice. It reads
;;; POO nodes and executes MATCH, optional property equality, and RETURN.
;;; Path joins and external source admission are outside this small API.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :yuanxu/utilities/functional
                 yuanxu-all? yuanxu-filter-map yuanxu-map)
        (only-in "types.ss" agentic-ai-lab-query?)
        (only-in "contracts.ss" agentic-ai-lab-query-source-content-identity))

(export agentic-ai-lab-query-select-scheme-nodes)

(def (projection-expressions projection)
  (if projection
    (cons (.ref projection 'expression)
          (projection-expressions (.ref projection 'next)))
    '()))

(def (agentic-ai-lab-query-select-scheme-nodes query nodes)
  (unless (and (agentic-ai-lab-query? query)
               (eq? (.ref (.ref query 'language) 'runtime-owner) 'agentic-ai-lab)
               (list? nodes) (<= (length nodes) 256)
               (yuanxu-all? object? nodes))
    (error "Scheme node selection requires a bounded Scheme GQL Query"))
  (let* ((program (.ref query 'program))
         (path (.ref program 'match))
         (start (.ref path 'start))
         (binding (.ref start 'binding))
         (predicate (.ref program 'where))
         (expressions
          (projection-expressions (.ref program 'project)))
         (properties
          (yuanxu-map (lambda (expression) (.ref expression 'property))
                        expressions)))
    (unless (and (not (.ref path 'next))
                 (yuanxu-all?
                  (lambda (expression)
                    (eq? (.ref expression 'binding) binding))
                  expressions)
                 (or (not predicate)
                     (eq? (.ref (.ref predicate 'left) 'binding)
                          binding)))
      (error "unsupported Scheme GQL syntax: expected one node"))
    (let ((rows-value
           (yuanxu-filter-map
            (lambda (node)
              (and (.slot? node 'label)
                   (eq? (.ref node 'label) (.ref start 'label))
                   (or (not predicate)
                       (let ((name (.ref (.ref predicate 'left) 'property)))
                         (and (.slot? node name)
                              (equal? (.ref node name)
                                      (.ref (.ref predicate 'right) 'value)))))
                   (begin
                     (unless (yuanxu-all?
                              (lambda (name) (.slot? node name))
                              properties)
                       (error "Scheme GQL node lacks projected property"))
                     (yuanxu-map (lambda (name) (.ref node name))
                                   properties))))
            nodes)))
      (when (> (length rows-value) (.ref query 'result-bound))
        (error "Scheme GQL result bound exceeded"))
      (.o kind: 'agentic-ai-lab.query.scheme-node-selection
          query-identity: (.ref query 'identity)
          query-source-identity:
          (agentic-ai-lab-query-source-content-identity query)
          rows: rows-value
          executed-in-scheme?: #t
          external-provenance-verified?: #f
          action-authority?: #f))))
