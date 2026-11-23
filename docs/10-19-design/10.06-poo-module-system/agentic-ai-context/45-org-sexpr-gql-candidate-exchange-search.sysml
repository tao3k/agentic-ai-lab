// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package OrgSexprGqlCandidateExchange {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def OrgElementAstRecord {
        attribute nodeId : String;
        attribute elementKind : String;
        attribute utf8ByteStart : Integer;
        attribute utf8ByteEnd : Integer;
    }

    item def GqlBoundedPathReceipt {
        attribute temporalGeneration : Integer;
        attribute pathComplete : Boolean;
    }

    item def AscentDeductionReceipt {
        attribute temporalGeneration : Integer;
        attribute derivationComplete : Boolean;
    }

    item def CandidateExchangePublication {
        attribute activeTemporalGeneration : Integer;
        attribute publishedToTemporal : Boolean;
    }

    port def SexprToGqlSpacePort {
        in item astNode : OrgElementAstRecord;
        out attribute elementSpaceId : String;
    }

    port def CandidateExchangeIntakePort {
        in item gqlReceipt : GqlBoundedPathReceipt;
        in item ascentReceipt : AscentDeductionReceipt;
        out item publication : CandidateExchangePublication;
    }

    part def OrgSexprSelectorEngine {
        port emitSpace : ~SexprToGqlSpacePort;
    }

    part def GqlRelationshipGraphEngine {
        port intakeSpace : SexprToGqlSpacePort;
        port emitExchange : ~CandidateExchangeIntakePort;
    }

    part def TemporalCandidateExchangeGate {
        port exchange : CandidateExchangeIntakePort;
    }

    part def HybridSearchAndExchangeSystem {
        part sexprEngine : OrgSexprSelectorEngine;
        part gqlEngine : GqlRelationshipGraphEngine;
        part exchangeGate : TemporalCandidateExchangeGate;
        part verifierSuite : OrthogonalVerificationSuite;
        connection buildElementSpace connect sexprEngine.emitSpace to gqlEngine.intakeSpace;
        connection joinProviders connect gqlEngine.emitExchange to exchangeGate.exchange;
    }

    part hybridSearchSystem : HybridSearchAndExchangeSystem;

    // 1. Lean Unbounded Recursive AST & Multi-Hop GQL Path Induction Obligations
    requirement recursiveAstSexprIsolationLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "45-org-sexpr-gql-candidate-exchange-search.lean";
        attribute :>> leanTheorems = "selectAstTree_excludes_source_blocks, selectAstTree_preserves_byte_bounds";
        doc /* Over arbitrarily nested ORG syntax trees, S-expression selection
               prunes source-block subtrees at every depth (blocking spoofed
               headings/properties inside code blocks) and preserves UTF-8 byte spans. */
    }

    requirement gqlMultiHopConfinementAndFuelLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "45-org-sexpr-gql-candidate-exchange-search.lean";
        attribute :>> leanTheorems = "admittedWalk_stays_in_element_space, walkFuel_append";
        doc /* By induction on path length, any GQL walk over admitted edges
               never escapes ElementSpace, and path fuel composes additively. */
    }

    // 2. Quint Nondeterministic Multi-Provider Join & Generation Race Obligations
    requirement candidateExchangeMultiProviderRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "45-org-sexpr-gql-candidate-exchange-search.qnt";
        attribute :>> quintInvariants = "publishedRequiresSameGenCompleteReceipts, receiptUniquenessPerProviderGen, genAdvanceClearsPublicationPreservingHistory";
        doc /* Under asynchronous GQL and ASCENT completions, mid-flight
               generation advances and duplicate retry races, CandidateExchange
               publishes iff every provider holds one complete receipt at the
               exact active generation. */
    }

    allocation ownSexprDomain allocate recursiveAstSexprIsolationLaw to hybridSearchSystem.sexprEngine;
    allocation verifySexprInLean allocate recursiveAstSexprIsolationLaw to hybridSearchSystem.verifierSuite.leanEngine;

    allocation ownGqlDomain allocate gqlMultiHopConfinementAndFuelLaw to hybridSearchSystem.gqlEngine;
    allocation verifyGqlInLean allocate gqlMultiHopConfinementAndFuelLaw to hybridSearchSystem.verifierSuite.leanEngine;

    allocation ownExchangeRaceDomain allocate candidateExchangeMultiProviderRace to hybridSearchSystem.exchangeGate;
    allocation verifyExchangeRaceInQuint allocate candidateExchangeMultiProviderRace to hybridSearchSystem.verifierSuite.quintEngine;

    verification def HybridSearchDispatchAndBoundaryContract {
        subject target : HybridSearchAndExchangeSystem default = hybridSearchSystem;
        in leanAstAndWalkProven : Boolean;
        in quintExchangeRaceChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in gqlReadsOnlyAdmittedElementSpace : Boolean;
        in mode : Integer;

        attribute dispatchValid : Boolean := false;
        attribute spaceFenceValid : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditHybridSearchBoundary;
        action auditHybridSearchBoundary {
            assign dispatchValid := leanAstAndWalkProven and quintExchangeRaceChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign spaceFenceValid := gqlReadsOnlyAdmittedElementSpace or mode == 2;
            assign admitted := dispatchValid and spaceFenceValid;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanAstAndWalkProven
                and quintExchangeRaceChecked
                and enginesStrictlyDisjoint
                and gqlReadsOnlyAdmittedElementSpace)
        );
    }
}
