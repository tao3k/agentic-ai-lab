-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.PolicyTrace

namespace AgenticAILabProof.PooC4.ControlPlane

structure SandboxProfile
    (Tool File Capability : Type u) where
  toolAllowed : Tool -> Prop
  fileAllowed : File -> Prop
  capabilityAllowed : Capability -> Prop

structure SessionProfile
    (Tool File Capability : Type u) where
  sandbox : SandboxProfile Tool File Capability

structure AgentProfile
    (Tool File Capability : Type u) where
  sandbox : SandboxProfile Tool File Capability

inductive SessionEvent
    (Tool File Capability Agent : Type u) where
  | useTool : Tool -> SessionEvent Tool File Capability Agent
  | readFile : File -> SessionEvent Tool File Capability Agent
  | writeFile : File -> SessionEvent Tool File Capability Agent
  | startSubagent :
      Agent ->
      AgentProfile Tool File Capability ->
      SessionEvent Tool File Capability Agent
  | sendToSubagent : Agent -> SessionEvent Tool File Capability Agent

def eventAllowed
    {Tool File Capability Agent : Type u}
    (session : SessionProfile Tool File Capability) :
    SessionEvent Tool File Capability Agent -> Prop
  | SessionEvent.useTool tool =>
      session.sandbox.toolAllowed tool
  | SessionEvent.readFile file =>
      session.sandbox.fileAllowed file
  | SessionEvent.writeFile file =>
      session.sandbox.fileAllowed file
  | SessionEvent.startSubagent _ childProfile =>
      (capability : Capability) ->
        childProfile.sandbox.capabilityAllowed capability ->
        session.sandbox.capabilityAllowed capability
  | SessionEvent.sendToSubagent _ =>
      True

structure SessionTrace
    {Tool File Capability Agent : Type u}
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) : Prop where
  allowed : eventAllowed session event

theorem tool_event_requires_sandbox_permission
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    (trace :
      SessionTrace
        session
        (SessionEvent.useTool
          (File := File)
          (Capability := Capability)
          (Agent := Agent)
          tool)) :
    session.sandbox.toolAllowed tool :=
  trace.allowed

theorem read_file_event_requires_sandbox_scope
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {file : File}
    (trace :
      SessionTrace
        session
        (SessionEvent.readFile
          (Tool := Tool)
          (Capability := Capability)
          (Agent := Agent)
          file)) :
    session.sandbox.fileAllowed file :=
  trace.allowed

theorem write_file_event_requires_sandbox_scope
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {file : File}
    (trace :
      SessionTrace
        session
        (SessionEvent.writeFile
          (Tool := Tool)
          (Capability := Capability)
          (Agent := Agent)
          file)) :
    session.sandbox.fileAllowed file :=
  trace.allowed

theorem start_subagent_requires_capability_subset
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    (trace :
      SessionTrace
        session
        (SessionEvent.startSubagent agent childProfile)) :
    (capability : Capability) ->
      childProfile.sandbox.capabilityAllowed capability ->
      session.sandbox.capabilityAllowed capability :=
  trace.allowed

def sandboxRefines
    {Tool File Capability : Type u}
    (child parent : SandboxProfile Tool File Capability) : Prop :=
  ((tool : Tool) ->
    child.toolAllowed tool ->
    parent.toolAllowed tool) ∧
  ((file : File) ->
    child.fileAllowed file ->
    parent.fileAllowed file) ∧
  ((capability : Capability) ->
    child.capabilityAllowed capability ->
    parent.capabilityAllowed capability)

theorem sandbox_refines_tool
    {Tool File Capability : Type u}
    {child parent : SandboxProfile Tool File Capability}
    (refines : sandboxRefines child parent)
    {tool : Tool}
    (allowed : child.toolAllowed tool) :
    parent.toolAllowed tool :=
  refines.left tool allowed

theorem sandbox_refines_file
    {Tool File Capability : Type u}
    {child parent : SandboxProfile Tool File Capability}
    (refines : sandboxRefines child parent)
    {file : File}
    (allowed : child.fileAllowed file) :
    parent.fileAllowed file :=
  refines.right.left file allowed

theorem sandbox_refines_capability
    {Tool File Capability : Type u}
    {child parent : SandboxProfile Tool File Capability}
    (refines : sandboxRefines child parent)
    {capability : Capability}
    (allowed : child.capabilityAllowed capability) :
    parent.capabilityAllowed capability :=
  refines.right.right capability allowed

theorem start_subagent_requires_sandbox_refinement
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    (toolSubset :
      (tool : Tool) ->
        childProfile.sandbox.toolAllowed tool ->
        session.sandbox.toolAllowed tool)
    (fileSubset :
      (file : File) ->
        childProfile.sandbox.fileAllowed file ->
        session.sandbox.fileAllowed file)
    (trace :
      SessionTrace
        session
        (SessionEvent.startSubagent agent childProfile)) :
    sandboxRefines childProfile.sandbox session.sandbox :=
  And.intro
    toolSubset
    (And.intro
      fileSubset
      (start_subagent_requires_capability_subset trace))

structure SessionInvariant
    {Tool File Capability Agent : Type u}
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) : Prop where
  toolSafe :
    (tool : Tool) ->
      event = SessionEvent.useTool
        (File := File)
        (Capability := Capability)
        (Agent := Agent)
        tool ->
      session.sandbox.toolAllowed tool
  readSafe :
    (file : File) ->
      event = SessionEvent.readFile
        (Tool := Tool)
        (Capability := Capability)
        (Agent := Agent)
        file ->
      session.sandbox.fileAllowed file
  writeSafe :
    (file : File) ->
      event = SessionEvent.writeFile
        (Tool := Tool)
        (Capability := Capability)
        (Agent := Agent)
        file ->
      session.sandbox.fileAllowed file
  subagentCapabilitySafe :
    (agent : Agent) ->
      (childProfile : AgentProfile Tool File Capability) ->
      event = SessionEvent.startSubagent agent childProfile ->
      (capability : Capability) ->
        childProfile.sandbox.capabilityAllowed capability ->
        session.sandbox.capabilityAllowed capability

theorem session_trace_enforces_invariant
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {event : SessionEvent Tool File Capability Agent}
    (trace : SessionTrace session event) :
    SessionInvariant session event :=
  { toolSafe := by
      intro tool eventEq
      subst event
      exact tool_event_requires_sandbox_permission trace
    readSafe := by
      intro file eventEq
      subst event
      exact read_file_event_requires_sandbox_scope trace
    writeSafe := by
      intro file eventEq
      subst event
      exact write_file_event_requires_sandbox_scope trace
    subagentCapabilitySafe := by
      intro agent childProfile eventEq capability childAllows
      subst event
      exact
        start_subagent_requires_capability_subset
          trace
          capability
          childAllows }

theorem denied_tool_event_cannot_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    (denied : ¬ session.sandbox.toolAllowed tool) :
    ¬ SessionTrace
      session
      (SessionEvent.useTool
        (File := File)
        (Capability := Capability)
        (Agent := Agent)
        tool) := by
  intro trace
  exact denied (tool_event_requires_sandbox_permission trace)

theorem out_of_scope_file_read_cannot_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {file : File}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    ¬ SessionTrace
      session
      (SessionEvent.readFile
        (Tool := Tool)
        (Capability := Capability)
        (Agent := Agent)
        file) := by
  intro trace
  exact outOfScope (read_file_event_requires_sandbox_scope trace)

theorem out_of_scope_file_write_cannot_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {file : File}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    ¬ SessionTrace
      session
      (SessionEvent.writeFile
        (Tool := Tool)
        (Capability := Capability)
        (Agent := Agent)
        file) := by
  intro trace
  exact outOfScope (write_file_event_requires_sandbox_scope trace)

theorem subagent_capability_escalation_cannot_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {capability : Capability}
    (childAllows : childProfile.sandbox.capabilityAllowed capability)
    (parentDenies : ¬ session.sandbox.capabilityAllowed capability) :
    ¬ SessionTrace
      session
      (SessionEvent.startSubagent agent childProfile) := by
  intro trace
  exact
    parentDenies
      (start_subagent_requires_capability_subset
        trace
        capability
        childAllows)

end AgenticAILabProof.PooC4.ControlPlane
