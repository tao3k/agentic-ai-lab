-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.ReferenceAudit
import AgenticAILabProof.PooC4.SessionLifecycle

namespace AgenticAILabProof.PooC4.SessionControlLink

open AgenticAILabProof.PooC4.ControlPlane
open AgenticAILabProof.PooC4.ReferenceBoundary

structure SessionControlState
    (Agent : Type u) where
  activeSubagent : Agent -> Prop
  channelAllowed : Agent -> Prop
  policyAllowsSend : Agent -> Prop

def lifecycleSendAllowed
    {Agent : Type u}
    (state : SessionControlState Agent)
    (target : Agent) : Prop :=
  state.activeSubagent target ∧
  state.channelAllowed target ∧
  state.policyAllowsSend target

def lifecycleEventAllowed
    {Tool File Capability Agent : Type u}
    (state : SessionControlState Agent)
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
  | SessionEvent.sendToSubagent target =>
      lifecycleSendAllowed state target

structure LifecycleTrace
    {Tool File Capability Agent : Type u}
    (state : SessionControlState Agent)
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) : Prop where
  allowed : lifecycleEventAllowed state session event

theorem base_control_plane_send_to_subagent_unconstrained
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    (target : Agent) :
    SessionTrace
      session
      (SessionEvent.sendToSubagent
        (Tool := Tool)
        (File := File)
        (Capability := Capability)
        target) :=
  { allowed := True.intro }

theorem lifecycle_trace_refines_base_control_plane
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {event : SessionEvent Tool File Capability Agent}
    (trace : LifecycleTrace state session event) :
    SessionTrace session event := by
  cases event with
  | useTool tool =>
      exact { allowed := trace.allowed }
  | readFile file =>
      exact { allowed := trace.allowed }
  | writeFile file =>
      exact { allowed := trace.allowed }
  | startSubagent agent childProfile =>
      exact { allowed := trace.allowed }
  | sendToSubagent target =>
      exact base_control_plane_send_to_subagent_unconstrained target

theorem lifecycle_send_requires_active_subagent
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (trace :
      LifecycleTrace
        state
        session
        (SessionEvent.sendToSubagent
          (Tool := Tool)
          (File := File)
          (Capability := Capability)
          target)) :
    state.activeSubagent target :=
  trace.allowed.left

theorem lifecycle_send_requires_channel_authorization
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (trace :
      LifecycleTrace
        state
        session
        (SessionEvent.sendToSubagent
          (Tool := Tool)
          (File := File)
          (Capability := Capability)
          target)) :
    state.channelAllowed target :=
  trace.allowed.right.left

theorem lifecycle_send_requires_policy
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (trace :
      LifecycleTrace
        state
        session
        (SessionEvent.sendToSubagent
          (Tool := Tool)
          (File := File)
          (Capability := Capability)
          target)) :
    state.policyAllowsSend target :=
  trace.allowed.right.right

theorem inactive_subagent_cannot_receive_lifecycle_message
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (inactive : ¬ state.activeSubagent target) :
    ¬ LifecycleTrace
      state
      session
      (SessionEvent.sendToSubagent
        (Tool := Tool)
        (File := File)
        (Capability := Capability)
        target) := by
  intro trace
  exact inactive (lifecycle_send_requires_active_subagent trace)

theorem unauthorized_channel_cannot_receive_lifecycle_message
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (unauthorized : ¬ state.channelAllowed target) :
    ¬ LifecycleTrace
      state
      session
      (SessionEvent.sendToSubagent
        (Tool := Tool)
        (File := File)
        (Capability := Capability)
        target) := by
  intro trace
  exact unauthorized (lifecycle_send_requires_channel_authorization trace)

theorem policy_denied_subagent_cannot_receive_lifecycle_message
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (denied : ¬ state.policyAllowsSend target) :
    ¬ LifecycleTrace
      state
      session
      (SessionEvent.sendToSubagent
        (Tool := Tool)
        (File := File)
        (Capability := Capability)
        target) := by
  intro trace
  exact denied (lifecycle_send_requires_policy trace)

theorem base_send_trace_does_not_discharge_lifecycle_send
    {Tool File Capability Agent : Type u}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    (inactive : ¬ state.activeSubagent target)
    (_baseTrace :
      SessionTrace
        session
        (SessionEvent.sendToSubagent
          (Tool := Tool)
          (File := File)
          (Capability := Capability)
          target)) :
    ¬ LifecycleTrace
      state
      session
      (SessionEvent.sendToSubagent
        (Tool := Tool)
        (File := File)
        (Capability := Capability)
        target) :=
  inactive_subagent_cannot_receive_lifecycle_message inactive

abbrev LifecycleTraceObligation
    (Source : Type u)
    (Tool File Capability Agent : Type v)
    (state : SessionControlState Agent)
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) :=
  CandidateObligation Source (LifecycleTrace state session event)

theorem discharged_lifecycle_send_obligation_requires_active_subagent
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (discharge : ObligationDischarge obligation) :
    state.activeSubagent target :=
  lifecycle_send_requires_active_subagent
    (obligation_discharge_claim_holds discharge)

theorem discharged_lifecycle_send_obligation_requires_channel_authorization
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (discharge : ObligationDischarge obligation) :
    state.channelAllowed target :=
  lifecycle_send_requires_channel_authorization
    (obligation_discharge_claim_holds discharge)

theorem inactive_lifecycle_send_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (inactive : ¬ state.activeSubagent target) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    inactive
      (discharged_lifecycle_send_obligation_requires_active_subagent
        discharge)

theorem unauthorized_lifecycle_send_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (unauthorized : ¬ state.channelAllowed target) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    unauthorized
      (discharged_lifecycle_send_obligation_requires_channel_authorization
        discharge)

def rejectedInactiveLifecycleSendObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (inactive : ¬ state.activeSubagent target) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      inactive_lifecycle_send_obligation_cannot_discharge inactive }

def rejectedUnauthorizedLifecycleSendObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {state : SessionControlState Agent}
    {session : SessionProfile Tool File Capability}
    {target : Agent}
    {obligation :
      LifecycleTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        state
        session
        (SessionEvent.sendToSubagent target)}
    (unauthorized : ¬ state.channelAllowed target) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      unauthorized_lifecycle_send_obligation_cannot_discharge
        unauthorized }

end AgenticAILabProof.PooC4.SessionControlLink
