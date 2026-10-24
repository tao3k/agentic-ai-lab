-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.ReferenceBoundary

namespace AgenticAILabProof.PooC4.ReferenceBoundary

open AgenticAILabProof.PooC4.ControlPlane

structure CandidateObligation
    (Source : Type u)
    (Claim : Prop) where
  reference : ReferenceObservation Source Claim

inductive ObligationDischarge
    {Source : Type u}
    {Claim : Prop}
    (obligation : CandidateObligation Source Claim) : Prop where
  | owned :
      AgenticAILabOwnedFact Claim ->
      ObligationDischarge obligation
  | adopted :
      VerifiedFromReference obligation.reference ->
      ObligationDischarge obligation

structure RejectionCertificate
    {Source : Type u}
    {Claim : Prop}
    (obligation : CandidateObligation Source Claim) : Prop where
  cannotDischarge : ¬ ObligationDischarge obligation

inductive AuditResult
    {Source : Type u}
    {Claim : Prop}
    (obligation : CandidateObligation Source Claim) : Prop where
  | discharged :
      ObligationDischarge obligation ->
      AuditResult obligation
  | rejected :
      RejectionCertificate obligation ->
      AuditResult obligation

theorem obligation_discharge_claim_holds
    {Source : Type u}
    {Claim : Prop}
    {obligation : CandidateObligation Source Claim}
    (discharge : ObligationDischarge obligation) :
    Claim := by
  cases discharge with
  | owned fact =>
      exact agentic_ai_lab_owned_fact_holds fact
  | adopted verified =>
      exact verified_reference_claim_holds verified

theorem obligation_cannot_discharge_without_owned_or_adoption
    {Source : Type u}
    {Claim : Prop}
    {obligation : CandidateObligation Source Claim}
    (noOwned : ¬ AgenticAILabOwnedFact Claim)
    (noCertificate : ¬ AdoptionCertificate obligation.reference) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  cases discharge with
  | owned fact =>
      exact noOwned fact
  | adopted verified =>
      exact noCertificate verified.certificate

theorem rejected_obligation_cannot_discharge
    {Source : Type u}
    {Claim : Prop}
    {obligation : CandidateObligation Source Claim}
    (rejection : RejectionCertificate obligation) :
    ¬ ObligationDischarge obligation :=
  rejection.cannotDischarge

theorem discharged_audit_result_claim_holds
    {Source : Type u}
    {Claim : Prop}
    {obligation : CandidateObligation Source Claim}
    (result : AuditResult obligation)
    (notRejected :
      ¬ RejectionCertificate obligation) :
    Claim := by
  cases result with
  | discharged discharge =>
      exact obligation_discharge_claim_holds discharge
  | rejected rejection =>
      exact False.elim (notRejected rejection)

abbrev ControlTraceObligation
    (Source : Type u)
    (Tool File Capability Agent : Type v)
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) :=
  CandidateObligation Source (SessionTrace session event)

def controlTraceObligationOfReference
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {event : SessionEvent Tool File Capability Agent}
    (reference :
      ReferenceControlTrace
        Source
        Tool
        File
        Capability
        Agent
        session
        event) :
    ControlTraceObligation
      Source
      Tool
      File
      Capability
      Agent
      session
      event :=
  { reference := reference }

theorem discharged_control_trace_obligation_is_trace
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {event : SessionEvent Tool File Capability Agent}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        event}
    (discharge : ObligationDischarge obligation) :
    SessionTrace session event :=
  obligation_discharge_claim_holds discharge

theorem discharged_tool_obligation_requires_sandbox_permission
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.useTool tool)}
    (discharge : ObligationDischarge obligation) :
    session.sandbox.toolAllowed tool :=
  tool_event_requires_sandbox_permission
    (discharged_control_trace_obligation_is_trace discharge)

theorem discharged_read_obligation_requires_sandbox_scope
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.readFile file)}
    (discharge : ObligationDischarge obligation) :
    session.sandbox.fileAllowed file :=
  read_file_event_requires_sandbox_scope
    (discharged_control_trace_obligation_is_trace discharge)

theorem discharged_write_obligation_requires_sandbox_scope
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.writeFile file)}
    (discharge : ObligationDischarge obligation) :
    session.sandbox.fileAllowed file :=
  write_file_event_requires_sandbox_scope
    (discharged_control_trace_obligation_is_trace discharge)

theorem discharged_subagent_obligation_requires_capability_subset
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.startSubagent agent childProfile)}
    (discharge : ObligationDischarge obligation) :
    (capability : Capability) ->
      childProfile.sandbox.capabilityAllowed capability ->
      session.sandbox.capabilityAllowed capability :=
  start_subagent_requires_capability_subset
    (discharged_control_trace_obligation_is_trace discharge)

theorem denied_tool_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.useTool tool)}
    (denied : ¬ session.sandbox.toolAllowed tool) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    denied
      (discharged_tool_obligation_requires_sandbox_permission discharge)

theorem out_of_scope_read_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.readFile file)}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    outOfScope
      (discharged_read_obligation_requires_sandbox_scope discharge)

theorem out_of_scope_write_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.writeFile file)}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    outOfScope
      (discharged_write_obligation_requires_sandbox_scope discharge)

theorem subagent_escalation_obligation_cannot_discharge
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {capability : Capability}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.startSubagent agent childProfile)}
    (childAllows : childProfile.sandbox.capabilityAllowed capability)
    (parentDenies : ¬ session.sandbox.capabilityAllowed capability) :
    ¬ ObligationDischarge obligation := by
  intro discharge
  exact
    parentDenies
      (discharged_subagent_obligation_requires_capability_subset
        discharge
        capability
        childAllows)

def rejectedDeniedToolObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.useTool tool)}
    (denied : ¬ session.sandbox.toolAllowed tool) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      denied_tool_obligation_cannot_discharge denied }

def rejectedOutOfScopeReadObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.readFile file)}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      out_of_scope_read_obligation_cannot_discharge outOfScope }

def rejectedOutOfScopeWriteObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.writeFile file)}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      out_of_scope_write_obligation_cannot_discharge outOfScope }

def rejectedSubagentEscalationObligation
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {capability : Capability}
    {obligation :
      ControlTraceObligation
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.startSubagent agent childProfile)}
    (childAllows : childProfile.sandbox.capabilityAllowed capability)
    (parentDenies : ¬ session.sandbox.capabilityAllowed capability) :
    RejectionCertificate obligation :=
  { cannotDischarge :=
      subagent_escalation_obligation_cannot_discharge
        childAllows
        parentDenies }

end AgenticAILabProof.PooC4.ReferenceBoundary
