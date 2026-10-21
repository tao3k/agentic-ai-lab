;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Marlin ABI projection for CI/CD runtime handoff.

(import :core/modules/funflow/check-types
        :core/modules/funflow/check-objects
        :core/modules/funflow/check-funs
        :core/modules/funflow/projection-syntax
        :poo-flow/modules/workflow/cicd-sandbox
        :poo-flow/modules/workflow/cicd-runtime-support/checks)

(export poo-flow-cicd-runtime-command-manifest-policy-ref
        poo-flow-cicd-runtime-command-manifest->marlin-handoff-entry
        poo-flow-cicd-runtime-command-manifests->marlin-handoff-entries
        poo-flow-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
        poo-flow-cicd-check-map->marlin-runtime-handoff-abi)

;; Policy lookup stays nested under the manifest policy field. The ABI wrapper
;; should not depend on incidental top-level keys from runtime descriptors.
;; : (-> Alist Symbol Value Value)
(def (poo-flow-cicd-runtime-command-manifest-policy-ref manifest key default)
  (poo-flow-cicd-alist-ref
   (poo-flow-cicd-alist-ref manifest 'policy '())
   key
   default))

;; Marlin handoff entries are a stable ABI view over runtime command
;; manifests. They whitelist the fields Rust needs and keep Scheme-side POO
;; objects out of the payload.
;; : (-> Alist Alist)
(def (poo-flow-cicd-runtime-command-manifest->marlin-handoff-entry manifest)
  (poo-flow-cicd-field-rows
   (kind 'poo-flow.workflow.cicd.marlin-runtime-handoff-entry)
   (schema +poo-flow-cicd-marlin-runtime-handoff-abi-schema+)
   (request-schema
    (poo-flow-cicd-alist-ref manifest 'request-schema #f))
   (operation
    (poo-flow-cicd-alist-ref manifest 'operation #f))
   (request-id
    (poo-flow-cicd-alist-ref manifest 'request-id #f))
   (artifact-handle
    (poo-flow-cicd-alist-ref manifest 'artifact-handle #f))
   (argv
    (poo-flow-cicd-alist-ref manifest 'argv '()))
   (request
    (poo-flow-cicd-alist-ref manifest 'request '()))
   (policy
    (poo-flow-cicd-alist-ref manifest 'policy '()))
   (plan-id
    (poo-flow-cicd-alist-ref manifest 'plan-id #f))
   (node-id
    (poo-flow-cicd-alist-ref manifest 'node-id #f))
   (frontier
    (poo-flow-cicd-alist-ref manifest 'frontier '()))
   (metadata
    (poo-flow-cicd-alist-ref manifest 'metadata '()))
   (durable-task-id
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'durable-task-id
     #f))
   (action-class
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'action-class
     #f))
   (artifact-refs
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-refs
     '()))
   (artifact-provenance
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-provenance
     #f))
   (artifact-retention
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-retention
     #f))
   (sandbox-refs
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'sandbox-refs
     '()))
   (checkpoint-ref
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'checkpoint-ref
     #f))
   (compensation-refs
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'compensation-refs
     '()))
   (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
   (handoff-required
    (poo-flow-cicd-runtime-command-manifest-policy-ref
     manifest
     'handoff-required
     #t))
   (runtime-executed #f)
   (runtime-parses-scheme-source #f)
   (scheme-manufactures-runtime-handlers #f)))

;; Entry projection is a one-to-one map over command manifests. Keeping it a
;; map preserves order and prevents the ABI layer from inventing scheduler data.
;; : (-> [Alist] [Alist])
(def (poo-flow-cicd-runtime-command-manifests->marlin-handoff-entries
      manifests)
  (cond
   ((null? manifests) '())
   (else
    (cons (poo-flow-cicd-runtime-command-manifest->marlin-handoff-entry
           (car manifests))
          (poo-flow-cicd-runtime-command-manifests->marlin-handoff-entries
           (cdr manifests))))))

;; The ABI map is the Marlin-facing workflow payload. It keeps the full
;; dependency graph and per-check command entries, but still records that no
;; runtime has executed in Scheme.
;; : (-> Alist Alist)
(def (poo-flow-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
      manifest-map)
  (let ((manifests (poo-flow-cicd-alist-ref manifest-map 'manifests '())))
    (poo-flow-cicd-field-rows
     (schema +poo-flow-cicd-marlin-runtime-handoff-abi-schema+)
     (kind 'poo-flow.workflow.cicd.marlin-runtime-handoff-abi)
     (check-map
      (poo-flow-cicd-alist-ref manifest-map 'check-map #f))
     (runtime-owner +poo-flow-cicd-marlin-runtime-owner+)
     (runtime-executed #f)
     (runtime-parses-scheme-source #f)
     (scheme-manufactures-runtime-handlers #f)
     (handoff-required
      (poo-flow-cicd-alist-ref manifest-map 'handoff-required #t))
     (required-fields
      +poo-flow-cicd-marlin-runtime-handoff-abi-fields+)
     (manifest-count (length manifests))
     (dependency-graph
      (poo-flow-cicd-alist-ref manifest-map
                               'dependency-graph
                               '()))
     (entries
      (poo-flow-cicd-runtime-command-manifests->marlin-handoff-entries
       manifests)))))

;; The check-map shortcut keeps callers on the public POO object surface while
;; delegating ABI formation through the manifest-map boundary above.
;; : (-> PooFlowCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-cicd-check-map->marlin-runtime-handoff-abi check-map
                                                               . maybe-profile-catalog)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (poo-flow-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
     (poo-flow-cicd-check-map->runtime-command-manifests
      check-map
      profile-catalog))))
