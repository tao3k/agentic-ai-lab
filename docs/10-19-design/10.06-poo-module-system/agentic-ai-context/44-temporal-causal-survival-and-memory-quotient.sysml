// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package TemporalCausalSurvivalMemoryQuotient {
    private import ScalarValues::*;
    private import VerificationCases::*;
    private import FormalVerificationTaxonomy::*;

    item def BitemporalProjectionSlice {
        attribute admissionCut : Integer;
        attribute validTimeQuery : Integer;
        attribute status : String;
    }

    item def SourceWatermarkObservation {
        attribute watermarkRank : Integer;
        attribute coverageClaimed : Boolean;
    }

    item def EvidenceUseInventory {
        attribute retrievedCount : Integer;
        attribute citedUsedCount : Integer;
    }

    item def QuotientMemoryProposal {
        attribute proposalId : String;
        attribute rawEpisodeCost : Integer;
        attribute compressedQuotientCost : Integer;
        attribute reliesOnAscentWhyNot : Boolean;
    }

    item def QuotientAdmissionVerdict {
        attribute causallySurvivesInActiveSet : Boolean;
        attribute archivedInColdLedger : Boolean;
    }

    port def ProposerToTemporalPort {
        in item proposal : QuotientMemoryProposal;
        in item useInventory : EvidenceUseInventory;
        out item verdict : QuotientAdmissionVerdict;
    }

    port def BitemporalClockAndWatermarkPort {
        in item bitemporal : BitemporalProjectionSlice;
        in item watermark : SourceWatermarkObservation;
        out attribute survivalPremisesHold : Boolean;
    }

    part def AscentAndLlmProposerPlane {
        port propose : ~ProposerToTemporalPort;
    }

    part def TemporalCausalitySurvivalSpine {
        port intake : ProposerToTemporalPort;
        port clockAndWatermark : BitemporalClockAndWatermarkPort;
    }

    part def BitemporalJournalAndClockPlane {
        port supply : ~BitemporalClockAndWatermarkPort;
    }

    part def CausalSurvivalMemorySystem {
        part proposerPlane : AscentAndLlmProposerPlane;
        part temporalSpine : TemporalCausalitySurvivalSpine;
        part journalPlane : BitemporalJournalAndClockPlane;
        part verifierSuite : OrthogonalVerificationSuite;
        connection evaluateProposal connect proposerPlane.propose to temporalSpine.intake;
        connection checkTimeAndWatermark connect journalPlane.supply to temporalSpine.clockAndWatermark;
    }

    part survivalSystem : CausalSurvivalMemorySystem;

    // 1. Lean Unbounded Bitemporal Journal & Citation-Frame Obligations
    requirement bitemporalJournalCutAlgebra : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "44-temporal-causal-survival-and-memory-quotient.lean";
        attribute :>> leanTheorems = "append_later_revision_preserves_historical_cut, filterUpToCut_monotone_in_cut";
        doc /* Over arbitrarily long append-only revision journals, appending
               later admission entries leaves historical cuts bit-for-bit
               identical, and cut visibility grows monotonically with cut rank. */
    }

    requirement citationFrameAndImpactInclusionLaw : LeanAlgebraicObligation {
        attribute :>> leanArtifact = "44-temporal-causal-survival-and-memory-quotient.lean";
        attribute :>> leanTheorems = "unused_retrieved_mutation_creates_zero_invalidation_burden, post_admission_citation_invalidates_prior_review, trajectoryImpact_subsumed_by_potentialFrontier";
        doc /* Mutating any uncited retrieved item preserves active survival
               (frame law), appending unverified citations invalidates review,
               and trajectory impact T refines potential frontier P. */
    }

    // 2. Quint Nondeterministic Watermark, Late-Fact & Eviction Race Obligations
    requirement watermarkVsWhyNotAndLateFactRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "44-temporal-causal-survival-and-memory-quotient.qnt";
        attribute :>> quintInvariants = "whyNotMemoryRequiresClosedWatermark, historicalCutImmutableUnderLateValidTimeArrival";
        doc /* Asynchronous ASCENT Why-Not proposals race safely against
               SourceWatermark closure, and out-of-order late valid-time facts
               advance the live cut without mutating historical cut snapshots. */
    }

    requirement concurrentRetrievedVsCitedMutationRace : QuintInterleavingObligation {
        attribute :>> quintArtifact = "44-temporal-causal-survival-and-memory-quotient.qnt";
        attribute :>> quintInvariants = "activeGemEvictsOnCitedRetractionAndIgnoresUncitedChurn";
        doc /* Concurrent churn on retrieved-only evidence never evicts an
               active memory gem, whereas retracting cited evidence atomically
               evicts it from active prompt selection into cold audit history. */
    }

    allocation ownJournalDomain allocate bitemporalJournalCutAlgebra to survivalSystem.journalPlane;
    allocation verifyJournalInLean allocate bitemporalJournalCutAlgebra to survivalSystem.verifierSuite.leanEngine;

    allocation ownCitationDomain allocate citationFrameAndImpactInclusionLaw to survivalSystem.temporalSpine;
    allocation verifyCitationInLean allocate citationFrameAndImpactInclusionLaw to survivalSystem.verifierSuite.leanEngine;

    allocation ownWatermarkRaceDomain allocate watermarkVsWhyNotAndLateFactRace to survivalSystem.temporalSpine;
    allocation verifyWatermarkRaceInQuint allocate watermarkVsWhyNotAndLateFactRace to survivalSystem.verifierSuite.quintEngine;

    allocation ownEvictionRaceDomain allocate concurrentRetrievedVsCitedMutationRace to survivalSystem.temporalSpine;
    allocation verifyEvictionRaceInQuint allocate concurrentRetrievedVsCitedMutationRace to survivalSystem.verifierSuite.quintEngine;

    verification def TemporalSurvivalDispatchAndBoundaryContract {
        subject target : CausalSurvivalMemorySystem default = survivalSystem;
        in leanBitemporalAndFrameProven : Boolean;
        in quintWatermarkAndEvictionRacesChecked : Boolean;
        in enginesStrictlyDisjoint : Boolean;
        in quotientStrictlyReducesEntropy : Boolean;
        in mode : Integer;

        attribute dispatchValid : Boolean := false;
        attribute quotientValid : Boolean := false;
        attribute admitted : Boolean := false;

        first start then auditSurvivalBoundary;
        action auditSurvivalBoundary {
            assign dispatchValid := leanBitemporalAndFrameProven and quintWatermarkAndEvictionRacesChecked
                and (enginesStrictlyDisjoint or mode == 1);
            assign quotientValid := quotientStrictlyReducesEntropy or mode == 2;
            assign admitted := dispatchValid and quotientValid;
        }
        then done;

        return verdict : VerdictKind = PassIf(
            not admitted
            or (leanBitemporalAndFrameProven
                and quintWatermarkAndEvictionRacesChecked
                and enginesStrictlyDisjoint
                and quotientStrictlyReducesEntropy)
        );
    }
}
