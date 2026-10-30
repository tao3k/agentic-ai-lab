-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionIssuanceModel

namespace AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionCommitmentModel

open AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityGenerationTransitionModel

structure TransitionCheckpointContext where
  authorityIdentity : Nat
  generation : Nat
  authorizationSnapshotIdentity : Nat
  deriving DecidableEq, Repr

structure TransitionArtifactCommitment where
  artifactIdentity : Nat
  currentSemanticIdentity : Nat
  deriving DecidableEq, Repr

structure TransitionArtifactProjectionRegistry where
  resolve : Nat → Option Nat

def transitionArtifactRegisteredAt
    (registry : TransitionArtifactProjectionRegistry)
    (authorizationSnapshotIdentity transitionArtifactIdentity : Nat) : Prop :=
  registry.resolve authorizationSnapshotIdentity =
    some transitionArtifactIdentity

def collapsedSnapshotArtifactIdentityAccepted
    (context : TransitionCheckpointContext)
    (artifact : TransitionArtifactCommitment) : Prop :=
  context.authorizationSnapshotIdentity = artifact.artifactIdentity

def contextOnlyTransitionAccepted
    (current : IdentityAuthoritySnapshot)
    (context : TransitionCheckpointContext) : Prop :=
  context.authorityIdentity = current.authorityIdentity ∧
    context.generation = current.generation

def committedTransitionAccepted
    (current : IdentityAuthoritySnapshot)
    (context : TransitionCheckpointContext)
    (artifact : TransitionArtifactCommitment) : Prop :=
  contextOnlyTransitionAccepted current context ∧
    context.authorizationSnapshotIdentity = artifact.artifactIdentity ∧
    artifact.currentSemanticIdentity = current.semanticIdentity

def semanticRotationFortyOne : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 41
  generation := 4
  digest := fun content => content + 141
  admitted := fun content => content = 7

def semanticRotationFortyTwo : IdentityAuthoritySnapshot where
  authorityIdentity := 17
  semanticIdentity := 42
  generation := 4
  digest := fun content => content + 142
  admitted := fun content => content = 7

def sharedTransitionContext : TransitionCheckpointContext where
  authorityIdentity := 17
  generation := 4
  authorizationSnapshotIdentity := 701

def rotationFortyOneArtifact : TransitionArtifactCommitment where
  artifactIdentity := 701
  currentSemanticIdentity := 41

def rotationFortyTwoArtifact : TransitionArtifactCommitment where
  artifactIdentity := 702
  currentSemanticIdentity := 42

def separatedIdentityTransitionContext : TransitionCheckpointContext where
  authorityIdentity := 17
  generation := 4
  authorizationSnapshotIdentity := 900

def separatedIdentityProjectionRegistry : TransitionArtifactProjectionRegistry where
  resolve := fun snapshotIdentity =>
    if snapshotIdentity = 900 then some 701 else none

theorem rotationFortyOneClosed :
    SemanticIdentityRotationClosed oldAuthority semanticRotationFortyOne := by
  exact
    { authorityStable := rfl
      semanticIdentityChanges := by decide
      generationAdvances := by decide }

theorem rotationFortyTwoClosed :
    SemanticIdentityRotationClosed oldAuthority semanticRotationFortyTwo := by
  exact
    { authorityStable := rfl
      semanticIdentityChanges := by decide
      generationAdvances := by decide }

theorem contextOnlyCheckpointAllowsSameGenerationSemanticFork :
    contextOnlyTransitionAccepted
        semanticRotationFortyOne sharedTransitionContext ∧
      contextOnlyTransitionAccepted
        semanticRotationFortyTwo sharedTransitionContext ∧
      semanticRotationFortyOne.semanticIdentity ≠
        semanticRotationFortyTwo.semanticIdentity := by
  simp [contextOnlyTransitionAccepted, semanticRotationFortyOne,
    semanticRotationFortyTwo, sharedTransitionContext]

theorem exactTransitionCommitmentAcceptsSelectedArtifact :
    committedTransitionAccepted
      semanticRotationFortyOne
      sharedTransitionContext
      rotationFortyOneArtifact := by
  simp [committedTransitionAccepted, contextOnlyTransitionAccepted,
    semanticRotationFortyOne, sharedTransitionContext,
    rotationFortyOneArtifact]

theorem exactTransitionCommitmentRejectsOtherArtifact :
    ¬ committedTransitionAccepted
      semanticRotationFortyTwo
      sharedTransitionContext
      rotationFortyTwoArtifact := by
  simp [committedTransitionAccepted, contextOnlyTransitionAccepted,
    semanticRotationFortyTwo, sharedTransitionContext,
    rotationFortyTwoArtifact]

theorem registryProjectionAcceptsSeparatedIdentityDomains :
    transitionArtifactRegisteredAt
      separatedIdentityProjectionRegistry
      separatedIdentityTransitionContext.authorizationSnapshotIdentity
      rotationFortyOneArtifact.artifactIdentity := by
  simp [transitionArtifactRegisteredAt, separatedIdentityProjectionRegistry,
    separatedIdentityTransitionContext, rotationFortyOneArtifact]

theorem collapsedIdentityRejectsValidSeparatedProjection :
    ¬ collapsedSnapshotArtifactIdentityAccepted
      separatedIdentityTransitionContext
      rotationFortyOneArtifact := by
  simp [collapsedSnapshotArtifactIdentityAccepted,
    separatedIdentityTransitionContext, rotationFortyOneArtifact]

end AgenticAILabProof.Enterprise.UseCompositionCedarInputIdentityTransitionCommitmentModel
