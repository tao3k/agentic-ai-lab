-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.AuditTransportInjectivityClosure

structure CanonicalAuditTransport (Graph AuditBytes : Type) where
  encode : Graph → AuditBytes
  decode : AuditBytes → Option Graph
  decodeEncode : ∀ graph, decode (encode graph) = some graph
  encodeDecode :
    ∀ auditBytes graph,
      decode auditBytes = some graph →
        encode graph = auditBytes

theorem losslessAuditEncodingIsInjective
    {Graph AuditBytes : Type}
    (transport : CanonicalAuditTransport Graph AuditBytes) :
    Function.Injective transport.encode := by
  intro left right encodedEqual
  have decodedEqual :
      transport.decode (transport.encode left) =
        transport.decode (transport.encode right) :=
    congrArg transport.decode encodedEqual
  rw [transport.decodeEncode left, transport.decodeEncode right] at decodedEqual
  exact Option.some.inj decodedEqual

theorem verificationSurvivesCanonicalAuditRoundTrip
    {Graph AuditBytes : Type}
    (transport : CanonicalAuditTransport Graph AuditBytes)
    (verified : Graph → Prop)
    (graph : Graph)
    (graphVerified : verified graph) :
    ∃ decoded,
      transport.decode (transport.encode graph) = some decoded ∧
        verified decoded := by
  exact ⟨graph, transport.decodeEncode graph, graphVerified⟩

theorem acceptedAuditBytesHaveOneCanonicalEncoding
    {Graph AuditBytes : Type}
    (transport : CanonicalAuditTransport Graph AuditBytes)
    (auditBytes : AuditBytes)
    (graph : Graph)
    (decoded : transport.decode auditBytes = some graph) :
    transport.encode graph = auditBytes :=
  transport.encodeDecode auditBytes graph decoded

inductive TwoDistinctGraphs
  | left
  | right

def digestOnlyProjection (_ : TwoDistinctGraphs) : Unit :=
  ()

theorem digestOnlyProjectionCannotBeLossless :
    ¬ ∃ decode : Unit → Option TwoDistinctGraphs,
        ∀ graph,
          decode (digestOnlyProjection graph) = some graph := by
  intro claimedDecoder
  obtain ⟨decode, roundTrip⟩ := claimedDecoder
  have leftRoundTrip := roundTrip .left
  have rightRoundTrip := roundTrip .right
  rw [digestOnlyProjection] at leftRoundTrip rightRoundTrip
  rw [leftRoundTrip] at rightRoundTrip
  have impossible : TwoDistinctGraphs.left = TwoDistinctGraphs.right :=
    Option.some.inj rightRoundTrip
  cases impossible

end AgenticAILabProof.Enterprise.AuditTransportInjectivityClosure
