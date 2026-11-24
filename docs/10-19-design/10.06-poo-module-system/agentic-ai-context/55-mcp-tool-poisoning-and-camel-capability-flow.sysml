// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package McpToolPoisoningAndCamelCapabilityFlow {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    doc /* Formalizes 2025-2026 MCP Tool Poisoning, Post-Approval Rug-Pull
           Manifest Pinning (MCPTox), Cross-Server Tool Shadowing Isolation,
           CaMeL Value-Level Capability Provenance at Sensitive Sinks, and
           MindGuard Zero-LLM Decision-Dependence Auditing under
           FormalVerificationTaxonomy XOR dispatch. */

    item def PinnedToolManifest {
        attribute serverId : String;
        attribute toolId : String;
        attribute descriptionDigest : String;
        attribute schemaDigest : String;
        attribute metadataTrustRank : Integer;
    }

    item def CapabilityTaggedArgument {
        attribute sinkKind : String;          // sensitive | benign
        attribute originKind : String;        // userIntent | rawToolOutput | untrustedMetadata
        attribute hasDeclassCert : Boolean;
        attribute manifestPinValid : Boolean;
    }

    port def ToolManifestPinPort {
        in item manifest : PinnedToolManifest;
        out attribute manifestAdmitted : Boolean;
    }

    port def SensitiveSinkGatePort {
        in item taggedArg : CapabilityTaggedArgument;
        out attribute sinkAdmitted : Boolean;
    }

    part def McpToolManifestRegistryGate {
        port manifestIn : ToolManifestPinPort;
        doc /* Enforces cryptographic manifest pinning against post-approval
               rug-pulls, cross-server tool shadowing rejection, and metadata
               trust segregation. */
    }

    part def CamelCapabilitySinkAndAuditGate {
        port sinkIn : SensitiveSinkGatePort;
        doc /* Enforces CaMeL value-level provenance checks at sensitive sinks
               and MindGuard-style zero-LLM counterfactual decision-dependence
               auditing against poisoned tool descriptions. */
    }

    part def McpToolPoisoningGovernanceSystem {
        part manifestRegistryGate : McpToolManifestRegistryGate;
        part camelSinkAuditGate : CamelCapabilitySinkAndAuditGate;
        part verifierSuite : OrthogonalVerificationSuite;
    }

    part mcpToolGovernanceSystem : McpToolPoisoningGovernanceSystem;

    // 1. Lean Unbounded Algebraic & Structural Preservation Laws
    requirement toolManifestPinningAndShadowingLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "55-mcp-tool-poisoning-and-camel-capability-flow.lean";
        attribute :>> leanTheorems = "rugPullMutation_breaks_manifest_pin, crossServerShadowing_rejected_fail_closed, metadataSegregation_keeps_description_untrusted";
        doc /* Any post-approval mutation to tool description or schema breaks
               manifest pin equality; cross-server tool name collisions fail
               closed across unbounded registries; external tool descriptions
               never attain trusted instruction rank. */
    }

    requirement camelCapabilityProvenanceAndSinkLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "55-mcp-tool-poisoning-and-camel-capability-flow.lean";
        attribute :>> leanTheorems = "untrustedOriginArgument_blocked_at_sensitive_sink, userIntentArgument_admitted_at_sensitive_sink, decisionDependenceAudit_flags_unendorsed_metadata_hijack";
        doc /* Sensitive sinks universally reject untrusted-metadata or
               raw-tool-output arguments without an active declassification cert;
               user-intent arguments pass cleanly; counterfactual decision flips
               driven by unendorsed tool metadata are always flagged offline. */
    }

    // 2. Quint Nondeterministic Rug-Pull, Shadowing & Sink-Exfiltration Races
    requirement mcpRugPullShadowingAndCapabilityFlowRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "55-mcp-tool-poisoning-and-camel-capability-flow.qnt";
        attribute :>> quintInvariants = "rugPullMutatedToolNeverInvoked, crossServerShadowedToolNeverDispatched, sensitiveSinkNeverAcceptsUntrustedOriginWithoutCert, poisonedMetadataDecisionHijackAlwaysFlaggedOffline";
        doc /* Under concurrent MCP server rug-pulls, cross-server shadowing
               registrations, untrusted argument flows into sensitive sinks,
               and offline MindGuard audits, all four safety invariants hold
               across the entire reachable state space. */
    }

    allocation ownManifestLaw allocate toolManifestPinningAndShadowingLaw to mcpToolGovernanceSystem.manifestRegistryGate;
    allocation verifyManifestInLean allocate toolManifestPinningAndShadowingLaw to mcpToolGovernanceSystem.verifierSuite.leanEngine;

    allocation ownCamelSinkLaw allocate camelCapabilityProvenanceAndSinkLaw to mcpToolGovernanceSystem.camelSinkAuditGate;
    allocation verifyCamelSinkInLean allocate camelCapabilityProvenanceAndSinkLaw to mcpToolGovernanceSystem.verifierSuite.leanEngine;

    allocation ownMcpRace allocate mcpRugPullShadowingAndCapabilityFlowRace to mcpToolGovernanceSystem.manifestRegistryGate;
    allocation verifyMcpRaceInQuint allocate mcpRugPullShadowingAndCapabilityFlowRace to mcpToolGovernanceSystem.verifierSuite.quintEngine;

    verification def McpToolPoisoningDispatchContract {
        subject target : McpToolPoisoningGovernanceSystem default = mcpToolGovernanceSystem;
        in leanAlgebraicLawsProven : Boolean;
        in quintConcurrencyRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in toolBoundaryClosed : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute boundaryOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditMcpToolBoundary;
        action auditMcpToolBoundary {
            assign dispatchOk := leanAlgebraicLawsProven and quintConcurrencyRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign boundaryOk := toolBoundaryClosed or mode == 2;
            assign admitted := dispatchOk and boundaryOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAlgebraicLawsProven
                and quintConcurrencyRacesChecked
                and enginesStrictlyDisjoint
                and toolBoundaryClosed)
        );
    }
}
