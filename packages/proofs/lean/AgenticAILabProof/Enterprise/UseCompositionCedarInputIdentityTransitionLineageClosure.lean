-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceClosure
import AgenticAILabProof.Enterprise.ReceiptContextSuccessorAdmissionBindingClosure
import AgenticAILabProof.Enterprise.ReceiptContextLineagePrefixClosure

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionLineageClosure

open AgenticAILabProof.Enterprise.ReceiptAuthorityBindingClosure
open AgenticAILabProof.Enterprise.ReceiptContextFreshnessClosure
open AgenticAILabProof.Enterprise.ReceiptContextMonotonicityClosure
open AgenticAILabProof.Enterprise.ReceiptContextCheckpointClosure
open AgenticAILabProof.Enterprise.ReceiptContextSuccessorAdmissionBindingClosure
open AgenticAILabProof.Enterprise.AuthorityValidatedSnapshotProjectionClosure
open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceClosure
open AgenticAILabProof.Enterprise.ReceiptContextLineagePrefixClosure

structure PublishedPredecessorCedarInputIdentityTransitionClosed
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
    (attestation : DeclaredCheckpointAttestation domain)
    (baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation)
    (successorAdmission : SuccessorAdmissionClosure)
    (lineage : AuthorityContextLineage)
    (priorPosition currentPosition : Nat) : Prop where
  priorContextBindsSuccessorAdmission :
    node.nodeBinding.priorContext = successorAdmission.before.context
  currentContextBindsSuccessorAdmission :
    node.nodeBinding.issuedContext = successorAdmission.after.context
  successorWatermarkBound :
    successorAdmission.verifierWatermark = watermark
  priorContextPublished :
    lineage.contextAt priorPosition = node.nodeBinding.priorContext
  currentContextPublished :
    lineage.contextAt currentPosition = node.nodeBinding.issuedContext
  lineageAuthorityBound :
    lineage.authorityIdentity = encoding.encode transitionAuthority.authorityIdentity
  positionsAdjacent : currentPosition = priorPosition + 1
  publicationDomainPrefixBound :
    LineagePrefixPublicationDomainBinding
      (lineagePrefixAt lineage currentPosition)
      domain

theorem closedTransitionUsesExactSuccessorAdmissionContexts
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
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    node.nodeBinding.priorContext = successorAdmission.before.context ∧
      node.nodeBinding.issuedContext = successorAdmission.after.context :=
  ⟨closed.priorContextBindsSuccessorAdmission,
    closed.currentContextBindsSuccessorAdmission⟩

theorem closedTransitionBindsPublishedPredecessorGeneration
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
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    (lineage.contextAt priorPosition).authorityGeneration =
      node.nodeBinding.oldAuthority.generation := by
  calc
    (lineage.contextAt priorPosition).authorityGeneration =
        node.nodeBinding.priorContext.authorityGeneration :=
      congrArg ReceiptValidationContext.authorityGeneration
        closed.priorContextPublished
    _ = node.nodeBinding.oldAuthority.generation :=
      node.nodeBinding.priorContextGenerationBound

theorem closedTransitionUsesValidAdjacentPublishedContextAdvance
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    validAuthorityContextTransition
      node.nodeBinding.priorContext node.nodeBinding.issuedContext := by
  have positionAdvanced : priorPosition < currentPosition := by
    rw [closed.positionsAdjacent]
    exact Nat.lt_succ_self priorPosition
  have publishedAdvance :
      validAuthorityContextTransition
        (lineage.contextAt priorPosition)
        (lineage.contextAt currentPosition) :=
    ⟨(lineage.fixedAuthority priorPosition).trans
        (lineage.fixedAuthority currentPosition).symm,
      lineage.generationStrict positionAdvanced⟩
  simpa [closed.priorContextPublished, closed.currentContextPublished] using
    publishedAdvance

theorem closedTransitionRequiresFreshSuccessorAdmission
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (_closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    successorAdmission.previousAdmissionEpoch <
      successorAdmission.admission.admissionEpoch :=
  closedSuccessorRequiresFreshCoordinatorAdmission successorAdmission

theorem unpublishedPriorContextCannotCloseTransition
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (notPublished :
      lineage.contextAt priorPosition ≠ node.nodeBinding.priorContext) :
    ¬ PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition := by
  intro closed
  exact notPublished closed.priorContextPublished

theorem nonAdjacentLineagePositionsCannotCloseTransition
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (notAdjacent : currentPosition ≠ priorPosition + 1) :
    ¬ PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition := by
  intro closed
  exact notAdjacent closed.positionsAdjacent

theorem closedTransitionPriorContextIsPublishedInCheckpointDomain
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    domain.published node.nodeBinding.priorContext := by
  have priorAtOrBeforeHead : priorPosition ≤ currentPosition := by
    rw [closed.positionsAdjacent]
    exact Nat.le_succ priorPosition
  apply (closed.publicationDomainPrefixBound.publishedExact _).2
  exact ⟨priorPosition, priorAtOrBeforeHead, closed.priorContextPublished⟩

theorem closedTransitionRejectsLineagePositionAfterCurrentHead
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition futurePosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition)
    (afterCurrentHead : currentPosition < futurePosition) :
    ¬ domain.published (lineage.contextAt futurePosition) :=
  boundDomainRejectsPositionAfterPrefixHead
    closed.publicationDomainPrefixBound afterCurrentHead

theorem closedTransitionSuccessorAdmissionUsesCheckpointDomain
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (closed :
      PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition) :
    successorAdmission.admission.publicationDomainIdentity =
      domain.domainIdentity := by
  have successorDomain := successorAdmission.checkpointBinding.1
  have watermarkDomainEqual :
      successorAdmission.verifierWatermark.publicationDomainIdentity =
        watermark.publicationDomainIdentity :=
    congrArg TrustedCheckpointWatermark.publicationDomainIdentity
      closed.successorWatermarkBound
  have checkpointDomain := baseClosed.checkpointAdmitted.2.1
  calc
    successorAdmission.admission.publicationDomainIdentity =
        successorAdmission.verifierWatermark.publicationDomainIdentity :=
      successorDomain.symm
    _ = watermark.publicationDomainIdentity := watermarkDomainEqual
    _ = domain.domainIdentity := checkpointDomain.symm

theorem mismatchedSuccessorAndCheckpointWatermarksCannotCloseTransition
    {encoding : CedarInputAuthorityIdentityEncoding}
    {Artifact : Type}
    {transitionAuthority :
      CedarInputIdentityTransitionAcceptanceAuthority encoding Artifact}
    {node :
      AuthorityBoundNode Artifact (CedarInputIdentityTransitionEvidence encoding)
        transitionAuthority.validation}
    {projectionAuthority : CedarInputIdentityTransitionProjectionAuthority}
    {projectionNode :
      AuthorityBoundNode Nat (SnapshotProjection Nat Nat)
        projectionAuthority.projection.validation}
    {domain : AuthoritativeContextPublicationDomain}
    {watermark : TrustedCheckpointWatermark}
    {checkpointAuthority : LiveCheckpointAttestationAuthority domain}
    {attestation : DeclaredCheckpointAttestation domain}
    {baseClosed :
      AuthorityIssuedCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation}
    {successorAdmission : SuccessorAdmissionClosure}
    {lineage : AuthorityContextLineage}
    {priorPosition currentPosition : Nat}
    (mismatch : successorAdmission.verifierWatermark ≠ watermark) :
    ¬ PublishedPredecessorCedarInputIdentityTransitionClosed
        encoding Artifact transitionAuthority node projectionAuthority
        projectionNode domain watermark checkpointAuthority attestation
        baseClosed successorAdmission lineage priorPosition currentPosition := by
  intro closed
  exact mismatch closed.successorWatermarkBound

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionLineageClosure
