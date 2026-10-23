;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD sandbox profile inheritance and runtime-readiness facts.
;;; Invariant: unresolved profile refs stay visible; no fallback profile is fabricated.

(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list delete-duplicates/hash)
        :yuanxu/modules/funflow/control-plane/projection-syntax
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile?
                 agentic-ai-lab-sandbox-profile-by-name
                 agentic-ai-lab-sandbox-profile-handoff-summary
                 agentic-ai-lab-sandbox-profile-name
                 agentic-ai-lab-sandbox-profile-runtime-summary)
        :yuanxu/modules/funflow/check-types
        :yuanxu/modules/funflow/check-objects)

(export agentic-ai-lab-cicd-check-profile-refs
        agentic-ai-lab-cicd-check-sandbox-runtime-summaries
        agentic-ai-lab-cicd-check-sandbox-handoff-summaries
        agentic-ai-lab-cicd-check-sandbox-unresolved-profile-refs
        agentic-ai-lab-cicd-check->runtime-manifest-readiness)

;;; Profile refs are an inheritance surface, not graph edges. This collector
;;; flattens symbol refs and inline profile objects into runtime catalog names.
;; : (-> AgenticAILabCicdProfileRef [Symbol] [Symbol])
(def (agentic-ai-lab-cicd-profile-refs/rev profile refs-rev)
  (cond
   ((symbol? profile)
    (cons profile refs-rev))
   ((agentic-ai-lab-sandbox-profile? profile)
    (cons (agentic-ai-lab-sandbox-profile-name profile) refs-rev))
   ((and (pair? profile) (list? profile))
    (foldl agentic-ai-lab-cicd-profile-refs/rev refs-rev profile))
   (else refs-rev)))

;;; Nested profile-ref lists preserve left-to-right inheritance order while
;;; flattening the runtime-facing catalog refs.
;; : (-> [AgenticAILabCicdProfileRef] [Symbol] [Symbol])
(def (agentic-ai-lab-cicd-check-profile-refs check)
  (delete-duplicates/hash
   (reverse
    (agentic-ai-lab-cicd-profile-refs/rev
     (yuanxu-cicd-check-profile check) '()))))

;;; Sandbox profile lookup accepts inline POO profiles and catalog symbols. It
;;; never constructs fallback profiles, so unresolved refs remain visible.
;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] MaybePooSandboxProfile)
(def (agentic-ai-lab-cicd-profile-ref->sandbox-profile profile profile-catalog)
  (cond
   ((agentic-ai-lab-sandbox-profile? profile) profile)
   ((symbol? profile)
    (agentic-ai-lab-sandbox-profile-by-name profile-catalog profile))
   (else #f)))

;; agentic-ai-lab-cicd-profile-projection-values/rev
;;   : (-> [RuntimeProjectionRow] [RuntimeProjectionRow] [RuntimeProjectionRow])
;;   | contract: prepend projected profile rows into a reversed accumulator
;;   | result: reversed projection rows with existing accumulator tail preserved
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-cicd-profile-projection-values/rev
;;        '((runtime . nono) (handoff . required))
;;        '((tail)))
;;       ;; => ((handoff . required) (runtime . nono) (tail))
;;       ```
;;     %
(def (agentic-ai-lab-cicd-profile-projection-values/rev values results)
  (foldl cons results values))

;; : (-> Procedure [AgenticAILabCicdProfileRef] [PooSandboxProfile] [Value] [Value])
(def (agentic-ai-lab-cicd-profile-projections/list-rev projector
                                                    profiles
                                                    profile-catalog
                                                    results)
  (cond
   ((null? profiles) results)
   (else
    (agentic-ai-lab-cicd-profile-projections/list-rev
     projector
     (cdr profiles)
     profile-catalog
     (agentic-ai-lab-cicd-profile-projections/rev
      projector
      (car profiles)
      profile-catalog
      results)))))

;; : (-> Procedure AgenticAILabCicdProfileRef [PooSandboxProfile] [Value] [Value])
(def (agentic-ai-lab-cicd-profile-projections/rev projector
                                            profile
                                            profile-catalog
                                            results)
  (if (and (pair? profile) (list? profile))
    (agentic-ai-lab-cicd-profile-projections/list-rev
     projector
     profile
     profile-catalog
     results)
    (agentic-ai-lab-cicd-profile-projection-values/rev
     (projector profile profile-catalog)
     results)))

;; : (-> Procedure AgenticAILabCicdProfileRef [PooSandboxProfile] [Value])
(def (agentic-ai-lab-cicd-profile-projections projector profile profile-catalog)
  (reverse
   (agentic-ai-lab-cicd-profile-projections/rev
    projector
    profile
    profile-catalog
    '())))

;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-profile-runtime-summary-values profile profile-catalog)
  (cond
   ((agentic-ai-lab-cicd-profile-ref->sandbox-profile profile profile-catalog)
    => (lambda (sandbox-profile)
         (list (agentic-ai-lab-sandbox-profile-runtime-summary sandbox-profile))))
   (else '())))

;;; Runtime summaries follow profile inheritance recursively. Missing catalog
;;; refs are skipped here and reported by the unresolved-ref projection.
;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-profile-runtime-summaries profile profile-catalog)
  (agentic-ai-lab-cicd-profile-projections
   agentic-ai-lab-cicd-profile-runtime-summary-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox runtime summaries is the policy-visible edge
;;; for sandbox, workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-check-sandbox-runtime-summaries check
                                                    . maybe-profile-catalog)
  (agentic-ai-lab-cicd-profile-runtime-summaries
   (yuanxu-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Handoff summaries mirror runtime summaries so both report paths preserve
;;; the same inherited profile order.
;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-profile-handoff-summary-values profile profile-catalog)
  (cond
   ((agentic-ai-lab-cicd-profile-ref->sandbox-profile profile profile-catalog)
    => (lambda (sandbox-profile)
         (list (agentic-ai-lab-sandbox-profile-handoff-summary sandbox-profile))))
   (else '())))

;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-profile-handoff-summaries profile profile-catalog)
  (agentic-ai-lab-cicd-profile-projections
   agentic-ai-lab-cicd-profile-handoff-summary-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox handoff summaries is the policy-visible edge
;;; for sandbox, workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-check-sandbox-handoff-summaries check
                                                    . maybe-profile-catalog)
  (agentic-ai-lab-cicd-profile-handoff-summaries
   (yuanxu-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Unresolved profile refs are the safety signal for fake or incomplete CI
;;; profiles. Inline POO profiles are already resolved and never reported.
;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Symbol])
(def (agentic-ai-lab-cicd-profile-unresolved-ref-values profile profile-catalog)
  (cond
   ((symbol? profile)
    (if (agentic-ai-lab-sandbox-profile-by-name profile-catalog profile)
      '()
      (list profile)))
   ((agentic-ai-lab-sandbox-profile? profile) '())
   (else '())))

;; : (-> AgenticAILabCicdProfileRef [PooSandboxProfile] [Symbol])
(def (agentic-ai-lab-cicd-profile-unresolved-refs profile profile-catalog)
  (agentic-ai-lab-cicd-profile-projections
   agentic-ai-lab-cicd-profile-unresolved-ref-values
   profile
   profile-catalog))

;;; Boundary: cicd check sandbox unresolved profile refs is the policy-visible
;;; edge for sandbox, workflow behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] [Symbol])
(def (agentic-ai-lab-cicd-check-sandbox-unresolved-profile-refs
      check
      . maybe-profile-catalog)
  (agentic-ai-lab-cicd-profile-unresolved-refs
   (yuanxu-cicd-check-profile check)
   (if (null? maybe-profile-catalog) '() (car maybe-profile-catalog))))

;;; Runtime readiness is a manifest-shaped promise. It is deliberately not a
;;; RuntimeCommandDescriptor because CI checks still need a sandbox/runtime owner
;;; to materialize the command envelope.
;;; The field list is intentionally explicit because these keys are the stable
;;; ABI contract consumed by the runtime handoff tests.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
;; | contract: project a CI check and sandbox catalog into readiness rows
;; | result: an ordered runtime-readiness alist with no command execution
;; | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-cicd-runtime-manifest-readiness-fields check profiles)
;;       ;; => ((schema . agentic-ai-lab.workflow.cicd.runtime-manifest-readiness.v1)
;;       ;;     (kind . agentic-ai-lab.workflow.cicd.runtime-manifest-ready)
;;       ;;     (runtime-executed . #f)
;;       ;;     (handoff-required . #t))
;;       ```
;;   %
;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-runtime-manifest-readiness-fields check profile-catalog)
  (yuanxu-product-field-rows
   (schema +yuanxu-cicd-runtime-manifest-readiness-schema+)
   (kind 'agentic-ai-lab.workflow.cicd.runtime-manifest-ready)
   (check (yuanxu-cicd-check-name check))
   (profile (yuanxu-cicd-check-profile check))
   (profile-refs (agentic-ai-lab-cicd-check-profile-refs check))
   (dependency-refs
    (yuanxu-cicd-check-dependency-refs check))
   (sandbox-runtime-summaries
    (agentic-ai-lab-cicd-check-sandbox-runtime-summaries
     check
     profile-catalog))
   (sandbox-handoff-summaries
    (agentic-ai-lab-cicd-check-sandbox-handoff-summaries
     check
     profile-catalog))
   (sandbox-unresolved-profile-refs
    (agentic-ai-lab-cicd-check-sandbox-unresolved-profile-refs
     check
     profile-catalog))
   (runtime (yuanxu-cicd-check-runtime check))
   (runtime-executed #f)
   (handoff-required #t)
   (command (yuanxu-cicd-check-command check))
   (argv (yuanxu-cicd-check-command check))
   (inputs (.ref check 'input-bindings))
   (config (.ref check 'config-sources))
   (artifacts (yuanxu-cicd-check-artifacts check))
   (durable-task-id
    (yuanxu-cicd-check-durable-task-id check))
   (action-class
    (yuanxu-cicd-check-action-class check))
   (artifact-refs
    (yuanxu-cicd-check-artifacts check))
   (artifact-retention
    (yuanxu-cicd-check-artifact-retention check))
   (sandbox-refs
    (agentic-ai-lab-cicd-check-profile-refs check))
   (checkpoint-ref
    (list 'workflow-cicd-check
          (yuanxu-cicd-check-name check)))
   (compensation-refs
    (yuanxu-cicd-check-compensation-refs check))
   (cache (yuanxu-cicd-check-cache check))
   (secrets (yuanxu-cicd-check-secrets check))
   (result (.ref check 'result-protocol))))

;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
;; | contract: validate a CI check and emit report-only readiness rows
;; | result: runtime manifest readiness alist for Marlin handoff planning
;; | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-cicd-check->runtime-manifest-readiness check profiles)
;;       ;; => ((kind . agentic-ai-lab.cicd.runtime-manifest-readiness.v1) ...)
;;       ```
;;   %
;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check->runtime-manifest-readiness check
                                                        . maybe-profile-catalog)
  (yuanxu-cicd-require "runtime manifest readiness requires a cicd check"
                         (yuanxu-cicd-check? check)
                         check)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (agentic-ai-lab-cicd-runtime-manifest-readiness-fields check profile-catalog)))
