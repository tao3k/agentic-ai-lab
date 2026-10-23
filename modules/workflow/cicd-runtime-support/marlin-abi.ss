;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Marlin ABI projection for CI/CD runtime handoff.

(import :yuanxu/modules/funflow/check-types
        :yuanxu/modules/funflow/check-objects
        :yuanxu/modules/funflow/check-funs
        :yuanxu/modules/funflow/projection-syntax
        :agentic-ai-lab/modules/workflow/cicd-sandbox
        :agentic-ai-lab/modules/workflow/cicd-runtime-support/checks)

(export agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
        agentic-ai-lab-cicd-runtime-command-manifest->marlin-handoff-entry
        agentic-ai-lab-cicd-runtime-command-manifests->marlin-handoff-entries
        agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
        agentic-ai-lab-cicd-check-map->marlin-runtime-handoff-abi)

;; Policy lookup stays nested under the manifest policy field. The ABI wrapper
;; should not depend on incidental top-level keys from runtime descriptors.
;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref manifest key default)
  (yuanxu-cicd-alist-ref
   (yuanxu-cicd-alist-ref manifest 'policy '())
   key
   default))

;; Marlin handoff entries are a stable ABI view over runtime command
;; manifests. They whitelist the fields Rust needs and keep Scheme-side POO
;; objects out of the payload.
;; : (-> Alist Alist)
(def (agentic-ai-lab-cicd-runtime-command-manifest->marlin-handoff-entry manifest)
  (yuanxu-cicd-field-rows
   (kind 'agentic-ai-lab.workflow.cicd.marlin-runtime-handoff-entry)
   (schema +yuanxu-cicd-marlin-runtime-handoff-abi-schema+)
   (request-schema
    (yuanxu-cicd-alist-ref manifest 'request-schema #f))
   (operation
    (yuanxu-cicd-alist-ref manifest 'operation #f))
   (request-id
    (yuanxu-cicd-alist-ref manifest 'request-id #f))
   (artifact-handle
    (yuanxu-cicd-alist-ref manifest 'artifact-handle #f))
   (argv
    (yuanxu-cicd-alist-ref manifest 'argv '()))
   (request
    (yuanxu-cicd-alist-ref manifest 'request '()))
   (policy
    (yuanxu-cicd-alist-ref manifest 'policy '()))
   (plan-id
    (yuanxu-cicd-alist-ref manifest 'plan-id #f))
   (node-id
    (yuanxu-cicd-alist-ref manifest 'node-id #f))
   (frontier
    (yuanxu-cicd-alist-ref manifest 'frontier '()))
   (metadata
    (yuanxu-cicd-alist-ref manifest 'metadata '()))
   (durable-task-id
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'durable-task-id
     #f))
   (action-class
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'action-class
     #f))
   (artifact-refs
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-refs
     '()))
   (artifact-provenance
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-provenance
     #f))
   (artifact-retention
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'artifact-retention
     #f))
   (sandbox-refs
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'sandbox-refs
     '()))
   (checkpoint-ref
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'checkpoint-ref
     #f))
   (compensation-refs
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'compensation-refs
     '()))
   (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
   (handoff-required
    (agentic-ai-lab-cicd-runtime-command-manifest-policy-ref
     manifest
     'handoff-required
     #t))
   (runtime-executed #f)
   (runtime-parses-scheme-source #f)
   (scheme-manufactures-runtime-handlers #f)))

;; Entry projection is a one-to-one map over command manifests. Keeping it a
;; map preserves order and prevents the ABI layer from inventing scheduler data.
;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-cicd-runtime-command-manifests->marlin-handoff-entries
      manifests)
  (cond
   ((null? manifests) '())
   (else
    (cons (agentic-ai-lab-cicd-runtime-command-manifest->marlin-handoff-entry
           (car manifests))
          (agentic-ai-lab-cicd-runtime-command-manifests->marlin-handoff-entries
           (cdr manifests))))))

;; The ABI map is the Marlin-facing workflow payload. It keeps the full
;; dependency graph and per-check command entries, but still records that no
;; runtime has executed in Scheme.
;; : (-> Alist Alist)
(def (agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
      manifest-map)
  (let ((manifests (yuanxu-cicd-alist-ref manifest-map 'manifests '())))
    (yuanxu-cicd-field-rows
     (schema +yuanxu-cicd-marlin-runtime-handoff-abi-schema+)
     (kind 'agentic-ai-lab.workflow.cicd.marlin-runtime-handoff-abi)
     (check-map
      (yuanxu-cicd-alist-ref manifest-map 'check-map #f))
     (runtime-owner +yuanxu-cicd-marlin-runtime-owner+)
     (runtime-executed #f)
     (runtime-parses-scheme-source #f)
     (scheme-manufactures-runtime-handlers #f)
     (handoff-required
      (yuanxu-cicd-alist-ref manifest-map 'handoff-required #t))
     (required-fields
      +yuanxu-cicd-marlin-runtime-handoff-abi-fields+)
     (manifest-count (length manifests))
     (dependency-graph
      (yuanxu-cicd-alist-ref manifest-map
                               'dependency-graph
                               '()))
     (entries
      (agentic-ai-lab-cicd-runtime-command-manifests->marlin-handoff-entries
       manifests)))))

;; The check-map shortcut keeps callers on the public POO object surface while
;; delegating ABI formation through the manifest-map boundary above.
;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-cicd-check-map->marlin-runtime-handoff-abi check-map
                                                               . maybe-profile-catalog)
  (let (profile-catalog (if (null? maybe-profile-catalog)
                          '()
                          (car maybe-profile-catalog)))
    (agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
     (agentic-ai-lab-cicd-check-map->runtime-command-manifests
      check-map
      profile-catalog))))
