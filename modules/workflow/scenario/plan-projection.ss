;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow Scenario projection from a closed Case into its
;;; product-owned ExecutionPlan.
;;; Invariant: internal traversal records are compact structs; public Plan
;;; nodes remain owned by src/core/plan.ss.

(import (only-in :clan/poo/object .all-slots .o .ref .slot? object?)
        (only-in :gerbil/runtime/hash list->hash-table-eq)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/list/list append-map filter-map fold)
        :poo-flow/modules/workflow/control-plane/plan)

(export poo-flow-scenario-case->execution-plan)

;;; Boundary: a composition lowers into the canonical execution-plan before
;;; any consumer observes it. Bundle/WASM and future projections consume the
;;; same dependency graph rather than reinterpreting composition clauses.

(defstruct composition-plan-target (kind name clause-kind) transparent: #t)
(defstruct composition-plan-descriptor (key name kind source) transparent: #t)
(defstruct composition-plan-edge (source-key target-key) transparent: #t)
(defstruct composition-plan-state (descriptors edges) transparent: #t)
(defstruct composition-plan-stage-view (name value) transparent: #t)

;; The Gerbil hash constructor keeps the last duplicate key. Reversing the
;; source entries preserves the first declared target, stage, or binding.
(def (composition-plan-leftmost-index-by key-of values)
  (list->hash-table-eq
   (reverse (map (lambda (value) (cons (key-of value) value)) values))))

(def (composition-plan-stage-name stage)
  (composition-plan-stage-view-name stage))
(def (composition-plan-stage-target-clauses stage slot kind)
  (let (stage-value (composition-plan-stage-view-value stage))
   (if (and (object? stage-value) (.slot? stage-value slot))
    (map (lambda (target)
           (.o clause-kind: kind payload: (list target)))
         (.all-slots (.ref stage-value slot)))
    '())))
(def (composition-plan-stage-clauses stage)
  (let (stage-value (composition-plan-stage-view-value stage))
    (append
     (composition-plan-stage-target-clauses stage 'steps 'step)
     (composition-plan-stage-target-clauses stage 'handoffs 'handoff)
     (if (and (object? stage-value) (.slot? stage-value 'edges))
       (list
        (.o clause-kind: 'edges
            payload:
            (map (lambda (edge-name)
                   (.ref (.ref stage-value 'edges) edge-name))
                 (.all-slots (.ref stage-value 'edges)))))
       '()))))
(def (composition-plan-clause-kind clause) (.ref clause 'clause-kind))
(def (composition-plan-clause-payload clause) (.ref clause 'payload))

(def (composition-plan-target-clause? kind)
  (or (eq? kind 'step) (eq? kind 'handoff)))

;; : (-> PooCompositionClause PooCompositionStage HashTable HashTable MaybeTarget)
(def (composition-plan-stage-target clause stage stage-index binding-index)
  (let (kind (composition-plan-clause-kind clause))
    (if (not (composition-plan-target-clause? kind))
      #f
      (let (payload (composition-plan-clause-payload clause))
        (unless (and (pair? payload)
                     (null? (cdr payload))
                     (symbol? (car payload)))
          (error "POO-FLOW-PLAN-E101 target requires one symbol"
                 (composition-plan-stage-name stage) kind payload))
        (let (target (car payload))
          (cond
           ((hash-get stage-index target)
            (make-composition-plan-target 'case target kind))
           ((hash-get binding-index target)
            (make-composition-plan-target 'profile target kind))
           (else
            (error "POO-FLOW-PLAN-E102 unknown Case or Profile target"
                   (composition-plan-stage-name stage) kind target))))))))

(def (composition-plan-stage-targets stage stage-index binding-index)
  (filter-map
   (lambda (clause)
     (composition-plan-stage-target clause stage stage-index binding-index))
   (composition-plan-stage-clauses stage)))

(def (composition-plan-explicit-edges stage)
  (append-map
   (lambda (clause)
     (if (not (eq? (composition-plan-clause-kind clause) 'edges))
       '()
       (map
        (lambda (edge)
          (unless (and (pair? edge)
                       (pair? (cdr edge))
                       (null? (cddr edge))
                       (symbol? (car edge))
                       (symbol? (cadr edge)))
            (error "POO-FLOW-PLAN-E103 edge requires two symbols"
                   (composition-plan-stage-name stage) edge))
          (make-composition-plan-edge (car edge) (cadr edge)))
        (composition-plan-clause-payload clause))))
   (composition-plan-stage-clauses stage)))

(def (composition-plan-case-target-names stage stage-index binding-index)
  (filter-map
   (lambda (target)
     (and (eq? (composition-plan-target-kind target) 'case)
          (composition-plan-target-name target)))
   (composition-plan-stage-targets stage stage-index binding-index)))

(def (composition-plan-referenced-case-names stages stage-index binding-index)
  (delete-duplicates/hash
   (append-map
    (lambda (stage)
      (composition-plan-case-target-names stage stage-index binding-index))
    stages)
   table: (make-hash-table-eq)
   from-end?: #t))

(def (composition-plan-root-stage-names stages stage-index binding-index)
  (let* ((referenced
          (composition-plan-referenced-case-names
           stages stage-index binding-index))
         (referenced-index
          (composition-plan-leftmost-index-by
           (lambda (name) name) referenced)))
    (filter-map
     (lambda (stage)
       (let (name (composition-plan-stage-name stage))
         (and (not (hash-key? referenced-index name)) name)))
     stages)))

(def (composition-plan-path-child path name)
  (string-append path "/" (symbol->string name)))
(def (composition-plan-case-key path) (string-append "case:" path))
(def (composition-plan-profile-key path name)
  (string-append "profile:" (composition-plan-path-child path name)))

(def (composition-plan-target-key path target-index name stage-name)
  (let (target (hash-get target-index name))
    (unless target
      (error "POO-FLOW-PLAN-E104 edge endpoint is not a direct target"
             stage-name name))
    (if (eq? (composition-plan-target-kind target) 'case)
      (composition-plan-case-key (composition-plan-path-child path name))
      (composition-plan-profile-key path name))))

(def (composition-plan-stage-edges stage path targets)
  (let (target-index
        (composition-plan-leftmost-index-by
         composition-plan-target-name targets))
    (map
     (lambda (edge)
       (make-composition-plan-edge
        (composition-plan-target-key
         path target-index
         (composition-plan-edge-source-key edge)
         (composition-plan-stage-name stage))
        (composition-plan-target-key
         path target-index
         (composition-plan-edge-target-key edge)
         (composition-plan-stage-name stage))))
     (composition-plan-explicit-edges stage))))

;; Prepend a forward-ordered chunk to reversed accumulated state.  The final
;; boundary performs one reverse, avoiding quadratic append growth while
;; preserving the source traversal order.
;; : (forall (a) (-> [a] [a] [a]))
;; : (-> List List List)
(def (composition-plan-accumulate chunk reversed)
  (fold cons reversed chunk))

(def (composition-plan-build-case
      stage-name path parent-key stage-index binding-index active)
  (when (memq stage-name active)
    (error "POO-FLOW-PLAN-E105 recursive Case cycle"
           (reverse (cons stage-name active))))
  (let* ((stage (hash-get stage-index stage-name))
         (key (composition-plan-case-key path))
         (targets
          (composition-plan-stage-targets
           stage stage-index binding-index))
         (descriptor
          (make-composition-plan-descriptor
           key stage-name 'case (composition-plan-stage-view-value stage))))
    (let (descriptors+edges
          (fold
           (lambda (target state)
             (let ((descriptors (composition-plan-state-descriptors state))
                   (edges (composition-plan-state-edges state))
                   (target-kind (composition-plan-target-kind target))
                   (target-name (composition-plan-target-name target)))
               (if (eq? target-kind 'case)
                 (let (child-path
                       (composition-plan-path-child path target-name))
                   (let-values
                       (((child-descriptors child-edges)
                         (composition-plan-build-case
                          target-name child-path key stage-index binding-index
                          (cons stage-name active))))
                     (make-composition-plan-state
                      (composition-plan-accumulate
                       child-descriptors descriptors)
                      (composition-plan-accumulate child-edges edges))))
                 (let* ((binding
                         (hash-get binding-index target-name))
                        (profile-key
                         (composition-plan-profile-key path target-name))
                        (profile-descriptor
                         (make-composition-plan-descriptor
                          profile-key target-name 'profile-instance binding)))
                   (make-composition-plan-state
                    (cons profile-descriptor descriptors)
                    (cons (make-composition-plan-edge key profile-key)
                          edges))))))
           (make-composition-plan-state
            (list descriptor)
            (if parent-key
              (list (make-composition-plan-edge parent-key key))
              '()))
           targets))
      (values
       (reverse (composition-plan-state-descriptors descriptors+edges))
       (reverse
        (composition-plan-accumulate
         (composition-plan-stage-edges stage path targets)
         (composition-plan-state-edges descriptors+edges)))))))

;; : (-> [CompositionPlanDescriptor] HashTable)
(def (composition-plan-descriptor-index descriptors)
  (let (index (make-hash-table))
    (let loop ((rest descriptors) (ordinal 1))
      (unless (null? rest)
        (let (descriptor (car rest))
          (hash-put! index
                     (composition-plan-descriptor-key descriptor)
                     (cons ordinal descriptor)))
        (loop (cdr rest) (+ ordinal 1))))
    index))

;; : (-> [CompositionPlanEdge] HashTable)
(def (composition-plan-incoming-index edges)
  (let (index (make-hash-table))
    (for-each
     (lambda (edge)
       (let ((source-key (composition-plan-edge-source-key edge))
             (target-key (composition-plan-edge-target-key edge)))
         (hash-put! index target-key
                    (cons source-key (or (hash-get index target-key) '())))))
     edges)
    index))

;; : (-> Symbol HashTable String PlanNodeId)
(def (composition-plan-node-id flow-name descriptor-index key)
  (let (entry (hash-get descriptor-index key))
    (unless entry
      (error "POO-FLOW-PLAN-E106 unresolved descriptor" key))
    (let ((ordinal (car entry))
          (descriptor (cdr entry)))
      (list 'node flow-name ordinal
          (composition-plan-descriptor-kind descriptor)
          (composition-plan-descriptor-name descriptor)))))

;; : (-> Symbol HashTable HashTable String [PlanNodeId])
(def (composition-plan-dependencies
      flow-name descriptor-index incoming-index target-key)
  (map (lambda (source-key)
         (composition-plan-node-id flow-name descriptor-index source-key))
       (reverse (or (hash-get incoming-index target-key) '()))))

;; : (-> Symbol [CompositionPlanDescriptor] [CompositionPlanEdge] [PlanNode])
(def (composition-plan-make-nodes flow-name descriptors edges)
  (let ((descriptor-index (composition-plan-descriptor-index descriptors))
        (incoming-index (composition-plan-incoming-index edges)))
    (reverse
     (cdr
      (fold
       (lambda (descriptor ordinal+nodes)
         (let ((ordinal (car ordinal+nodes))
               (key (composition-plan-descriptor-key descriptor)))
           (cons
            (+ ordinal 1)
            (cons
             (make-plan-node
              (composition-plan-node-id flow-name descriptor-index key)
              ordinal
              (composition-plan-descriptor-source descriptor)
              (composition-plan-descriptor-kind descriptor)
              (composition-plan-descriptor-name descriptor)
              (composition-plan-dependencies
               flow-name descriptor-index incoming-index key))
             (cdr ordinal+nodes)))))
       (cons 1 '())
       descriptors)))))

;; : (-> PooFlowScenarioCase ExecutionPlan)
(def (poo-flow-scenario-case->execution-plan composition)
  (unless (eq? (.ref composition 'kind) 'poo-flow.scenario-case.v1)
    (error "POO-FLOW-PLAN-E100 expected poo-flow.scenario-case.v1" composition))
  (let* ((name (.ref composition 'name))
         (stage-space (.ref composition 'stages))
         (stages
          (map (lambda (stage-name)
                 (make-composition-plan-stage-view
                  stage-name (.ref stage-space stage-name)))
               (.all-slots stage-space)))
         (bindings (.ref composition 'profile-bindings))
         (stage-index
          (composition-plan-leftmost-index-by
           composition-plan-stage-name stages))
         (binding-index
          (composition-plan-leftmost-index-by
           (lambda (binding) (.ref binding 'slot)) bindings))
         (root-key (string-append "composition:" (symbol->string name)))
         (root-descriptor
          (make-composition-plan-descriptor root-key name 'composition composition))
         (roots
          (composition-plan-root-stage-names
           stages stage-index binding-index)))
    (when (null? roots)
      (error "POO-FLOW-PLAN-E107 composition has no acyclic root Case" name))
    (let (descriptors+edges
          (fold
           (lambda (root-name state)
             (let (root-path (symbol->string root-name))
               (let-values
                   (((case-descriptors case-edges)
                     (composition-plan-build-case
                      root-name root-path root-key
                      stage-index binding-index '())))
                 (make-composition-plan-state
                  (composition-plan-accumulate
                   case-descriptors
                   (composition-plan-state-descriptors state))
                  (composition-plan-accumulate
                   case-edges
                   (composition-plan-state-edges state))))))
           (make-composition-plan-state (list root-descriptor) '())
           roots))
      (make-execution-plan
       name
       (composition-plan-make-nodes
        name
        (reverse (composition-plan-state-descriptors descriptors+edges))
        (reverse (composition-plan-state-edges descriptors+edges)))
       #f
       #f))))
