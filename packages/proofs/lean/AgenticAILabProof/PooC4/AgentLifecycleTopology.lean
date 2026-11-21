-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.AgentLifecycle

namespace AgenticAILabProof.PooC4.AgentLifecycleTopology

/-!
Topology proof layer for AI lifecycle policies.

`AgentLifecycle` proves that the required lifecycle facts are present.
This module gives those facts a mathematical shape: scope containment is a
preorder relation, tool permission is scoped, loop starts imply exit and
handoff transitions, and every subagent belongs to the lifecycle session.
-/

universe u1 u2 u3 u4 u5

structure ScopePreorder (Scope : Type u1) where
  le : Scope -> Scope -> Prop
  refl : forall scope, le scope scope
  trans : forall {a b c}, le a b -> le b c -> le a c

structure LifecycleTopologyFacts
    (Lifecycle : Type u1)
    (Session : Type u2)
    (Scope : Type u3)
    (Tool : Type u4)
    (Loop : Type u5) where
  lifecycleSession : Lifecycle -> Session
  parentScope : Lifecycle -> Scope
  childScope : Lifecycle -> Scope
  scopeOrder : ScopePreorder Scope
  requestedTool : Lifecycle -> Tool -> Prop
  toolAllowedInScope : Tool -> Scope -> Prop
  loopStart : Lifecycle -> Loop -> Prop
  loopExit : Lifecycle -> Loop -> Prop
  loopHandoff : Lifecycle -> Loop -> Prop

structure LifecycleSubagentFacts
    (Lifecycle : Type u1)
    (Session : Type u2)
    (Subagent : Type u3) where
  lifecycleSession : Lifecycle -> Session
  subagentOf : Lifecycle -> Subagent -> Prop
  subagentSession : Subagent -> Session

structure SoundLifecycleTopology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Scope : Type u3}
    {Tool : Type u4}
    {Loop : Type u5}
    (facts : LifecycleTopologyFacts Lifecycle Session Scope Tool Loop) :
    Prop where
  childScopeContained :
    forall lifecycle,
      facts.scopeOrder.le
        (facts.childScope lifecycle)
        (facts.parentScope lifecycle)
  requestedToolAllowed :
    forall lifecycle tool,
      facts.requestedTool lifecycle tool ->
        facts.toolAllowedInScope tool (facts.childScope lifecycle)
  loopStartHasExit :
    forall lifecycle loop,
      facts.loopStart lifecycle loop ->
        facts.loopExit lifecycle loop
  loopStartHasHandoff :
    forall lifecycle loop,
      facts.loopStart lifecycle loop ->
        facts.loopHandoff lifecycle loop

structure SoundLifecycleSubagentTopology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Subagent : Type u3}
    (facts : LifecycleSubagentFacts Lifecycle Session Subagent) :
    Prop where
  subagentSessionMatchesParent :
    forall lifecycle subagent,
      facts.subagentOf lifecycle subagent ->
        facts.subagentSession subagent = facts.lifecycleSession lifecycle

theorem child_scope_containment_is_transitive
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Scope : Type u3}
    {Tool : Type u4}
    {Loop : Type u5}
    {facts : LifecycleTopologyFacts Lifecycle Session Scope Tool Loop}
    (h : SoundLifecycleTopology facts)
    {lifecycle : Lifecycle}
    {rootScope : Scope}
    (hparent :
      facts.scopeOrder.le (facts.parentScope lifecycle) rootScope) :
    facts.scopeOrder.le (facts.childScope lifecycle) rootScope := by
  exact facts.scopeOrder.trans (h.childScopeContained lifecycle) hparent

theorem requested_tool_not_allowed_contradicts_topology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Scope : Type u3}
    {Tool : Type u4}
    {Loop : Type u5}
    {facts : LifecycleTopologyFacts Lifecycle Session Scope Tool Loop}
    (h : SoundLifecycleTopology facts)
    {lifecycle : Lifecycle}
    {tool : Tool}
    (hrequest : facts.requestedTool lifecycle tool)
    (hdenied :
      Not (facts.toolAllowedInScope tool (facts.childScope lifecycle))) :
    False := by
  exact hdenied (h.requestedToolAllowed lifecycle tool hrequest)

theorem loop_start_without_exit_contradicts_topology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Scope : Type u3}
    {Tool : Type u4}
    {Loop : Type u5}
    {facts : LifecycleTopologyFacts Lifecycle Session Scope Tool Loop}
    (h : SoundLifecycleTopology facts)
    {lifecycle : Lifecycle}
    {loop : Loop}
    (hstart : facts.loopStart lifecycle loop)
    (hnoExit : Not (facts.loopExit lifecycle loop)) :
    False := by
  exact hnoExit (h.loopStartHasExit lifecycle loop hstart)

theorem loop_start_without_handoff_contradicts_topology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Scope : Type u3}
    {Tool : Type u4}
    {Loop : Type u5}
    {facts : LifecycleTopologyFacts Lifecycle Session Scope Tool Loop}
    (h : SoundLifecycleTopology facts)
    {lifecycle : Lifecycle}
    {loop : Loop}
    (hstart : facts.loopStart lifecycle loop)
    (hnoHandoff : Not (facts.loopHandoff lifecycle loop)) :
    False := by
  exact hnoHandoff (h.loopStartHasHandoff lifecycle loop hstart)

theorem subagent_wrong_session_contradicts_topology
    {Lifecycle : Type u1}
    {Session : Type u2}
    {Subagent : Type u3}
    {facts : LifecycleSubagentFacts Lifecycle Session Subagent}
    (h : SoundLifecycleSubagentTopology facts)
    {lifecycle : Lifecycle}
    {subagent : Subagent}
    (hchild : facts.subagentOf lifecycle subagent)
    (hwrong :
      Not (facts.subagentSession subagent =
        facts.lifecycleSession lifecycle)) :
    False := by
  exact hwrong (h.subagentSessionMatchesParent lifecycle subagent hchild)

end AgenticAILabProof.PooC4.AgentLifecycleTopology
