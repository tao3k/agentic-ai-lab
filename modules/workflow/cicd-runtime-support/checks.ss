;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: per-check runtime projections and per-check-to-map manifest/receipt
;;; projection helpers for CI/CD runtime handoff.

(import (only-in :clan/poo/object .ref)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :poo-flow/modules/workflow/types
        :poo-flow/modules/workflow/objects
        :poo-flow/modules/workflow/cicd-funs
        :poo-flow/modules/workflow/cicd-projection-syntax
        :poo-flow/modules/workflow/cicd-sandbox
        :poo-flow/modules/workflow/cicd-runtime-support/graph)

(export poo-flow-cicd-check-artifact-provenance
        poo-flow-cicd-check-durable-fields
        poo-flow-cicd-check-runtime-metadata
        poo-flow-cicd-check-runtime-policy
        poo-flow-cicd-check-runtime-command-envelope
        poo-flow-cicd-check->runtime-command-manifest
        poo-flow-cicd-check-receipt-fields
        poo-flow-cicd-check->receipt
        poo-flow-cicd-checks->receipts
        poo-flow-cicd-check-map->receipts
        poo-flow-cicd-checks->runtime-manifest-readiness
        poo-flow-cicd-check-map->runtime-manifest-readiness
        poo-flow-cicd-checks->runtime-command-manifests
        poo-flow-cicd-check-map->runtime-command-manifests)

;; Durable fields are a bounded runtime receipt projection. They are derived
;; from validated POO check metadata once, then copied into runtime handoff
;; alists so Marlin never has to inspect the POO object graph.
;; : (forall (a) (-> PooFlowCicdCheck [a]))
;; : (-> PooFlowCicdCheck [Alist])
(def (poo-flow-cicd-check-artifact-provenance check)
  (let ((producer-check (poo-flow-cicd-check-name check))
        (durable-task-id (poo-flow-cicd-check-durable-task-id check))
        (retention (poo-flow-cicd-check-artifact-retention check)))
    (map (lambda (artifact-ref)
           (poo-flow-cicd-field-rows
            (artifact-ref artifact-ref)
            (producer-check producer-check)
            (durable-task-id durable-task-id)
            (retention retention)
            (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
            (runtime-executed #f)))
         (poo-flow-cicd-check-artifacts check))))

;; : (-> PooFlowCicdCheck Alist)
(def (poo-flow-cicd-check-durable-fields check)
  (poo-flow-cicd-field-rows
   (durable-task-id (poo-flow-cicd-check-durable-task-id check))
   (action-class (poo-flow-cicd-check-action-class check))
   (artifact-refs (poo-flow-cicd-check-artifacts check))
   (artifact-provenance (poo-flow-cicd-check-artifact-provenance check))
   (artifact-retention (poo-flow-cicd-check-artifact-retention check))
   (sandbox-refs (poo-flow-cicd-check-profile-refs check))
   (checkpoint-ref
    (list 'workflow-cicd-check
          (poo-flow-cicd-check-name check)))
   (compensation-refs (poo-flow-cicd-check-compensation-refs check))))

;; : (-> PooFlowCicdCheck Alist Alist)
(def (poo-flow-cicd-check-runtime-metadata check readiness)
  (poo-flow-cicd-field-rows/tail
   (poo-flow-cicd-check-durable-fields check)
   (source 'poo-flow.workflow.cicd.check)
   (check (poo-flow-cicd-check-name check))
   (profile (poo-flow-cicd-check-profile check))
   (profile-refs (poo-flow-cicd-check-profile-refs check))
   (dependency-refs (poo-flow-cicd-check-dependency-refs check))
   (runtime (poo-flow-cicd-check-runtime check))
   (runtime-executed #f)
   (handoff-required #t)
   (artifacts (poo-flow-cicd-check-artifacts check))
   (cache (poo-flow-cicd-check-cache check))
   (secrets (poo-flow-cicd-check-secrets check))
   (readiness readiness)))

;; : (-> PooFlowCicdCheck Alist)
(def (poo-flow-cicd-check-runtime-policy check)
  (poo-flow-cicd-field-rows/tail
   (poo-flow-cicd-check-durable-fields check)
   (runtime (poo-flow-cicd-check-runtime check))
   (dependency-refs (poo-flow-cicd-check-dependency-refs check))
   (runtime-executed #f)
   (handoff-required #t)))

;; The envelope is intentionally the smallest runtime request shape: it names
;; the workflow operation and carries readiness as data, while leaving plan and
;; frontier fields inert until a real scheduler supplies them.
;; : (-> PooFlowCicdCheck Alist Alist)
(def (poo-flow-cicd-check-runtime-command-envelope check readiness)
  (poo-flow-cicd-field-rows
   (schema +runtime-request-schema+)
   (operation 'workflow-cicd-check)
   (request-id
    (list 'poo-flow.workflow.cicd
          (poo-flow-cicd-check-name check)))
   (artifact-handle (poo-flow-cicd-check-artifacts check))
   (request readiness)
   (policy (poo-flow-cicd-check-runtime-policy check))
   (plan-id #f)
   (node-id (poo-flow-cicd-check-name check))
   (frontier '())))

;; Public manifest projection is the handoff boundary for one check. It
;; validates the POO check, reuses the readiness projector, and delegates final
;; manifest shape to class-free runtime command helpers.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check->runtime-command-manifest check
                                                     . maybe-profile-catalog)
  (poo-flow-cicd-require "runtime command manifest requires a cicd check"
                         (poo-flow-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (readiness
          (poo-flow-cicd-check->runtime-manifest-readiness
           check
           profile-catalog))
         (command (poo-flow-cicd-check-command check))
         (envelope
          (poo-flow-cicd-check-runtime-command-envelope check readiness)))
    (runtime-command-fields->manifest
     (poo-flow-cicd-check-name check)
     (car command)
     (cdr command)
     (.ref check 'result-protocol)
     (poo-flow-cicd-check-runtime-metadata check readiness)
     envelope)))

;; Receipts are normalized alists so Rust/Marlin can consume them without
;; knowing the Gerbil POO object representation.
;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist Alist)
(def (poo-flow-cicd-check-receipt-fields check
                                          profile-catalog
                                          runtime-ready)
  (poo-flow-cicd-field-rows/tail
   (poo-flow-cicd-check-durable-fields check)
   (schema +poo-flow-cicd-check-receipt-schema+)
   (kind 'poo-flow.workflow.cicd.check-receipt)
   (check (poo-flow-cicd-check-name check))
   (profile (poo-flow-cicd-check-profile check))
   (profile-refs (poo-flow-cicd-check-profile-refs check))
   (dependency-refs (poo-flow-cicd-check-dependency-refs check))
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
   (command (poo-flow-cicd-check-command check))
   (inputs (.ref check 'input-bindings))
   (config (.ref check 'config-sources))
   (artifacts (poo-flow-cicd-check-artifacts check))
   (cache (poo-flow-cicd-check-cache check))
   (secrets (poo-flow-cicd-check-secrets check))
   (result (.ref check 'result-protocol))
   (runtime (poo-flow-cicd-check-runtime check))
   (runtime-executed #f)
   (status 'ready)
   (runtime-manifest-ready runtime-ready)))

;; : (-> PooFlowCicdCheck [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check->receipt check . maybe-profile-catalog)
  (poo-flow-cicd-require "cicd receipt requires a cicd check"
                         (poo-flow-cicd-check? check)
                         check)
  (let* ((profile-catalog (if (null? maybe-profile-catalog)
                            '()
                            (car maybe-profile-catalog)))
         (runtime-ready
          (poo-flow-cicd-check->runtime-manifest-readiness
           check
           profile-catalog)))
    (poo-flow-cicd-check-receipt-fields check
                                        profile-catalog
                                        runtime-ready)))

;; The map is the whole data-flow: each POO check becomes one immutable
;; receipt row, preserving order without a hand-written accumulator.
;; : (-> [PooFlowCicdCheck] [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-checks->receipts checks profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (poo-flow-cicd-check->receipt (car checks) profile-catalog)
          (poo-flow-cicd-checks->receipts (cdr checks)
                                          profile-catalog)))))

;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-check-map->receipts check-map . maybe-profile-catalog)
  (poo-flow-cicd-require "cicd receipts require a cicd check-map"
                         (poo-flow-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-checks->receipts
     (poo-flow-cicd-check-map-checks check-map)
     profile-catalog)))

;; Runtime readiness uses the same ordered sequence-map as receipts so every
;; check has exactly one handoff row and no runtime side effect is introduced.
;; : (-> [PooFlowCicdCheck] [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-checks->runtime-manifest-readiness checks
                                                       profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (poo-flow-cicd-check->runtime-manifest-readiness
           (car checks)
           profile-catalog)
          (poo-flow-cicd-checks->runtime-manifest-readiness
           (cdr checks)
           profile-catalog)))))

;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check-map->runtime-manifest-readiness check-map
                                                              . maybe-profile-catalog)
  (poo-flow-cicd-require "runtime manifest readiness requires a cicd check-map"
                         (poo-flow-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-field-rows
     (schema +poo-flow-cicd-runtime-manifest-readiness-schema+)
     (kind 'poo-flow.workflow.cicd.runtime-manifest-ready-map)
     (check-map (poo-flow-cicd-check-map-name check-map))
     (runtime-executed #f)
     (handoff-required #t)
     (dependency-graph
      (poo-flow-cicd-check-map->dependency-graph check-map))
     (checks
      (poo-flow-cicd-checks->runtime-manifest-readiness
       (poo-flow-cicd-check-map-checks check-map)
       profile-catalog)))))

;; Check-map manifest projection keeps CI/CD orchestration declarative: each
;; check contributes one runtime command manifest, and the wrapper records that
;; this is still report-only handoff data, not an execution result.
;; : (-> [PooFlowCicdCheck] [PooSandboxProfile] [Alist])
(def (poo-flow-cicd-checks->runtime-command-manifests checks profile-catalog)
  (cond
   ((null? checks) '())
   (else
    (cons (poo-flow-cicd-check->runtime-command-manifest
           (car checks)
           profile-catalog)
          (poo-flow-cicd-checks->runtime-command-manifests
           (cdr checks)
           profile-catalog)))))

;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check-map->runtime-command-manifests check-map
                                                          . maybe-profile-catalog)
  (poo-flow-cicd-require "runtime command manifests require a cicd check-map"
                         (poo-flow-cicd-check-map? check-map)
                         check-map)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-field-rows
     (schema +poo-flow-cicd-runtime-manifest-readiness-schema+)
     (kind 'poo-flow.workflow.cicd.runtime-command-manifest-map)
     (check-map (poo-flow-cicd-check-map-name check-map))
     (runtime-executed #f)
     (handoff-required #t)
     (dependency-graph
      (poo-flow-cicd-check-map->dependency-graph check-map))
     (manifests
      (poo-flow-cicd-checks->runtime-command-manifests
       (poo-flow-cicd-check-map-checks check-map)
       profile-catalog)))))
