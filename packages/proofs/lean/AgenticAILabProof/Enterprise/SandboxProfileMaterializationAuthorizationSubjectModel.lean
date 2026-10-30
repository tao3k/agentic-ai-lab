-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectModel

def effectOnlyBinding
    {Effect : Type}
    (expectedEffect observedEffect : Effect) : Prop :=
  expectedEffect = observedEffect

def subjectOnlyBinding
    {Subject : Type}
    (authorizedSubject executionSubject : Subject) : Prop :=
  authorizedSubject = executionSubject

theorem subjectBindingAlonePermitsRuntimeEpochSubstitution
    {Subject Epoch : Type}
    (subject : Subject)
    (authorizedEpoch executionEpoch : Epoch)
    (staleEpoch : authorizedEpoch ≠ executionEpoch) :
    subjectOnlyBinding subject subject ∧
      authorizedEpoch ≠ executionEpoch := by
  exact ⟨rfl, staleEpoch⟩

theorem effectOnlyBindingPermitsOwnerSubjectSubstitution
    {Owner Effect : Type}
    (leftOwner rightOwner : Owner)
    (ownersDiffer : leftOwner ≠ rightOwner)
    (effect : Effect) :
    effectOnlyBinding effect effect ∧
      effectOnlyBinding effect effect ∧
      leftOwner ≠ rightOwner := by
  exact ⟨rfl, rfl, ownersDiffer⟩

structure AuthorizationSubjectProjection
    (Owner Materialization Context Subject : Type) where
  project : Owner → Materialization → Context → Subject
  ownerInjectiveAt :
    ∀ materialization context,
      Function.Injective (fun owner => project owner materialization context)

def projectionLocallyCloses
    {Owner Materialization Context Subject : Type}
    (projection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (owner : Owner)
    (materialization : Materialization)
    (context : Context)
    (authorizationSubject : Subject) : Prop :=
  authorizationSubject =
    projection.project owner materialization context

theorem injectivityAlonePermitsProjectionSubstitution
    {Owner Materialization Context Subject : Type}
    (leftProjection rightProjection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (owner : Owner)
    (materialization : Materialization)
    (context : Context)
    (projectedSubjectsDiffer :
      leftProjection.project owner materialization context ≠
        rightProjection.project owner materialization context) :
    projectionLocallyCloses
        leftProjection
        owner
        materialization
        context
        (leftProjection.project owner materialization context) ∧
      projectionLocallyCloses
        rightProjection
        owner
        materialization
        context
        (rightProjection.project owner materialization context) ∧
      leftProjection.project owner materialization context ≠
        rightProjection.project owner materialization context := by
  exact ⟨rfl, rfl, projectedSubjectsDiffer⟩

structure AuthorizationSubjectProjectionRegistry
    (Snapshot Owner Materialization Context Subject : Type) where
  resolve :
    Snapshot → Option (Owner → Materialization → Context → Subject)

def projectionRegisteredAt
    {Snapshot Owner Materialization Context Subject : Type}
    (registry :
      AuthorizationSubjectProjectionRegistry
        Snapshot Owner Materialization Context Subject)
    (snapshot : Snapshot)
    (projection :
      AuthorizationSubjectProjection Owner Materialization Context Subject) :
    Prop :=
  registry.resolve snapshot = some projection.project

theorem registeredProjectionsAtOneSnapshotAgree
    {Snapshot Owner Materialization Context Subject : Type}
    (registry :
      AuthorizationSubjectProjectionRegistry
        Snapshot Owner Materialization Context Subject)
    (snapshot : Snapshot)
    (leftProjection rightProjection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (owner : Owner)
    (materialization : Materialization)
    (context : Context)
    (leftRegistered :
      projectionRegisteredAt registry snapshot leftProjection)
    (rightRegistered :
      projectionRegisteredAt registry snapshot rightProjection) :
    leftProjection.project owner materialization context =
      rightProjection.project owner materialization context := by
  have functionsAgree : leftProjection.project = rightProjection.project := by
    apply Option.some.inj
    exact leftRegistered.symm.trans rightRegistered
  exact
    congrFun
      (congrFun
        (congrFun functionsAgree owner)
        materialization)
      context

theorem sameSnapshotAcrossUnboundRegistriesPermitsProjectionSubstitution
    {Snapshot Owner Materialization Context Subject : Type}
    (leftRegistry rightRegistry :
      AuthorizationSubjectProjectionRegistry
        Snapshot Owner Materialization Context Subject)
    (snapshot : Snapshot)
    (leftProjection rightProjection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (owner : Owner)
    (materialization : Materialization)
    (context : Context)
    (leftRegistered :
      projectionRegisteredAt leftRegistry snapshot leftProjection)
    (rightRegistered :
      projectionRegisteredAt rightRegistry snapshot rightProjection)
    (projectedSubjectsDiffer :
      leftProjection.project owner materialization context ≠
        rightProjection.project owner materialization context) :
    projectionRegisteredAt leftRegistry snapshot leftProjection ∧
      projectionRegisteredAt rightRegistry snapshot rightProjection ∧
      leftProjection.project owner materialization context ≠
        rightProjection.project owner materialization context := by
  exact ⟨leftRegistered, rightRegistered, projectedSubjectsDiffer⟩

theorem deterministicAuthorityValidationRejectsRegistrySubstitution
    {Artifact Registry : Type}
    (validate : Artifact → Option Registry)
    (artifact : Artifact)
    (leftRegistry rightRegistry : Registry)
    (leftValidated : validate artifact = some leftRegistry)
    (rightValidated : validate artifact = some rightRegistry) :
    leftRegistry = rightRegistry := by
  apply Option.some.inj
  exact leftValidated.symm.trans rightValidated

theorem projectedAuthorizationSubjectRejectsOwnerSubstitution
    {Owner Materialization Context Subject : Type}
    (projection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (materialization : Materialization)
    (context : Context)
    (authorizationSubject : Subject)
    (leftOwner rightOwner : Owner)
    (leftClosed :
      authorizationSubject =
        projection.project leftOwner materialization context)
    (rightClosed :
      authorizationSubject =
        projection.project rightOwner materialization context) :
    leftOwner = rightOwner := by
  apply projection.ownerInjectiveAt materialization context
  exact leftClosed.symm.trans rightClosed

theorem dualEngineSubjectsBindProjectedOwner
    {Owner Materialization Context Subject : Type}
    (projection :
      AuthorizationSubjectProjection Owner Materialization Context Subject)
    (owner : Owner)
    (materialization : Materialization)
    (context : Context)
    (authorizationSubject leftSubject rightSubject : Subject)
    (leftExact : leftSubject = authorizationSubject)
    (rightExact : rightSubject = authorizationSubject)
    (subjectProjected :
      authorizationSubject =
        projection.project owner materialization context) :
    leftSubject = projection.project owner materialization context ∧
      rightSubject = projection.project owner materialization context := by
  exact
    ⟨leftExact.trans subjectProjected,
      rightExact.trans subjectProjected⟩

end AgenticAILabProof.Enterprise.SandboxProfileMaterializationAuthorizationSubjectModel
