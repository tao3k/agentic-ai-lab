;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: graph objects expose native POO Type/Contract descriptors.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

;; : (-> AgenticAILabGraphExpr AgenticAILabGraphValue)
(def (graph-eval expr)
  (eval expr))

;; : (-> Alist Symbol Object Object)
(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;; : (-> Alist [Symbol])
(def (contract-slot-names row)
  (map (lambda (slot-row)
         (alist-ref/default slot-row 'slot #f))
       (alist-ref/default row 'slots '())))

(export graph-native-type-contract-test)

(def graph-native-type-contract-test
  (test-suite "graph-native-type-contract-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import "./core/graph/types.ss"))
      (eval '(import "./core/graph/algorithms.ss"))
      (eval '(import :clan/poo/mop :clan/poo/object))
      (let (node-row
      (graph-eval '(yuanxu-graph-node-type-contract->alist)))
  (unless (and (eq? (alist-ref/default node-row 'object-kind #f)
                    'YuanxuGraphNode)
               (equal? (contract-slot-names node-row)
                       '(id payload metadata)))
    (error "graph node contract should expose node slots")))

(let (edge-row
      (graph-eval '(yuanxu-graph-edge-type-contract->alist)))
  (unless (and (eq? (alist-ref/default edge-row 'object-kind #f)
                    'YuanxuGraphEdge)
               (equal? (contract-slot-names edge-row)
                       '(from to edge-kind metadata)))
    (error "graph edge contract should expose edge slots")))

(unless (graph-eval
         '(and (element? Type YuanxuGraphEdgeContract)
               (element? YuanxuGraphEdgeContract
                         (yuanxu-graph-edge 'start 'finish))))
  (error "graph edge contract should be a native Type and admit valid edges"))

(when (graph-eval
       '(element?
         YuanxuGraphEdgeContract
         (object<-alist
          (list
           (cons 'kind +yuanxu-graph-edge-prototype-kind+)
           (cons 'schema 'yuanxu.graph.edge.v1)
           (cons 'from 'start)
           (cons 'to 'finish)
           (cons 'edge-kind "not-a-symbol")
           (cons 'metadata '())
           (cons 'runtime-executed #f)))))
  (error "native graph edge contract should reject an invalid slot type"))

(let (graph-row
      (graph-eval '(yuanxu-graph-type-contract->alist)))
  (unless (and (eq? (alist-ref/default graph-row 'object-kind #f)
                    'YuanxuGraph)
               (equal? (contract-slot-names graph-row)
                       '(graph-id nodes edges metadata)))
    (error "graph contract should expose aggregate slots")))

(when (graph-eval
       '(with-catch
         (lambda (_failure) #f)
         (lambda ()
           (yuanxu-graph-edge 'a 'b "not-a-symbol")
           #t)))
  (error "graph edge constructor should reject non-symbol edge kinds"))

(def analysis
  (graph-eval
   '(yuanxu-graph-analysis-receipt
     (yuanxu-graph
      'graph-contract-test
      (list (yuanxu-graph-node 'start)
            (yuanxu-graph-node 'finish))
      (list (yuanxu-graph-edge 'start 'finish))))))

(unless (graph-eval `(yuanxu-graph-analysis? ',analysis))
  (error "graph analysis receipt should be a graph analysis object"))

(let (analysis-row
      (graph-eval '(yuanxu-graph-analysis-type-contract->alist)))
  (unless (and (eq? (alist-ref/default analysis-row 'object-kind #f)
                    'YuanxuGraphAnalysis)
               (member 'diagnostics (contract-slot-names analysis-row)))
    (error "graph analysis contract should expose analysis slots"))))))
