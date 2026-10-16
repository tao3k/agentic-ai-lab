;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Module boundary: workflow-CI presentation code owns runtime handoff projection

;;; slots while the facade keeps only scenario selection.

(export poo-flow-user-config-workflow-cicd-focused-presentation)

(import (only-in :clan/poo/object .ref object<-fun)
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/entrypoints
        :poo-flow/modules/sandbox-core/backend-capability-catalog
        (only-in :poo-flow/modules/sandbox-core/profile-support/policy-backend-validation
                 poo-flow-sandbox-backend-capability-registry-validation-valid?
                 poo-flow-sandbox-backend-capability-registry-validation-diagnostic-count
                 poo-flow-sandbox-backend-capability-registry-validation-diagnostics)
        :poo-flow/modules/workflow/cicd-config
        :poo-flow/modules/workflow/cicd-pipeline-run-config
        :poo-flow/modules/workflow/cicd-runtime-command-config
        :poo-flow/modules/workflow/scenario/configuration/presentation-config-support)

;; Engineering note: workflow-CI focused presentation keeps runtime projection
;; memoized so command, handoff, and receipt rows share one projection pass.
;; : (-> UserConfig ModuleSelections UserSettings SettingKeys PresentationObject)
(def (poo-flow-user-config-workflow-cicd-focused-presentation
      config
      selected-modules
      setting-object
      public-setting-keys)
  ;; Shared projections use Gerbil promises; object<-fun supplies the public
  ;; per-slot cache without exposing the POO slot-spec implementation.
  (let ()
    ;; : (-> Void FeatureFacts)
    (def feature-fact-rows/promise
      (delay (poo-flow-user-config-feature-facts config)))
    (def (feature-fact-rows)
      (force feature-fact-rows/promise))
    ;; : (-> Void DerivationRows)
    (def sandbox-profile-derivation-rows/promise
      (delay
        (poo-flow-user-config-sandbox-profile-derivations selected-modules)))
    (def (sandbox-profile-derivation-rows)
      (force sandbox-profile-derivation-rows/promise))
    ;; : (-> Void SandboxValidation)
    (def sandbox-validation/promise
      (delay
        (poo-flow-user-config-sandbox-backend-capability-registry-validation
         selected-modules)))
    (def (sandbox-validation)
      (force sandbox-validation/promise))
    ;; : (-> Void CicdIntents)
    (def cicd-intent-rows/promise
      (delay (poo-flow-user-config-cicd-intents config)))
    (def (cicd-intent-rows)
      (force cicd-intent-rows/promise))
    ;; : (-> Void RuntimeProjection)
    (def workflow-projection/promise
      (delay
        (poo-flow-user-config-workflow-cicd-runtime-projection-object config)))
    (def (workflow-projection)
      (force workflow-projection/promise))
    ;; : (-> Symbol FieldDefault FieldValue)
    (def (workflow-field key _default-value)
      (.ref (workflow-projection) key))
    ;; : (-> Void CicdCheckMaps)
    (def (workflow-check-maps)
      (workflow-field 'check-maps '()))
    ;; : (-> Void FunctionalDagRows)
    (def workflow-functional-dag-rows/promise
      (delay
        (poo-flow-user-workflow-cicd-functional-dag-rows
         (workflow-check-maps))))
    (def (workflow-functional-dag-rows)
      (force workflow-functional-dag-rows/promise))
    ;; : (-> Void PipelineRunRows)
    (def workflow-pipeline-run-rows/promise
      (delay (poo-flow-user-config-workflow-cicd-pipeline-runs config)))
    (def (workflow-pipeline-run-rows)
      (force workflow-pipeline-run-rows/promise))
    ;; : (-> Void PipelineResultRows)
    (def workflow-pipeline-result-rows/promise
      (delay (poo-flow-user-config-workflow-cicd-pipeline-results config)))
    (def (workflow-pipeline-result-rows)
      (force workflow-pipeline-result-rows/promise))
    ;; : (-> Void RuntimeReadinessRows)
    (def (workflow-readiness-rows)
      (workflow-field 'runtime-readiness '()))
    ;; : (-> Void RuntimeCommandRows)
    (def (workflow-runtime-command-manifest-rows)
      (workflow-field 'runtime-command-manifests '()))
    ;; : (-> Void RuntimeCommandSummaryRows)
    (def (workflow-runtime-command-manifest-summary-rows)
      (workflow-field 'runtime-command-manifest-summaries '()))
    ;; : (-> Void RuntimeAgreementReport)
    (def (workflow-runtime-command-manifest-agreement)
      (workflow-field 'runtime-command-manifest-agreement '()))
    ;; : (-> Void HandoffAbiRows)
    (def (workflow-marlin-runtime-handoff-abi-rows)
      (workflow-field 'marlin-runtime-handoff-abis '()))
    ;; : (-> Void HandoffSummaryRows)
    (def (workflow-marlin-runtime-handoff-summary-rows)
      (workflow-field 'marlin-runtime-handoff-summaries '()))
    ;; : (-> Void ReceiptRows)
    (def (workflow-receipt-rows)
      (workflow-field 'receipts '()))
    ;; : (-> Void HandoffBundle)
    (def (workflow-handoff-bundle)
      (workflow-field 'marlin-handoff-receipt-bundle '()))
    ;; : (-> Void PresentationTrace)
    (def presentation-trace-rows/promise
      (delay
        (poo-flow-user-config-presentation-trace
         selected-modules
         (feature-fact-rows)
         (sandbox-profile-derivation-rows)
         '()
         (cicd-intent-rows)
         (workflow-check-maps)
         (workflow-functional-dag-rows)
         (workflow-pipeline-run-rows)
         (workflow-pipeline-result-rows)
         (workflow-readiness-rows)
         (workflow-runtime-command-manifest-rows)
         (workflow-runtime-command-manifest-summary-rows)
         (workflow-runtime-command-manifest-agreement)
         (workflow-marlin-runtime-handoff-abi-rows)
         (workflow-receipt-rows)
         (workflow-handoff-bundle)
         '()
         public-setting-keys)))
    (def (presentation-trace-rows)
      (force presentation-trace-rows/promise))
    (object<-fun
     (lambda (key)
       (case key
        ((kind) poo-flow-user-config-presentation-kind)
        ((module-count) (length selected-modules))
        ((module-keys) (poo-flow-user-config-module-keys config))
        ((modules) (map poo-flow-user-module-selection->alist
                       selected-modules))
        ((feature-count) (length selected-modules))
        ((feature-facts) (feature-fact-rows))
        ((sandbox-profile-derivation-count) (length (sandbox-profile-derivation-rows)))
        ((sandbox-profile-derivations) (sandbox-profile-derivation-rows))
        ((sandbox-backend-capability-registry-validation) (sandbox-validation))
        ((sandbox-backend-capability-registry-valid?) (poo-flow-sandbox-backend-capability-registry-validation-valid?
                   (sandbox-validation)))
        ((sandbox-backend-capability-registry-diagnostic-count) (poo-flow-sandbox-backend-capability-registry-validation-diagnostic-count
                   (sandbox-validation)))
        ((sandbox-backend-capability-registry-diagnostics) (poo-flow-sandbox-backend-capability-registry-validation-diagnostics
                   (sandbox-validation)))
        ((session-intent-count) 0)
        ((session-intents) '())
        ((cicd-intent-count) (length (cicd-intent-rows)))
        ((cicd-intents) (cicd-intent-rows))
        ((workflow-cicd-pipeline-count) (workflow-field 'pipeline-count 0))
        ((workflow-cicd-pipelines) (workflow-field 'pipeline-names '()))
        ((workflow-cicd-functional-dag-count) (length (workflow-functional-dag-rows)))
        ((workflow-cicd-functional-dags) (workflow-functional-dag-rows))
        ((workflow-cicd-pipeline-run-count) (length (workflow-pipeline-run-rows)))
        ((workflow-cicd-pipeline-runs) (workflow-pipeline-run-rows))
        ((workflow-cicd-pipeline-result-count) (length (workflow-pipeline-result-rows)))
        ((workflow-cicd-pipeline-results) (workflow-pipeline-result-rows))
        ((workflow-cicd-runtime-readiness-count) (length (workflow-readiness-rows)))
        ((workflow-cicd-runtime-readiness) (workflow-readiness-rows))
        ((workflow-cicd-runtime-command-manifest-map-count) (length (workflow-runtime-command-manifest-rows)))
        ((workflow-cicd-runtime-command-manifests) (workflow-runtime-command-manifest-rows))
        ((workflow-cicd-runtime-command-manifest-summary-count) (length
                   (workflow-runtime-command-manifest-summary-rows)))
        ((workflow-cicd-runtime-command-manifest-summaries) (workflow-runtime-command-manifest-summary-rows))
        ((workflow-cicd-runtime-command-manifest-agreement) (workflow-runtime-command-manifest-agreement))
        ((workflow-cicd-runtime-command-manifest-agreement-valid?) (poo-flow-user-alist-ref
                   (workflow-runtime-command-manifest-agreement)
                   'valid?
                   #f))
        ((workflow-cicd-runtime-command-manifest-agreement-diagnostics) (poo-flow-user-alist-ref
                   (workflow-runtime-command-manifest-agreement)
                   'diagnostics
                   '()))
        ((workflow-cicd-marlin-runtime-handoff-abi-count) (length (workflow-marlin-runtime-handoff-abi-rows)))
        ((workflow-cicd-marlin-runtime-handoff-abis) (workflow-marlin-runtime-handoff-abi-rows))
        ((workflow-cicd-marlin-runtime-handoff-summary-count) (length
                   (workflow-marlin-runtime-handoff-summary-rows)))
        ((workflow-cicd-marlin-runtime-handoff-summaries) (workflow-marlin-runtime-handoff-summary-rows))
        ((workflow-cicd-receipt-count) (length (workflow-receipt-rows)))
        ((workflow-cicd-receipts) (workflow-receipt-rows))
        ((workflow-cicd-sandbox-runtime-summaries) (workflow-field 'sandbox-runtime-summaries '()))
        ((workflow-cicd-sandbox-handoff-summaries) (workflow-field 'sandbox-handoff-summaries '()))
        ((workflow-cicd-sandbox-unresolved-profile-refs) (workflow-field 'sandbox-unresolved-profile-refs '()))
        ((loop-engine-intent-count) 0)
        ((loop-engine-intents) '())
        ((loop-engine-runtime-handoff-count) 0)
        ((loop-engine-runtime-handoffs) '())
        ((loop-engine-workflow-agreements) '())
        ((loop-engine-workflow-functional-dag-counts) '())
        ((loop-engine-workflow-functional-dags) '())
        ((loop-engine-receipt-contracts) '())
        ((loop-engine-result-contracts) '())
        ((loop-engine-agent-profiles) '())
        ((loop-engine-agent-harnesses) '())
        ((loop-engine-agent-sessions) '())
        ((loop-engine-session-agent-graphs) '())
        ((loop-engine-session-agent-topology-traces) '())
        ((loop-engine-workflow-runs) '())
        ((loop-engine-dispatch-receipts) '())
        ((loop-engine-agent-operations) '())
        ((loop-engine-delegated-operations) '())
        ((loop-engine-lineage-receipts) '())
        ((loop-engine-selector-receipts) '())
        ((loop-engine-resource-dispatch-receipts) '())
        ((loop-engine-capability-receipts) '())
        ((loop-engine-memory-receipts) '())
        ((loop-engine-compression-receipts) '())
        ((loop-engine-session-selector-receipts) '())
        ((loop-engine-session-materialization-receipts) '())
        ((loop-engine-policy-extension-receipts) '())
        ((loop-engine-spec-evolution-reviews) '())
        ((loop-engine-spec-evolution-human-audit-review-items) '())
        ((loop-engine-spec-evolution-runtime-manifest-rows) '())
        ((loop-engine-runtime-command-manifests) '())
        ((loop-engine-runtime-command-manifest-summaries) '())
        ((loop-engine-sandbox-runtime-summaries) '())
        ((loop-engine-sandbox-handoff-summaries) '())
        ((loop-engine-sandbox-handoff-agreements) '())
        ((loop-engine-sandbox-unresolved-profile-refs) '())
        ((loop-engine-runtime-snapshot-count) 0)
        ((loop-engine-runtime-snapshots) '())
        ((presentation-trace) (presentation-trace-rows))
        ((setting-count) (length public-setting-keys))
        ((setting-keys) public-setting-keys)
        ((settings) (poo-flow-user-settings->alist
                   setting-object
                   public-setting-keys))
        ((user-entrypoints) poo-flow-user-config-public-entrypoints)
        ((api-entrypoints) poo-flow-user-config-api-entrypoints)
        ((boundary) poo-flow-user-config-boundary)
        ((brand-name) poo-flow-brand-name)
        ((brand-group) poo-flow-brand-group)
        ((scheme-owner) poo-flow-scheme-owner)
        ((module-system-owner) poo-flow-module-system-owner)
        ((runtime-owner) "marlin-agent-core")
        ((runtime-parses-scheme-source) #f)
        ((scheme-manufactures-runtime-handlers) #f)
        ((package-management?) #f)
        ((dependency-installation?) #f)
        ((descriptor-realized?) #f)
        ((runtime-executed) #f)
        ((workflow-cicd-marlin-handoff-receipt-bundle) (workflow-handoff-bundle))
        ((workflow-cicd-marlin-handoff-receipt-bundle-runtime-executed) (poo-flow-user-alist-ref
                   (workflow-handoff-bundle)
                   'runtime-executed
                   #f))
        ((replayable) #t)
        (else (error "unknown workflow presentation slot" key))))
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
