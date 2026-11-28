// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package MultiRepoAgentDeclassification {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def ObservedRepoBinding {
        attribute repoIdentity : String;
        attribute sourceCut : String;
        attribute bindingAuthenticated : Boolean;
    }

    item def RedactionProjection {
        attribute rawSliceDigest : String;
        attribute redactedSliceDigest : String;
        attribute preservesActiveDefeaters : Boolean;
    }

    item def DeclassificationCertificate {
        attribute proposerPrincipal : String;
        attribute declassifierPrincipal : String;
        attribute recipientAgent : String;
        attribute boundOriginCut : String;
        attribute boundRedactedDigest : String;
    }

    port def CrossRepoTopologyPort {
        in item sourceRepo : ObservedRepoBinding;
        in item targetRepo : ObservedRepoBinding;
        out attribute topologyVerified : Boolean;
    }

    port def DeclassificationGatePort {
        in item redaction : RedactionProjection;
        in item certificate : DeclassificationCertificate;
        out attribute deliveryEligible : Boolean;
    }

    part def SourceRepoContextOwner {
        port topology : ~CrossRepoTopologyPort;
        port declassify : ~DeclassificationGatePort;
    }

    part def CrossRepoGovernanceGate {
        port topologyCheck : CrossRepoTopologyPort;
        port declassifyGate : DeclassificationGatePort;
    }

    part def RecipientSubagentContext {
        attribute agentIdentity : String;
        attribute targetRepoIdentity : String;
    }

    part def MultiRepoCollaborativeSystem {
        part coordinator : SourceRepoContextOwner;
        part governanceGate : CrossRepoGovernanceGate;
        part subagent : RecipientSubagentContext;
        part verifierSuite : OrthogonalVerificationSuite;
        connection checkTopology connect coordinator.topology to governanceGate.topologyCheck;
        connection checkDeclassification connect coordinator.declassify to governanceGate.declassifyGate;
    }

    part collaborativeSystem : MultiRepoCollaborativeSystem;

    // 1. Lean Unbounded Functional Projection & Set-Algebra Obligations
    requirement redactionProjectionOperatorAlgebra : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "42-multi-repo-multi-agent-declassification.lean";
        attribute :>> leanTheorems = "redactFields_idem, redactFields_preserves_defeaters, redactFields_strips_all_secrets, redactFields_length_le";
        doc /* Pure redaction over arbitrarily long ORG field lists is
               idempotent, preserves every active defeater, strips every secret
               field, and monotonically contracts payload length. */
    }

    requirement digestInequalityAndReaderIntersectionLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "42-multi-repo-multi-agent-declassification.lean";
        attribute :>> leanTheorems = "redacted_ne_raw_when_secret_present, commit_redacted_ne_raw, ordinary_intersection_never_adds_ungranted_subagent";
        doc /* Any slice containing a secret field produces a strictly distinct
               redacted representation under injective commitment, and ordinary
               reader-set intersection never widens access to ungranted subagents. */
    }

    // 2. Quint Nondeterministic Multi-Actor & Cut-Drift Interleaving Obligations
    requirement multiActorDeclassificationAndSubagentRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "42-multi-repo-multi-agent-declassification.qnt";
        attribute :>> quintInvariants = "noTransitiveGrantLeakOrRawExposure, activeDeliverySatisfiesDistinctRoles";
        doc /* Under asynchronous certificate signing, nested subagent spawning
               and confused-deputy forwarding races, ungranted subagents receive
               only redacted digests under 3-way distinct roles. */
    }

    requirement cascadingOriginCutDriftRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "42-multi-repo-multi-agent-declassification.qnt";
        attribute :>> quintInvariants = "originCutAdvanceWithdrawsActiveSubagentDelivery";
        doc /* Concurrent Repo-Core cut advances or certificate revocations
               racing before or after delivery immediately withdraw active
               subagent eligibility while preserving historical delivery records. */
    }

    allocation ownRedactionDomain allocate redactionProjectionOperatorAlgebra to collaborativeSystem.coordinator;
    allocation verifyRedactionInLean allocate redactionProjectionOperatorAlgebra to collaborativeSystem.verifierSuite.leanEngine;

    allocation ownIntersectionDomain allocate digestInequalityAndReaderIntersectionLaw to collaborativeSystem.governanceGate;
    allocation verifyIntersectionInLean allocate digestInequalityAndReaderIntersectionLaw to collaborativeSystem.verifierSuite.leanEngine;

    allocation ownActorRaceDomain allocate multiActorDeclassificationAndSubagentRace to collaborativeSystem.governanceGate;
    allocation verifyActorRaceInQuint allocate multiActorDeclassificationAndSubagentRace to collaborativeSystem.verifierSuite.quintEngine;

    allocation ownCascadeDomain allocate cascadingOriginCutDriftRace to collaborativeSystem.governanceGate;
    allocation verifyCascadeInQuint allocate cascadingOriginCutDriftRace to collaborativeSystem.verifierSuite.quintEngine;

    verification def MultiRepoDispatchAndBoundaryContract {
        subject target : MultiRepoCollaborativeSystem default = collaborativeSystem;
        in leanRedactionAlgebraProven : Boolean;
        in quintMultiActorRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in dualRepoBindingsObserved : Boolean;
        in mode : Integer;

        attribute dispatchOk : Boolean := false;
        attribute topologyOk : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditMultiRepoBoundary;
        action auditMultiRepoBoundary {
            assign dispatchOk := leanRedactionAlgebraProven and quintMultiActorRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign topologyOk := dualRepoBindingsObserved or mode == 2;
            assign admitted := dispatchOk and topologyOk;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanRedactionAlgebraProven
                and quintMultiActorRacesChecked
                and enginesStrictlyDisjoint
                and dualRepoBindingsObserved)
        );
    }
}
