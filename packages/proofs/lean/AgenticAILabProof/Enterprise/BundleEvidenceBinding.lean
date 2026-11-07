-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.BundleOwnership

namespace AgenticAILabProof.Enterprise.BundleEvidenceBinding

open BundleOwnership

abbrev Revision := String
abbrev BundleDigest := String
abbrev EnvironmentId := String
abbrev RootDeclaration := String

structure ResolvedSourceClaim where
  packageId : PackageId
  revision : Revision
  sourceTreeDigest : Digest
  deriving DecidableEq, Repr

def Resolves :=
  PackageId → Revision → Digest → Prop

def resolutionEvidenceClosed
    (resolves : Resolves)
    (sources : List ResolvedSourceClaim) : Prop :=
  ∀ source ∈ sources,
    resolves source.packageId source.revision source.sourceTreeDigest

def sourceClaimA : ResolvedSourceClaim where
  packageId := "agentic-ai-lab-proof"
  revision := "revision-a"
  sourceTreeDigest := "sha256:tree-b"

theorem populatedResolutionFieldsDoNotProveResolution :
    ¬ resolutionEvidenceClosed
      (fun _packageId _revision _sourceTreeDigest => False)
      [sourceClaimA] := by
  intro closed
  exact closed sourceClaimA (by simp)

structure BundleSubject where
  bundleDigest : BundleDigest
  canonicalSourceDigest : Digest
  rootDeclarations : List RootDeclaration
  environment : EnvironmentId
  deriving DecidableEq, Repr

structure UnboundVerificationReceipt where
  okay : Bool
  failedDeclarations : List DeclarationName
  deriving DecidableEq, Repr

def acceptsUnbound
    (_subject : BundleSubject)
    (receipt : UnboundVerificationReceipt) : Prop :=
  receipt.okay = true ∧ receipt.failedDeclarations = []

def subjectA : BundleSubject where
  bundleDigest := "sha256:bundle-a"
  canonicalSourceDigest := "sha256:source-a"
  rootDeclarations := ["Enterprise.safe"]
  environment := "lean-4.31.0"

def subjectB : BundleSubject where
  bundleDigest := "sha256:bundle-b"
  canonicalSourceDigest := "sha256:source-b"
  rootDeclarations := ["Enterprise.other"]
  environment := "lean-4.31.0"

def greenUnboundReceipt : UnboundVerificationReceipt where
  okay := true
  failedDeclarations := []

theorem subjectsAreDistinct : subjectA ≠ subjectB := by
  decide

theorem unboundGreenReceiptReplaysAcrossDistinctSubjects :
    acceptsUnbound subjectA greenUnboundReceipt ∧
      acceptsUnbound subjectB greenUnboundReceipt := by
  constructor <;> simp [acceptsUnbound, greenUnboundReceipt]

structure BoundVerificationReceipt extends UnboundVerificationReceipt where
  subjectBundleDigest : BundleDigest
  subjectCanonicalSourceDigest : Digest
  subjectRootDeclarations : List RootDeclaration
  subjectEnvironment : EnvironmentId
  deriving DecidableEq, Repr

def receiptMatches
    (subject : BundleSubject)
    (receipt : BoundVerificationReceipt) : Prop :=
  receipt.subjectBundleDigest = subject.bundleDigest ∧
    receipt.subjectCanonicalSourceDigest = subject.canonicalSourceDigest ∧
    receipt.subjectRootDeclarations = subject.rootDeclarations ∧
    receipt.subjectEnvironment = subject.environment

def acceptsBound
    (subject : BundleSubject)
    (receipt : BoundVerificationReceipt) : Prop :=
  receipt.okay = true ∧
    receipt.failedDeclarations = [] ∧
    receiptMatches subject receipt

def boundReceiptA : BoundVerificationReceipt where
  okay := true
  failedDeclarations := []
  subjectBundleDigest := subjectA.bundleDigest
  subjectCanonicalSourceDigest := subjectA.canonicalSourceDigest
  subjectRootDeclarations := subjectA.rootDeclarations
  subjectEnvironment := subjectA.environment

theorem boundReceiptAAcceptsSubjectA :
    acceptsBound subjectA boundReceiptA := by
  simp [acceptsBound, receiptMatches, boundReceiptA, subjectA]

theorem boundReceiptARejectsSubjectB :
    ¬ acceptsBound subjectB boundReceiptA := by
  simp [acceptsBound, receiptMatches, boundReceiptA, subjectA, subjectB]

structure ResolutionReceipt where
  packageId : PackageId
  revision : Revision
  sourceTreeDigest : Digest
  resolverId : String
  resolverReceiptDigest : Digest
  deriving DecidableEq, Repr

def resolutionReceiptMatches
    (source : ResolvedSourceClaim)
    (receipt : ResolutionReceipt) : Prop :=
  receipt.packageId = source.packageId ∧
    receipt.revision = source.revision ∧
    receipt.sourceTreeDigest = source.sourceTreeDigest

def ResolutionReceiptValid :=
  ResolutionReceipt → Prop

def resolutionReceiptsClosed
    (valid : ResolutionReceiptValid)
    (sources : List ResolvedSourceClaim)
    (receipts : List ResolutionReceipt) : Prop :=
  ∀ source ∈ sources,
    ∃ receipt ∈ receipts,
      resolutionReceiptMatches source receipt ∧ valid receipt

def sourceReceiptA : ResolutionReceipt where
  packageId := sourceClaimA.packageId
  revision := sourceClaimA.revision
  sourceTreeDigest := sourceClaimA.sourceTreeDigest
  resolverId := "lake"
  resolverReceiptDigest := "sha256:lake-receipt"

theorem matchingResolutionReceiptClosesSourceClaim :
    resolutionReceiptsClosed
      (fun _receipt => True)
      [sourceClaimA]
      [sourceReceiptA] := by
  intro source sourceMember
  simp [sourceClaimA] at sourceMember
  subst source
  exact
    ⟨sourceReceiptA, by simp,
      by simp [resolutionReceiptMatches, sourceReceiptA, sourceClaimA]⟩

theorem matchingFieldsDoNotProveResolverAuthority :
    resolutionReceiptMatches sourceClaimA sourceReceiptA ∧
      ¬ resolutionReceiptsClosed
        (fun _receipt => False)
        [sourceClaimA]
        [sourceReceiptA] := by
  constructor
  · simp [resolutionReceiptMatches, sourceClaimA, sourceReceiptA]
  · intro closed
    obtain ⟨receipt, receiptMember, _matches, valid⟩ :=
      closed sourceClaimA (by simp)
    simp [sourceReceiptA] at receiptMember
    subst receipt
    exact valid

def proofEvidenceClosed
    (subject : BundleSubject)
    (verification : BoundVerificationReceipt)
    (resolutionReceiptValid : ResolutionReceiptValid)
    (sources : List ResolvedSourceClaim)
    (resolutionReceipts : List ResolutionReceipt) : Prop :=
  acceptsBound subject verification ∧
    resolutionReceiptsClosed
      resolutionReceiptValid
      sources
      resolutionReceipts

theorem proofEvidenceClosedRejectsReceiptReplay
    (resolutionReceiptValid : ResolutionReceiptValid)
    (sources : List ResolvedSourceClaim)
    (resolutionReceipts : List ResolutionReceipt) :
    ¬ proofEvidenceClosed
      subjectB
      boundReceiptA
      resolutionReceiptValid
      sources
      resolutionReceipts := by
  intro closed
  exact boundReceiptARejectsSubjectB closed.1

end AgenticAILabProof.Enterprise.BundleEvidenceBinding
