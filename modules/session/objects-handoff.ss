;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: fixed session handoff receipts for runtime owners.
;;; Invariant: handoff values are data receipts, not executable Scheme handlers.

(import (only-in :std/list/list any every)
        (only-in :clan/poo/object .ref object?)
        :agentic-ai-lab/modules/session/objects-core)

(export make-agentic-ai-lab-session-handoff-receipt
        agentic-ai-lab-session-handoff-receipt?
        agentic-ai-lab-session-handoff-receipt-kind
        agentic-ai-lab-session-handoff-receipt-schema
        agentic-ai-lab-session-handoff-receipt-source
        agentic-ai-lab-session-handoff-receipt-session-id
        agentic-ai-lab-session-handoff-receipt-chunk-count
        agentic-ai-lab-session-handoff-receipt-placement-profile-ref
        agentic-ai-lab-session-handoff-receipt-placement-resolved?
        agentic-ai-lab-session-handoff-receipt-placement-diagnostics
        agentic-ai-lab-session-handoff-receipt-runtime-owner
        agentic-ai-lab-session-handoff-receipt-handoff-required
        agentic-ai-lab-session-handoff-receipt-runtime-executed
        agentic-ai-lab-session-handoff-receipt-runtime-parses-scheme-source
        agentic-ai-lab-session-handoff-receipt-scheme-manufactures-runtime-handlers
        agentic-ai-lab-session-handoff-receipt-metadata
        agentic-ai-lab-session-handoff
        agentic-ai-lab-session-handoff?
        agentic-ai-lab-session-topology->handoff-metadata
        make-agentic-ai-lab-lean-fact-key-contract
        agentic-ai-lab-lean-fact-key-contract?
        agentic-ai-lab-lean-fact-key-contract-key
        agentic-ai-lab-lean-fact-key-contract-kind
        agentic-ai-lab-lean-fact-key-contract-lean-owner
        agentic-ai-lab-lean-fact-key-contract-lean-name
        agentic-ai-lab-lean-fact-key-contract-source-slot
        agentic-ai-lab-lean-fact-key-contract-polarity
        agentic-ai-lab-session-handoff-lean-fact-key-contracts
        agentic-ai-lab-ui-scenario-lean-fact-key-contracts
        agentic-ai-lab-lean-fact-contract-keys
        agentic-ai-lab-lean-fact-contract-complete?
        agentic-ai-lab-ui-scenario->lean-facts
        agentic-ai-lab-session-handoff->lean-facts
        agentic-ai-lab-session-handoff->alist)

;;; Fixed handoff receipts make the ABI boundary explicit: Scheme constructs
;;; typed receipt state, and only the ABI projection turns it into alist data.
;; : (-> Symbol Symbol Symbol Symbol Integer Symbol Boolean [Alist] String Boolean Boolean Boolean Boolean Alist PooSessionHandoffReceipt)
(defstruct agentic-ai-lab-session-handoff-receipt
  (kind
   schema
   source
   session-id
   chunk-count
   placement-profile-ref
   placement-resolved?
   placement-diagnostics
   runtime-owner
   handoff-required
   runtime-executed
   runtime-parses-scheme-source
   scheme-manufactures-runtime-handlers
   metadata)
  transparent: #t)

;;; Handoff receipts summarize the session for runtime owners. They keep the
;;; heavy execution boundary explicit and never claim Scheme executed work.
;; : (-> PooSession [Alist] PooSessionHandoffReceipt)
(def (agentic-ai-lab-session-handoff session . maybe-metadata)
  (agentic-ai-lab-session-require "session handoff requires a session"
                            (agentic-ai-lab-session? session)
                            session)
  (let (placement (agentic-ai-lab-session-value-placement session))
    (make-agentic-ai-lab-session-handoff-receipt
     'agentic-ai-lab.session.handoff
     'agentic-ai-lab.modules.session.handoff.v1
     'agentic-ai-lab-session-presentation
     (agentic-ai-lab-session-id session)
     (length (agentic-ai-lab-session-chunks session))
     (agentic-ai-lab-session-placement-profile-ref placement)
     (agentic-ai-lab-session-placement-resolved? placement)
     (agentic-ai-lab-session-placement-diagnostics placement)
     "marlin-agent-core"
     #t
     #f
     #f
     #f
     (if (null? maybe-metadata) '() (car maybe-metadata)))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-handoff? value)
  (or (agentic-ai-lab-session-handoff-receipt? value)
      (object? value)))

;; : (-> Object Symbol Procedure Object)
(def (agentic-ai-lab-session-handoff-ref handoff slot struct-ref)
  (if (agentic-ai-lab-session-handoff-receipt? handoff)
    (struct-ref handoff)
    (.ref handoff slot)))

;;; The ABI projection is the only place where handoff receipt state becomes an
;;; alist. Runtime language bindings consume this shape without seeing Gerbil
;;; structs or POO internals.
;; agentic-ai-lab-session-handoff->alist
;;   : (-> Object Alist)
;;   | contract: project one fixed handoff receipt into ABI alist fields
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-session-handoff->alist handoff)
;;       ;; => ((kind . agentic-ai-lab.session.handoff) ...)
;;       ```
;;     %
(def (agentic-ai-lab-session-handoff->alist handoff)
  (list
   (cons 'kind
         (agentic-ai-lab-session-handoff-ref
          handoff
          'kind
          agentic-ai-lab-session-handoff-receipt-kind))
   (cons 'schema
         (agentic-ai-lab-session-handoff-ref
          handoff
          'schema
          agentic-ai-lab-session-handoff-receipt-schema))
   (cons 'source
         (agentic-ai-lab-session-handoff-ref
          handoff
          'source
          agentic-ai-lab-session-handoff-receipt-source))
   (cons 'session-id
         (agentic-ai-lab-session-handoff-ref
          handoff
          'session-id
          agentic-ai-lab-session-handoff-receipt-session-id))
   (cons 'chunk-count
         (agentic-ai-lab-session-handoff-ref
          handoff
          'chunk-count
          agentic-ai-lab-session-handoff-receipt-chunk-count))
   (cons 'placement-profile-ref
         (agentic-ai-lab-session-handoff-ref
          handoff
          'placement-profile-ref
          agentic-ai-lab-session-handoff-receipt-placement-profile-ref))
   (cons 'placement-resolved?
         (agentic-ai-lab-session-handoff-ref
          handoff
          'placement-resolved?
          agentic-ai-lab-session-handoff-receipt-placement-resolved?))
   (cons 'placement-diagnostics
         (agentic-ai-lab-session-handoff-ref
          handoff
          'placement-diagnostics
          agentic-ai-lab-session-handoff-receipt-placement-diagnostics))
   (cons 'runtime-owner
         (agentic-ai-lab-session-handoff-ref
          handoff
          'runtime-owner
          agentic-ai-lab-session-handoff-receipt-runtime-owner))
   (cons 'handoff-required
         (agentic-ai-lab-session-handoff-ref
          handoff
          'handoff-required
          agentic-ai-lab-session-handoff-receipt-handoff-required))
   (cons 'runtime-executed
         (agentic-ai-lab-session-handoff-ref
          handoff
          'runtime-executed
          agentic-ai-lab-session-handoff-receipt-runtime-executed))
   (cons 'runtime-parses-scheme-source
         (agentic-ai-lab-session-handoff-ref
          handoff
          'runtime-parses-scheme-source
          agentic-ai-lab-session-handoff-receipt-runtime-parses-scheme-source))
   (cons 'scheme-manufactures-runtime-handlers
         (agentic-ai-lab-session-handoff-ref
          handoff
          'scheme-manufactures-runtime-handlers
          agentic-ai-lab-session-handoff-receipt-scheme-manufactures-runtime-handlers))
   (cons 'metadata
         (agentic-ai-lab-session-handoff-ref
          handoff
          'metadata
          agentic-ai-lab-session-handoff-receipt-metadata))))

;; : (-> Alist Symbol Object)
(def (agentic-ai-lab-session-handoff-fact-ref facts key)
  (let ((cell (assq key facts)))
    (and cell (cdr cell))))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol PooLeanFactKeyContract)
(defstruct agentic-ai-lab-lean-fact-key-contract
  (key
   kind
   lean-owner
   lean-name
   source-slot
   polarity)
  transparent: #t)

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol PooLeanFactKeyContract)
(def (agentic-ai-lab-lean-fact-key key kind lean-owner lean-name source-slot polarity)
  (make-agentic-ai-lab-lean-fact-key-contract
   key
   kind
   lean-owner
   lean-name
   source-slot
   polarity))

;;; Boundary: handoff Lean fact key contracts define the proof ABI between
;;; session POO objects and external proof tooling.
;; : [PooLeanFactKeyContract]
(def agentic-ai-lab-session-handoff-lean-fact-key-contracts
  (list
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/chunk-present
    'fact
    'SessionLifecycle.SessionFact
    'chunkPresent
    'chunk-count
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/placement-resolved
    'fact
    'SessionLifecycle.SessionFact
    'placementResolved
    'placement-resolved?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/placement-missing-profile
    'fact
    'SessionLifecycle.SessionFact
    'placementMissingProfile
    'placement-diagnostics/missing-profile
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/runtime-summary-present
    'fact
    'SessionLifecycle.SessionFact
    'runtimeSummaryPresent
    'handoff-receipt
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/handoff-receipt-present
    'fact
    'SessionLifecycle.SessionFact
    'handoffReceiptPresent
    'handoff-receipt
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/runtime-executed-false
    'fact
    'SessionLifecycle.SessionFact
    'runtimeExecutedFalse
    'runtime-executed
    'negative)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/handoff-required-true
    'fact
    'SessionLifecycle.SessionFact
    'handoffRequiredTrue
    'handoff-required
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/runtime-owner-marlin
    'fact
    'SessionLifecycle.SessionFact
    'runtimeOwnerMarlin
    'runtime-owner
    'positive)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/runtime-parses-scheme-source-false
    'fact
    'SessionLifecycle.SessionFact
    'runtimeParsesSchemeSourceFalse
    'runtime-parses-scheme-source
    'negative)
   (agentic-ai-lab-lean-fact-key
    'session.lifecycle/scheme-manufactures-runtime-handlers-false
    'fact
    'SessionLifecycle.SessionFact
    'schemeManufacturesRuntimeHandlersFalse
    'scheme-manufactures-runtime-handlers
    'negative)
   (agentic-ai-lab-lean-fact-key
    'scenario.bridge/s3-handoff-receipt
    'fact
    'ScenarioProof.ScenarioBridgeFact
    's3HandoffReceipt
    'static-marlin-handoff
    'positive)
   (agentic-ai-lab-lean-fact-key
    'scenario.bridge/s11-agent-registered
    'fact
    'ScenarioProof.ScenarioBridgeFact
    's11AgentRegistered
    'metadata/agent-registered
    'positive)
   (agentic-ai-lab-lean-fact-key
    'scenario.bridge/s11-subagent-registered
    'fact
    'ScenarioProof.ScenarioBridgeFact
    's11SubagentRegistered
    'metadata/subagent-registered
    'positive)
   (agentic-ai-lab-lean-fact-key
    'scenario.bridge/s11-channel-authorized
    'fact
    'ScenarioProof.ScenarioBridgeFact
    's11ChannelAuthorized
    'metadata/channel-authorized
    'positive)
   (agentic-ai-lab-lean-fact-key
    'scenario.bridge/s14-placement-missing-profile
    'fact
    'ScenarioProof.ScenarioBridgeFact
    's14PlacementMissingProfile
    'placement-diagnostics/missing-profile
    'positive)))

;;; Boundary: UI scenario Lean fact contracts keep user-facing examples aligned
;;; with the proof handoff schema.
;; : [PooLeanFactKeyContract]
(def agentic-ai-lab-ui-scenario-lean-fact-key-contracts
  (list
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/use-case-declared
    'fact
    'UserInterface.UiScenarioFact
    'useCaseDeclared
    'use-case-declared?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/profile-declared
    'fact
    'UserInterface.UiScenarioFact
    'profileDeclared
    'profile-declared?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/governor-configured
    'fact
    'UserInterface.UiScenarioFact
    'governorConfigured
    'governor-configured?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/lineage-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'lineagePolicyDone
    'lineage-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/selector-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'selectorPolicyDone
    'selector-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/resource-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'resourcePolicyDone
    'resource-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/capability-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'capabilityPolicyDone
    'capability-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/memory-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'memoryPolicyDone
    'memory-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/compression-policy-done
    'fact
    'UserInterface.UiScenarioFact
    'compressionPolicyDone
    'compression-policy-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/strategy-plan-done
    'fact
    'UserInterface.UiScenarioFact
    'strategyPlanDone
    'strategy-plan-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/local-validation-done
    'fact
    'UserInterface.UiScenarioFact
    'localValidationDone
    'local-validation-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/runtime-manifest-done
    'fact
    'UserInterface.UiScenarioFact
    'runtimeManifestDone
    'runtime-manifest-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/marlin-handoff-done
    'fact
    'UserInterface.UiScenarioFact
    'marlinHandoffDone
    'marlin-handoff-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/l1-report-done
    'fact
    'UserInterface.UiScenarioFact
    'l1ReportDone
    'l1-report-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/scenario-matrix-done
    'fact
    'UserInterface.UiScenarioFact
    'scenarioMatrixDone
    'scenario-matrix-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/scenario-benchmark-done
    'fact
    'UserInterface.UiScenarioFact
    'scenarioBenchmarkDone
    'scenario-benchmark-done?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.scenario/performance-fixture-bound
    'fact
    'UserInterface.UiScenarioFact
    'performanceFixtureBound
    'performance-fixture-bound?
    'positive)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/strategy-missing-selector-policy
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_strategy_without_selector_policy
    'selector-policy-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/strategy-missing-resource-policy
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_strategy_without_resource_policy
    'resource-policy-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/strategy-missing-capability-policy
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_strategy_without_capability_policy
    'capability-policy-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/local-validation-missing-strategy-plan
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_local_validation_without_strategy_plan
    'strategy-plan-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/runtime-manifest-missing-strategy-plan
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_runtime_manifest_without_strategy_plan
    'strategy-plan-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/runtime-manifest-missing-local-validation
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_runtime_manifest_without_local_validation
    'local-validation-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/runtime-manifest-missing-memory-policy
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_runtime_manifest_without_memory_policy
    'memory-policy-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/runtime-manifest-missing-compression-policy
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_runtime_manifest_without_compression_policy
    'compression-policy-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/handoff-missing-runtime-manifest
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_handoff_without_runtime_manifest
    'runtime-manifest-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/benchmark-missing-scenario-matrix
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_benchmark_without_matrix
    'scenario-matrix-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/benchmark-missing-l1-report
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_benchmark_without_l1_report
    'l1-report-done?
    'missing)
   (agentic-ai-lab-lean-fact-key
    'ui.failure/benchmark-missing-performance-fixture
    'failure-obligation
    'UserInterface
    'ui_projection_blocks_benchmark_without_performance_fixture
    'performance-fixture-bound?
    'missing)))

;; : (-> [PooLeanFactKeyContract] [Symbol])
(def (agentic-ai-lab-lean-fact-contract-keys contracts)
  (map agentic-ai-lab-lean-fact-key-contract-key contracts))

;; : (-> [PooLeanFactKeyContract] Symbol Boolean)
(def (agentic-ai-lab-lean-fact-key-declared? contracts key)
  (and (any (lambda (contract)
              (eq? key (agentic-ai-lab-lean-fact-key-contract-key contract)))
            contracts)
       #t))

;; : (-> [PooLeanFactKeyContract] Alist Boolean)
(def (agentic-ai-lab-lean-fact-contract-keys-present? contracts facts)
  (every (lambda (contract)
           (and (assq (agentic-ai-lab-lean-fact-key-contract-key contract) facts)
                #t))
         contracts))

;; : (-> Alist [PooLeanFactKeyContract] Boolean)
(def (agentic-ai-lab-lean-fact-contract-facts-declared? facts contracts)
  (every (lambda (fact)
           (agentic-ai-lab-lean-fact-key-declared? contracts (car fact)))
         facts))

;; : (-> [PooLeanFactKeyContract] Alist Boolean)
(def (agentic-ai-lab-lean-fact-contract-complete? contracts facts)
  (and (agentic-ai-lab-lean-fact-contract-keys-present? contracts facts)
       (agentic-ai-lab-lean-fact-contract-facts-declared? facts contracts)))

;; : (-> Object Symbol Boolean)
(def (agentic-ai-lab-session-diagnostic-present? diagnostics key)
  (and (list? diagnostics)
       (or (and (memq key diagnostics) #t)
           (and (assq key diagnostics) #t))))

;; : (-> Object Symbol Boolean)
(def (agentic-ai-lab-session-metadata-true? metadata key)
  (and (list? metadata)
       (let ((cell (assq key metadata)))
         (and cell (eq? (cdr cell) #t)))))

;; : (-> Object Symbol Object)
(def (agentic-ai-lab-session-topology-ref topology slot)
  (cond
   ((object? topology) (.ref topology slot))
   ((list? topology)
    (let ((cell (assq slot topology)))
      (and cell (cdr cell))))
   (else #f)))

;; : (-> Object [Alist] Alist)
(def (agentic-ai-lab-session-topology->handoff-metadata topology . maybe-metadata)
  (let ((metadata (if (null? maybe-metadata) '() (car maybe-metadata))))
    (append
     (list
      (cons 'agent-registered
            (eq? (agentic-ai-lab-session-topology-ref
                  topology
                  'agent-registered?)
                 #t))
      (cons 'subagent-registered
            (eq? (agentic-ai-lab-session-topology-ref
                  topology
                  'subagent-registered?)
                 #t))
      (cons 'channel-authorized
            (eq? (agentic-ai-lab-session-topology-ref
                  topology
                  'channel-authorized?)
                 #t)))
     metadata)))

;; : (-> Object Symbol Object)
(def (agentic-ai-lab-ui-scenario-ref scenario slot)
  (cond
   ((object? scenario)
    (with-catch
     (lambda (_)
       #f)
     (lambda ()
       (.ref scenario slot))))
   ((list? scenario)
    (let ((cell (assq slot scenario)))
      (and cell (cdr cell))))
   (else #f)))

;; : (-> Object Symbol Boolean)
(def (agentic-ai-lab-ui-scenario-flag scenario slot)
  (eq? (agentic-ai-lab-ui-scenario-ref scenario slot) #t))

;;; Boundary: UI scenario projection emits proof facts without mutating the
;;; source scenario object or its session ancestry.
;; : (-> Object Alist)
(def (agentic-ai-lab-ui-scenario->lean-facts scenario)
  (let* ((use-case-declared
          (agentic-ai-lab-ui-scenario-flag scenario 'use-case-declared?))
         (profile-declared
          (agentic-ai-lab-ui-scenario-flag scenario 'profile-declared?))
         (governor-configured
          (agentic-ai-lab-ui-scenario-flag scenario 'governor-configured?))
         (lineage-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'lineage-policy-done?))
         (selector-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'selector-policy-done?))
         (resource-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'resource-policy-done?))
         (capability-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'capability-policy-done?))
         (memory-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'memory-policy-done?))
         (compression-policy-done
          (agentic-ai-lab-ui-scenario-flag scenario 'compression-policy-done?))
         (strategy-plan-done
          (agentic-ai-lab-ui-scenario-flag scenario 'strategy-plan-done?))
         (local-validation-done
          (agentic-ai-lab-ui-scenario-flag scenario 'local-validation-done?))
         (runtime-manifest-done
          (agentic-ai-lab-ui-scenario-flag scenario 'runtime-manifest-done?))
         (marlin-handoff-done
          (agentic-ai-lab-ui-scenario-flag scenario 'marlin-handoff-done?))
         (l1-report-done
          (agentic-ai-lab-ui-scenario-flag scenario 'l1-report-done?))
         (scenario-matrix-done
          (agentic-ai-lab-ui-scenario-flag scenario 'scenario-matrix-done?))
         (scenario-benchmark-done
          (agentic-ai-lab-ui-scenario-flag scenario 'scenario-benchmark-done?))
         (performance-fixture-bound
          (agentic-ai-lab-ui-scenario-flag scenario 'performance-fixture-bound?)))
    (list
     (cons 'ui.scenario/use-case-declared use-case-declared)
     (cons 'ui.scenario/profile-declared profile-declared)
     (cons 'ui.scenario/governor-configured governor-configured)
     (cons 'ui.scenario/lineage-policy-done lineage-policy-done)
     (cons 'ui.scenario/selector-policy-done selector-policy-done)
     (cons 'ui.scenario/resource-policy-done resource-policy-done)
     (cons 'ui.scenario/capability-policy-done capability-policy-done)
     (cons 'ui.scenario/memory-policy-done memory-policy-done)
     (cons 'ui.scenario/compression-policy-done compression-policy-done)
     (cons 'ui.scenario/strategy-plan-done strategy-plan-done)
     (cons 'ui.scenario/local-validation-done local-validation-done)
     (cons 'ui.scenario/runtime-manifest-done runtime-manifest-done)
     (cons 'ui.scenario/marlin-handoff-done marlin-handoff-done)
     (cons 'ui.scenario/l1-report-done l1-report-done)
     (cons 'ui.scenario/scenario-matrix-done scenario-matrix-done)
     (cons 'ui.scenario/scenario-benchmark-done scenario-benchmark-done)
     (cons 'ui.scenario/performance-fixture-bound performance-fixture-bound)
     (cons 'ui.failure/strategy-missing-selector-policy
           (not selector-policy-done))
     (cons 'ui.failure/strategy-missing-resource-policy
           (not resource-policy-done))
     (cons 'ui.failure/strategy-missing-capability-policy
           (not capability-policy-done))
     (cons 'ui.failure/local-validation-missing-strategy-plan
           (not strategy-plan-done))
     (cons 'ui.failure/runtime-manifest-missing-strategy-plan
           (not strategy-plan-done))
     (cons 'ui.failure/runtime-manifest-missing-local-validation
           (not local-validation-done))
     (cons 'ui.failure/runtime-manifest-missing-memory-policy
           (not memory-policy-done))
     (cons 'ui.failure/runtime-manifest-missing-compression-policy
           (not compression-policy-done))
     (cons 'ui.failure/handoff-missing-runtime-manifest
           (not runtime-manifest-done))
     (cons 'ui.failure/benchmark-missing-scenario-matrix
           (not scenario-matrix-done))
     (cons 'ui.failure/benchmark-missing-l1-report
           (not l1-report-done))
     (cons 'ui.failure/benchmark-missing-performance-fixture
           (not performance-fixture-bound)))))

;;; Boundary: session handoff projection is the stable proof fact bridge from
;;; runtime handoff receipts to Lean-facing facts.
;; : (-> Object Alist)
(def (agentic-ai-lab-session-handoff->lean-facts handoff)
  (let* ((facts (agentic-ai-lab-session-handoff->alist handoff))
         (chunk-count
          (agentic-ai-lab-session-handoff-fact-ref facts 'chunk-count))
         (placement-resolved?
          (agentic-ai-lab-session-handoff-fact-ref facts 'placement-resolved?))
         (placement-diagnostics
          (agentic-ai-lab-session-handoff-fact-ref facts 'placement-diagnostics))
         (runtime-owner
          (agentic-ai-lab-session-handoff-fact-ref facts 'runtime-owner))
         (handoff-required
          (agentic-ai-lab-session-handoff-fact-ref facts 'handoff-required))
         (runtime-executed
          (agentic-ai-lab-session-handoff-fact-ref facts 'runtime-executed))
         (runtime-parses-scheme-source
          (agentic-ai-lab-session-handoff-fact-ref
           facts
           'runtime-parses-scheme-source))
         (scheme-manufactures-runtime-handlers
          (agentic-ai-lab-session-handoff-fact-ref
           facts
           'scheme-manufactures-runtime-handlers))
         (metadata
          (agentic-ai-lab-session-handoff-fact-ref facts 'metadata))
         (placement-missing-profile
          (agentic-ai-lab-session-diagnostic-present?
           placement-diagnostics
           'missing-profile))
         (static-marlin-handoff
          (and (eq? handoff-required #t)
               (eq? runtime-executed #f)
               (eq? runtime-parses-scheme-source #f)
               (eq? scheme-manufactures-runtime-handlers #f)
               (equal? runtime-owner "marlin-agent-core"))))
    (list
     (cons 'session.lifecycle/chunk-present
           (and (number? chunk-count) (> chunk-count 0)))
     (cons 'session.lifecycle/placement-resolved
           (and placement-resolved? #t))
     (cons 'session.lifecycle/placement-missing-profile
           placement-missing-profile)
     (cons 'session.lifecycle/runtime-summary-present #t)
     (cons 'session.lifecycle/handoff-receipt-present #t)
     (cons 'session.lifecycle/runtime-executed-false
           (eq? runtime-executed #f))
     (cons 'session.lifecycle/handoff-required-true
           (eq? handoff-required #t))
     (cons 'session.lifecycle/runtime-owner-marlin
           (equal? runtime-owner "marlin-agent-core"))
     (cons 'session.lifecycle/runtime-parses-scheme-source-false
           (eq? runtime-parses-scheme-source #f))
     (cons 'session.lifecycle/scheme-manufactures-runtime-handlers-false
           (eq? scheme-manufactures-runtime-handlers #f))
     (cons 'scenario.bridge/s3-handoff-receipt
           static-marlin-handoff)
     (cons 'scenario.bridge/s11-agent-registered
           (agentic-ai-lab-session-metadata-true?
            metadata
            'agent-registered))
     (cons 'scenario.bridge/s11-subagent-registered
           (agentic-ai-lab-session-metadata-true?
            metadata
            'subagent-registered))
     (cons 'scenario.bridge/s11-channel-authorized
           (agentic-ai-lab-session-metadata-true?
            metadata
            'channel-authorized))
     (cons 'scenario.bridge/s14-placement-missing-profile
           placement-missing-profile))))
