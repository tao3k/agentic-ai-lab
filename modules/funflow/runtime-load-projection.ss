;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime-facing projection for user-interface module fragments.
;;; Invariant: runtime adapters load user fragments through the same
;;; `use-module` surface; module-specific projection remains behind this
;;; Funflow module boundary.

(import (only-in :clan/poo/object .all-slots .ref .slot? object? object<-alist)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-flags
                 poo-flow-user-module-selection-key)
        (only-in :poo-flow/modules/workflow/scenario/accessors
                 poo-flow-scenario-case-name
                 poo-flow-scenario-case-profiles
                 poo-flow-scenario-case-stages)
        (only-in :poo-flow/modules/workflow/scenario/case
                 poo-flow-scenario-case?)
        (only-in :poo-flow/modules/funflow/config
                 funflow-plan
                 poo-flow-funflow-plan->runtime-projection))

(export poo-flow-runtime-load-projection
        poo-flow-runtime-load-write!)

;; : (-> Alist Symbol Object)
(def (poo-flow-runtime-load-flag-ref flags key)
  (cond
   ((null? flags) #f)
   ((and (pair? (car flags))
         (eq? (caar flags) key))
    (cdar flags))
   (else
    (poo-flow-runtime-load-flag-ref (cdr flags) key))))

;; : (-> [PooObject] PooObject)
(def (poo-flow-runtime-load-first-selection selections)
  (if (pair? selections)
    (car selections)
    (error "runtime load expected use-module selection list" selections)))

;; : (-> Object Boolean)
(def (poo-flow-runtime-load-composition? value)
  (and (object? value)
       (.slot? value 'kind)
       (poo-flow-scenario-case? value)))

;; : (-> Object Boolean)
(def (poo-flow-runtime-load-funflow-profile? profile)
  (and (object? profile)
       (.slot? profile 'module)
       (eq? (.ref profile 'module) 'funflow)))

;; : (-> [PooObject] Boolean)
(def (poo-flow-runtime-load-has-funflow-profile? profiles)
  (cond
   ((null? profiles) #f)
   ((poo-flow-runtime-load-funflow-profile? (car profiles)) #t)
   (else
    (poo-flow-runtime-load-has-funflow-profile? (cdr profiles)))))

;; : (-> PooObject [Symbol])
(def (poo-flow-runtime-load-stage-step-names stage)
  (if (and (object? stage) (.slot? stage 'steps))
    (.all-slots (.ref stage 'steps))
    '()))

;; : (-> PooObject [Symbol])
(def (poo-flow-runtime-load-composition-step-names stage-space)
  (apply append
         (map (lambda (stage-name)
                (poo-flow-runtime-load-stage-step-names
                 (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> Symbol Alist)
(def (poo-flow-runtime-load-node-row node)
  (list (cons 'name node)
        (cons 'kind 'funflow-step)
        (cons 'runtime-executed #f)))

;; : (-> [Symbol] [Alist])
(def (poo-flow-runtime-load-node-rows nodes)
  (cond
   ((null? nodes) '())
   (else
    (cons (poo-flow-runtime-load-node-row (car nodes))
          (poo-flow-runtime-load-node-rows (cdr nodes))))))

;; : (-> [Object] Alist)
(def (poo-flow-runtime-load-edge-row edge)
  (if (and (pair? edge)
           (pair? (cdr edge))
           (null? (cddr edge))
           (symbol? (car edge))
           (symbol? (cadr edge)))
    (list (cons 'kind 'poo-flow.funflow.dag-edge)
          (cons 'from (car edge))
          (cons 'to (cadr edge))
          (cons 'runtime-executed #f))
    (error "runtime load expected edge payload shaped as (from to)" edge)))

;; : (-> [Object] [Alist])
(def (poo-flow-runtime-load-edge-rows edges)
  (cond
   ((null? edges) '())
   (else
    (cons (poo-flow-runtime-load-edge-row (car edges))
          (poo-flow-runtime-load-edge-rows (cdr edges))))))

;; : (-> PooObject [Alist])
(def (poo-flow-runtime-load-stage-edge-rows stage)
  (if (and (object? stage) (.slot? stage 'edges))
    (poo-flow-runtime-load-edge-rows
     (map (lambda (edge-name) (.ref (.ref stage 'edges) edge-name))
          (.all-slots (.ref stage 'edges))))
    '()))

;; : (-> PooObject [Alist])
(def (poo-flow-runtime-load-composition-edge-rows stage-space)
  (apply append
         (map (lambda (stage-name)
                (poo-flow-runtime-load-stage-edge-rows
                 (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> Symbol Symbol Symbol Alist)
(def (poo-flow-runtime-load-source-map-row composition-name stage-name step-name)
  (list (cons 'stage step-name)
        (cons 'source 'user-composition-funflow)
        (cons 'path
              (list 'user-composition 'funflow composition-name stage-name step-name))))

;; : (-> Symbol Symbol [Symbol] [Alist])
(def (poo-flow-runtime-load-source-map-stage-rows composition-name stage-name nodes)
  (cond
   ((null? nodes) '())
   (else
    (cons (poo-flow-runtime-load-source-map-row
           composition-name
           stage-name
           (car nodes))
          (poo-flow-runtime-load-source-map-stage-rows
           composition-name
           stage-name
           (cdr nodes))))))

;; : (-> PooObject Symbol PooObject [Alist])
(def (poo-flow-runtime-load-stage-source-map-rows composition stage-name stage)
  (poo-flow-runtime-load-source-map-stage-rows
   (poo-flow-scenario-case-name composition)
   stage-name
   (poo-flow-runtime-load-stage-step-names stage)))

;; : (-> PooObject PooObject [Alist])
(def (poo-flow-runtime-load-composition-source-map-rows composition stage-space)
  (apply append
         (map (lambda (stage-name)
                (poo-flow-runtime-load-stage-source-map-rows
                 composition stage-name (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> PooObject PooObject)
(def (poo-flow-runtime-load-composition->funflow-plan composition)
  (let* ((profiles (poo-flow-scenario-case-profiles composition))
         (_funflow-profile
          (if (poo-flow-runtime-load-has-funflow-profile? profiles)
            #t
            (error "runtime load expected a composed funflow profile"
                   profiles)))
         (stages (poo-flow-scenario-case-stages composition))
         (nodes (poo-flow-runtime-load-composition-step-names stages))
         (edge-rows (poo-flow-runtime-load-composition-edge-rows stages))
         (source-map
          (poo-flow-runtime-load-composition-source-map-rows composition
                                                            stages)))
    (object<-alist
     (list
      (cons 'kind (.ref funflow-plan 'kind))
      (cons 'schema 'poo-flow.modules.funflow.plan.v1)
      (cons 'name (poo-flow-scenario-case-name composition))
      (cons 'version 1)
      (cons 'origin 'user-composition-funflow)
      (cons 'normalized-flow (poo-flow-scenario-case-name composition))
      (cons 'node-table
            (list->vector (poo-flow-runtime-load-node-rows nodes)))
      (cons 'edge-table (list->vector edge-rows))
      (cons 'policy-table
            (vector
             (list (cons 'policy-family 'funflow)
                   (cons 'profiles
                         (map (lambda (profile) (.ref profile 'name))
                              profiles)))))
      (cons 'effect-table '#())
      (cons 'runtime-contract 'poo-flow.anyio.v1)
      (cons 'source-map source-map)
      (cons 'diagnostics '())
      (cons 'valid? #t)
      (cons 'runtime-owner "python-anyio")
      (cons 'runtime-executed #f)))))

;; : (-> PooObject Alist)
(def (poo-flow-runtime-load-composition-projection composition)
  (poo-flow-funflow-plan->runtime-projection
   (poo-flow-runtime-load-composition->funflow-plan composition)))

;; : (-> [PooObject] Alist)
(def (poo-flow-runtime-load-selection-projection selections)
  (let* ((selection (poo-flow-runtime-load-first-selection selections))
         (key (poo-flow-user-module-selection-key selection))
         (flags (poo-flow-user-module-selection-flags selection))
         (funflow-plan (poo-flow-runtime-load-flag-ref flags ':funflow-plan)))
    (cond
     (funflow-plan
      (poo-flow-funflow-plan->runtime-projection funflow-plan))
     (else
      (error "runtime load does not have a projection for module" key)))))

;; : (-> Object Alist)
(def (poo-flow-runtime-load-projection value)
  (cond
   ((poo-flow-runtime-load-composition? value)
    (poo-flow-runtime-load-composition-projection value))
   (else
    (poo-flow-runtime-load-selection-projection value))))

;; : (-> [PooObject] Void)
(def (poo-flow-runtime-load-write! selections)
  (write (poo-flow-runtime-load-projection selections))
  (newline))
