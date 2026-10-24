-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionClosure
import AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
import AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
import AgenticAILabProof.Enterprise.AuthorityValidatedSnapshotProjectionClosure

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceClosure

open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityRefinementClosure
open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionClosure
open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
open AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
open AgenticAILabProof.Enterprise.AuthorityValidatedSnapshotProjectionClosure

structure CedarInputAuthorityIdentityEncoding where
  encode : String → Nat
  encodeInjective : Function.Injective encode

structure CedarInputIdentityTransitionEvidence
    (encoding : CedarInputAuthorityIdentityEncoding) where
  oldAuthority : CedarInputContentIdentityAuthority
  currentAuthority : CedarInputContentIdentityAuthority
  transition :
    CompatibleCedarInputIdentityGenerationTransitionClosed
        oldAuthority currentAuthority ∨
      CedarInputSemanticIdentityRotationClosed oldAuthority currentAuthority
  priorContext : ReceiptValidationContext
  priorContextAuthorityBound :
    priorContext.authorityIdentity = encoding.encode oldAuthority.authorityIdentity
  priorContextGenerationBound :
    priorContext.authorityGeneration = oldAuthority.generation
  issuedContext : ReceiptValidationContext
  contextAuthorityBound :
    issuedContext.authorityIdentity =
      encoding.encode currentAuthority.authorityIdentity
  contextGenerationBound :
    issuedContext.authorityGeneration = currentAuthority.generation
  transitionArtifactIdentity : Nat
  transitionArtifactIdentityNonzero : transitionArtifactIdentity ≠ 0

structure CedarInputIdentityTransitionAcceptanceAuthority
    (encoding : CedarInputAuthorityIdentityEncoding)
    (Artifact : Type) where
  authorityIdentity : String
  validation :
    AcceptanceAuthority Artifact (CedarInputIdentityTransitionEvidence encoding)
  validationAuthorityBound :
    ∀ artifact evidence,
      validation.validate artifact = some evidence →
        evidence.oldAuthority.authorityIdentity = authorityIdentity ∧
        evidence.currentAuthority.authorityIdentity = authorityIdentity
  artifactIdentity : Artifact → Nat
  validationBindsArtifactIdentity :
    ∀ artifact evidence,
      validation.validate artifact = some evidence →
        evidence.transitionArtifactIdentity = artifactIdentity artifact
  artifactIdentityUniqueOnValidated :
    ∀ left right leftEvidence rightEvidence,
      validation.validate left = some leftEvidence →
      validation.validate right = some rightEvidence →
      artifactIdentity left = artifactIdentity right →
      left = right

structure CedarInputIdentityTransitionProjectionAuthority where
  authorityIdentity : String
  projection : SnapshotProjectionAuthority Nat Nat

structure AuthorityIssuedCedarInputIdentityTransitionClosed
    (encoding : CedarInputAuthorityIdentityEncoding)
    (Artifact : Type)
    (transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact)
    (node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation)
    (projectionAuthority : CedarInputIdentityTransitionProjectionAuthority)
    (projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation)
    (domain : AuthoritativeContextPublicationDomain)
    (watermark : TrustedCheckpointWatermark)
    (checkpointAuthority : LiveCheckpointAttestationAuthority domain)
    (attestation : DeclaredCheckpointAttestation domain) : Prop where
  checkpointAdmitted :
    authorityIssuedCheckpointCurrentForAdmission
      watermark checkpointAuthority attestation
  bindingMatchesAttestedHead :
    node.nodeBinding.issuedContext = attestation.checkpoint.head.context
  watermarkAuthorityBound :
    watermark.authorityIdentity =
      encoding.encode transitionAuthority.authorityIdentity
  watermarkGenerationBound :
    watermark.minimumGeneration =
      node.nodeBinding.currentAuthority.generation
  projectionAuthorityBound :
    projectionAuthority.authorityIdentity = transitionAuthority.authorityIdentity
  projectionSnapshotBound :
    projectionNode.artifact =
      node.nodeBinding.issuedContext.authorizationSnapshotIdentity
  projectionArtifactBound :
    projectionNode.nodeBinding.payload =
      node.nodeBinding.transitionArtifactIdentity

theorem authorityIssuedTransitionBindingIsAccepted
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    (node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation) :
    transitionAuthority.validation.accepted node.nodeBinding :=
  authorityValidatedNodeIsAccepted transitionAuthority.validation node

theorem validatedTransitionUsesExactContentIdentityAuthority
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    (node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation) :
    node.nodeBinding.oldAuthority.authorityIdentity =
        transitionAuthority.authorityIdentity ∧
      node.nodeBinding.currentAuthority.authorityIdentity =
        transitionAuthority.authorityIdentity := by
  have validated :=
    transitionAuthority.validationAuthorityBound
      node.artifact node.validatedBinding node.validation
  constructor
  · calc
      node.nodeBinding.oldAuthority.authorityIdentity =
          node.validatedBinding.oldAuthority.authorityIdentity :=
        congrArg
          (fun evidence => evidence.oldAuthority.authorityIdentity)
          node.exactBinding.symm
      _ = transitionAuthority.authorityIdentity := validated.1
  · calc
      node.nodeBinding.currentAuthority.authorityIdentity =
          node.validatedBinding.currentAuthority.authorityIdentity :=
        congrArg
          (fun evidence => evidence.currentAuthority.authorityIdentity)
          node.exactBinding.symm
      _ = transitionAuthority.authorityIdentity := validated.2

theorem closedTransitionUsesAuthorityIssuedCurrentHead
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    node.nodeBinding.issuedContext =
      checkpointAuthority.currentCheckpoint.head.context := by
  calc
    node.nodeBinding.issuedContext = attestation.checkpoint.head.context :=
      closed.bindingMatchesAttestedHead
    _ = checkpointAuthority.currentCheckpoint.head.context :=
      authorityIssuedAttestationEstablishesCurrentHead closed.checkpointAdmitted

theorem closedTransitionBindsCurrentGeneration
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    checkpointAuthority.currentCheckpoint.head.context.authorityGeneration =
      node.nodeBinding.currentAuthority.generation := by
  calc
    checkpointAuthority.currentCheckpoint.head.context.authorityGeneration =
        node.nodeBinding.issuedContext.authorityGeneration :=
      congrArg ReceiptValidationContext.authorityGeneration
        (closedTransitionUsesAuthorityIssuedCurrentHead closed).symm
    _ = node.nodeBinding.currentAuthority.generation :=
      node.nodeBinding.contextGenerationBound

theorem closedTransitionBindsExactAuthorityIdentity
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    checkpointAuthority.currentCheckpoint.head.context.authorityIdentity =
      encoding.encode transitionAuthority.authorityIdentity := by
  have authorityBound := validatedTransitionUsesExactContentIdentityAuthority node
  calc
    checkpointAuthority.currentCheckpoint.head.context.authorityIdentity =
        node.nodeBinding.issuedContext.authorityIdentity :=
      congrArg ReceiptValidationContext.authorityIdentity
        (closedTransitionUsesAuthorityIssuedCurrentHead closed).symm
    _ = encoding.encode node.nodeBinding.currentAuthority.authorityIdentity :=
      node.nodeBinding.contextAuthorityBound
    _ = encoding.encode transitionAuthority.authorityIdentity :=
      congrArg encoding.encode authorityBound.2

theorem closedTransitionProjectionAuthorityMatchesTransitionAuthority
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    projectionAuthority.authorityIdentity =
      transitionAuthority.authorityIdentity :=
  closed.projectionAuthorityBound

theorem closedTransitionProjectionNodeIsAuthorityAccepted
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (_closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    projectionAuthority.projection.validation.accepted
      projectionNode.nodeBinding :=
  authorityValidatedSnapshotProjectionIsAccepted
    projectionAuthority.projection projectionNode

theorem closedTransitionAuthorizationSnapshotProjectsValidatedArtifact
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (closed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation) :
    checkpointAuthority.currentCheckpoint.head.context.authorizationSnapshotIdentity =
        projectionNode.artifact ∧
      projectionNode.nodeBinding.payload =
        transitionAuthority.artifactIdentity node.artifact := by
  have validatedIdentity :=
    transitionAuthority.validationBindsArtifactIdentity
      node.artifact node.validatedBinding node.validation
  constructor
  · calc
      checkpointAuthority.currentCheckpoint.head.context.authorizationSnapshotIdentity =
          node.nodeBinding.issuedContext.authorizationSnapshotIdentity :=
        congrArg ReceiptValidationContext.authorizationSnapshotIdentity
          (closedTransitionUsesAuthorityIssuedCurrentHead closed).symm
      _ = projectionNode.artifact := closed.projectionSnapshotBound.symm
  · calc
      projectionNode.nodeBinding.payload =
          node.nodeBinding.transitionArtifactIdentity :=
        closed.projectionArtifactBound
      _ = node.validatedBinding.transitionArtifactIdentity :=
        congrArg
          CedarInputIdentityTransitionEvidence.transitionArtifactIdentity
          node.exactBinding.symm
      _ = transitionAuthority.artifactIdentity node.artifact := validatedIdentity

theorem sameCurrentCheckpointSelectsUniqueTransitionArtifact
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {left right :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {leftProjection rightProjection :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {leftAttestation rightAttestation : DeclaredCheckpointAttestation domain}
    (leftClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority left projectionAuthority
        leftProjection domain watermark checkpointAuthority leftAttestation)
    (rightClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority right projectionAuthority
        rightProjection domain watermark checkpointAuthority rightAttestation) :
    left.artifact = right.artifact := by
  have leftProjectionClosed :=
    closedTransitionAuthorizationSnapshotProjectsValidatedArtifact leftClosed
  have rightProjectionClosed :=
    closedTransitionAuthorizationSnapshotProjectsValidatedArtifact rightClosed
  have sameSnapshot : leftProjection.artifact = rightProjection.artifact :=
    leftProjectionClosed.1.symm.trans rightProjectionClosed.1
  have sameProjectedArtifactIdentity :
      leftProjection.nodeBinding.payload =
        rightProjection.nodeBinding.payload :=
    oneValidatedSnapshotSelectsOnePayload
      projectionAuthority.projection
      leftProjection rightProjection sameSnapshot
  have identitiesEqual :
      transitionAuthority.artifactIdentity left.artifact =
        transitionAuthority.artifactIdentity right.artifact :=
    leftProjectionClosed.2.symm.trans
      (sameProjectedArtifactIdentity.trans rightProjectionClosed.2)
  exact
    transitionAuthority.artifactIdentityUniqueOnValidated
      left.artifact right.artifact left.validatedBinding right.validatedBinding
      left.validation right.validation identitiesEqual

theorem encodedAuthorityEqualityRecoversStringIdentity
    (encoding : CedarInputAuthorityIdentityEncoding)
    {left right : String}
    (encodedEqual : encoding.encode left = encoding.encode right) :
    left = right :=
  encoding.encodeInjective encodedEqual

theorem rejectedArtifactCannotFormAuthorityBoundTransition
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {artifact : Artifact}
    (rejected : transitionAuthority.validation.validate artifact = none) :
    ¬ ∃ node :
        AuthorityBoundNode
          Artifact
          (CedarInputIdentityTransitionEvidence encoding)
          transitionAuthority.validation,
        node.artifact = artifact := by
  intro existsNode
  rcases existsNode with ⟨node, artifactEqual⟩
  have validationAtArtifact :
      transitionAuthority.validation.validate artifact =
        some node.validatedBinding := by
    simpa [artifactEqual] using node.validation
  rw [rejected] at validationAtArtifact
  contradiction

theorem unissuedCheckpointCannotCloseTransition
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode
        Artifact
        (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode
        Nat
        (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    (notIssued : ¬ checkpointAuthority.issued attestation) :
    ¬ AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation := by
  intro closed
  exact notIssued closed.checkpointAdmitted.1

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceClosure
