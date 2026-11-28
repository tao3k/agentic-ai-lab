-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.AISecurityGuaranteeCoordinateAlgebraClosure

namespace AgenticAILabProof.Enterprise

/-!
The first concrete external-framework mapping bundle.  Snowflake's
Data-Model-Agent protection-object coordinates and CSA's three operational
domains are projected into Agentic AI Lab guarantee families.  The mapping stays
fail closed where the reviewed CSA ten-layer document is not yet final.
-/

inductive ExternalSecurityCoordinate where
  | snowflakeData
  | snowflakeModel
  | snowflakeAgent
  | csaInfrastructureIntelligenceKnowledge
  | csaAgencyEnvironmentExecution
  | csaGovernanceAccountability
  | csaFinalTenLayerDetail
  deriving DecidableEq, Repr

inductive AgenticAILabGuaranteeFamily where
  | dataKnowledge
  | modelIntelligence
  | agentIdentityIntent
  | capabilityToolEffect
  | contextMemory
  | ecosystemSupplyChain
  | infrastructureResilience
  | observationRecovery
  | governanceAccountability
  | evidenceProofReplay
  deriving DecidableEq, Repr

structure ExternalFrameworkMappingClaim where
  claimId : String
  source : ExternalSecurityCoordinate
  target : AgenticAILabGuaranteeFamily
  status : CoordinateMappingStatus
  authorityBefore : Nat
  authorityAfter : Nat
  evidenceRoot : String
  owner : String
  deriving DecidableEq, Repr

def frameworkMappingEvidenceRoot : String :=
  "sha256:829a2476e80940124ddae18d2955fb850011ff7b223472787bb3ecd511f7aed6"

def firstExternalFrameworkMappingClaims :
    List ExternalFrameworkMappingClaim :=
  [
    {
      claimId := "snowflake-data-to-data-knowledge"
      source := .snowflakeData
      target := .dataKnowledge
      status := .refinement
      authorityBefore := 3
      authorityAfter := 3
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "snowflake-model-to-model-intelligence"
      source := .snowflakeModel
      target := .modelIntelligence
      status := .refinement
      authorityBefore := 3
      authorityAfter := 3
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "snowflake-agent-to-agent-identity-intent"
      source := .snowflakeAgent
      target := .agentIdentityIntent
      status := .refinement
      authorityBefore := 3
      authorityAfter := 3
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "csa-iik-to-infrastructure-resilience"
      source := .csaInfrastructureIntelligenceKnowledge
      target := .infrastructureResilience
      status := .projection
      authorityBefore := 3
      authorityAfter := 2
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "csa-aee-to-capability-tool-effect"
      source := .csaAgencyEnvironmentExecution
      target := .capabilityToolEffect
      status := .projection
      authorityBefore := 3
      authorityAfter := 2
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "csa-ga-to-governance-accountability"
      source := .csaGovernanceAccountability
      target := .governanceAccountability
      status := .projection
      authorityBefore := 3
      authorityAfter := 2
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "snowflake-agent-to-csa-aee-crosswalk"
      source := .snowflakeAgent
      target := .capabilityToolEffect
      status := .partialMapping
      authorityBefore := 3
      authorityAfter := 2
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    },
    {
      claimId := "csa-final-ten-layer-detail"
      source := .csaFinalTenLayerDetail
      target := .evidenceProofReplay
      status := .unknown
      authorityBefore := 3
      authorityAfter := 0
      evidenceRoot := frameworkMappingEvidenceRoot
      owner := "agentic-ai-lab"
    }
  ]

def mappingStatusAdmitted : CoordinateMappingStatus → Bool
  | .exact => true
  | .refinement => true
  | .projection => true
  | .partialMapping => false
  | .conflicting => false
  | .unknown => false

def mappingStatusEscalated : CoordinateMappingStatus → Bool
  | .partialMapping => true
  | .conflicting => true
  | .unknown => true
  | _ => false

def countMappingClaims
    (predicate : ExternalFrameworkMappingClaim → Bool) :
    List ExternalFrameworkMappingClaim → Nat
  | [] => 0
  | claim :: rest =>
      (if predicate claim then 1 else 0) +
        countMappingClaims predicate rest

def firstExternalFrameworkProofCoverage : Nat :=
  countMappingClaims
    (fun claim => mappingStatusAdmitted claim.status)
    firstExternalFrameworkMappingClaims

def firstExternalFrameworkEscalationCount : Nat :=
  countMappingClaims
    (fun claim => mappingStatusEscalated claim.status)
    firstExternalFrameworkMappingClaims

def allMappingAuthoritiesConfined :
    List ExternalFrameworkMappingClaim → Bool
  | [] => true
  | claim :: rest =>
      decide (claim.authorityAfter ≤ claim.authorityBefore) &&
        allMappingAuthoritiesConfined rest

def allMappingEvidenceRootsBound
    (expectedRoot : String) :
    List ExternalFrameworkMappingClaim → Bool
  | [] => true
  | claim :: rest =>
      claim.evidenceRoot == expectedRoot &&
        allMappingEvidenceRootsBound expectedRoot rest

theorem FirstExternalFrameworkMappingProofCoverage :
    firstExternalFrameworkProofCoverage = 6 := by
  decide

theorem FirstExternalFrameworkMappingUnknownEscalationRate :
    firstExternalFrameworkEscalationCount = 2 := by
  decide

theorem FirstExternalFrameworkMappingConfinesAuthority :
    allMappingAuthoritiesConfined
      firstExternalFrameworkMappingClaims = true := by
  decide

theorem FirstExternalFrameworkMappingBindsOneEvidenceRoot :
    allMappingEvidenceRootsBound
      frameworkMappingEvidenceRoot
      firstExternalFrameworkMappingClaims = true := by
  decide

def csaFinalTenLayerMappingStatus : CoordinateMappingStatus :=
  .unknown

theorem CSAFinalTenLayerMappingFailsClosed :
    mappingProofContribution csaFinalTenLayerMappingStatus 1 = 0 := by
  rfl

structure ExternalFrameworkMappingBundleReceipt where
  schemaVersion : String
  bundleId : String
  evidenceRoot : String
  claimCount : Nat
  proofCoverageCount : Nat
  escalationCount : Nat
  owner : String
  deriving DecidableEq, Repr

def firstExternalFrameworkMappingBundleReceipt :
    ExternalFrameworkMappingBundleReceipt :=
  {
    schemaVersion := "ai-security-framework-mapping-bundle.v1"
    bundleId := "snowflake-csa-agentic-ai-lab-001"
    evidenceRoot := frameworkMappingEvidenceRoot
    claimCount := firstExternalFrameworkMappingClaims.length
    proofCoverageCount := firstExternalFrameworkProofCoverage
    escalationCount := firstExternalFrameworkEscalationCount
    owner := "agentic-ai-lab"
  }

structure ExternalFrameworkReplaySummary where
  bundleId : String
  evidenceRoot : String
  claimCount : Nat
  proofCoverageCount : Nat
  escalationCount : Nat
  deriving DecidableEq, Repr

def replayExternalFrameworkMappingBundle
    (receipt : ExternalFrameworkMappingBundleReceipt) :
    ExternalFrameworkReplaySummary :=
  {
    bundleId := receipt.bundleId
    evidenceRoot := receipt.evidenceRoot
    claimCount := receipt.claimCount
    proofCoverageCount := receipt.proofCoverageCount
    escalationCount := receipt.escalationCount
  }

theorem FirstExternalFrameworkMappingReplayUsesOnlyBundle :
    replayExternalFrameworkMappingBundle
      firstExternalFrameworkMappingBundleReceipt =
      {
        bundleId := "snowflake-csa-agentic-ai-lab-001"
        evidenceRoot := frameworkMappingEvidenceRoot
        claimCount := 8
        proofCoverageCount := 6
        escalationCount := 2
      } := by
  decide

end AgenticAILabProof.Enterprise
