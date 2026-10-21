# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Quint model cases and their required positive and negative controls."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class QuintCase:
    model: str
    invariant: str = "safety"
    negative: bool = False
    temporal: str | None = None
    source_directory: str = "packages/proofs/quint"

GROUPS = {
    "search-inputs": [QuintCase("SearchInputs_none"),
        QuintCase("SearchInputs_ignoreCurrent", "CurrentInputs", True),
        QuintCase("SearchInputs_ignoreMissing", "CompleteInputs", True)],
    "search-evidence-history": [QuintCase("SearchEvidenceHistory_none"),
        QuintCase("SearchEvidenceHistory_ignoreUsed", "UniqueEventAdmission", True),
        QuintCase("SearchEvidenceHistory_clearHistory", "HistoryRetention", True)],
    "search-evidence": [QuintCase("SearchEvidence_none"),
        QuintCase("SearchEvidence_ignoreParents", "ExactCausalParents", True),
        QuintCase("SearchEvidence_ignoreScope", "ObservationScope", True),
        QuintCase("SearchEvidence_ignoreTime", "TemporalOrder", True),
        QuintCase("SearchEvidence_ignoreCommitted", "CommittedEvidence", True)],
    "search-dag": [QuintCase("SearchDag_none"),
        QuintCase("SearchDag_ignoreParents", "DependencyOrder", True),
        QuintCase("SearchDag_ignoreFreshness", "FreshResults", True),
        QuintCase("SearchDag_clearAll", "BranchRetention", True)],
    "search-readiness": [QuintCase("SearchReadiness_none"),
        QuintCase("SearchReadiness_ignoreMissing", "AllPrerequisites", True),
        QuintCase("SearchReadiness_ignoreRevision", "CurrentPrerequisites", True),
        QuintCase("SearchReadiness_ignoreScope", "ScopeIsolation", True)],
    "search-attempt": [QuintCase("SearchAttempt_none"),
        QuintCase("SearchAttempt_ignoreRevision", "CurrentRevision", True),
        QuintCase("SearchAttempt_ignoreAttempt", "ExactAttempt", True),
        QuintCase("SearchAttempt_ignoreRetired", "NoRetiredAdmission", True),
        QuintCase("SearchAttempt_cancelAny", "NoStaleCancellation", True)],
    "governance": [QuintCase("GovernanceCore")],
    "query": [QuintCase("NativeSemanticQuery", source_directory="core/dev/proofs/quint")],
    "healthcare": [QuintCase("HealthcarePrescriptionCausality")],
    "healthcare-ai": [QuintCase("HealthcareAIAssistedPrescriptionCausality")],
    "healthcare-migration": [QuintCase("HealthcareStandardMigration")],
    "family": [QuintCase(n, temporal="eventuallyTerminal") for n in
               ("TemporalFamilyCase", "TemporalFamilyBounded", "TemporalDiscriminatingCase")]
              + [QuintCase("TemporalFamilyMutation", "TerminalAgreement", True)],
    "revision": [QuintCase("TemporalRevision", temporal="eventuallyComplete")],
    "invalidation": [QuintCase(n, temporal="eventuallyComplete") for n in
                     ("TemporalInvalidationCase", "TemporalReprojectionCase")]
                    + [QuintCase("TemporalReprojectionMutation", "DirectScheduled", True)],
    "selection": [QuintCase("TemporalConclusionSelectionCase", temporal="eventuallyResolved"),
                  QuintCase("TemporalConclusionSelectionMutation", "AtMostOneCommit", True)],
    "evidence": [QuintCase("EvidenceLineageCase"), QuintCase("EvidenceAssessmentCase"),
                 QuintCase("CandidateExchangeCase"),
                 QuintCase("EvidenceLineageMutation", "ActiveSupportInvariant", True),
                 QuintCase("EvidenceAssessmentMutation", "ActiveAssessmentInvariant", True),
                 QuintCase("CandidateExchangeMutation", "ReviewabilityInvariant", True)],
    "publication": [QuintCase("TemporalPublicationDeliveryCase"),
                    QuintCase("TemporalPublicationDeliveryMutation", "AtomicTuple", True),
                    QuintCase("TemporalPublicationAuthorityCase"),
                    QuintCase("TemporalPublicationGenerationMutation", "NoUnauthorizedCommit", True),
                    QuintCase("TemporalPublicationRetirementMutation", "NoUnauthorizedCommit", True)],
    "session": [],
    "context-temporal-lifecycle": [QuintCase("ContextTemporalLifecycle_none")] + [
        QuintCase("ContextTemporalLifecycle_" + bug, invariant, True) for bug, invariant in [
            ("ignoreSource", "ExactSource"), ("ignoreTemporal", "ExactTemporal"),
            ("ignorePolicy", "ExactPolicy"), ("ignoreEvidence", "CurrentEvidence"),
            ("ignoreDomain", "ComparableClock"), ("ignoreUncertainty", "ConservativeWindow"),
            ("ignoreTerminalReceipt", "TerminalReceipt"), ("resurrect", "NoResurrection"),
            ("reviveObligation", "NoObligationResurrection")]],
    "context-session-claim": [QuintCase("ContextSessionClaim_none")] + [
        QuintCase("ContextSessionClaim_" + bug, invariant, True) for bug, invariant in [
            ("ignoreOwner", "ExactOwner"), ("ignoreSource", "ExactSource"),
            ("ignoreGrantGeneration", "CurrentGrant"), ("ignoreRevocation", "EnabledGrant"),
            ("ignoreClock", "EffectiveClock"), ("dropObligation", "PendingPreserved"),
            ("ignoreScope", "FixedScope")]],
    "session-attempt": [QuintCase("SessionAttempt_none"),
        QuintCase("SessionAttempt_ignoreGeneration", "ExactAttempt", True),
        QuintCase("SessionAttempt_dropObligation", "RecoveryPreservesObligation", True),
        QuintCase("SessionAttempt_resumeClosed", "ClosedIsTerminal", True)],
    "context-coverage": [QuintCase("ContextCoverage_none")] + [
        QuintCase("ContextCoverage_" + bug, "IncrementalEqualsFull", True)
        for bug in ("omitInsertion", "omitRemoval", "omitNegative")],
    "context-delta": [QuintCase("ContextDelta_none")] + [
        QuintCase("ContextDelta_" + bug, inv, True) for bug, inv in [
            ("ignoreCAS", "OnePublication"), ("ignoreCut", "ExactTargetCut"),
            ("ignoreDelete", "ExactReconstruction"), ("ignoreUseCut", "CurrentConsumption"),
            ("ignoreGrant", "AuthorizedConsumption")]],
}
SESSION_CASES = (
    ("ContextSession", "none", None),
    ("ContextSession", "ignoreCAS", "NoDoubleCommit"),
    ("ContextSession", "ignoreAuth", "NoUnauthorizedCommit"),
    ("ContextSession", "ignoreCut", "NoMixedCut"),
    ("ContextSession", "resurrect", "NoClosedResume"),
    ("WorktreeContext", "none", None),
    ("WorktreeContext", "ignoreScope", "NoForeignRead"),
    ("WorktreeContext", "ignoreReadAuth", "NoUnauthorizedRead"),
    ("WorktreeContext", "ignoreSourceCut", "NoStaleSourceImport"),
    ("WorktreeContext", "ignoreTargetCut", "NoStaleTargetImport"),
    ("WorktreeContext", "ignoreCAS", "NoDoubleImport"),
    ("WorktreeContext", "ignoreApplicable", "NoInapplicableImport"),
)
GROUPS["session"] = [QuintCase(f"{m}_{bug}", inv or "safety", inv is not None)
                     for m, bug, inv in SESSION_CASES]

