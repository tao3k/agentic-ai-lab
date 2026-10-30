-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.SessionLifecycle

namespace AgenticAILabProof.PooC4.AgentLifecycle

/-!
AI agent lifecycle policy gates connect the Scheme control-plane facts for
sessions, sandboxes, loop policies, subagents, tool permissions, receipts, and
counterexamples. The target is not interpreter correctness. The target is the
strategy/policy question: may this agent lifecycle become a reusable public
policy surface?
-/

universe u

structure LifecyclePolicyFacts (Lifecycle : Type u) where
  publicPolicy : Lifecycle -> Prop
  experimentalPolicy : Lifecycle -> Prop
  acceptedGate : Lifecycle -> Prop
  reusablePolicySurface : Lifecycle -> Prop
  sessionCreated : Lifecycle -> Prop
  parentSessionBound : Lifecycle -> Prop
  sandboxAttached : Lifecycle -> Prop
  sandboxScopeContained : Lifecycle -> Prop
  toolPermissionsContained : Lifecycle -> Prop
  loopStartGuarded : Lifecycle -> Prop
  loopExitDefined : Lifecycle -> Prop
  loopHandoffGuarded : Lifecycle -> Prop
  subagentsParented : Lifecycle -> Prop
  dependencyClosed : Lifecycle -> Prop
  tested : Lifecycle -> Prop
  proofReceiptPresent : Lifecycle -> Prop
  observabilityClean : Lifecycle -> Prop
  counterexampleRejected : Lifecycle -> Prop

structure AcceptedLifecycleEvidence
    {Lifecycle : Type u}
    (facts : LifecyclePolicyFacts Lifecycle)
    (lifecycle : Lifecycle) : Prop where
  sessionCreated : facts.sessionCreated lifecycle
  parentSessionBound : facts.parentSessionBound lifecycle
  sandboxAttached : facts.sandboxAttached lifecycle
  sandboxScopeContained : facts.sandboxScopeContained lifecycle
  toolPermissionsContained : facts.toolPermissionsContained lifecycle
  loopStartGuarded : facts.loopStartGuarded lifecycle
  loopExitDefined : facts.loopExitDefined lifecycle
  loopHandoffGuarded : facts.loopHandoffGuarded lifecycle
  subagentsParented : facts.subagentsParented lifecycle
  dependencyClosed : facts.dependencyClosed lifecycle
  tested : facts.tested lifecycle
  proofReceiptPresent : facts.proofReceiptPresent lifecycle
  observabilityClean : facts.observabilityClean lifecycle
  counterexampleRejected : facts.counterexampleRejected lifecycle

structure SoundLifecyclePolicy
    {Lifecycle : Type u}
    (facts : LifecyclePolicyFacts Lifecycle) : Prop where
  acceptedGateSound :
    forall lifecycle,
      facts.acceptedGate lifecycle ->
        AcceptedLifecycleEvidence facts lifecycle
  publicGateReuse :
    forall lifecycle,
      facts.publicPolicy lifecycle ->
        facts.acceptedGate lifecycle ->
          facts.reusablePolicySurface lifecycle
  experimentalExcluded :
    forall lifecycle,
      facts.experimentalPolicy lifecycle ->
        Not (facts.reusablePolicySurface lifecycle)
  publicExperimentalDisjoint :
    forall lifecycle,
      facts.publicPolicy lifecycle ->
        Not (facts.experimentalPolicy lifecycle)

theorem accepted_public_lifecycle_has_session_sandbox_loop_and_subagents
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (hpublic : facts.publicPolicy lifecycle)
    (haccepted : facts.acceptedGate lifecycle) :
    facts.sessionCreated lifecycle /\
      facts.parentSessionBound lifecycle /\
      facts.sandboxAttached lifecycle /\
      facts.sandboxScopeContained lifecycle /\
      facts.toolPermissionsContained lifecycle /\
      facts.loopStartGuarded lifecycle /\
      facts.loopExitDefined lifecycle /\
      facts.loopHandoffGuarded lifecycle /\
      facts.subagentsParented lifecycle /\
      facts.reusablePolicySurface lifecycle := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact And.intro hevidence.sessionCreated
    (And.intro hevidence.parentSessionBound
      (And.intro hevidence.sandboxAttached
        (And.intro hevidence.sandboxScopeContained
          (And.intro hevidence.toolPermissionsContained
            (And.intro hevidence.loopStartGuarded
              (And.intro hevidence.loopExitDefined
                (And.intro hevidence.loopHandoffGuarded
                  (And.intro hevidence.subagentsParented
                    (h.publicGateReuse lifecycle hpublic haccepted)))))))))

theorem accepted_subagent_without_parent_session_is_contradictory
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (haccepted : facts.acceptedGate lifecycle)
    (hunparented : Not (facts.subagentsParented lifecycle)) :
    False := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact hunparented hevidence.subagentsParented

theorem accepted_lifecycle_without_sandbox_scope_is_contradictory
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (haccepted : facts.acceptedGate lifecycle)
    (hscopeLeak : Not (facts.sandboxScopeContained lifecycle)) :
    False := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact hscopeLeak hevidence.sandboxScopeContained

theorem accepted_lifecycle_with_tool_permission_overflow_is_contradictory
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (haccepted : facts.acceptedGate lifecycle)
    (htoolOverflow : Not (facts.toolPermissionsContained lifecycle)) :
    False := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact htoolOverflow hevidence.toolPermissionsContained

theorem accepted_loop_without_exit_is_contradictory
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (haccepted : facts.acceptedGate lifecycle)
    (hnoExit : Not (facts.loopExitDefined lifecycle)) :
    False := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact hnoExit hevidence.loopExitDefined

theorem accepted_loop_without_handoff_guard_is_contradictory
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (haccepted : facts.acceptedGate lifecycle)
    (hnoHandoff : Not (facts.loopHandoffGuarded lifecycle)) :
    False := by
  have hevidence := h.acceptedGateSound lifecycle haccepted
  exact hnoHandoff hevidence.loopHandoffGuarded

theorem experimental_lifecycle_is_not_reusable_policy_surface
    {Lifecycle : Type u}
    {facts : LifecyclePolicyFacts Lifecycle}
    (h : SoundLifecyclePolicy facts)
    {lifecycle : Lifecycle}
    (hexperimental : facts.experimentalPolicy lifecycle) :
    Not (facts.reusablePolicySurface lifecycle) := by
  exact h.experimentalExcluded lifecycle hexperimental

end AgenticAILabProof.PooC4.AgentLifecycle
