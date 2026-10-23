;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime-facing projection for user-interface module fragments.
;;; Invariant: runtime adapters load user fragments through the same
;;; `use-module` surface; module-specific projection remains behind this
;;; Funflow module boundary.

(import (only-in :clan/poo/object .all-slots .ref .slot? object? object<-alist)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-key)
        (only-in :agentic-ai-lab/modules/workflow/scenario/accessors
                 agentic-ai-lab-scenario-case-name
                 agentic-ai-lab-scenario-case-profiles
                 agentic-ai-lab-scenario-case-stages)
        (only-in :agentic-ai-lab/modules/workflow/scenario/case
                 agentic-ai-lab-scenario-case?)
        (only-in :yuanxu/modules/funflow/graph-projection
                 funflow-plan
                 yuanxu-funflow-plan->runtime-projection))

(export agentic-ai-lab-runtime-load-projection
        agentic-ai-lab-runtime-load-write!)

;; : (-> Alist Symbol Object)
(def (agentic-ai-lab-runtime-load-flag-ref flags key)
  (cond
   ((null? flags) #f)
   ((and (pair? (car flags))
         (eq? (caar flags) key))
    (cdar flags))
   (else
    (agentic-ai-lab-runtime-load-flag-ref (cdr flags) key))))

;; : (-> [PooObject] PooObject)
(def (agentic-ai-lab-runtime-load-first-selection selections)
  (if (pair? selections)
    (car selections)
    (error "runtime load expected use-module selection list" selections)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-runtime-load-composition? value)
  (and (object? value)
       (.slot? value 'kind)
       (agentic-ai-lab-scenario-case? value)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-runtime-load-funflow-profile? profile)
  (and (object? profile)
       (.slot? profile 'module)
       (eq? (.ref profile 'module) 'funflow)))

;; : (-> [PooObject] Boolean)
(def (agentic-ai-lab-runtime-load-has-funflow-profile? profiles)
  (cond
   ((null? profiles) #f)
   ((agentic-ai-lab-runtime-load-funflow-profile? (car profiles)) #t)
   (else
    (agentic-ai-lab-runtime-load-has-funflow-profile? (cdr profiles)))))

;; : (-> PooObject [Symbol])
(def (agentic-ai-lab-runtime-load-stage-step-names stage)
  (if (and (object? stage) (.slot? stage 'steps))
    (.all-slots (.ref stage 'steps))
    '()))

;; : (-> PooObject [Symbol])
(def (agentic-ai-lab-runtime-load-composition-step-names stage-space)
  (apply append
         (map (lambda (stage-name)
                (agentic-ai-lab-runtime-load-stage-step-names
                 (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> Symbol Alist)
(def (agentic-ai-lab-runtime-load-node-row node)
  (list (cons 'name node)
        (cons 'kind 'funflow-step)
        (cons 'runtime-executed #f)))

;; : (-> [Symbol] [Alist])
(def (agentic-ai-lab-runtime-load-node-rows nodes)
  (cond
   ((null? nodes) '())
   (else
    (cons (agentic-ai-lab-runtime-load-node-row (car nodes))
          (agentic-ai-lab-runtime-load-node-rows (cdr nodes))))))

;; : (-> [Object] Alist)
(def (agentic-ai-lab-runtime-load-edge-row edge)
  (if (and (pair? edge)
           (pair? (cdr edge))
           (null? (cddr edge))
           (symbol? (car edge))
           (symbol? (cadr edge)))
    (list (cons 'kind 'agentic-ai-lab.funflow.dag-edge)
          (cons 'from (car edge))
          (cons 'to (cadr edge))
          (cons 'runtime-executed #f))
    (error "runtime load expected edge payload shaped as (from to)" edge)))

;; : (-> [Object] [Alist])
(def (agentic-ai-lab-runtime-load-edge-rows edges)
  (cond
   ((null? edges) '())
   (else
    (cons (agentic-ai-lab-runtime-load-edge-row (car edges))
          (agentic-ai-lab-runtime-load-edge-rows (cdr edges))))))

;; : (-> PooObject [Alist])
(def (agentic-ai-lab-runtime-load-stage-edge-rows stage)
  (if (and (object? stage) (.slot? stage 'edges))
    (agentic-ai-lab-runtime-load-edge-rows
     (map (lambda (edge-name) (.ref (.ref stage 'edges) edge-name))
          (.all-slots (.ref stage 'edges))))
    '()))

;; : (-> PooObject [Alist])
(def (agentic-ai-lab-runtime-load-composition-edge-rows stage-space)
  (apply append
         (map (lambda (stage-name)
                (agentic-ai-lab-runtime-load-stage-edge-rows
                 (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> Symbol Symbol Symbol Alist)
(def (agentic-ai-lab-runtime-load-source-map-row composition-name stage-name step-name)
  (list (cons 'stage step-name)
        (cons 'source 'user-composition-funflow)
        (cons 'path
              (list 'user-composition 'funflow composition-name stage-name step-name))))

;; : (-> Symbol Symbol [Symbol] [Alist])
(def (agentic-ai-lab-runtime-load-source-map-stage-rows composition-name stage-name nodes)
  (cond
   ((null? nodes) '())
   (else
    (cons (agentic-ai-lab-runtime-load-source-map-row
           composition-name
           stage-name
           (car nodes))
          (agentic-ai-lab-runtime-load-source-map-stage-rows
           composition-name
           stage-name
           (cdr nodes))))))

;; : (-> PooObject Symbol PooObject [Alist])
(def (agentic-ai-lab-runtime-load-stage-source-map-rows composition stage-name stage)
  (agentic-ai-lab-runtime-load-source-map-stage-rows
   (agentic-ai-lab-scenario-case-name composition)
   stage-name
   (agentic-ai-lab-runtime-load-stage-step-names stage)))

;; : (-> PooObject PooObject [Alist])
(def (agentic-ai-lab-runtime-load-composition-source-map-rows composition stage-space)
  (apply append
         (map (lambda (stage-name)
                (agentic-ai-lab-runtime-load-stage-source-map-rows
                 composition stage-name (.ref stage-space stage-name)))
              (.all-slots stage-space))))

;; : (-> PooObject PooObject)
(def (agentic-ai-lab-runtime-load-composition->funflow-plan composition)
  (let* ((profiles (agentic-ai-lab-scenario-case-profiles composition))
         (_funflow-profile
          (if (agentic-ai-lab-runtime-load-has-funflow-profile? profiles)
            #t
            (error "runtime load expected a composed funflow profile"
                   profiles)))
         (stages (agentic-ai-lab-scenario-case-stages composition))
         (nodes (agentic-ai-lab-runtime-load-composition-step-names stages))
         (edge-rows (agentic-ai-lab-runtime-load-composition-edge-rows stages))
         (source-map
          (agentic-ai-lab-runtime-load-composition-source-map-rows composition
                                                            stages)))
    (object<-alist
     (list
      (cons 'kind (.ref funflow-plan 'kind))
      (cons 'schema 'yuanxu.modules.funflow.plan.v1)
      (cons 'name (agentic-ai-lab-scenario-case-name composition))
      (cons 'version 1)
      (cons 'origin 'user-composition-funflow)
      (cons 'normalized-flow (agentic-ai-lab-scenario-case-name composition))
      (cons 'node-table
            (list->vector (agentic-ai-lab-runtime-load-node-rows nodes)))
      (cons 'edge-table (list->vector edge-rows))
      (cons 'policy-table
            (vector
             (list (cons 'policy-family 'funflow)
                   (cons 'profiles
                         (map (lambda (profile) (.ref profile 'name))
                              profiles)))))
      (cons 'effect-table '#())
      (cons 'runtime-contract 'yuanxu.anyio.v1)
      (cons 'source-map source-map)
      (cons 'diagnostics '())
      (cons 'valid? #t)
      (cons 'runtime-owner "python-anyio")
      (cons 'runtime-executed #f)))))

;; : (-> PooObject Alist)
(def (agentic-ai-lab-runtime-load-composition-projection composition)
  (yuanxu-funflow-plan->runtime-projection
   (agentic-ai-lab-runtime-load-composition->funflow-plan composition)))

;; : (-> [PooObject] Alist)
(def (agentic-ai-lab-runtime-load-selection-projection selections)
  (let* ((selection (agentic-ai-lab-runtime-load-first-selection selections))
         (key (yuanxu-user-module-selection-key selection))
         (flags (yuanxu-user-module-selection-flags selection))
         (funflow-plan (agentic-ai-lab-runtime-load-flag-ref flags ':funflow-plan)))
    (cond
     (funflow-plan
      (yuanxu-funflow-plan->runtime-projection funflow-plan))
     (else
      (error "runtime load does not have a projection for module" key)))))

;; : (-> Object Alist)
(def (agentic-ai-lab-runtime-load-projection value)
  (cond
   ((agentic-ai-lab-runtime-load-composition? value)
    (agentic-ai-lab-runtime-load-composition-projection value))
   (else
    (agentic-ai-lab-runtime-load-selection-projection value))))

;; : (-> [PooObject] Void)
(def (agentic-ai-lab-runtime-load-write! selections)
  (write (agentic-ai-lab-runtime-load-projection selections))
  (newline))
