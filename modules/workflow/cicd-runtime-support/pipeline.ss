;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD pipeline assembly and status projection from check maps.

(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list delete-duplicates/hash)
        :core/modules/funflow/check-types
        :core/modules/funflow/check-objects
        :core/modules/funflow/check-funs
        :core/modules/funflow/projection-syntax
        :poo-flow/modules/workflow/cicd-sandbox
        :poo-flow/modules/workflow/cicd-runtime-support/checks
        :core/modules/funflow/dependency-graph)

(export poo-flow-cicd-pipeline-run-step-status
        poo-flow-cicd-pipeline-run-step-diagnostics
        poo-flow-cicd-pipeline-run-step-fields
        poo-flow-cicd-check->pipeline-run-step
        poo-flow-cicd-pipeline-run-step-summary
        poo-flow-cicd-symbol-list-unique
        poo-flow-cicd-symbols-into/rev
        poo-flow-cicd-pipeline-run-steps-diagnostics/rev
        poo-flow-cicd-pipeline-run-steps-diagnostics
        poo-flow-cicd-pipeline-run-diagnostics
        poo-flow-cicd-pipeline-run-steps-admitted?
        poo-flow-cicd-pipeline-run-status
        poo-flow-cicd-check-map->pipeline-run
        poo-flow-cicd-pipeline-run->result
        poo-flow-cicd-check-map->pipeline-result)

;; A step is admitted only when the declarative graph accepts its dependency
;; path and sandbox profile refs are resolved. This is not execution state.
;; : (-> Alist Alist Symbol Symbol)
(def (poo-flow-cicd-pipeline-run-step-status graph readiness check-name)
  (cond
   ((not (poo-flow-cicd-alist-ref graph 'valid? #f)) 'blocked)
   ((not (null? (poo-flow-cicd-alist-ref
                 readiness
                 'sandbox-unresolved-profile-refs
                 '())))
    'blocked)
   ((poo-flow-cicd-symbol-member?
     check-name
     (poo-flow-cicd-alist-ref graph 'ready-order '()))
    'admitted)
   (else 'blocked)))

;; Pipeline-run diagnostics keep graph errors and sandbox errors distinct.
;; Agents can decide whether to edit dependencies or profile bindings first.
;; : (-> Alist Alist Symbol [Symbol])
(def (poo-flow-cicd-pipeline-run-step-diagnostics graph readiness check-name)
  (let* ((diagnostics0
          (if (poo-flow-cicd-alist-ref graph 'valid? #f)
            '()
            '(blocked-dependency-graph)))
         (diagnostics1
          (if (null? (poo-flow-cicd-alist-ref
                      readiness
                      'sandbox-unresolved-profile-refs
                      '()))
            diagnostics0
            (cons 'unresolved-sandbox-profile-refs diagnostics0)))
         (diagnostics2
          (if (or (not (poo-flow-cicd-alist-ref graph 'valid? #f))
                  (poo-flow-cicd-symbol-member?
                   check-name
                   (poo-flow-cicd-alist-ref graph 'ready-order '())))
            diagnostics1
            (cons 'blocked-dependency-order diagnostics1))))
    (reverse diagnostics2)))

;; : (-> PooFlowCicdCheck Symbol Symbol [Symbol] [Symbol] Alist Alist)
(def (poo-flow-cicd-pipeline-run-step-fields check
                                              check-name
                                              status
                                              unresolved-profile-refs
                                              diagnostics
                                              readiness)
  (poo-flow-cicd-field-rows/tail
   (poo-flow-cicd-check-durable-fields check)
   (schema +poo-flow-cicd-pipeline-run-schema+)
   (kind 'poo-flow.workflow.cicd.pipeline-run-step)
   (check check-name)
   (status status)
   (handoff-ready
    (and (eq? status 'admitted)
         (null? unresolved-profile-refs)))
   (profile (poo-flow-cicd-check-profile check))
   (profile-refs (poo-flow-cicd-check-profile-refs check))
   (dependency-refs
    (poo-flow-cicd-check-dependency-refs check))
   (command (poo-flow-cicd-check-command check))
   (argv (poo-flow-cicd-check-command check))
   (runtime (poo-flow-cicd-check-runtime check))
   (result (.ref check 'result-protocol))
   (artifacts (poo-flow-cicd-check-artifacts check))
   (sandbox-unresolved-profile-refs unresolved-profile-refs)
   (diagnostics diagnostics)
   (valid? (and (eq? status 'admitted)
                (null? diagnostics)))
   (runtime-readiness readiness)
   (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
   (runtime-executed #f)))

;; : (-> PooFlowCicdCheck Alist [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check->pipeline-run-step check
                                             graph
                                             . maybe-profile-catalog)
  (poo-flow-cicd-require "pipeline run step requires a cicd check"
                         (poo-flow-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (readiness
          (poo-flow-cicd-check->runtime-manifest-readiness
           check
           profile-catalog))
         (check-name (poo-flow-cicd-check-name check))
         (status
          (poo-flow-cicd-pipeline-run-step-status
           graph
           readiness
           check-name))
         (unresolved-profile-refs
          (poo-flow-cicd-alist-ref
           readiness
           'sandbox-unresolved-profile-refs
           '()))
         (diagnostics
          (poo-flow-cicd-pipeline-run-step-diagnostics
           graph
           readiness
           check-name)))
    (poo-flow-cicd-pipeline-run-step-fields check
                                            check-name
                                            status
                                            unresolved-profile-refs
                                            diagnostics
                                            readiness)))

;; : (forall (c p) (-> [c] Alist [p] Alist))
;; : (-> [PooFlowCicdCheck] Alist [PooSandboxProfile] Alist)
(def (poo-flow-cicd-pipeline-run-step-summary checks graph profile-catalog)
  (let* ((steps
          (map (lambda (check)
                 (poo-flow-cicd-check->pipeline-run-step
                  check
                  graph
                  profile-catalog))
               checks))
         (blocked-steps-rev
          (foldl (lambda (step blocked-steps)
                   (let ((check-name (poo-flow-cicd-alist-ref step 'check #f))
                         (admitted?
                          (eq? (poo-flow-cicd-alist-ref step
                                                        'status
                                                        'blocked)
                               'admitted)))
                     (if admitted?
                       blocked-steps
                       (cons check-name blocked-steps))))
                 '()
                 steps)))
    (list
     (cons 'steps steps)
     (cons 'blocked-steps (reverse blocked-steps-rev)))))

;; : (-> [Symbol] [Symbol])
(def (poo-flow-cicd-symbol-list-unique values)
  (delete-duplicates/hash values from-end?: #t))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (poo-flow-cicd-symbols-into/rev values result)
  (cond
   ((null? values) result)
   (else
    (poo-flow-cicd-symbols-into/rev
     (cdr values)
     (cons (car values) result)))))

;; : (-> [Alist] [Symbol] [Symbol])
(def (poo-flow-cicd-pipeline-run-steps-diagnostics/rev steps diagnostics-rev)
  (cond
   ((null? steps) diagnostics-rev)
   (else
    (poo-flow-cicd-pipeline-run-steps-diagnostics/rev
     (cdr steps)
     (poo-flow-cicd-symbols-into/rev
      (poo-flow-cicd-alist-ref (car steps) 'diagnostics '())
      diagnostics-rev)))))

;; Step diagnostics are aggregated at the pipeline level so result rows can be
;; audited without traversing every step.
;; : (-> [Alist] [Symbol])
(def (poo-flow-cicd-pipeline-run-steps-diagnostics steps)
  (reverse (poo-flow-cicd-pipeline-run-steps-diagnostics/rev steps '())))

;; Pipeline diagnostics merge graph, step, and blocked-step facts into a
;; stable report-only list for user-interface and agent editing loops.
;; : (-> Alist [Alist] [Symbol] [Symbol])
(def (poo-flow-cicd-pipeline-run-diagnostics graph steps blocked-steps)
  (let* ((diagnostics0
          (poo-flow-cicd-symbols-into/rev
           (poo-flow-cicd-alist-ref graph 'diagnostics '())
           '()))
         (diagnostics1
          (poo-flow-cicd-pipeline-run-steps-diagnostics/rev
           steps
           diagnostics0))
         (diagnostics2
          (if (null? blocked-steps)
            diagnostics1
            (cons 'blocked-steps diagnostics1))))
    (poo-flow-cicd-symbol-list-unique (reverse diagnostics2))))

;; Pipeline run status is a control-plane admission result. It stays blocked
;; when graph diagnostics or sandbox refs prevent a clean Marlin handoff.
;; : (-> [Alist] Boolean)
(def (poo-flow-cicd-pipeline-run-steps-admitted? steps)
  (cond
   ((null? steps) #t)
   ((eq? (poo-flow-cicd-alist-ref (car steps) 'status 'blocked)
         'admitted)
    (poo-flow-cicd-pipeline-run-steps-admitted? (cdr steps)))
   (else #f)))

;; : (-> Alist [Alist] Symbol)
(def (poo-flow-cicd-pipeline-run-status graph steps)
  (if (and (poo-flow-cicd-alist-ref graph 'valid? #f)
           (poo-flow-cicd-pipeline-run-steps-admitted? steps))
    'admitted
    'blocked))

;; The pipeline run is the concrete, inspectable plan produced from a
;; check-map. It includes DAG order, steps, and handoff status but no output.
;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check-map->pipeline-run check-map . maybe-profile-catalog)
  (poo-flow-cicd-require "pipeline run requires a cicd check-map"
                         (poo-flow-cicd-check-map? check-map)
                         check-map)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (graph (poo-flow-cicd-check-map->dependency-graph check-map))
         (step-summary
          (poo-flow-cicd-pipeline-run-step-summary
           (poo-flow-cicd-check-map-checks check-map)
           graph
           profile-catalog))
         (steps
          (poo-flow-cicd-alist-ref step-summary 'steps '()))
         (blocked-steps
          (poo-flow-cicd-alist-ref step-summary 'blocked-steps '()))
         (status (poo-flow-cicd-pipeline-run-status graph steps))
         (diagnostics
          (poo-flow-cicd-pipeline-run-diagnostics
           graph
           steps
           blocked-steps)))
    (poo-flow-cicd-field-rows
     (schema +poo-flow-cicd-pipeline-run-schema+)
     (kind 'poo-flow.workflow.cicd.pipeline-run)
     (check-map (poo-flow-cicd-check-map-name check-map))
     (status status)
     (step-count (length steps))
     (steps steps)
     (ready-order
      (poo-flow-cicd-alist-ref graph 'ready-order '()))
     (blocked-steps blocked-steps)
     (diagnostics diagnostics)
     (dependency-graph graph)
     (handoff-required #t)
     (handoff-ready (and (eq? status 'admitted)
                         (null? diagnostics)))
     (valid? (null? diagnostics))
     (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
     (runtime-executed #f))))

;; Pipeline results summarize the projected run. They are the tutorial-facing
;; "what would this produce" surface before a runtime returns real outputs.
;; : (-> Alist Alist)
(def (poo-flow-cicd-pipeline-run->result run)
  (let* ((blocked-steps
          (poo-flow-cicd-alist-ref run 'blocked-steps '()))
         (diagnostics
          (poo-flow-cicd-alist-ref run 'diagnostics '()))
         (handoff-ready
          (and (eq? (poo-flow-cicd-alist-ref run 'status 'blocked)
                    'admitted)
               (null? diagnostics))))
    (poo-flow-cicd-field-rows
     (schema +poo-flow-cicd-pipeline-result-schema+)
     (kind 'poo-flow.workflow.cicd.pipeline-result)
     (check-map (poo-flow-cicd-alist-ref run 'check-map #f))
     (status (if handoff-ready 'handoff-ready 'blocked))
     (pipeline-run-status
      (poo-flow-cicd-alist-ref run 'status 'blocked))
     (step-count (poo-flow-cicd-alist-ref run 'step-count 0))
     (ready-order (poo-flow-cicd-alist-ref run 'ready-order '()))
     (blocked-steps blocked-steps)
     (diagnostics diagnostics)
     (valid? handoff-ready)
     (handoff-required #t)
     (handoff-ready handoff-ready)
     (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
     (runtime-executed #f))))

;; The check-map shortcut keeps callers on the public object surface when they
;; only need the result projection rather than the full run step payload.
;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check-map->pipeline-result check-map
                                                . maybe-profile-catalog)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-pipeline-run->result
     (poo-flow-cicd-check-map->pipeline-run check-map profile-catalog))))
