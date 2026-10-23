;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: per-check runtime projections and per-check-to-map manifest/receipt
;;; projection helpers for CI/CD runtime handoff.

(import (only-in :clan/poo/object .ref)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :yuanxu/modules/funflow/check-types
        :yuanxu/modules/funflow/check-objects
        :yuanxu/modules/funflow/check-funs
        :yuanxu/modules/funflow/projection-syntax
        :agentic-ai-lab/modules/workflow/cicd-sandbox
        :yuanxu/modules/funflow/dependency-graph)

(export agentic-ai-lab-cicd-check-artifact-provenance
        agentic-ai-lab-cicd-check-durable-fields
        agentic-ai-lab-cicd-check-runtime-metadata
        agentic-ai-lab-cicd-check-runtime-policy
        agentic-ai-lab-cicd-check-runtime-command-envelope
        agentic-ai-lab-cicd-check->runtime-command-manifest
        agentic-ai-lab-cicd-check-receipt-fields
        agentic-ai-lab-cicd-check->receipt
        agentic-ai-lab-cicd-checks->receipts
        agentic-ai-lab-cicd-check-map->receipts
        agentic-ai-lab-cicd-checks->runtime-manifest-readiness
        agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
        agentic-ai-lab-cicd-checks->runtime-command-manifests
        agentic-ai-lab-cicd-check-map->runtime-command-manifests)

;; Durable fields are a bounded runtime receipt projection. They are derived
;; from validated POO check metadata once, then copied into runtime handoff
;; alists so Marlin never has to inspect the POO object graph.
;; : (forall (a) (-> YuanxuCicdCheck [a]))
;; : (-> YuanxuCicdCheck [Alist])
(def (agentic-ai-lab-cicd-check-artifact-provenance check)
  (let ((producer-check (yuanxu-cicd-check-name check))
        (durable-task-id (yuanxu-cicd-check-durable-task-id check))
        (retention (yuanxu-cicd-check-artifact-retention check)))
    (map (lambda (artifact-ref)
           (yuanxu-cicd-field-rows
            (artifact-ref artifact-ref)
            (producer-check producer-check)
            (durable-task-id durable-task-id)
            (retention retention)
            (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
            (runtime-executed #f)))
         (yuanxu-cicd-check-artifacts check))))

;; : (-> YuanxuCicdCheck Alist)
(def (agentic-ai-lab-cicd-check-durable-fields check)
  (yuanxu-cicd-field-rows
   (durable-task-id (yuanxu-cicd-check-durable-task-id check))
   (action-class (yuanxu-cicd-check-action-class check))
   (artifact-refs (yuanxu-cicd-check-artifacts check))
   (artifact-provenance (agentic-ai-lab-cicd-check-artifact-provenance check))
   (artifact-retention (yuanxu-cicd-check-artifact-retention check))
   (sandbox-refs (agentic-ai-lab-cicd-check-profile-refs check))
   (checkpoint-ref
    (list 'workflow-cicd-check
          (yuanxu-cicd-check-name check)))
   (compensation-refs (yuanxu-cicd-check-compensation-refs check))))

;; : (-> YuanxuCicdCheck Alist Alist)
(def (agentic-ai-lab-cicd-check-runtime-metadata check readiness)
  (yuanxu-cicd-field-rows/tail
   (agentic-ai-lab-cicd-check-durable-fields check)
   (source 'yuanxu.workflow.cicd.check)
   (check (yuanxu-cicd-check-name check))
   (profile (yuanxu-cicd-check-profile check))
   (profile-refs (agentic-ai-lab-cicd-check-profile-refs check))
   (dependency-refs (yuanxu-cicd-check-dependency-refs check))
   (runtime (yuanxu-cicd-check-runtime check))
   (runtime-executed #f)
   (handoff-required #t)
   (artifacts (yuanxu-cicd-check-artifacts check))
   (cache (yuanxu-cicd-check-cache check))
   (secrets (yuanxu-cicd-check-secrets check))
   (readiness readiness)))

;; : (-> YuanxuCicdCheck Alist)
(def (agentic-ai-lab-cicd-check-runtime-policy check)
  (yuanxu-cicd-field-rows/tail
   (agentic-ai-lab-cicd-check-durable-fields check)
   (runtime (yuanxu-cicd-check-runtime check))
   (dependency-refs (yuanxu-cicd-check-dependency-refs check))
   (runtime-executed #f)
   (handoff-required #t)))

;; The envelope is intentionally the smallest runtime request shape: it names
;; the workflow operation and carries readiness as data, while leaving plan and
;; frontier fields inert until a real scheduler supplies them.
;; : (-> YuanxuCicdCheck Alist Alist)
(def (agentic-ai-lab-cicd-check-runtime-command-envelope check readiness)
  (yuanxu-cicd-field-rows
   (schema +runtime-request-schema+)
   (operation 'workflow-cicd-check)
   (request-id
    (list 'agentic-ai-lab.workflow.cicd
          (yuanxu-cicd-check-name check)))
   (artifact-handle (yuanxu-cicd-check-artifacts check))
   (request readiness)
   (policy (agentic-ai-lab-cicd-check-runtime-policy check))
   (plan-id #f)
   (node-id (yuanxu-cicd-check-name check))
   (frontier '())))

;; Public manifest projection is the handoff boundary for one check. It
;; validates the POO check, reuses the readiness projector, and delegates final
;; manifest shape to class-free runtime command helpers.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check->runtime-command-manifest check
                                                     . maybe-profile-catalog)
  (yuanxu-cicd-require "runtime command manifest requires a cicd check"
                         (yuanxu-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (readiness
          (agentic-ai-lab-cicd-check->runtime-manifest-readiness
           check
           profile-catalog))
         (command (yuanxu-cicd-check-command check))
         (envelope
          (agentic-ai-lab-cicd-check-runtime-command-envelope check readiness)))
    (runtime-command-fields->manifest
     (yuanxu-cicd-check-name check)
     (car command)
     (cdr command)
     (.ref check 'result-protocol)
     (agentic-ai-lab-cicd-check-runtime-metadata check readiness)
     envelope)))

;; Receipts are normalized alists so Rust/Marlin can consume them without
;; knowing the Gerbil POO object representation.
;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist Alist)
(def (agentic-ai-lab-cicd-check-receipt-fields check
                                          profile-catalog
                                          runtime-ready)
  (yuanxu-cicd-field-rows/tail
   (agentic-ai-lab-cicd-check-durable-fields check)
   (schema +yuanxu-cicd-check-receipt-schema+)
   (kind 'agentic-ai-lab.workflow.cicd.check-receipt)
   (check (yuanxu-cicd-check-name check))
   (profile (yuanxu-cicd-check-profile check))
   (profile-refs (agentic-ai-lab-cicd-check-profile-refs check))
   (dependency-refs (yuanxu-cicd-check-dependency-refs check))
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
   (command (yuanxu-cicd-check-command check))
   (inputs (.ref check 'input-bindings))
   (config (.ref check 'config-sources))
   (artifacts (yuanxu-cicd-check-artifacts check))
   (cache (yuanxu-cicd-check-cache check))
   (secrets (yuanxu-cicd-check-secrets check))
   (result (.ref check 'result-protocol))
   (runtime (yuanxu-cicd-check-runtime check))
   (runtime-executed #f)
   (status 'ready)
   (runtime-manifest-ready runtime-ready)))

;; : (-> YuanxuCicdCheck [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check->receipt check . maybe-profile-catalog)
  (yuanxu-cicd-require "cicd receipt requires a cicd check"
                         (yuanxu-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (runtime-ready
          (agentic-ai-lab-cicd-check->runtime-manifest-readiness
           check
           profile-catalog)))
    (agentic-ai-lab-cicd-check-receipt-fields check
                                        profile-catalog
                                        runtime-ready)))

;; The map is the whole data-flow: each POO check becomes one immutable
;; receipt row, preserving order without a hand-written accumulator.
;; : (-> [YuanxuCicdCheck] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-checks->receipts checks profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (agentic-ai-lab-cicd-check->receipt (car checks) profile-catalog)
          (agentic-ai-lab-cicd-checks->receipts (cdr checks)
                                          profile-catalog)))))

;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-check-map->receipts check-map . maybe-profile-catalog)
  (yuanxu-cicd-require "cicd receipts require a cicd check-map"
                         (yuanxu-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (agentic-ai-lab-cicd-checks->receipts
     (yuanxu-cicd-check-map-checks check-map)
     profile-catalog)))

;; Runtime readiness uses the same ordered sequence-map as receipts so every
;; check has exactly one handoff row and no runtime side effect is introduced.
;; : (-> [YuanxuCicdCheck] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-checks->runtime-manifest-readiness checks
                                                       profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (agentic-ai-lab-cicd-check->runtime-manifest-readiness
           (car checks)
           profile-catalog)
          (agentic-ai-lab-cicd-checks->runtime-manifest-readiness
           (cdr checks)
           profile-catalog)))))

;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check-map->runtime-manifest-readiness check-map
                                                              . maybe-profile-catalog)
  (yuanxu-cicd-require "runtime manifest readiness requires a cicd check-map"
                         (yuanxu-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (yuanxu-cicd-field-rows
     (schema +yuanxu-cicd-runtime-manifest-readiness-schema+)
     (kind 'agentic-ai-lab.workflow.cicd.runtime-manifest-ready-map)
     (check-map (yuanxu-cicd-check-map-name check-map))
     (runtime-executed #f)
     (handoff-required #t)
     (dependency-graph
      (yuanxu-cicd-check-map->dependency-graph check-map))
     (checks
      (agentic-ai-lab-cicd-checks->runtime-manifest-readiness
       (yuanxu-cicd-check-map-checks check-map)
       profile-catalog)))))

;; Check-map manifest projection keeps CI/CD orchestration declarative: each
;; check contributes one runtime command manifest, and the wrapper records that
;; this is still report-only handoff data, not an execution result.
;; : (-> [YuanxuCicdCheck] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-cicd-checks->runtime-command-manifests checks profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (agentic-ai-lab-cicd-check->runtime-command-manifest
           (car checks)
           profile-catalog)
          (agentic-ai-lab-cicd-checks->runtime-command-manifests
           (cdr checks)
           profile-catalog)))))

;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check-map->runtime-command-manifests check-map
                                                          . maybe-profile-catalog)
  (yuanxu-cicd-require "runtime command manifests require a cicd check-map"
                         (yuanxu-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (yuanxu-cicd-field-rows
     (schema +yuanxu-cicd-runtime-manifest-readiness-schema+)
     (kind 'agentic-ai-lab.workflow.cicd.runtime-command-manifest-map)
     (check-map (yuanxu-cicd-check-map-name check-map))
     (runtime-executed #f)
     (handoff-required #t)
     (dependency-graph
      (yuanxu-cicd-check-map->dependency-graph check-map))
     (manifests
      (agentic-ai-lab-cicd-checks->runtime-command-manifests
       (yuanxu-cicd-check-map-checks check-map)
       profile-catalog)))))
