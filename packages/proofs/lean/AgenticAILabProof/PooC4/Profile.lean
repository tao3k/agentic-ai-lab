-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.NatScope

namespace AgenticAILabProof.PooC4.Profile

open AgenticAILabProof.PooC4

inductive ProfileModule where
  | declaration
  | governor
  | selectorPolicy
  | resourcePolicy
  | capabilityPolicy
  | memoryPolicy
  | compressionPolicy
  | runtimeManifest
deriving Repr, DecidableEq

abbrev ProfileScope := Nat

def declarationScope : ProfileScope := 1
def governorScope : ProfileScope := 2
def policyScope : ProfileScope := 3
def runtimeManifestScope : ProfileScope := 4

structure ProfileState where
  activeScope : ProfileScope
  declared : Prop
  governorConfigured : Prop
  selectorPolicyDone : Prop
  resourcePolicyDone : Prop
  capabilityPolicyDone : Prop
  memoryPolicyDone : Prop
  compressionPolicyDone : Prop
  runtimeManifestDone : Prop

inductive ProfileFact where
  | declared
  | governorConfigured
  | selectorPolicyDone
  | resourcePolicyDone
  | capabilityPolicyDone
  | memoryPolicyDone
  | compressionPolicyDone
  | runtimeManifestDone
deriving Repr, DecidableEq

abbrev ProfileFactEnv := ProfileFact -> Prop

def profileStateOfFacts
    (activeScope : ProfileScope)
    (facts : ProfileFactEnv) :
    ProfileState :=
  { activeScope := activeScope
    declared := facts ProfileFact.declared
    governorConfigured := facts ProfileFact.governorConfigured
    selectorPolicyDone := facts ProfileFact.selectorPolicyDone
    resourcePolicyDone := facts ProfileFact.resourcePolicyDone
    capabilityPolicyDone := facts ProfileFact.capabilityPolicyDone
    memoryPolicyDone := facts ProfileFact.memoryPolicyDone
    compressionPolicyDone := facts ProfileFact.compressionPolicyDone
    runtimeManifestDone := facts ProfileFact.runtimeManifestDone }

inductive ProfileDependsOn : ProfileModule -> ProfileModule -> Prop where
  | governorDeclaration :
      ProfileDependsOn ProfileModule.governor ProfileModule.declaration
  | selectorGovernor :
      ProfileDependsOn ProfileModule.selectorPolicy ProfileModule.governor
  | resourceGovernor :
      ProfileDependsOn ProfileModule.resourcePolicy ProfileModule.governor
  | capabilityGovernor :
      ProfileDependsOn ProfileModule.capabilityPolicy ProfileModule.governor
  | memoryGovernor :
      ProfileDependsOn ProfileModule.memoryPolicy ProfileModule.governor
  | compressionGovernor :
      ProfileDependsOn ProfileModule.compressionPolicy ProfileModule.governor
  | runtimeSelector :
      ProfileDependsOn ProfileModule.runtimeManifest ProfileModule.selectorPolicy
  | runtimeResource :
      ProfileDependsOn ProfileModule.runtimeManifest ProfileModule.resourcePolicy
  | runtimeCapability :
      ProfileDependsOn ProfileModule.runtimeManifest ProfileModule.capabilityPolicy
  | runtimeMemory :
      ProfileDependsOn ProfileModule.runtimeManifest ProfileModule.memoryPolicy
  | runtimeCompression :
      ProfileDependsOn ProfileModule.runtimeManifest ProfileModule.compressionPolicy

def profileModuleScope : ProfileModule -> ProfileScope
  | ProfileModule.declaration => declarationScope
  | ProfileModule.governor => governorScope
  | ProfileModule.selectorPolicy => policyScope
  | ProfileModule.resourcePolicy => policyScope
  | ProfileModule.capabilityPolicy => policyScope
  | ProfileModule.memoryPolicy => policyScope
  | ProfileModule.compressionPolicy => policyScope
  | ProfileModule.runtimeManifest => runtimeManifestScope

def profileCompleted (state : ProfileState) : ProfileModule -> Prop
  | ProfileModule.declaration => state.declared
  | ProfileModule.governor => state.governorConfigured
  | ProfileModule.selectorPolicy => state.selectorPolicyDone
  | ProfileModule.resourcePolicy => state.resourcePolicyDone
  | ProfileModule.capabilityPolicy => state.capabilityPolicyDone
  | ProfileModule.memoryPolicy => state.memoryPolicyDone
  | ProfileModule.compressionPolicy => state.compressionPolicyDone
  | ProfileModule.runtimeManifest => state.runtimeManifestDone

def profilePrecondition (state : ProfileState) : ProfileModule -> Prop
  | ProfileModule.declaration => True
  | ProfileModule.governor => state.declared
  | ProfileModule.selectorPolicy => state.governorConfigured
  | ProfileModule.resourcePolicy => state.governorConfigured
  | ProfileModule.capabilityPolicy => state.governorConfigured
  | ProfileModule.memoryPolicy => state.governorConfigured
  | ProfileModule.compressionPolicy => state.governorConfigured
  | ProfileModule.runtimeManifest =>
      state.selectorPolicyDone ∧
      state.resourcePolicyDone ∧
      state.capabilityPolicyDone ∧
      state.memoryPolicyDone ∧
      state.compressionPolicyDone

def profileSpec : FlowSpec ProfileModule ProfileScope ProfileState :=
  { scopeOrder := natScopeOrder
    moduleScope := profileModuleScope
    activeScope := ProfileState.activeScope
    dependsOn := ProfileDependsOn
    policyAllows := fun _ _ => True
    precondition := profilePrecondition
    guard := fun _ _ => True
    branchSibling := fun _ _ => False
    completed := profileCompleted }

theorem runtime_manifest_requires_selector_policy
    {state : ProfileState}
    (canStart : CanStart profileSpec state ProfileModule.runtimeManifest) :
    state.selectorPolicyDone :=
  deps_completed_of_can_start canStart ProfileDependsOn.runtimeSelector

theorem runtime_manifest_requires_memory_policy
    {state : ProfileState}
    (canStart : CanStart profileSpec state ProfileModule.runtimeManifest) :
    state.memoryPolicyDone :=
  deps_completed_of_can_start canStart ProfileDependsOn.runtimeMemory

theorem runtime_manifest_blocks_without_selector_policy
    {state : ProfileState}
    (missingSelector : ¬ state.selectorPolicyDone) :
    ¬ CanStart profileSpec state ProfileModule.runtimeManifest := by
  intro canStart
  exact missingSelector (runtime_manifest_requires_selector_policy canStart)

theorem runtime_manifest_blocks_without_memory_policy
    {state : ProfileState}
    (missingMemory : ¬ state.memoryPolicyDone) :
    ¬ CanStart profileSpec state ProfileModule.runtimeManifest := by
  intro canStart
  exact missingMemory (runtime_manifest_requires_memory_policy canStart)

end AgenticAILabProof.PooC4.Profile
