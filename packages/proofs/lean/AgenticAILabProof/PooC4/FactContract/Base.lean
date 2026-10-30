-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.PooC4.FactContract

inductive FactContractKind where
  | fact
  | failureObligation
deriving Repr, DecidableEq

inductive FactPolarity where
  | positive
  | missing
deriving Repr, DecidableEq

inductive SchemeFactSource where
  | sessionLifecycle
  | scenarioBridge
  | uiScenario
  | uiFailure
deriving Repr, DecidableEq

inductive SchemeFactKey where
  | sessionLifecycleChunkPresent
  | sessionLifecyclePlacementResolved
  | sessionLifecyclePlacementMissingProfile
  | sessionLifecycleRuntimeSummaryPresent
  | sessionLifecycleHandoffReceiptPresent
  | sessionLifecycleRuntimeExecutedFalse
  | sessionLifecycleHandoffRequiredTrue
  | sessionLifecycleRuntimeOwnerMarlin
  | sessionLifecycleRuntimeParsesSchemeSourceFalse
  | sessionLifecycleSchemeManufacturesRuntimeHandlersFalse
  | scenarioBridgeS3HandoffReceipt
  | scenarioBridgeS11AgentRegistered
  | scenarioBridgeS11SubagentRegistered
  | scenarioBridgeS11ChannelAuthorized
  | scenarioBridgeS14PlacementMissingProfile
  | uiScenarioUseCaseDeclared
  | uiScenarioProfileDeclared
  | uiScenarioGovernorConfigured
  | uiScenarioLineagePolicyDone
  | uiScenarioSelectorPolicyDone
  | uiScenarioResourcePolicyDone
  | uiScenarioCapabilityPolicyDone
  | uiScenarioMemoryPolicyDone
  | uiScenarioCompressionPolicyDone
  | uiScenarioStrategyPlanDone
  | uiScenarioLocalValidationDone
  | uiScenarioRuntimeManifestDone
  | uiScenarioMarlinHandoffDone
  | uiScenarioL1ReportDone
  | uiScenarioScenarioMatrixDone
  | uiScenarioScenarioBenchmarkDone
  | uiScenarioPerformanceFixtureBound
  | uiFailureStrategyMissingSelectorPolicy
  | uiFailureStrategyMissingResourcePolicy
  | uiFailureStrategyMissingCapabilityPolicy
  | uiFailureLocalValidationMissingStrategyPlan
  | uiFailureRuntimeManifestMissingStrategyPlan
  | uiFailureRuntimeManifestMissingLocalValidation
  | uiFailureRuntimeManifestMissingMemoryPolicy
  | uiFailureRuntimeManifestMissingCompressionPolicy
  | uiFailureHandoffMissingRuntimeManifest
  | uiFailureBenchmarkMissingScenarioMatrix
  | uiFailureBenchmarkMissingL1Report
  | uiFailureBenchmarkMissingPerformanceFixture
deriving Repr, DecidableEq

def SchemeFactKey.source : SchemeFactKey -> SchemeFactSource
  | sessionLifecycleChunkPresent => SchemeFactSource.sessionLifecycle
  | sessionLifecyclePlacementResolved => SchemeFactSource.sessionLifecycle
  | sessionLifecyclePlacementMissingProfile => SchemeFactSource.sessionLifecycle
  | sessionLifecycleRuntimeSummaryPresent => SchemeFactSource.sessionLifecycle
  | sessionLifecycleHandoffReceiptPresent => SchemeFactSource.sessionLifecycle
  | sessionLifecycleRuntimeExecutedFalse => SchemeFactSource.sessionLifecycle
  | sessionLifecycleHandoffRequiredTrue => SchemeFactSource.sessionLifecycle
  | sessionLifecycleRuntimeOwnerMarlin => SchemeFactSource.sessionLifecycle
  | sessionLifecycleRuntimeParsesSchemeSourceFalse =>
      SchemeFactSource.sessionLifecycle
  | sessionLifecycleSchemeManufacturesRuntimeHandlersFalse =>
      SchemeFactSource.sessionLifecycle
  | scenarioBridgeS3HandoffReceipt => SchemeFactSource.scenarioBridge
  | scenarioBridgeS11AgentRegistered => SchemeFactSource.scenarioBridge
  | scenarioBridgeS11SubagentRegistered => SchemeFactSource.scenarioBridge
  | scenarioBridgeS11ChannelAuthorized => SchemeFactSource.scenarioBridge
  | scenarioBridgeS14PlacementMissingProfile => SchemeFactSource.scenarioBridge
  | uiScenarioUseCaseDeclared => SchemeFactSource.uiScenario
  | uiScenarioProfileDeclared => SchemeFactSource.uiScenario
  | uiScenarioGovernorConfigured => SchemeFactSource.uiScenario
  | uiScenarioLineagePolicyDone => SchemeFactSource.uiScenario
  | uiScenarioSelectorPolicyDone => SchemeFactSource.uiScenario
  | uiScenarioResourcePolicyDone => SchemeFactSource.uiScenario
  | uiScenarioCapabilityPolicyDone => SchemeFactSource.uiScenario
  | uiScenarioMemoryPolicyDone => SchemeFactSource.uiScenario
  | uiScenarioCompressionPolicyDone => SchemeFactSource.uiScenario
  | uiScenarioStrategyPlanDone => SchemeFactSource.uiScenario
  | uiScenarioLocalValidationDone => SchemeFactSource.uiScenario
  | uiScenarioRuntimeManifestDone => SchemeFactSource.uiScenario
  | uiScenarioMarlinHandoffDone => SchemeFactSource.uiScenario
  | uiScenarioL1ReportDone => SchemeFactSource.uiScenario
  | uiScenarioScenarioMatrixDone => SchemeFactSource.uiScenario
  | uiScenarioScenarioBenchmarkDone => SchemeFactSource.uiScenario
  | uiScenarioPerformanceFixtureBound => SchemeFactSource.uiScenario
  | uiFailureStrategyMissingSelectorPolicy => SchemeFactSource.uiFailure
  | uiFailureStrategyMissingResourcePolicy => SchemeFactSource.uiFailure
  | uiFailureStrategyMissingCapabilityPolicy => SchemeFactSource.uiFailure
  | uiFailureLocalValidationMissingStrategyPlan => SchemeFactSource.uiFailure
  | uiFailureRuntimeManifestMissingStrategyPlan => SchemeFactSource.uiFailure
  | uiFailureRuntimeManifestMissingLocalValidation => SchemeFactSource.uiFailure
  | uiFailureRuntimeManifestMissingMemoryPolicy => SchemeFactSource.uiFailure
  | uiFailureRuntimeManifestMissingCompressionPolicy =>
      SchemeFactSource.uiFailure
  | uiFailureHandoffMissingRuntimeManifest => SchemeFactSource.uiFailure
  | uiFailureBenchmarkMissingScenarioMatrix => SchemeFactSource.uiFailure
  | uiFailureBenchmarkMissingL1Report => SchemeFactSource.uiFailure
  | uiFailureBenchmarkMissingPerformanceFixture => SchemeFactSource.uiFailure

def SchemeFactKey.externalName : SchemeFactKey -> String
  | sessionLifecycleChunkPresent => "session.lifecycle/chunk-present"
  | sessionLifecyclePlacementResolved => "session.lifecycle/placement-resolved"
  | sessionLifecyclePlacementMissingProfile =>
      "session.lifecycle/placement-missing-profile"
  | sessionLifecycleRuntimeSummaryPresent =>
      "session.lifecycle/runtime-summary-present"
  | sessionLifecycleHandoffReceiptPresent =>
      "session.lifecycle/handoff-receipt-present"
  | sessionLifecycleRuntimeExecutedFalse =>
      "session.lifecycle/runtime-executed-false"
  | sessionLifecycleHandoffRequiredTrue =>
      "session.lifecycle/handoff-required-true"
  | sessionLifecycleRuntimeOwnerMarlin =>
      "session.lifecycle/runtime-owner-marlin"
  | sessionLifecycleRuntimeParsesSchemeSourceFalse =>
      "session.lifecycle/runtime-parses-scheme-source-false"
  | sessionLifecycleSchemeManufacturesRuntimeHandlersFalse =>
      "session.lifecycle/scheme-manufactures-runtime-handlers-false"
  | scenarioBridgeS3HandoffReceipt =>
      "scenario.bridge/s3-handoff-receipt"
  | scenarioBridgeS11AgentRegistered =>
      "scenario.bridge/s11-agent-registered"
  | scenarioBridgeS11SubagentRegistered =>
      "scenario.bridge/s11-subagent-registered"
  | scenarioBridgeS11ChannelAuthorized =>
      "scenario.bridge/s11-channel-authorized"
  | scenarioBridgeS14PlacementMissingProfile =>
      "scenario.bridge/s14-placement-missing-profile"
  | uiScenarioUseCaseDeclared => "ui.scenario/use-case-declared"
  | uiScenarioProfileDeclared => "ui.scenario/profile-declared"
  | uiScenarioGovernorConfigured => "ui.scenario/governor-configured"
  | uiScenarioLineagePolicyDone => "ui.scenario/lineage-policy-done"
  | uiScenarioSelectorPolicyDone => "ui.scenario/selector-policy-done"
  | uiScenarioResourcePolicyDone => "ui.scenario/resource-policy-done"
  | uiScenarioCapabilityPolicyDone => "ui.scenario/capability-policy-done"
  | uiScenarioMemoryPolicyDone => "ui.scenario/memory-policy-done"
  | uiScenarioCompressionPolicyDone => "ui.scenario/compression-policy-done"
  | uiScenarioStrategyPlanDone => "ui.scenario/strategy-plan-done"
  | uiScenarioLocalValidationDone => "ui.scenario/local-validation-done"
  | uiScenarioRuntimeManifestDone => "ui.scenario/runtime-manifest-done"
  | uiScenarioMarlinHandoffDone => "ui.scenario/marlin-handoff-done"
  | uiScenarioL1ReportDone => "ui.scenario/l1-report-done"
  | uiScenarioScenarioMatrixDone => "ui.scenario/scenario-matrix-done"
  | uiScenarioScenarioBenchmarkDone => "ui.scenario/scenario-benchmark-done"
  | uiScenarioPerformanceFixtureBound =>
      "ui.scenario/performance-fixture-bound"
  | uiFailureStrategyMissingSelectorPolicy =>
      "ui.failure/strategy-missing-selector-policy"
  | uiFailureStrategyMissingResourcePolicy =>
      "ui.failure/strategy-missing-resource-policy"
  | uiFailureStrategyMissingCapabilityPolicy =>
      "ui.failure/strategy-missing-capability-policy"
  | uiFailureLocalValidationMissingStrategyPlan =>
      "ui.failure/local-validation-missing-strategy-plan"
  | uiFailureRuntimeManifestMissingStrategyPlan =>
      "ui.failure/runtime-manifest-missing-strategy-plan"
  | uiFailureRuntimeManifestMissingLocalValidation =>
      "ui.failure/runtime-manifest-missing-local-validation"
  | uiFailureRuntimeManifestMissingMemoryPolicy =>
      "ui.failure/runtime-manifest-missing-memory-policy"
  | uiFailureRuntimeManifestMissingCompressionPolicy =>
      "ui.failure/runtime-manifest-missing-compression-policy"
  | uiFailureHandoffMissingRuntimeManifest =>
      "ui.failure/handoff-missing-runtime-manifest"
  | uiFailureBenchmarkMissingScenarioMatrix =>
      "ui.failure/benchmark-missing-scenario-matrix"
  | uiFailureBenchmarkMissingL1Report =>
      "ui.failure/benchmark-missing-l1-report"
  | uiFailureBenchmarkMissingPerformanceFixture =>
      "ui.failure/benchmark-missing-performance-fixture"

end AgenticAILabProof.PooC4.FactContract
