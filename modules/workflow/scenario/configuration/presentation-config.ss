;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Facade boundary: public user-config presentation exports remain stable while
;;; loop-engine and workflow-CI scenario builders live in focused modules.

(export agenticAiLabUserConfigPresentation)

(import (only-in :clan/poo/object object<-alist)
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy
        :agentic-ai-lab/modules/workflow/interface
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :yuanxu/module-system/observability/presentation
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        :agentic-ai-lab/modules/workflow/cicd-config
        :agentic-ai-lab/modules/workflow/cicd-pipeline-run-config
        :agentic-ai-lab/modules/session/presentation
        (only-in :agentic-ai-lab/modules/loop-engine/config
                 agentic-ai-lab-user-config-loop-engine-intents
                 agentic-ai-lab-user-loop-engine-intent-ref)
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config-support
        :agentic-ai-lab/modules/loop-engine/presentation
        :agentic-ai-lab/modules/workflow/presentation)

;; : (-> ModuleSelections Bool)
(def (agentic-ai-lab-user-config-loop-engine-only? selected-modules)
  (cond
   ((null? selected-modules) #f)
   (else
    (let loop ((modules selected-modules))
      (cond
       ((null? modules) #t)
       ((equal? (yuanxu-user-module-selection-key (car modules))
                '(flow . loop-engine))
        (loop (cdr modules)))
       (else #f))))))

;; : (-> ModuleSelection Bool)
(def (agentic-ai-lab-user-config-workflow-cicd-focused-selection? selection)
  (or (agentic-ai-lab-user-module-selection-workflow-cicd-check-map selection)
      (eq? (car (yuanxu-user-module-selection-key selection)) 'sandbox)))

;; : (-> ModuleSelections Bool)
(def (agentic-ai-lab-user-config-workflow-cicd-focused? selected-modules)
  (and (ormap agentic-ai-lab-user-module-selection-workflow-cicd-check-map
              selected-modules)
       (andmap agentic-ai-lab-user-config-workflow-cicd-focused-selection?
               selected-modules)))

;; Engineering note: mixed-module presentation remains in the facade because it
;; is the public compatibility shape joining sandbox, session, workflow, and loop
;; projections.
;; : (-> UserConfig SettingKeys PresentationObject)
(def (agenticAiLabUserConfigPresentation config . maybe-setting-keys)
  ;; Engineering note: branch order preserves the loop-only fast path first, then
  ;; the workflow-CI focused path, and keeps the full mixed fallback last.
  (let ((selected-modules
         (yuanxu-user-config-modules config))
        (setting-object
         (yuanxu-user-config-settings config))
        (public-setting-keys
         (if (null? maybe-setting-keys) '() (car maybe-setting-keys))))
    (if (agentic-ai-lab-user-config-loop-engine-only? selected-modules)
      (agentic-ai-lab-user-config-loop-engine-only-presentation
       config
       selected-modules
       setting-object
       public-setting-keys)
      (if (agentic-ai-lab-user-config-workflow-cicd-focused? selected-modules)
        (agentic-ai-lab-user-config-workflow-cicd-focused-presentation
         config
         selected-modules
         setting-object
         public-setting-keys)
        (let* ((feature-fact-rows
                (yuanxu-user-config-feature-facts config))
               (sandbox-profile-derivation-rows
                (agentic-ai-lab-user-config-sandbox-profile-derivations
                 selected-modules))
               (sandbox-backend-capability-registry-validation
                (agentic-ai-lab-user-config-sandbox-backend-capability-registry-validation
                 selected-modules))
               (session-intent-rows
                (agentic-ai-lab-user-config-session-intents config))
               (cicd-intent-rows
                (agentic-ai-lab-user-config-cicd-intents config))
               (workflow-cicd-runtime-projection
                (agentic-ai-lab-user-config-workflow-cicd-runtime-projection config))
               (workflow-cicd-check-maps
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'check-maps
                 '()))
               (workflow-cicd-functional-dag-rows
                (agentic-ai-lab-user-config-workflow-cicd-functional-dag-rows
                 config))
               (workflow-cicd-pipeline-run-rows
                (agentic-ai-lab-user-config-workflow-cicd-pipeline-runs config))
               (workflow-cicd-pipeline-result-rows
                (agentic-ai-lab-user-config-workflow-cicd-pipeline-results config))
               (workflow-cicd-readiness-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'runtime-readiness
                 '()))
               (workflow-cicd-runtime-command-manifest-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'runtime-command-manifests
                 '()))
               (workflow-cicd-runtime-command-manifest-summary-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'runtime-command-manifest-summaries
                 '()))
               (workflow-cicd-runtime-command-manifest-agreement-report
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'runtime-command-manifest-agreement
                 '()))
               (workflow-cicd-marlin-runtime-handoff-abi-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'marlin-runtime-handoff-abis
                 '()))
               (workflow-cicd-marlin-runtime-handoff-abi-summary-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'marlin-runtime-handoff-summaries
                 '()))
               (workflow-cicd-receipt-rows
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'receipts
                 '()))
               (workflow-cicd-marlin-handoff-receipt-bundle-row
                (agentic-ai-lab-user-alist-ref
                 workflow-cicd-runtime-projection
                 'marlin-handoff-receipt-bundle
                 '()))
               (loop-engine-intent-rows
                (agentic-ai-lab-user-config-loop-engine-intents config))
               (presentation-trace-rows
                (agentic-ai-lab-user-config-presentation-trace
                 selected-modules
                 feature-fact-rows
                 sandbox-profile-derivation-rows
                 session-intent-rows
                 cicd-intent-rows
                 workflow-cicd-check-maps
                 workflow-cicd-functional-dag-rows
                 workflow-cicd-pipeline-run-rows
                 workflow-cicd-pipeline-result-rows
                 workflow-cicd-readiness-rows
                 workflow-cicd-runtime-command-manifest-rows
                 workflow-cicd-runtime-command-manifest-summary-rows
                 workflow-cicd-runtime-command-manifest-agreement-report
                 workflow-cicd-marlin-runtime-handoff-abi-rows
                 workflow-cicd-receipt-rows
                 workflow-cicd-marlin-handoff-receipt-bundle-row
                 loop-engine-intent-rows
                 public-setting-keys)))
          (let ((workflow-cicd-sandbox-runtime-summary-rows
                 (agentic-ai-lab-user-alist-ref
                  workflow-cicd-runtime-projection
                  'sandbox-runtime-summaries
                  '()))
                (workflow-cicd-sandbox-handoff-summary-rows
                 (agentic-ai-lab-user-alist-ref
                  workflow-cicd-runtime-projection
                  'sandbox-handoff-summaries
                  '()))
                (workflow-cicd-sandbox-unresolved-profile-ref-rows
                 (agentic-ai-lab-user-alist-ref
                  workflow-cicd-runtime-projection
                  'sandbox-unresolved-profile-refs
                  '())))
            (let ((loop-engine-field-values
                   (agentic-ai-lab-user-config-presentation-field-values
                    loop-engine-intent-rows
                    +agentic-ai-lab-user-config-presentation-loop-engine-fields+
                    agentic-ai-lab-user-loop-engine-intent-ref)))
              (object<-alist
               (append
                (list
                 (cons 'kind yuanxu-user-config-presentation-kind)
                 (cons 'module-count (length selected-modules))
                 (cons 'module-keys (yuanxu-user-config-module-keys config))
                 (cons 'modules
                       (map yuanxu-user-module-selection->alist
                            selected-modules))
                 (cons 'feature-count (length selected-modules))
                 (cons 'feature-facts feature-fact-rows)
                 (cons 'sandbox-profile-derivation-count
                       (length sandbox-profile-derivation-rows))
                 (cons 'sandbox-profile-derivations
                       sandbox-profile-derivation-rows)
                 (cons 'sandbox-backend-capability-registry-validation
                       sandbox-backend-capability-registry-validation)
                 (cons 'sandbox-backend-capability-registry-valid?
                       (agentic-ai-lab-sandbox-backend-capability-registry-validation-valid?
                        sandbox-backend-capability-registry-validation))
                 (cons 'sandbox-backend-capability-registry-diagnostic-count
                       (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count
                        sandbox-backend-capability-registry-validation))
                 (cons 'sandbox-backend-capability-registry-diagnostics
                       (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics
                        sandbox-backend-capability-registry-validation))
                 (cons 'session-intent-count
                       (length session-intent-rows))
                 (cons 'session-intents session-intent-rows)
                 (cons 'cicd-intent-count (length cicd-intent-rows))
                 (cons 'cicd-intents cicd-intent-rows)
                 (cons 'workflow-cicd-pipeline-count
                       (length workflow-cicd-check-maps))
                 (cons 'workflow-cicd-pipelines
                       (agentic-ai-lab-user-config-presentation-workflow-cicd-check-map-names
                        workflow-cicd-check-maps))
                 (cons 'workflow-cicd-functional-dag-count
                       (length workflow-cicd-functional-dag-rows))
                 (cons 'workflow-cicd-functional-dags
                       workflow-cicd-functional-dag-rows)
                 (cons 'workflow-cicd-pipeline-run-count
                       (length workflow-cicd-pipeline-run-rows))
                 (cons 'workflow-cicd-pipeline-runs
                       workflow-cicd-pipeline-run-rows)
                 (cons 'workflow-cicd-pipeline-result-count
                       (length workflow-cicd-pipeline-result-rows))
                 (cons 'workflow-cicd-pipeline-results
                       workflow-cicd-pipeline-result-rows)
                 (cons 'workflow-cicd-runtime-readiness-count
                       (length workflow-cicd-readiness-rows))
                 (cons 'workflow-cicd-runtime-readiness
                       workflow-cicd-readiness-rows)
                 (cons 'workflow-cicd-runtime-command-manifest-map-count
                       (length workflow-cicd-runtime-command-manifest-rows))
                 (cons 'workflow-cicd-runtime-command-manifests
                       workflow-cicd-runtime-command-manifest-rows)
                 (cons 'workflow-cicd-runtime-command-manifest-summary-count
                       (length
                        workflow-cicd-runtime-command-manifest-summary-rows))
                 (cons 'workflow-cicd-runtime-command-manifest-summaries
                       workflow-cicd-runtime-command-manifest-summary-rows)
                 (cons 'workflow-cicd-runtime-command-manifest-agreement
                       workflow-cicd-runtime-command-manifest-agreement-report)
                 (cons 'workflow-cicd-runtime-command-manifest-agreement-valid?
                       (agentic-ai-lab-user-alist-ref
                        workflow-cicd-runtime-command-manifest-agreement-report
                        'valid?
                        #f))
                 (cons 'workflow-cicd-runtime-command-manifest-agreement-diagnostics
                       (agentic-ai-lab-user-alist-ref
                        workflow-cicd-runtime-command-manifest-agreement-report
                        'diagnostics
                        '()))
                 (cons 'workflow-cicd-marlin-runtime-handoff-abi-count
                       (length workflow-cicd-marlin-runtime-handoff-abi-rows))
                 (cons 'workflow-cicd-marlin-runtime-handoff-abis
                       workflow-cicd-marlin-runtime-handoff-abi-rows)
                 (cons 'workflow-cicd-marlin-runtime-handoff-summary-count
                       (length
                        workflow-cicd-marlin-runtime-handoff-abi-summary-rows))
                 (cons 'workflow-cicd-marlin-runtime-handoff-summaries
                       workflow-cicd-marlin-runtime-handoff-abi-summary-rows)
                 (cons 'workflow-cicd-receipt-count
                       (length workflow-cicd-receipt-rows))
                 (cons 'workflow-cicd-receipts workflow-cicd-receipt-rows)
                 (cons 'workflow-cicd-sandbox-runtime-summaries
                       workflow-cicd-sandbox-runtime-summary-rows)
                 (cons 'workflow-cicd-sandbox-handoff-summaries
                       workflow-cicd-sandbox-handoff-summary-rows)
                 (cons 'workflow-cicd-sandbox-unresolved-profile-refs
                       workflow-cicd-sandbox-unresolved-profile-ref-rows))
                (agentic-ai-lab-user-config-presentation-loop-engine-slots
                 loop-engine-field-values
                 loop-engine-intent-rows)
                (list
                 (cons 'presentation-trace presentation-trace-rows)
                 (cons 'setting-count (length public-setting-keys))
                 (cons 'setting-keys public-setting-keys)
                 (cons 'settings
                       (yuanxu-user-settings->alist
                        setting-object
                        public-setting-keys))
                 (cons 'user-entrypoints
                       agentic-ai-lab-user-config-public-entrypoints)
                 (cons 'api-entrypoints agentic-ai-lab-user-config-api-entrypoints)
                 (cons 'boundary agentic-ai-lab-user-config-boundary)
                 (cons 'brand-name agentic-ai-lab-brand-name)
                 (cons 'brand-group agentic-ai-lab-brand-group)
                 (cons 'scheme-owner agentic-ai-lab-scheme-owner)
                 (cons 'module-system-owner agentic-ai-lab-module-system-owner)
                 (cons 'runtime-owner "marlin-agent-core")
                 (cons 'runtime-parses-scheme-source #f)
                 (cons 'scheme-manufactures-runtime-handlers #f)
                 (cons 'package-management? #f)
                 (cons 'dependency-installation? #f)
                 (cons 'descriptor-realized? #f)
                 (cons 'runtime-executed #f)
                 (cons 'workflow-cicd-marlin-handoff-receipt-bundle
                       workflow-cicd-marlin-handoff-receipt-bundle-row)
                 (cons 'workflow-cicd-marlin-handoff-receipt-bundle-runtime-executed
                       (agentic-ai-lab-user-alist-ref
                        workflow-cicd-marlin-handoff-receipt-bundle-row
                        'runtime-executed
                        #f))
                 (cons 'replayable #t)))))))))))
;;; Facade boundary: public user-config presentation exports remain stable while
;;; loop-engine and workflow-CI scenario builders live in focused modules.

(export agentic-ai-lab-user-config-presentation-trace
        agentic-ai-lab-user-config-sandbox-profile-derivations)
