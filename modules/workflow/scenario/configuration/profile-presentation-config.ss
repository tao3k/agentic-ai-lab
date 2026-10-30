;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user profile presentation receipts.
;;; Invariant: presentation is shallow inspection data and does not activate modules.

(import (only-in :clan/poo/object .ref object<-alist)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        :yuanxu/utilities/final-projection-syntax
        :yuanxu/profile-composition/user-profile)

(export agenticAiLabUserProfilePresentation
        agenticAiLabUserProfileSetPresentation)

;; : (-> [PooUserModuleSelection] [Symbol])
(def (agentic-ai-lab-user-profile-module-keys modules)
  (map yuanxu-user-module-selection-key modules))

;; : (-> [PooUserProfile] [Alist])
(def (agentic-ai-lab-user-profile-summaries profiles)
  (map agentic-ai-lab-user-profile-summary->alist profiles))

;;; Profile summaries avoid embedding POO profile objects in presentations.
;; : (-> PooUserProfile Alist)
(defpoo-final-projection
  agentic-ai-lab-user-profile-summary->alist (profile)
  (bindings ((modules (yuanxu-user-profile-modules profile))))
  (fields ((profile-name (yuanxu-user-profile-name profile))
           (module-count (length modules))
           (module-keys
            (agentic-ai-lab-user-profile-module-keys modules))
           (module-bundle-count
            (length (yuanxu-user-profile-module-bundles profile)))
           (setting-keys (yuanxu-user-profile-setting-keys profile))
           (descriptor-realized? #f)
           (runtime-executed #f))))

;; : (-> POOObject [Symbol] Alist)
(def (agentic-ai-lab-user-profile-presentation-copy-slots source keys)
  (map (lambda (key)
         (cons key (.ref source key)))
       keys))

;;; Profile presentation is the downstream view for the high-level user
;;; entrypoint. It keeps config fields shallow to avoid recursive POO printing.
;; : (-> PooUserProfile POOObject)
(def (agenticAiLabUserProfilePresentation profile)
  (let* ((config (yuanxuUserConfigFromProfile profile))
         (config-presentation
          (agenticAiLabUserConfigPresentation
           config
           (yuanxu-user-profile-setting-keys profile))))
    (object<-alist
     (append
      (list (cons 'kind yuanxu-user-profile-presentation-kind)
            (cons 'profile-name (yuanxu-user-profile-name profile))
            (cons 'module-bundle-count
                  (length (yuanxu-user-profile-module-bundles profile))))
      (agentic-ai-lab-user-profile-presentation-copy-slots
       config-presentation
       '(module-count
         module-keys
         modules
         feature-count
         feature-facts
         sandbox-profile-derivation-count
         sandbox-profile-derivations
         sandbox-backend-capability-registry-validation
         sandbox-backend-capability-registry-valid?
         sandbox-backend-capability-registry-diagnostic-count
         sandbox-backend-capability-registry-diagnostics
         session-intent-count
         session-intents
         cicd-intent-count
         cicd-intents
         workflow-cicd-pipeline-count
         workflow-cicd-pipelines
         workflow-cicd-functional-dag-count
         workflow-cicd-functional-dags
         workflow-cicd-pipeline-run-count
         workflow-cicd-pipeline-runs
         workflow-cicd-pipeline-result-count
         workflow-cicd-pipeline-results
         workflow-cicd-runtime-readiness-count
         workflow-cicd-runtime-readiness
         workflow-cicd-runtime-command-manifest-map-count
         workflow-cicd-runtime-command-manifests
         workflow-cicd-runtime-command-manifest-summary-count
         workflow-cicd-runtime-command-manifest-summaries
         workflow-cicd-runtime-command-manifest-agreement
         workflow-cicd-runtime-command-manifest-agreement-valid?
         workflow-cicd-runtime-command-manifest-agreement-diagnostics
         workflow-cicd-marlin-runtime-handoff-abi-count
         workflow-cicd-marlin-runtime-handoff-abis
         workflow-cicd-marlin-runtime-handoff-summary-count
         workflow-cicd-marlin-runtime-handoff-summaries
         workflow-cicd-marlin-handoff-receipt-bundle
         workflow-cicd-marlin-handoff-receipt-bundle-runtime-executed
         workflow-cicd-receipt-count
         workflow-cicd-receipts
         workflow-cicd-sandbox-runtime-summaries
         workflow-cicd-sandbox-handoff-summaries
         workflow-cicd-sandbox-unresolved-profile-refs
         loop-engine-intent-count
         loop-engine-intents
         loop-engine-runtime-handoff-count
         loop-engine-runtime-handoffs
         loop-engine-workflow-agreements
         loop-engine-workflow-functional-dag-counts
         loop-engine-workflow-functional-dags
         loop-engine-result-contracts
         loop-engine-agent-profiles
         loop-engine-agent-harnesses
         loop-engine-agent-sessions
         loop-engine-session-agent-topology-traces
         loop-engine-workflow-runs
         loop-engine-dispatch-receipts
         loop-engine-agent-operations
         loop-engine-delegated-operations
         loop-engine-spec-evolution-reviews
         loop-engine-spec-evolution-human-audit-review-items
         loop-engine-spec-evolution-runtime-manifest-rows
         loop-engine-runtime-command-manifests
         loop-engine-runtime-command-manifest-summaries
         loop-engine-sandbox-runtime-summaries
         loop-engine-sandbox-handoff-summaries
         loop-engine-sandbox-handoff-agreements
         loop-engine-sandbox-unresolved-profile-refs
         loop-engine-runtime-snapshot-count
         loop-engine-runtime-snapshots
         presentation-trace
         setting-count
         setting-keys
         settings))
      (list
       (cons 'config-presentation-kind (.ref config-presentation 'kind))
       (cons 'config-module-count (.ref config-presentation 'module-count))
       (cons 'user-entrypoints agentic-ai-lab-user-config-public-entrypoints)
       (cons 'api-entrypoints agentic-ai-lab-user-config-api-entrypoints)
       (cons 'boundary agentic-ai-lab-user-config-boundary)
       (cons 'brand-name agentic-ai-lab-brand-name)
       (cons 'brand-group agentic-ai-lab-brand-group)
       (cons 'scheme-owner agentic-ai-lab-scheme-owner)
       (cons 'module-system-owner agentic-ai-lab-module-system-owner)
       (cons 'runtime-owner "marlin-agent-core")
       (cons 'package-management? #f)
       (cons 'dependency-installation? #f)
       (cons 'descriptor-realized? #f)
       (cons 'runtime-executed #f)
       (cons 'replayable #t))))))

;;; Profile set presentation is the inspectable registry view. It keeps the
;;; selected profile shallow and does not trigger descriptor realization.
;; : (-> PooUserProfileSet POOObject)
(def (agenticAiLabUserProfileSetPresentation profile-set)
  (let ((selected-profile
         (yuanxu-user-profile-set-default-profile profile-set)))
    (object<-alist
     (list
      (cons 'kind yuanxu-user-profile-set-presentation-kind)
      (cons 'profile-set-name
            (yuanxu-user-profile-set-name profile-set))
      (cons 'default-profile-name
            (yuanxu-user-profile-set-default-profile-name profile-set))
      (cons 'selected-profile-name
            (if selected-profile
              (yuanxu-user-profile-name selected-profile)
              #f))
      (cons 'selected-profile? (not (not selected-profile)))
      (cons 'profile-count
            (length (yuanxu-user-profile-set-profiles profile-set)))
      (cons 'profile-names
            (yuanxu-user-profile-set-profile-names profile-set))
      (cons 'profiles
            (agentic-ai-lab-user-profile-summaries
             (yuanxu-user-profile-set-profiles profile-set)))
      (cons 'user-entrypoints agentic-ai-lab-user-config-public-entrypoints)
      (cons 'api-entrypoints agentic-ai-lab-user-config-api-entrypoints)
      (cons 'boundary agentic-ai-lab-user-config-boundary)
      (cons 'brand-name agentic-ai-lab-brand-name)
      (cons 'brand-group agentic-ai-lab-brand-group)
      (cons 'scheme-owner agentic-ai-lab-scheme-owner)
      (cons 'module-system-owner agentic-ai-lab-module-system-owner)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'package-management? #f)
      (cons 'dependency-installation? #f)
      (cons 'descriptor-realized? #f)
      (cons 'runtime-executed #f)
      (cons 'replayable #t)))))
