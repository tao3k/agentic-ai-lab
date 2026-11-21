-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeClosure

namespace AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProofBaseReceiptCompositionClosure

inductive RootDeclarationKind where
  | theorem
  | nonTheorem
  deriving DecidableEq, Repr

inductive TheoremProofStatus where
  | accepted
  | notApplicable
  deriving DecidableEq, Repr

def RootObligationSatisfied :
    RootDeclarationKind → TheoremProofStatus → Prop
  | .theorem, .accepted => True
  | .nonTheorem, .notApplicable => True
  | _, _ => False

def DeclarationSetsDisjoint
    {Name : Type}
    (proofBaseDeclaration sourceDeclaration : Name → Prop) : Prop :=
  ∀ name, ¬(proofBaseDeclaration name ∧ sourceDeclaration name)

def DigestBindingInjective
    {Digest Interface : Type}
    (DigestBinds : Digest → Interface → Prop) : Prop :=
  ∀ digest left right,
    DigestBinds digest left →
      DigestBinds digest right →
        left = right

structure ProofBaseReceipt
    (Digest Interface : Type)
    (DigestBinds : Digest → Interface → Prop) where
  canonicalInterface : Interface
  interfaceDigest : Digest
  baseProofAccepted : Prop
  digestBindsCanonicalInterface :
    DigestBinds interfaceDigest canonicalInterface

structure IncrementReceipt
    (Digest Interface Name : Type)
    (DigestBinds : Digest → Interface → Prop) where
  assumedInterface : Interface
  interfaceDigest : Digest
  rootKind : RootDeclarationKind
  theoremProofStatus : TheoremProofStatus
  roundTripAccepted : Prop
  digestBindsAssumedInterface :
    DigestBinds interfaceDigest assumedInterface
  proofBaseDeclaration : Name → Prop
  sourceDeclaration : Name → Prop
  ownershipDisjoint :
    DeclarationSetsDisjoint proofBaseDeclaration sourceDeclaration

def IncrementAccepted
    {Digest Interface Name : Type}
    {DigestBinds : Digest → Interface → Prop}
    (receipt : IncrementReceipt Digest Interface Name DigestBinds) : Prop :=
  receipt.roundTripAccepted ∧
    RootObligationSatisfied
      receipt.rootKind
      receipt.theoremProofStatus

def ReceiptDigestBound
    {Digest Interface Name : Type}
    {DigestBinds : Digest → Interface → Prop}
    (base : ProofBaseReceipt Digest Interface DigestBinds)
    (increment : IncrementReceipt Digest Interface Name DigestBinds) : Prop :=
  base.interfaceDigest = increment.interfaceDigest

def CanonicalInterfaceBound
    {Digest Interface Name : Type}
    {DigestBinds : Digest → Interface → Prop}
    (base : ProofBaseReceipt Digest Interface DigestBinds)
    (increment : IncrementReceipt Digest Interface Name DigestBinds) : Prop :=
  base.canonicalInterface = increment.assumedInterface

structure VerifiedComposition
    {Digest Interface Name World : Type}
    {DigestBinds : Digest → Interface → Prop}
    (base : ProofBaseReceipt Digest Interface DigestBinds)
    (increment : IncrementReceipt Digest Interface Name DigestBinds)
    (BaseSemantics IncrementSemantics : World → Prop) : Prop where
  baseReceiptAccepted : base.baseProofAccepted
  incrementReceiptAccepted : IncrementAccepted increment
  canonicalInterfaceBound : CanonicalInterfaceBound base increment
  semanticGuarantee :
    ∀ world, BaseSemantics world → IncrementSemantics world

theorem digestBoundClosesCanonicalInterface
    {Digest Interface Name : Type}
    {DigestBinds : Digest → Interface → Prop}
    (base : ProofBaseReceipt Digest Interface DigestBinds)
    (increment : IncrementReceipt Digest Interface Name DigestBinds)
    (digestBindingInjective : DigestBindingInjective DigestBinds)
    (digestBound : ReceiptDigestBound base increment) :
    CanonicalInterfaceBound base increment := by
  apply digestBindingInjective
      base.interfaceDigest
      base.canonicalInterface
      increment.assumedInterface
  · exact base.digestBindsCanonicalInterface
  · rw [digestBound]
    exact increment.digestBindsAssumedInterface

theorem receiptBoundAssumeGuaranteeComposition
    {Digest Interface Name World : Type}
    {DigestBinds : Digest → Interface → Prop}
    (base : ProofBaseReceipt Digest Interface DigestBinds)
    (increment : IncrementReceipt Digest Interface Name DigestBinds)
    (BaseSemantics IncrementSemantics : World → Prop)
    (InterfaceSemantics : Interface → World → Prop)
    (digestBindingInjective : DigestBindingInjective DigestBinds)
    (digestBound : ReceiptDigestBound base increment)
    (baseReceiptAccepted : base.baseProofAccepted)
    (incrementReceiptAccepted : IncrementAccepted increment)
    (baseEstablishesInterface :
      ∀ world,
        BaseSemantics world →
          InterfaceSemantics base.canonicalInterface world)
    (incrementValidUnderInterface :
      ∀ world,
        InterfaceSemantics increment.assumedInterface world →
          IncrementSemantics world) :
    VerifiedComposition
      base
      increment
      BaseSemantics
      IncrementSemantics := by
  have interfaceBound :
      CanonicalInterfaceBound base increment :=
    digestBoundClosesCanonicalInterface
      base
      increment
      digestBindingInjective
      digestBound
  refine
    { baseReceiptAccepted := baseReceiptAccepted
      incrementReceiptAccepted := incrementReceiptAccepted
      canonicalInterfaceBound := interfaceBound
      semanticGuarantee := ?_ }
  intro world baseHolds
  apply incrementValidUnderInterface
  rw [← interfaceBound]
  exact baseEstablishesInterface world baseHolds

def CollidingDigestBinds (_ : Unit) (_ : Bool) : Prop :=
  True

theorem digestEqualityAloneDoesNotCloseCanonicalInterface :
    ∃ baseInterface incrementInterface : Bool,
      CollidingDigestBinds () baseInterface ∧
        CollidingDigestBinds () incrementInterface ∧
          ((): Unit) = () ∧
            baseInterface ≠ incrementInterface := by
  refine ⟨false, true, trivial, trivial, rfl, ?_⟩
  decide

def Rfc50RootDeclarationName : String :=
  "AgenticAILabProof.Enterprise." ++
    "SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeClosure." ++
    "SourceBoundEffectCompletionRecoveryCommittedEffectExactlyOnceBridgeEvidence"

def Rfc50RootKind : RootDeclarationKind :=
  .nonTheorem

theorem rfc50RootObligationSatisfied :
    RootObligationSatisfied
      Rfc50RootKind
      .notApplicable := by
  trivial

theorem theoremRootRejectsNotApplicable :
    ¬ RootObligationSatisfied
      .theorem
      .notApplicable := by
  simp [RootObligationSatisfied]

end AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryProofBaseReceiptCompositionClosure
