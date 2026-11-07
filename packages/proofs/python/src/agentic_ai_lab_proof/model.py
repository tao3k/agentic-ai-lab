# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Python-side typed model for emitting Lean constructors.

The values here are not proof objects. They are a generator-friendly mirror of
the Lean constructors in AgenticAILabProof.Manifest.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Obligation:
    name: str
    claim: str
    source: str


@dataclass(frozen=True)
class TypedManifest:
    request_id: str
    artifact_handle: str
    required_obligation_mask: int
    obligations: tuple[Obligation, ...]


def canonical_loop_engine_manifest() -> TypedManifest:
    return TypedManifest(
        request_id="loop-engine/current-system-build-loop/request",
        artifact_handle="loop-engine/current-system-build-loop/artifact",
        required_obligation_mask=31,
        obligations=(
            Obligation(
                "ObligationName.uiConfigWellFormed",
                "ObligationClaim.allRuntimeHandoffReferencesArePresent",
                "ObligationSource.schemeProjection",
            ),
            Obligation(
                "ObligationName.runtimeCommandInert",
                "ObligationClaim.schemeEmitsManifestWithoutRuntimeExecution",
                "ObligationSource.runtimeCommandManifest",
            ),
            Obligation(
                "ObligationName.policyStrategyDeterministic",
                "ObligationClaim.policyAndStrategyProjectionHasStablePrecedence",
                "ObligationSource.policyProfilePacket",
            ),
            Obligation(
                "ObligationName.workflowAgreementLinked",
                "ObligationClaim.workflowAgreementIsCarriedIntoRuntimeEnvelope",
                "ObligationSource.workflowAgreement",
            ),
            Obligation(
                "ObligationName.sandboxBoundaryLinked",
                "ObligationClaim.sandboxHandoffAgreementIsCarriedIntoProofScope",
                "ObligationSource.sandboxHandoffAgreement",
            ),
        ),
    )
