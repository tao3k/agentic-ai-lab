;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD sandbox profile inheritance and runtime-readiness facts.
;;; Invariant: unresolved profile refs stay visible; no fallback profile is fabricated.

(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list delete-duplicates/hash)
        :poo-flow/modules/workflow/control-plane/projection-syntax
        (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-sandbox-profile?
                 poo-flow-sandbox-profile-by-name
                 poo-flow-sandbox-profile-handoff-summary
                 poo-flow-sandbox-profile-name
                 poo-flow-sandbox-profile-runtime-summary)
        :poo-flow/modules/workflow/types
        :poo-flow/modules/workflow/objects)

(export poo-flow-cicd-check-profile-refs
        poo-flow-cicd-check-sandbox-runtime-summaries
        poo-flow-cicd-check-sandbox-handoff-summaries
        poo-flow-cicd-check-sandbox-unresolved-profile-refs
        poo-flow-cicd-check->runtime-manifest-readiness)

;;; Profile refs are an inheritance surface, not graph edges. This collector
;;; flattens symbol refs and inline profile objects into runtime catalog names.
;; : (-> PooFlowCicdProfileRef [Symbol] [Symbol])
(def (poo-flow-cicd-profile-refs/rev profile refs-rev)
  (cond
   ((symbol? profile)
    (cons profile refs-rev))
   ((poo-flow-sandbox-profile? profile)
    (cons (poo-flow-sandbox-profile-name profile) refs-rev))
   ((and (pair? profile) (list? profile))
    (foldl poo-flow-cicd-profile-refs/rev refs-rev profile))
   (else refs-rev)))

;;; Nested profile-ref lists preserve left-to-right inheritance order while
;;; flattening the runtime-facing catalog refs.
;; : (-> [PooFlowCicdProfileRef] [Symbol] [Symbol])
(def (poo-flow-cicd-check-profile-refs check)
  (delete-duplicates/hash
   (reverse
    (poo-flow-cicd-profile-refs/rev
     (poo-flow-cicd-check-profile check) '()))))

;;; Sandbox profile lookup accepts inline POO profiles and catalog symbols. It
;;; never constructs fallback profiles, so unresolved refs remain visible.
;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] MaybePooSandboxProfile)
(def (poo-flow-cicd-profile-ref->sandbox-profile profile profile-catalog)
  (cond
   ((poo-flow-sandbox-profile? profile) profile)
   ((symbol? profile)
    (poo-flow-sandbox-profile-by-name profile-catalog profile))
   (else #f)))

;; poo-flow-cicd-profile-projection-values/rev
;;   : (-> [RuntimeProjectionRow] [RuntimeProjectionRow] [RuntimeProjectionRow])
;;   | contract: prepend projected profile rows into a reversed accumulator
;;   | result: reversed projection rows with existing accumulator tail preserved
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-cicd-profile-projection-values/rev
;;        '((runtime . nono) (handoff . required))
;;        '((tail)))
;;       ;; => ((handoff . required) (runtime . nono) (tail))
;;       ```
;;     %
(def (poo-flow-cicd-profile-projection-values/rev values results)
  (foldl cons results values))

;; : (-> Procedure [PooFlowCicdProfileRef] [PooSandboxProfile] [Value] [Value])
(def (poo-flow-cicd-profile-projections/list-rev projector
                                                    profiles
                                                    profile-catalog
                                                    results)
  (cond
   ((null? profiles) results)
   (else
    (poo-flow-cicd-profile-projections/list-rev
     projector
     (cdr profiles)
     profile-catalog
     (poo-flow-cicd-profile-projections/rev
      projector
      (car profiles)
      profile-catalog
      results)))))

;; : (-> Procedure PooFlowCicdProfileRef [PooSandboxProfile] [Value] [Value])
(def (poo-flow-cicd-profile-projections/rev projector
                                            profile
                                            profile-catalog
                                            results)
  (if (and (pair? profile) (list? profile))
    (poo-flow-cicd-profile-projections/list-rev
     projector
     profile
     profile-catalog
     results)
    (poo-flow-cicd-profile-projection-values/rev
     (projector profile profile-catalog)
     results)))

;; : (-> Procedure PooFlowCicdProfileRef [PooSandboxProfile] [Value])
(def (poo-flow-cicd-profile-projections projector profile profile-catalog)
  (reverse
   (poo-flow-cicd-profile-projections/rev
    projector
    profile
    profile-catalog
    '())))

;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-profile-runtime-summary-values profile profile-catalog)
  (cond
   ((poo-flow-cicd-profile-ref->sandbox-profile profile profile-catalog)
    => (lambda (sandbox-profile)
         (list (poo-flow-sandbox-profile-runtime-summary sandbox-profile))))
   (else '())))

;;; Runtime summaries follow profile inheritance recursively. Missing catalog
;;; refs are skipped here and reported by the unresolved-ref projection.
;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-profile-runtime-summaries profile profile-catalog)
  (poo-flow-cicd-profile-projections
   poo-flow-cicd-profile-runtime-summary-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox runtime summaries is the policy-visible edge
;;; for sandbox, workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-check-sandbox-runtime-summaries check
                                                    . maybe-profile-catalog)
  (poo-flow-cicd-profile-runtime-summaries
   (poo-flow-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Handoff summaries mirror runtime summaries so both report paths preserve
;;; the same inherited profile order.
;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-profile-handoff-summary-values profile profile-catalog)
  (cond
   ((poo-flow-cicd-profile-ref->sandbox-profile profile profile-catalog)
    => (lambda (sandbox-profile)
         (list (poo-flow-sandbox-profile-handoff-summary sandbox-profile))))
   (else '())))

;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-profile-handoff-summaries profile profile-catalog)
  (poo-flow-cicd-profile-projections
   poo-flow-cicd-profile-handoff-summary-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox handoff summaries is the policy-visible edge
;;; for sandbox, workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-check-sandbox-handoff-summaries check
                                                    . maybe-profile-catalog)
  (poo-flow-cicd-profile-handoff-summaries
   (poo-flow-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Unresolved profile refs are the safety signal for fake or incomplete CI
;;; profiles. Inline POO profiles are already resolved and never reported.
;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Symbol])
(def (poo-flow-cicd-profile-unresolved-ref-values profile profile-catalog)
  (cond
   ((symbol? profile)
    (if (poo-flow-sandbox-profile-by-name profile-catalog profile)
      '()
      (list profile)))
   ((poo-flow-sandbox-profile? profile) '())
   (else '())))

;; : (-> PooFlowCicdProfileRef [PooSandboxProfile] [Symbol])
(def (poo-flow-cicd-profile-unresolved-refs profile profile-catalog)
  (poo-flow-cicd-profile-projections
   poo-flow-cicd-profile-unresolved-ref-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox unresolved profile refs is the policy-visible
;;; edge for sandbox, workflow behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] [Symbol])
(def (poo-flow-cicd-check-sandbox-unresolved-profile-refs
      check
      . maybe-profile-catalog)
  (poo-flow-cicd-profile-unresolved-refs
   (poo-flow-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Runtime readiness is a manifest-shaped promise. It is deliberately not a
;;; RuntimeCommandDescriptor because CI checks still need a sandbox/runtime owner
;;; to materialize the command envelope.
;;; The field list is intentionally explicit because these keys are the stable
;;; ABI contract consumed by the runtime handoff tests.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
;; | contract: project a CI check and sandbox catalog into readiness rows
;; | result: an ordered runtime-readiness alist with no command execution
;; | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-cicd-runtime-manifest-readiness-fields check profiles)
;;       ;; => ((schema . poo-flow.workflow.cicd.runtime-manifest-readiness.v1)
;;       ;;     (kind . poo-flow.workflow.cicd.runtime-manifest-ready)
;;       ;;     (runtime-executed . #f)
;;       ;;     (handoff-required . #t))
;;       ```
;;   %
;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
(def (poo-flow-cicd-runtime-manifest-readiness-fields check profile-catalog)
  (poo-flow-product-field-rows
   (schema +poo-flow-cicd-runtime-manifest-readiness-schema+)
   (kind 'poo-flow.workflow.cicd.runtime-manifest-ready)
   (check (poo-flow-cicd-check-name check))
   (profile (poo-flow-cicd-check-profile check))
   (profile-refs (poo-flow-cicd-check-profile-refs check))
   (dependency-refs
    (poo-flow-cicd-check-dependency-refs check))
   (sandbox-runtime-summaries
    (poo-flow-cicd-check-sandbox-runtime-summaries
     check
     profile-catalog))
   (sandbox-handoff-summaries
    (poo-flow-cicd-check-sandbox-handoff-summaries
     check
     profile-catalog))
   (sandbox-unresolved-profile-refs
    (poo-flow-cicd-check-sandbox-unresolved-profile-refs
     check
     profile-catalog))
   (runtime (poo-flow-cicd-check-runtime check))
   (runtime-executed #f)
   (handoff-required #t)
   (command (poo-flow-cicd-check-command check))
   (argv (poo-flow-cicd-check-command check))
   (inputs (.ref check 'input-bindings))
   (config (.ref check 'config-sources))
   (artifacts (poo-flow-cicd-check-artifacts check))
   (durable-task-id
    (poo-flow-cicd-check-durable-task-id check))
   (action-class
    (poo-flow-cicd-check-action-class check))
   (artifact-refs
    (poo-flow-cicd-check-artifacts check))
   (artifact-retention
    (poo-flow-cicd-check-artifact-retention check))
   (sandbox-refs
    (poo-flow-cicd-check-profile-refs check))
   (checkpoint-ref
    (list 'workflow-cicd-check
          (poo-flow-cicd-check-name check)))
   (compensation-refs
    (poo-flow-cicd-check-compensation-refs check))
   (cache (poo-flow-cicd-check-cache check))
   (secrets (poo-flow-cicd-check-secrets check))
   (result (.ref check 'result-protocol))))

;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
;; | contract: validate a CI check and emit report-only readiness rows
;; | result: runtime manifest readiness alist for Marlin handoff planning
;; | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-cicd-check->runtime-manifest-readiness check profiles)
;;       ;; => ((kind . poo-flow.cicd.runtime-manifest-readiness.v1) ...)
;;       ```
;;   %
;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check->runtime-manifest-readiness check
                                                        . maybe-profile-catalog)
  (poo-flow-cicd-require "runtime manifest readiness requires a cicd check"
                         (poo-flow-cicd-check? check)
                         check)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-runtime-manifest-readiness-fields check profile-catalog)))
