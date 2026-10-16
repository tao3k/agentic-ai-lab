-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import PooFlowCoreProof.PooC4.EventIngressCausalCut

namespace PooFlowProof.PooC4.TemporalCausality

open EventIngressCausalCut

inductive EventModality where
  | observed
  | declared
  | derived
  | hypothesized
  | counterfactual
  deriving DecidableEq, Repr

structure CausalEvent (EventIdentity SubjectIdentity PayloadIdentity : Type) where
  identity : EventIdentity
  subject : SubjectIdentity
  payloadIdentity : PayloadIdentity
  logicalPosition : Nat
  causalParents : List EventIdentity
  modality : EventModality
  committed : Bool

def ModalityCommitmentValid
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity) : Prop :=
  (event.modality = .observed → event.committed = true) ∧
    (event.modality = .hypothesized → event.committed = false) ∧
    (event.modality = .counterfactual → event.committed = false)

def AdmittedAt
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (asOf : Nat)
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity) : Prop :=
  event.committed = true ∧ event.logicalPosition ≤ asOf

/- A declarative trajectory keeps the actual path, counterfactual error paths,
and hypothesized impacts separate.  Vertical domains refine this contract;
they do not invent their own modality semantics. -/
def ErrorTrajectoryValid
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (events : List (CausalEvent EventIdentity SubjectIdentity PayloadIdentity)) : Prop :=
  ∀ event ∈ events,
    event.modality = .counterfactual ∧ event.committed = false

def ImpactTrajectoryValid
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (events : List (CausalEvent EventIdentity SubjectIdentity PayloadIdentity)) : Prop :=
  ∀ event ∈ events,
    event.modality = .hypothesized ∧ event.committed = false

theorem validErrorTrajectoryMemberCannotBeAdmitted
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (events : List (CausalEvent EventIdentity SubjectIdentity PayloadIdentity))
    (valid : ErrorTrajectoryValid events)
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity)
    (member : event ∈ events) (asOf : Nat) :
    ¬ AdmittedAt asOf event := by
  intro admitted
  have notCommitted := (valid event member).2
  simp [AdmittedAt, notCommitted] at admitted

theorem validImpactTrajectoryMemberCannotBeAdmitted
    {EventIdentity SubjectIdentity PayloadIdentity : Type}
    (events : List (CausalEvent EventIdentity SubjectIdentity PayloadIdentity))
    (valid : ImpactTrajectoryValid events)
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity)
    (member : event ∈ events) (asOf : Nat) :
    ¬ AdmittedAt asOf event := by
  intro admitted
  have notCommitted := (valid event member).2
  simp [AdmittedAt, notCommitted] at admitted

structure CausalEventGraph
    (EventIdentity SubjectIdentity PayloadIdentity GraphIdentity : Type) where
  graphIdentity : GraphIdentity
  subject : SubjectIdentity
  events : List (CausalEvent EventIdentity SubjectIdentity PayloadIdentity)
  eventIdentityInjective :
    ∀ left ∈ events, ∀ right ∈ events,
      left.identity = right.identity → left = right

structure CausalCutProjection
    (EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity : Type) where
  graph : CausalEventGraph EventIdentity SubjectIdentity PayloadIdentity GraphIdentity
  asOf : Nat
  cut : ImmutableCausalCut EventIdentity CutIdentity
  cutComesFromGraph :
    ∀ eventIdentity ∈ cut.events,
      ∃ event ∈ graph.events,
        event.identity = eventIdentity ∧ AdmittedAt asOf event
  containsEveryAdmittedEvent :
    ∀ event ∈ graph.events,
      AdmittedAt asOf event → event.identity ∈ cut.events

structure TemporalClassificationReceipt
    (EventIdentity GraphIdentity CutIdentity : Type) where
  graphIdentity : GraphIdentity
  cutIdentity : CutIdentity
  past : List EventIdentity
  current : List EventIdentity
  future : List EventIdentity
  counterfactual : List EventIdentity
  outsideHorizon : List EventIdentity
  unknownFrontier : List EventIdentity
  completeClassification : Prop
  completenessRequiresClosedFrontier :
    completeClassification → unknownFrontier = []
  assuranceClosed : Bool
  releaseAuthorized : Bool
  structuralClassificationHasNoAssurance : assuranceClosed = false
  structuralClassificationHasNoAuthority : releaseAuthorized = false

theorem cutContainsOnlyCommittedPastOrCurrentEvents
    {EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity : Type}
    (projection :
      CausalCutProjection
        EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity)
    (eventIdentity : EventIdentity)
    (membership : eventIdentity ∈ projection.cut.events) :
    ∃ event ∈ projection.graph.events,
      event.identity = eventIdentity ∧
      event.committed = true ∧
      event.logicalPosition ≤ projection.asOf := by
  obtain ⟨event, inGraph, identity, admitted⟩ :=
    projection.cutComesFromGraph eventIdentity membership
  exact ⟨event, inGraph, identity, admitted.1, admitted.2⟩

theorem futureEventIsExcludedFromCut
    {EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity : Type}
    (projection :
      CausalCutProjection
        EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity)
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity)
    (inGraph : event ∈ projection.graph.events)
    (future : projection.asOf < event.logicalPosition) :
    event.identity ∉ projection.cut.events := by
  intro inCut
  obtain ⟨projected, projectedInGraph, sameIdentity, _, notFuture⟩ :=
    cutContainsOnlyCommittedPastOrCurrentEvents projection event.identity inCut
  have projectedIsEvent : projected = event := by
    exact projection.graph.eventIdentityInjective
      projected projectedInGraph event inGraph sameIdentity
  subst projected
  exact (Nat.not_le_of_lt future) notFuture

theorem counterfactualEventIsExcludedFromCut
    {EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity : Type}
    (projection :
      CausalCutProjection
        EventIdentity SubjectIdentity PayloadIdentity GraphIdentity CutIdentity)
    (event : CausalEvent EventIdentity SubjectIdentity PayloadIdentity)
    (inGraph : event ∈ projection.graph.events)
    (valid : ModalityCommitmentValid event)
    (counterfactual : event.modality = .counterfactual) :
    event.identity ∉ projection.cut.events := by
  intro inCut
  obtain ⟨projected, projectedInGraph, sameIdentity, committed, _⟩ :=
    cutContainsOnlyCommittedPastOrCurrentEvents projection event.identity inCut
  have projectedIsEvent : projected = event := by
    exact projection.graph.eventIdentityInjective
      projected projectedInGraph event inGraph sameIdentity
  subst projected
  have notCommitted := valid.2.2 counterfactual
  simp [notCommitted] at committed

theorem openFrontierPreventsCompleteClassification
    {EventIdentity GraphIdentity CutIdentity : Type}
    (receipt : TemporalClassificationReceipt EventIdentity GraphIdentity CutIdentity)
    (openFrontier : receipt.unknownFrontier ≠ []) :
    ¬ receipt.completeClassification := by
  intro complete
  exact openFrontier (receipt.completenessRequiresClosedFrontier complete)

theorem structuralClassificationNeverAuthorizesRelease
    {EventIdentity GraphIdentity CutIdentity : Type}
    (receipt : TemporalClassificationReceipt EventIdentity GraphIdentity CutIdentity) :
    receipt.releaseAuthorized = false :=
  receipt.structuralClassificationHasNoAuthority

end PooFlowProof.PooC4.TemporalCausality
