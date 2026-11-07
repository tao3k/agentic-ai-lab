-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.ControlPlane

namespace AgenticAILabProof.PooC4.ReferenceBoundary

open AgenticAILabProof.PooC4.ControlPlane

inductive ProductionReference where
  | openRATH
deriving Repr, DecidableEq

structure AgenticAILabOwnedFact (Claim : Prop) : Prop where
  proof : Claim

structure ReferenceObservation
    (Source : Type u)
    (Claim : Prop) where
  source : Source
  observed : True

structure AdoptionCertificate
    {Source : Type u}
    {Claim : Prop}
    (reference : ReferenceObservation Source Claim) : Prop where
  verifiedByAgenticAILab : Claim

structure VerifiedFromReference
    {Source : Type u}
    {Claim : Prop}
    (reference : ReferenceObservation Source Claim) : Prop where
  certificate : AdoptionCertificate reference

theorem agentic_ai_lab_owned_fact_holds
    {Claim : Prop}
    (fact : AgenticAILabOwnedFact Claim) :
    Claim :=
  fact.proof

theorem verified_reference_claim_holds
    {Source : Type u}
    {Claim : Prop}
    {reference : ReferenceObservation Source Claim}
    (verified : VerifiedFromReference reference) :
    Claim :=
  verified.certificate.verifiedByAgenticAILab

theorem reference_without_certificate_cannot_verify
    {Source : Type u}
    {Claim : Prop}
    {reference : ReferenceObservation Source Claim}
    (noCertificate : ¬ AdoptionCertificate reference) :
    ¬ VerifiedFromReference reference := by
  intro verified
  exact noCertificate verified.certificate

abbrev OpenRATHObservation (Claim : Prop) :=
  ReferenceObservation ProductionReference Claim

def openRATHObservation
    {Claim : Prop} : OpenRATHObservation Claim :=
  { source := ProductionReference.openRATH
    observed := True.intro }

theorem openRATH_without_certificate_cannot_verify
    {Claim : Prop}
    {reference : OpenRATHObservation Claim}
    (noCertificate : ¬ AdoptionCertificate reference) :
    ¬ VerifiedFromReference reference :=
  reference_without_certificate_cannot_verify noCertificate

abbrev ReferenceControlTrace
    (Source : Type u)
    (Tool File Capability Agent : Type v)
    (session : SessionProfile Tool File Capability)
    (event : SessionEvent Tool File Capability Agent) :=
  ReferenceObservation Source (SessionTrace session event)

theorem verified_reference_trace_is_poo_trace
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {event : SessionEvent Tool File Capability Agent}
    {reference : ReferenceControlTrace Source Tool File Capability Agent session event}
    (verified : VerifiedFromReference reference) :
    SessionTrace session event :=
  verified_reference_claim_holds verified

theorem verified_reference_tool_trace_requires_sandbox_permission
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    {reference :
      ReferenceControlTrace
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.useTool tool)}
    (verified : VerifiedFromReference reference) :
    session.sandbox.toolAllowed tool :=
  tool_event_requires_sandbox_permission
    (verified_reference_trace_is_poo_trace verified)

theorem verified_reference_read_trace_requires_sandbox_scope
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {reference :
      ReferenceControlTrace
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.readFile file)}
    (verified : VerifiedFromReference reference) :
    session.sandbox.fileAllowed file :=
  read_file_event_requires_sandbox_scope
    (verified_reference_trace_is_poo_trace verified)

theorem verified_reference_write_trace_requires_sandbox_scope
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {reference :
      ReferenceControlTrace
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.writeFile file)}
    (verified : VerifiedFromReference reference) :
    session.sandbox.fileAllowed file :=
  write_file_event_requires_sandbox_scope
    (verified_reference_trace_is_poo_trace verified)

theorem verified_reference_subagent_trace_requires_capability_subset
    {Source : Type u}
    {Tool File Capability Agent : Type v}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {reference :
      ReferenceControlTrace
        Source
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.startSubagent agent childProfile)}
    (verified : VerifiedFromReference reference) :
    (capability : Capability) ->
      childProfile.sandbox.capabilityAllowed capability ->
      session.sandbox.capabilityAllowed capability :=
  start_subagent_requires_capability_subset
    (verified_reference_trace_is_poo_trace verified)

theorem openRATH_reference_denied_tool_cannot_verify_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {tool : Tool}
    {reference :
      ReferenceControlTrace
        ProductionReference
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.useTool tool)}
    (denied : ¬ session.sandbox.toolAllowed tool) :
    ¬ VerifiedFromReference reference := by
  intro verified
  exact
    denied
      (verified_reference_tool_trace_requires_sandbox_permission verified)

theorem openRATH_reference_out_of_scope_read_cannot_verify_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {file : File}
    {reference :
      ReferenceControlTrace
        ProductionReference
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.readFile file)}
    (outOfScope : ¬ session.sandbox.fileAllowed file) :
    ¬ VerifiedFromReference reference := by
  intro verified
  exact
    outOfScope
      (verified_reference_read_trace_requires_sandbox_scope verified)

theorem openRATH_reference_subagent_escalation_cannot_verify_trace
    {Tool File Capability Agent : Type u}
    {session : SessionProfile Tool File Capability}
    {agent : Agent}
    {childProfile : AgentProfile Tool File Capability}
    {capability : Capability}
    {reference :
      ReferenceControlTrace
        ProductionReference
        Tool
        File
        Capability
        Agent
        session
        (SessionEvent.startSubagent agent childProfile)}
    (childAllows : childProfile.sandbox.capabilityAllowed capability)
    (parentDenies : ¬ session.sandbox.capabilityAllowed capability) :
    ¬ VerifiedFromReference reference := by
  intro verified
  exact
    parentDenies
      (verified_reference_subagent_trace_requires_capability_subset
        verified
        capability
        childAllows)

end AgenticAILabProof.PooC4.ReferenceBoundary
