;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream durable artifact policy Case imported through its
;;; precise owner when selected.
;;; Invariant: this declares artifact policy validation data only; Scheme does
;;; not store, publish, index, or retain artifacts at runtime.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-policy)

(export agentic-ai-lab-custom-my-module-durable-artifact-case)

(def agentic-ai-lab-custom-my-module-durable-artifact-case
  (let* ((custom-artifact-profile
        (artifact-profile custom-report
          :extends report/base
          :scope (tenant project workflow session human-handoff publish-channel)
          :storage (file-system object-store vector-index checkpoint-store)
          :analysis (checksum schema provenance citation-trace)
          :publish (human-approved proof-gated)
          :retention (project-retained audit-log)
          :lifecycle (created stored indexed retained published)))
       (custom-artifact-database
        (database-profile turso
          :classes (artifact metadata vector)
          :capabilities (concurrent-writes
                         local-first-push-pull
                         vector-index)
          :storage (file-system object-store vector-index checkpoint-store)))
       (custom-artifact
        (durable-artifact artifact/custom-report
          :kind report
          :scope (tenant project workflow session human-handoff publish-channel)
          :storage-class file-system
          :state created
          :producer agent/build
          :owner project/team
          :sandbox (sandbox/build)
          :checksum checksum/sha256
          :analysis (checksum schema provenance citation-trace)
          :index vector-index
          :call read-only
          :publish (human-approved proof-gated)
          :retention project-retained
          :grants (actor/reviewer)))
       (artifact-policy-receipt
        (agentic-ai-lab-durable-artifact-validate
         custom-artifact
         custom-artifact-profile
         custom-artifact-database))
       (artifact-manifest-receipt
        (agentic-ai-lab-durable-artifact-manifest
         custom-artifact
         custom-artifact-profile
         custom-artifact-database
         '((manifest-id . artifact-manifest/custom-report)
           (metadata . ((source . user-interface)
                        (case . durable-artifact))))))
       (artifact-handoff
        (agentic-ai-lab-durable-artifact-manifest->marlin-handoff
         artifact-manifest-receipt)))
  (list
   (cons 'kind 'agentic-ai-lab.custom.durable-artifact)
   (cons 'profile
         (agentic-ai-lab-artifact-profile->alist custom-artifact-profile))
   (cons 'database
         (agentic-ai-lab-artifact-database-profile->alist custom-artifact-database))
   (cons 'artifact
         (agentic-ai-lab-durable-artifact->alist custom-artifact))
   (cons 'policy-receipt
         (agentic-ai-lab-durable-artifact-policy-receipt->alist
          artifact-policy-receipt))
   (cons 'manifest-receipt
         (agentic-ai-lab-durable-artifact-manifest-receipt->alist
          artifact-manifest-receipt))
   (cons 'marlin-handoff artifact-handoff)
   (cons 'valid?
         (agentic-ai-lab-durable-artifact-policy-receipt-valid?
          artifact-policy-receipt))
   (cons 'runtime-executed #f))))
