;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Module boundary: shared presentation projection helpers stay here so facade
;;; and focused runtime leaf modules preserve one stable slot vocabulary.

(export poo-flow-user-config-presentation-workflow-cicd-check-map-names/rev
        poo-flow-user-config-presentation-workflow-cicd-check-map-names
        poo-flow-user-sandbox-profile-derivation-last-step
        poo-flow-user-sandbox-profile-derivation-path
        poo-flow-user-sandbox-profile-derivation-row
        poo-flow-user-module-selection-sandbox-config-profiles
        poo-flow-user-module-selection-sandbox-profile-derivations/rev
        poo-flow-user-module-selection-sandbox-profile-derivations
        poo-flow-user-config-sandbox-profile-derivations/rev
        poo-flow-user-config-sandbox-profile-derivations
        poo-flow-user-config-presentation-trace
        poo-flow-user-config-presentation-empty-field-values
        poo-flow-user-config-presentation-accumulate-field-values
        poo-flow-user-config-presentation-accumulate-rows
        poo-flow-user-config-presentation-reverse-field-values
        poo-flow-user-config-presentation-field-values
        poo-flow-user-config-presentation-field-values-ref
        poo-flow-user-config-presentation-loop-engine-slots
        +poo-flow-user-config-presentation-loop-engine-fields+)

(import :poo-flow/modules/sandbox-core/profile-support/policy
        (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-sandbox-profile?
                 poo-flow-sandbox-profile-name
                 poo-flow-sandbox-profile-backend-kind
                 poo-flow-sandbox-profile-backend-ref
                 poo-flow-sandbox-profile-metadata)
        :poo-flow/modules/workflow/interface
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/selection/objects
        (only-in :poo-flow/modules/workflow/cicd-runtime-command-config
                 poo-flow-user-alist-ref)
        :core/module-system/observability/presentation)

;; : (-> CicdCheckMaps SymbolList SymbolList)
(def (poo-flow-user-config-presentation-workflow-cicd-check-map-names/rev
      check-maps
      names-rev)
  (if (null? check-maps)
    names-rev
    (poo-flow-user-config-presentation-workflow-cicd-check-map-names/rev
     (cdr check-maps)
     (cons (poo-flow-cicd-check-map-name (car check-maps)) names-rev))))

;; : (-> CicdCheckMaps SymbolList)
(def (poo-flow-user-config-presentation-workflow-cicd-check-map-names
      check-maps)
  (map poo-flow-cicd-check-map-name check-maps))

;; : (-> DerivationPath DerivationStep)
(def (poo-flow-user-sandbox-profile-derivation-last-step derivation-path)
  (if (null? derivation-path)
    #f
    (car (reverse derivation-path))))

;; : (-> SandboxProfile DerivationPath)
(def (poo-flow-user-sandbox-profile-derivation-path profile)
  (let ((derivation-path
         (poo-flow-user-alist-ref
          (poo-flow-sandbox-profile-metadata profile)
          'derivation-path
          '())))
    (if (list? derivation-path) derivation-path '())))

;; : (-> ModuleSelection SandboxProfile DerivationRow)
(def (poo-flow-user-sandbox-profile-derivation-row selection profile)
  (let* ((module-key (poo-flow-user-module-selection-key selection))
         (derivation-path
          (poo-flow-user-sandbox-profile-derivation-path profile))
         (last-step
          (poo-flow-user-sandbox-profile-derivation-last-step
           derivation-path)))
    (if last-step
      (list
       (cons 'key module-key)
       (cons 'group (car module-key))
       (cons 'module (cdr module-key))
       (cons 'profile-name (poo-flow-sandbox-profile-name profile))
       (cons 'backend-kind (poo-flow-sandbox-profile-backend-kind profile))
       (cons 'backend-ref (poo-flow-sandbox-profile-backend-ref profile))
       (cons 'parent-profile
             (poo-flow-user-alist-ref last-step 'parent-profile #f))
       (cons 'scope (poo-flow-user-alist-ref last-step 'scope #f))
       (cons 'scope-ref (poo-flow-user-alist-ref last-step 'scope-ref #f))
       (cons 'derivation-depth (length derivation-path))
       (cons 'derivation-path derivation-path)
       (cons 'runtime-owner "marlin-agent-core")
       (cons 'descriptor-realized? #f)
       (cons 'runtime-executed #f))
      #f)))

;; : (-> ModuleSelection SandboxProfiles)
(def (poo-flow-user-module-selection-sandbox-config-profiles selection)
  (let ((entry (poo-flow-user-module-selection-flag-entry selection ':config)))
    (if (and entry (pair? entry))
      (filter poo-flow-sandbox-profile? (cdr entry))
      '())))

;; : (-> ModuleSelection SandboxProfiles DerivationRows DerivationRows)
(def (poo-flow-user-module-selection-sandbox-profile-derivations/rev
      selection
      profiles
      results)
  (cond
   ((null? profiles) results)
   (else
    (let ((row (poo-flow-user-sandbox-profile-derivation-row
                selection
                (car profiles))))
      (if row
        (poo-flow-user-module-selection-sandbox-profile-derivations/rev
         selection
         (cdr profiles)
         (cons row results))
        (poo-flow-user-module-selection-sandbox-profile-derivations/rev
         selection
         (cdr profiles)
         results))))))

;; : (-> ModuleSelection DerivationRows)
(def (poo-flow-user-module-selection-sandbox-profile-derivations selection)
  (filter (lambda (row) row)
          (map (lambda (profile)
                 (poo-flow-user-sandbox-profile-derivation-row
                  selection
                  profile))
               (poo-flow-user-module-selection-sandbox-config-profiles
                selection))))

;; : (-> ModuleSelections DerivationRows DerivationRows)
(def (poo-flow-user-config-sandbox-profile-derivations/rev selected-modules
                                                           results)
  (cond
   ((null? selected-modules) results)
   (else
    (poo-flow-user-config-sandbox-profile-derivations/rev
     (cdr selected-modules)
     (poo-flow-user-module-selection-sandbox-profile-derivations/rev
      (car selected-modules)
      (poo-flow-user-module-selection-sandbox-config-profiles
       (car selected-modules))
      results)))))

;; : (-> ModuleSelections DerivationRows)
(def (poo-flow-user-config-sandbox-profile-derivations selected-modules)
  (if (null? selected-modules)
    '()
    (apply append
           (map poo-flow-user-module-selection-sandbox-profile-derivations
                selected-modules))))

;; Engineering note: trace construction is a count-only projection so presentation
;; callers can observe large configs without retaining the source rows again.
;; : (-> ModuleSelections FeatureFacts DerivationRows SessionIntents CicdIntents CicdCheckMaps FunctionalDagRows PipelineRunRows PipelineResultRows RuntimeReadinessRows RuntimeCommandRows RuntimeCommandSummaryRows RuntimeAgreementReport HandoffAbiRows ReceiptRows HandoffBundle LoopIntentRows SettingKeys PresentationTrace)
(def (poo-flow-user-config-presentation-trace
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
      workflow-cicd-marlin-handoff-receipt-bundle
      loop-engine-intent-rows
      public-setting-keys)
  (poo-flow-module-presentation-trace
   'user-config-presentation
   (list (cons 'selected-modules (length selected-modules))
         (cons 'feature-facts (length feature-fact-rows))
         (cons 'sandbox-profile-derivations
               (length sandbox-profile-derivation-rows))
         (cons 'session-intents (length session-intent-rows))
         (cons 'cicd-intents (length cicd-intent-rows))
         (cons 'workflow-cicd-pipelines
               (length workflow-cicd-check-maps))
         (cons 'workflow-cicd-functional-dags
               (length workflow-cicd-functional-dag-rows))
         (cons 'workflow-cicd-pipeline-runs
               (length workflow-cicd-pipeline-run-rows))
         (cons 'workflow-cicd-pipeline-results
               (length workflow-cicd-pipeline-result-rows))
         (cons 'workflow-cicd-runtime-readiness
               (length workflow-cicd-readiness-rows))
         (cons 'workflow-cicd-runtime-command-manifest-maps
               (length workflow-cicd-runtime-command-manifest-rows))
         (cons 'workflow-cicd-runtime-command-manifest-summaries
               (length workflow-cicd-runtime-command-manifest-summary-rows))
         (cons 'workflow-cicd-runtime-command-manifest-agreement
               (if (poo-flow-user-alist-ref
                    workflow-cicd-runtime-command-manifest-agreement-report
                    'valid?
                    #f)
                 1
                 0))
         (cons 'workflow-cicd-marlin-runtime-handoff-abis
               (length workflow-cicd-marlin-runtime-handoff-abi-rows))
         (cons 'workflow-cicd-receipts
               (length workflow-cicd-receipt-rows))
         (cons 'workflow-cicd-marlin-handoff-receipt-bundle
               (if (poo-flow-user-alist-ref
                    workflow-cicd-marlin-handoff-receipt-bundle
                    'runtime-executed
                    #t)
                 0
                 1))
         (cons 'loop-engine-intents (length loop-engine-intent-rows))
         (cons 'settings (length public-setting-keys)))))

;; : (-> List List)
(def (poo-flow-user-config-presentation-empty-field-values fields)
  (map (lambda (field) (cons field '())) fields))

;; : (-> ProjectionRow FieldValues RowRef FieldValues)
(def (poo-flow-user-config-presentation-accumulate-field-values
      row
      field-values
      row-ref)
  (map (lambda (field-value)
         (let ((field (car field-value))
               (values (cdr field-value)))
           (cons field (cons (row-ref row field #f) values))))
       field-values))

;; : (-> ProjectionRows FieldValues RowRef FieldValues)
(def (poo-flow-user-config-presentation-accumulate-rows
      rows
      field-values
      row-ref)
  (cond
   ((null? rows) field-values)
   (else
    (poo-flow-user-config-presentation-accumulate-rows
     (cdr rows)
     (poo-flow-user-config-presentation-accumulate-field-values
      (car rows)
      field-values
      row-ref)
     row-ref))))

;; : (-> List List)
(def (poo-flow-user-config-presentation-reverse-field-values field-values)
  (map (lambda (field-value)
         (cons (car field-value) (reverse (cdr field-value))))
       field-values))

;; : (-> ProjectionRows FieldNames RowRef FieldValues)
(def (poo-flow-user-config-presentation-field-values rows fields row-ref)
  (poo-flow-user-config-presentation-reverse-field-values
   (poo-flow-user-config-presentation-accumulate-rows
    rows
    (poo-flow-user-config-presentation-empty-field-values fields)
    row-ref)))

;; : (-> FieldValues Symbol FieldValues)
(def (poo-flow-user-config-presentation-field-values-ref field-values field)
  (poo-flow-user-alist-ref field-values field '()))

;; Engineering note: loop-engine slots are centralized because the mixed facade
;; and loop-only summary must expose the same field vocabulary.
;; : (-> LoopFieldValues LoopIntentRows PresentationSlots)
(def (poo-flow-user-config-presentation-loop-engine-slots
      loop-engine-field-values
      loop-engine-intent-rows)
  ;; Engineering note: keeping the vocabulary as one alist builder prevents the
  ;; mixed and summary presentations from drifting field-by-field.
  (def (field key)
    (poo-flow-user-config-presentation-field-values-ref
     loop-engine-field-values
     key))
  (list
   (cons 'loop-engine-intent-count (length loop-engine-intent-rows))
   (cons 'loop-engine-intents loop-engine-intent-rows)
   (cons 'loop-engine-runtime-handoff-count
         (length loop-engine-intent-rows))
   (cons 'loop-engine-runtime-handoffs (field 'runtime-handoff-facts))
   (cons 'loop-engine-workflow-agreements (field 'workflow-agreement))
   (cons 'loop-engine-workflow-functional-dag-counts
         (field 'workflow-functional-dag-count))
   (cons 'loop-engine-workflow-functional-dags
         (field 'workflow-functional-dags))
   (cons 'loop-engine-receipt-contracts (field 'receipt-contracts))
   (cons 'loop-engine-result-contracts (field 'result-contract))
   (cons 'loop-engine-agent-profiles (field 'agent-profiles))
   (cons 'loop-engine-agent-harnesses (field 'agent-harnesses))
   (cons 'loop-engine-agent-sessions (field 'agent-sessions))
   (cons 'loop-engine-session-agent-graphs (field 'session-agent-graph))
   (cons 'loop-engine-session-agent-topology-traces
         (field 'session-agent-topology-trace))
   (cons 'loop-engine-workflow-runs (field 'workflow-run))
   (cons 'loop-engine-dispatch-receipts (field 'dispatch-receipt))
   (cons 'loop-engine-agent-operations (field 'agent-operation))
   (cons 'loop-engine-delegated-operations (field 'delegated-operation))
   (cons 'loop-engine-lineage-receipts (field 'lineage-receipt))
   (cons 'loop-engine-selector-receipts (field 'selector-receipt))
   (cons 'loop-engine-resource-dispatch-receipts
         (field 'resource-dispatch-receipt))
   (cons 'loop-engine-capability-receipts (field 'capability-receipt))
   (cons 'loop-engine-memory-receipts (field 'memory-receipt))
   (cons 'loop-engine-compression-receipts (field 'compression-receipt))
   (cons 'loop-engine-session-selector-receipts
         (field 'session-selector-receipts))
   (cons 'loop-engine-session-materialization-receipts
         (field 'session-materialization-receipts))
   (cons 'loop-engine-policy-extension-receipts
         (field 'policy-extension-receipts))
   (cons 'loop-engine-spec-evolution-reviews
         (field 'spec-evolution-reviews))
   (cons 'loop-engine-spec-evolution-human-audit-review-items
         (field 'spec-evolution-human-audit-review-items))
   (cons 'loop-engine-spec-evolution-runtime-manifest-rows
         (field 'spec-evolution-runtime-manifest-rows))
   (cons 'loop-engine-runtime-command-manifests
         (field 'runtime-command-manifest))
   (cons 'loop-engine-runtime-command-manifest-summaries
         (field 'runtime-command-manifest-summary))
   (cons 'loop-engine-sandbox-runtime-summaries
         (field 'sandbox-runtime-summaries))
   (cons 'loop-engine-sandbox-handoff-summaries
         (field 'sandbox-handoff-summaries))
   (cons 'loop-engine-sandbox-handoff-agreements
         (field 'sandbox-handoff-agreement))
   (cons 'loop-engine-sandbox-unresolved-profile-refs
         (field 'sandbox-unresolved-profile-refs))
   (cons 'loop-engine-runtime-snapshot-count
         (length loop-engine-intent-rows))
   (cons 'loop-engine-runtime-snapshots (field 'runtime-snapshot))))

;; : LoopEngineFieldNames
(def +poo-flow-user-config-presentation-loop-engine-fields+
  '(runtime-handoff-facts
    workflow-agreement
    workflow-functional-dag-count
    workflow-functional-dags
    receipt-contracts
    result-contract
    agent-profiles
    agent-harnesses
    agent-sessions
    session-agent-graph
    session-agent-topology-trace
    workflow-run
    dispatch-receipt
    agent-operation
    delegated-operation
    lineage-receipt
    selector-receipt
    resource-dispatch-receipt
    capability-receipt
    memory-receipt
    compression-receipt
    session-selector-receipts
    session-materialization-receipts
    policy-extension-receipts
    spec-evolution-reviews
    spec-evolution-human-audit-review-items
    spec-evolution-runtime-manifest-rows
    runtime-command-manifest
    runtime-command-manifest-summary
    sandbox-runtime-summaries
    sandbox-handoff-summaries
    sandbox-handoff-agreement
    sandbox-unresolved-profile-refs
    runtime-snapshot))
