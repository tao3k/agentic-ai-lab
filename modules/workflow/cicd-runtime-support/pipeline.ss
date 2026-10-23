;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD pipeline assembly and status projection from check maps.

(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list delete-duplicates/hash)
        :yuanxu/modules/funflow/check-types
        :yuanxu/modules/funflow/check-objects
        :yuanxu/modules/funflow/check-funs
        :yuanxu/modules/funflow/projection-syntax
        :agentic-ai-lab/modules/workflow/cicd-sandbox
        :agentic-ai-lab/modules/workflow/cicd-runtime-support/checks
        :yuanxu/modules/funflow/dependency-graph)

(export agentic-ai-lab-cicd-pipeline-run-step-status
        agentic-ai-lab-cicd-pipeline-run-step-diagnostics
        agentic-ai-lab-cicd-pipeline-run-step-fields
        agentic-ai-lab-cicd-check->pipeline-run-step
        agentic-ai-lab-cicd-pipeline-run-step-summary
        agentic-ai-lab-cicd-symbol-list-unique
        agentic-ai-lab-cicd-symbols-into/rev
        agentic-ai-lab-cicd-pipeline-run-steps-diagnostics/rev
        agentic-ai-lab-cicd-pipeline-run-steps-diagnostics
        agentic-ai-lab-cicd-pipeline-run-diagnostics
        agentic-ai-lab-cicd-pipeline-run-steps-admitted?
        agentic-ai-lab-cicd-pipeline-run-status
        agentic-ai-lab-cicd-check-map->pipeline-run
        agentic-ai-lab-cicd-pipeline-run->result
        agentic-ai-lab-cicd-check-map->pipeline-result)

;; A step is admitted only when the declarative graph accepts its dependency
;; path and sandbox profile refs are resolved. This is not execution state.
;; : (-> Alist Alist Symbol Symbol)
(def (agentic-ai-lab-cicd-pipeline-run-step-status graph readiness check-name)
  (cond
   ((not (yuanxu-cicd-alist-ref graph 'valid? #f)) 'blocked)
   ((not (null? (yuanxu-cicd-alist-ref
                 readiness
                 'sandbox-unresolved-profile-refs
                 '())))
    'blocked)
   ((yuanxu-cicd-symbol-member?
     check-name
     (yuanxu-cicd-alist-ref graph 'ready-order '()))
    'admitted)
   (else 'blocked)))

;; Pipeline-run diagnostics keep graph errors and sandbox errors distinct.
;; Agents can decide whether to edit dependencies or profile bindings first.
;; : (-> Alist Alist Symbol [Symbol])
(def (agentic-ai-lab-cicd-pipeline-run-step-diagnostics graph readiness check-name)
  (let* ((diagnostics0
          (if (yuanxu-cicd-alist-ref graph 'valid? #f)
            '()
            '(blocked-dependency-graph)))
         (diagnostics1
          (if (null? (yuanxu-cicd-alist-ref
                      readiness
                      'sandbox-unresolved-profile-refs
                      '()))
            diagnostics0
            (cons 'unresolved-sandbox-profile-refs diagnostics0)))
         (diagnostics2
          (if (or (not (yuanxu-cicd-alist-ref graph 'valid? #f))
                  (yuanxu-cicd-symbol-member?
                   check-name
                   (yuanxu-cicd-alist-ref graph 'ready-order '())))
            diagnostics1
            (cons 'blocked-dependency-order diagnostics1))))
    (reverse diagnostics2)))

;; : (-> YuanxuCicdCheck Symbol Symbol [Symbol] [Symbol] Alist Alist)
(def (agentic-ai-lab-cicd-pipeline-run-step-fields check
                                              check-name
                                              status
                                              unresolved-profile-refs
                                              diagnostics
                                              readiness)
  (yuanxu-cicd-field-rows/tail
   (agentic-ai-lab-cicd-check-durable-fields check)
   (schema +yuanxu-cicd-pipeline-run-schema+)
   (kind 'agentic-ai-lab.workflow.cicd.pipeline-run-step)
   (check check-name)
   (status status)
   (handoff-ready
    (and (eq? status 'admitted)
         (null? unresolved-profile-refs)))
   (profile (yuanxu-cicd-check-profile check))
   (profile-refs (agentic-ai-lab-cicd-check-profile-refs check))
   (dependency-refs
    (yuanxu-cicd-check-dependency-refs check))
   (command (yuanxu-cicd-check-command check))
   (argv (yuanxu-cicd-check-command check))
   (runtime (yuanxu-cicd-check-runtime check))
   (result (.ref check 'result-protocol))
   (artifacts (yuanxu-cicd-check-artifacts check))
   (sandbox-unresolved-profile-refs unresolved-profile-refs)
   (diagnostics diagnostics)
   (valid? (and (eq? status 'admitted)
                (null? diagnostics)))
   (runtime-readiness readiness)
   (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
   (runtime-executed #f)))

;; : (-> YuanxuCicdCheck Alist [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check->pipeline-run-step check
                                             graph
                                             . maybe-profile-catalog)
  (yuanxu-cicd-require "pipeline run step requires a cicd check"
                         (yuanxu-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (readiness
          (agentic-ai-lab-cicd-check->runtime-manifest-readiness
           check
           profile-catalog))
         (check-name (yuanxu-cicd-check-name check))
         (status
          (agentic-ai-lab-cicd-pipeline-run-step-status
           graph
           readiness
           check-name))
         (unresolved-profile-refs
          (yuanxu-cicd-alist-ref
           readiness
           'sandbox-unresolved-profile-refs
           '()))
         (diagnostics
          (agentic-ai-lab-cicd-pipeline-run-step-diagnostics
           graph
           readiness
           check-name)))
    (agentic-ai-lab-cicd-pipeline-run-step-fields check
                                            check-name
                                            status
                                            unresolved-profile-refs
                                            diagnostics
                                            readiness)))

;; : (forall (c p) (-> [c] Alist [p] Alist))
;; : (-> [YuanxuCicdCheck] Alist [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-pipeline-run-step-summary checks graph profile-catalog)
  (let* ((steps
          (map (lambda (check)
                 (agentic-ai-lab-cicd-check->pipeline-run-step
                  check
                  graph
                  profile-catalog))
               checks))
         (blocked-steps-rev
          (foldl (lambda (step blocked-steps)
                   (let ((check-name (yuanxu-cicd-alist-ref step 'check #f))
                         (admitted?
                          (eq? (yuanxu-cicd-alist-ref step
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
(def (agentic-ai-lab-cicd-symbol-list-unique values)
  (delete-duplicates/hash values from-end?: #t))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-cicd-symbols-into/rev values result)
  (cond
   ((null? values) result)
   (else
    (agentic-ai-lab-cicd-symbols-into/rev
     (cdr values)
     (cons (car values) result)))))

;; : (-> [Alist] [Symbol] [Symbol])
(def (agentic-ai-lab-cicd-pipeline-run-steps-diagnostics/rev steps diagnostics-rev)
  (cond
   ((null? steps) diagnostics-rev)
   (else
    (agentic-ai-lab-cicd-pipeline-run-steps-diagnostics/rev
     (cdr steps)
     (agentic-ai-lab-cicd-symbols-into/rev
      (yuanxu-cicd-alist-ref (car steps) 'diagnostics '())
      diagnostics-rev)))))

;; Step diagnostics are aggregated at the pipeline level so result rows can be
;; audited without traversing every step.
;; : (-> [Alist] [Symbol])
(def (agentic-ai-lab-cicd-pipeline-run-steps-diagnostics steps)
  (reverse (agentic-ai-lab-cicd-pipeline-run-steps-diagnostics/rev steps '())))

;; Pipeline diagnostics merge graph, step, and blocked-step facts into a
;; stable report-only list for user-interface and agent editing loops.
;; : (-> Alist [Alist] [Symbol] [Symbol])
(def (agentic-ai-lab-cicd-pipeline-run-diagnostics graph steps blocked-steps)
  (let* ((diagnostics0
          (agentic-ai-lab-cicd-symbols-into/rev
           (yuanxu-cicd-alist-ref graph 'diagnostics '())
           '()))
         (diagnostics1
          (agentic-ai-lab-cicd-pipeline-run-steps-diagnostics/rev
           steps
           diagnostics0))
         (diagnostics2
          (if (null? blocked-steps)
            diagnostics1
            (cons 'blocked-steps diagnostics1))))
    (agentic-ai-lab-cicd-symbol-list-unique (reverse diagnostics2))))

;; Pipeline run status is a control-plane admission result. It stays blocked
;; when graph diagnostics or sandbox refs prevent a clean Marlin handoff.
;; : (-> [Alist] Boolean)
(def (agentic-ai-lab-cicd-pipeline-run-steps-admitted? steps)
  (cond
   ((null? steps) #t)
   ((eq? (yuanxu-cicd-alist-ref (car steps) 'status 'blocked)
         'admitted)
    (agentic-ai-lab-cicd-pipeline-run-steps-admitted? (cdr steps)))
   (else #f)))

;; : (-> Alist [Alist] Symbol)
(def (agentic-ai-lab-cicd-pipeline-run-status graph steps)
  (if (and (yuanxu-cicd-alist-ref graph 'valid? #f)
           (agentic-ai-lab-cicd-pipeline-run-steps-admitted? steps))
    'admitted
    'blocked))

;; The pipeline run is the concrete, inspectable plan produced from a
;; check-map. It includes DAG order, steps, and handoff status but no output.
;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check-map->pipeline-run check-map . maybe-profile-catalog)
  (yuanxu-cicd-require "pipeline run requires a cicd check-map"
                         (yuanxu-cicd-check-map? check-map)
                         check-map)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (graph (yuanxu-cicd-check-map->dependency-graph check-map))
         (step-summary
          (agentic-ai-lab-cicd-pipeline-run-step-summary
           (yuanxu-cicd-check-map-checks check-map)
           graph
           profile-catalog))
         (steps
          (yuanxu-cicd-alist-ref step-summary 'steps '()))
         (blocked-steps
          (yuanxu-cicd-alist-ref step-summary 'blocked-steps '()))
         (status (agentic-ai-lab-cicd-pipeline-run-status graph steps))
         (diagnostics
          (agentic-ai-lab-cicd-pipeline-run-diagnostics
           graph
           steps
           blocked-steps)))
    (yuanxu-cicd-field-rows
     (schema +yuanxu-cicd-pipeline-run-schema+)
     (kind 'agentic-ai-lab.workflow.cicd.pipeline-run)
     (check-map (yuanxu-cicd-check-map-name check-map))
     (status status)
     (step-count (length steps))
     (steps steps)
     (ready-order
      (yuanxu-cicd-alist-ref graph 'ready-order '()))
     (blocked-steps blocked-steps)
     (diagnostics diagnostics)
     (dependency-graph graph)
     (handoff-required #t)
     (handoff-ready (and (eq? status 'admitted)
                         (null? diagnostics)))
     (valid? (null? diagnostics))
     (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
     (runtime-executed #f))))

;; Pipeline results summarize the projected run. They are the tutorial-facing
;; "what would this produce" surface before a runtime returns real outputs.
;; : (-> Alist Alist)
(def (agentic-ai-lab-cicd-pipeline-run->result run)
  (let* ((blocked-steps
          (yuanxu-cicd-alist-ref run 'blocked-steps '()))
         (diagnostics
          (yuanxu-cicd-alist-ref run 'diagnostics '()))
         (handoff-ready
          (and (eq? (yuanxu-cicd-alist-ref run 'status 'blocked)
                    'admitted)
               (null? diagnostics))))
    (yuanxu-cicd-field-rows
     (schema +yuanxu-cicd-pipeline-result-schema+)
     (kind 'agentic-ai-lab.workflow.cicd.pipeline-result)
     (check-map (yuanxu-cicd-alist-ref run 'check-map #f))
     (status (if handoff-ready 'handoff-ready 'blocked))
     (pipeline-run-status
      (yuanxu-cicd-alist-ref run 'status 'blocked))
     (step-count (yuanxu-cicd-alist-ref run 'step-count 0))
     (ready-order (yuanxu-cicd-alist-ref run 'ready-order '()))
     (blocked-steps blocked-steps)
     (diagnostics diagnostics)
     (valid? handoff-ready)
     (handoff-required #t)
     (handoff-ready handoff-ready)
     (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
     (runtime-executed #f))))

;; The check-map shortcut keeps callers on the public object surface when they
;; only need the result projection rather than the full run step payload.
;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check-map->pipeline-result check-map
                                                . maybe-profile-catalog)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (agentic-ai-lab-cicd-pipeline-run->result
     (agentic-ai-lab-cicd-check-map->pipeline-run check-map profile-catalog))))
