;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Module boundary: loop-engine presentation code is isolated from the facade so
;;; the loop-only fast path can be optimized without widening the public API.

(export agentic-ai-lab-user-config-loop-engine-only-presentation)

(import (only-in :clan/poo/object object<-fun)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        (only-in :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-validation
                 agentic-ai-lab-sandbox-backend-capability-registry-validation-valid?
                 agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count
                 agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics)
        :agentic-ai-lab/modules/workflow/cicd-config
        :agentic-ai-lab/modules/workflow/cicd-runtime-command-config
        (only-in "config.ss"
                 agentic-ai-lab-user-config-loop-engine-intents
                 agentic-ai-lab-user-loop-engine-intent-ref)
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config-support)

;; Engineering note: loop-engine-only presentation uses lazy slots so heavy
;; receipt projections are computed only when a downstream caller asks for them.
;; : (-> UserConfig ModuleSelections UserSettings SettingKeys PresentationObject)
(def (agentic-ai-lab-user-config-loop-engine-only-presentation
      config
      selected-modules
      setting-object
      public-setting-keys)
  ;; Shared projections use Gerbil promises; each public slot is then cached by
  ;; the native :clan/poo object returned from object<-fun.
  (let ()
    ;; : (-> Void FeatureFacts)
    (def feature-fact-rows/promise
      (delay (yuanxu-user-config-feature-facts config)))
    (def (feature-fact-rows)
      (force feature-fact-rows/promise))
    ;; : (-> Void SandboxValidation)
    (def sandbox-validation/promise
      (delay
        (agentic-ai-lab-user-config-sandbox-backend-capability-registry-validation
         selected-modules)))
    (def (sandbox-validation)
      (force sandbox-validation/promise))
    ;; : (-> Void LoopIntentRows)
    (def loop-engine-intent-rows/promise
      (delay (agentic-ai-lab-user-config-loop-engine-intents config)))
    (def (loop-engine-intent-rows)
      (force loop-engine-intent-rows/promise))
    ;; : (-> Void LoopFieldValues)
    (def loop-engine-field-values/promise
      (delay
        (agentic-ai-lab-user-config-presentation-field-values
         (loop-engine-intent-rows)
         +agentic-ai-lab-user-config-presentation-loop-engine-fields+
         agentic-ai-lab-user-loop-engine-intent-ref)))
    (def (loop-engine-field-values)
      (force loop-engine-field-values/promise))
    ;; : (-> Symbol FieldValues)
    (def (loop-engine-field field)
      (agentic-ai-lab-user-config-presentation-field-values-ref
       (loop-engine-field-values)
       field))
    ;; : (-> Void RuntimeManifestAgreement)
    (def workflow-command-manifest-agreement/promise
      (delay
        (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
         '()
         '())))
    (def (workflow-command-manifest-agreement)
      (force workflow-command-manifest-agreement/promise))
    ;; : (-> Void HandoffBundle)
    (def workflow-handoff-bundle/promise
      (delay
        (agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
         '()
         '()
         (workflow-command-manifest-agreement)
         '()
         '()
         '())))
    (def (workflow-handoff-bundle)
      (force workflow-handoff-bundle/promise))
    ;; : (-> Void PresentationTrace)
    (def presentation-trace-rows/promise
      (delay
        (agentic-ai-lab-user-config-presentation-trace
         selected-modules
         (feature-fact-rows)
         '()
         '()
         '()
         '()
         '()
         '()
         '()
         '()
         '()
         '()
         (workflow-command-manifest-agreement)
         '()
         '()
         (workflow-handoff-bundle)
         (loop-engine-intent-rows)
         public-setting-keys)))
    (def (presentation-trace-rows)
      (force presentation-trace-rows/promise))
    (object<-fun
     (lambda (key)
       (case key
        ((kind) yuanxu-user-config-presentation-kind)
        ((module-count) (length selected-modules))
        ((module-keys) (yuanxu-user-config-module-keys config))
        ((modules) (map yuanxu-user-module-selection->alist
                       selected-modules))
        ((feature-count) (length selected-modules))
        ((feature-facts) (feature-fact-rows))
        ((sandbox-profile-derivation-count) 0)
        ((sandbox-profile-derivations) '())
        ((sandbox-backend-capability-registry-validation) (sandbox-validation))
        ((sandbox-backend-capability-registry-valid?) (agentic-ai-lab-sandbox-backend-capability-registry-validation-valid?
                   (sandbox-validation)))
        ((sandbox-backend-capability-registry-diagnostic-count) (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostic-count
                   (sandbox-validation)))
        ((sandbox-backend-capability-registry-diagnostics) (agentic-ai-lab-sandbox-backend-capability-registry-validation-diagnostics
                   (sandbox-validation)))
        ((session-intent-count) 0)
        ((session-intents) '())
        ((cicd-intent-count) 0)
        ((cicd-intents) '())
        ((workflow-cicd-pipeline-count) 0)
        ((workflow-cicd-pipelines) '())
        ((workflow-cicd-functional-dag-count) 0)
        ((workflow-cicd-functional-dags) '())
        ((workflow-cicd-pipeline-run-count) 0)
        ((workflow-cicd-pipeline-runs) '())
        ((workflow-cicd-pipeline-result-count) 0)
        ((workflow-cicd-pipeline-results) '())
        ((workflow-cicd-runtime-readiness-count) 0)
        ((workflow-cicd-runtime-readiness) '())
        ((workflow-cicd-runtime-command-manifest-map-count) 0)
        ((workflow-cicd-runtime-command-manifests) '())
        ((workflow-cicd-runtime-command-manifest-summary-count) 0)
        ((workflow-cicd-runtime-command-manifest-summaries) '())
        ((workflow-cicd-runtime-command-manifest-agreement) (workflow-command-manifest-agreement))
        ((workflow-cicd-runtime-command-manifest-agreement-valid?) (agentic-ai-lab-user-alist-ref
                   (workflow-command-manifest-agreement)
                   'valid?
                   #f))
        ((workflow-cicd-runtime-command-manifest-agreement-diagnostics) (agentic-ai-lab-user-alist-ref
                   (workflow-command-manifest-agreement)
                   'diagnostics
                   '()))
        ((workflow-cicd-marlin-runtime-handoff-abi-count) 0)
        ((workflow-cicd-marlin-runtime-handoff-abis) '())
        ((workflow-cicd-marlin-runtime-handoff-summary-count) 0)
        ((workflow-cicd-marlin-runtime-handoff-summaries) '())
        ((workflow-cicd-receipt-count) 0)
        ((workflow-cicd-receipts) '())
        ((workflow-cicd-sandbox-runtime-summaries) '())
        ((workflow-cicd-sandbox-handoff-summaries) '())
        ((workflow-cicd-sandbox-unresolved-profile-refs) '())
        ((loop-engine-intent-count) (length (loop-engine-intent-rows)))
        ((loop-engine-intents) (loop-engine-intent-rows))
        ((loop-engine-runtime-handoff-count) (length (loop-engine-intent-rows)))
        ((loop-engine-runtime-handoffs) (loop-engine-field 'runtime-handoff-facts))
        ((loop-engine-workflow-agreements) (loop-engine-field 'workflow-agreement))
        ((loop-engine-workflow-functional-dag-counts) (loop-engine-field 'workflow-functional-dag-count))
        ((loop-engine-workflow-functional-dags) (loop-engine-field 'workflow-functional-dags))
        ((loop-engine-receipt-contracts) (loop-engine-field 'receipt-contracts))
        ((loop-engine-result-contracts) (loop-engine-field 'result-contract))
        ((loop-engine-agent-profiles) (loop-engine-field 'agent-profiles))
        ((loop-engine-agent-harnesses) (loop-engine-field 'agent-harnesses))
        ((loop-engine-agent-sessions) (loop-engine-field 'agent-sessions))
        ((loop-engine-session-agent-graphs) (loop-engine-field 'session-agent-graph))
        ((loop-engine-session-agent-topology-traces) (loop-engine-field 'session-agent-topology-trace))
        ((loop-engine-workflow-runs) (loop-engine-field 'workflow-run))
        ((loop-engine-dispatch-receipts) (loop-engine-field 'dispatch-receipt))
        ((loop-engine-agent-operations) (loop-engine-field 'agent-operation))
        ((loop-engine-delegated-operations) (loop-engine-field 'delegated-operation))
        ((loop-engine-lineage-receipts) (loop-engine-field 'lineage-receipt))
        ((loop-engine-selector-receipts) (loop-engine-field 'selector-receipt))
        ((loop-engine-resource-dispatch-receipts) (loop-engine-field 'resource-dispatch-receipt))
        ((loop-engine-capability-receipts) (loop-engine-field 'capability-receipt))
        ((loop-engine-memory-receipts) (loop-engine-field 'memory-receipt))
        ((loop-engine-compression-receipts) (loop-engine-field 'compression-receipt))
        ((loop-engine-session-selector-receipts) (loop-engine-field 'session-selector-receipts))
        ((loop-engine-session-materialization-receipts) (loop-engine-field 'session-materialization-receipts))
        ((loop-engine-policy-extension-receipts) (loop-engine-field 'policy-extension-receipts))
        ((loop-engine-spec-evolution-reviews) (loop-engine-field 'spec-evolution-reviews))
        ((loop-engine-spec-evolution-human-audit-review-items) (loop-engine-field
                   'spec-evolution-human-audit-review-items))
        ((loop-engine-spec-evolution-runtime-manifest-rows) (loop-engine-field
                   'spec-evolution-runtime-manifest-rows))
        ((loop-engine-runtime-command-manifests) (loop-engine-field 'runtime-command-manifest))
        ((loop-engine-runtime-command-manifest-summaries) (loop-engine-field 'runtime-command-manifest-summary))
        ((loop-engine-sandbox-runtime-summaries) (loop-engine-field 'sandbox-runtime-summaries))
        ((loop-engine-sandbox-handoff-summaries) (loop-engine-field 'sandbox-handoff-summaries))
        ((loop-engine-sandbox-handoff-agreements) (loop-engine-field 'sandbox-handoff-agreement))
        ((loop-engine-sandbox-unresolved-profile-refs) (loop-engine-field 'sandbox-unresolved-profile-refs))
        ((loop-engine-runtime-snapshot-count) (length (loop-engine-intent-rows)))
        ((loop-engine-runtime-snapshots) (loop-engine-field 'runtime-snapshot))
        ((presentation-trace) (presentation-trace-rows))
        ((setting-count) (length public-setting-keys))
        ((setting-keys) public-setting-keys)
        ((settings) (yuanxu-user-settings->alist
                   setting-object
                   public-setting-keys))
        ((user-entrypoints) agentic-ai-lab-user-config-public-entrypoints)
        ((api-entrypoints) agentic-ai-lab-user-config-api-entrypoints)
        ((boundary) agentic-ai-lab-user-config-boundary)
        ((brand-name) agentic-ai-lab-brand-name)
        ((brand-group) agentic-ai-lab-brand-group)
        ((scheme-owner) agentic-ai-lab-scheme-owner)
        ((module-system-owner) agentic-ai-lab-module-system-owner)
        ((runtime-owner) "marlin-agent-core")
        ((runtime-parses-scheme-source) #f)
        ((scheme-manufactures-runtime-handlers) #f)
        ((package-management?) #f)
        ((dependency-installation?) #f)
        ((descriptor-realized?) #f)
        ((runtime-executed) #f)
        ((workflow-cicd-marlin-handoff-receipt-bundle) (workflow-handoff-bundle))
        ((workflow-cicd-marlin-handoff-receipt-bundle-runtime-executed) (agentic-ai-lab-user-alist-ref
                   (workflow-handoff-bundle)
                   'runtime-executed
                   #f))
        ((replayable) #t)
        (else (error "unknown loop-engine presentation slot" key))))
     keys:
     '(kind
       module-count
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
       loop-engine-receipt-contracts
       loop-engine-result-contracts
       loop-engine-agent-profiles
       loop-engine-agent-harnesses
       loop-engine-agent-sessions
       loop-engine-session-agent-graphs
       loop-engine-session-agent-topology-traces
       loop-engine-workflow-runs
       loop-engine-dispatch-receipts
       loop-engine-agent-operations
       loop-engine-delegated-operations
       loop-engine-lineage-receipts
       loop-engine-selector-receipts
       loop-engine-resource-dispatch-receipts
       loop-engine-capability-receipts
       loop-engine-memory-receipts
       loop-engine-compression-receipts
       loop-engine-session-selector-receipts
       loop-engine-session-materialization-receipts
       loop-engine-policy-extension-receipts
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
       settings
       user-entrypoints
       api-entrypoints
       boundary
       brand-name
       brand-group
       scheme-owner
       module-system-owner
       runtime-owner
       runtime-parses-scheme-source
       scheme-manufactures-runtime-handlers
       package-management?
       dependency-installation?
       descriptor-realized?
       runtime-executed
       workflow-cicd-marlin-handoff-receipt-bundle
       workflow-cicd-marlin-handoff-receipt-bundle-runtime-executed
       replayable))))
