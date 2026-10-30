# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Independent deterministic replay for the EASE-005 refinement."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from agentic_ai_lab_proof.embodied_ai_provider_non_authority import (
    AnalysisCandidateV1,
    AuthorityEnvelopeV1,
    AuthorityRole,
    IssuerKind,
    ProviderIdentityV1,
    evaluate_provider_admission,
)


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def _candidate() -> AnalysisCandidateV1:
    return AnalysisCandidateV1(
        candidate_id="ease005-candidate-1",
        provider=ProviderIdentityV1(
            provider_id="ease005-provider-1",
            model_id="ease005-model-1",
            input_context_id="ease005-context-1",
            generation_version="ease005-generation-1",
        ),
    )


def _implementation_artifact_digest() -> str:
    artifact = Path(__file__).with_name("embodied_ai_provider_non_authority.py")
    return f"sha256:{hashlib.sha256(artifact.read_bytes()).hexdigest()}"


def _case_record(
    case_id: str,
    authority: AuthorityEnvelopeV1,
    role: AuthorityRole,
) -> dict[str, object]:
    trace = evaluate_provider_admission(_candidate(), authority, role)
    return {
        "caseId": case_id,
        "issuerKind": authority.issuer_kind.value,
        "authorityId": authority.issuer_id,
        "role": role.value,
        "roleOnlyWouldAdmit": trace.role_only_would_admit,
        "admitted": trace.decision.admitted,
        "reasonKind": trace.decision.reason_kind,
        "providerId": trace.decision.provider_id,
    }


def build_ease005_replay_receipt() -> dict[str, Any]:
    all_roles = frozenset(AuthorityRole)
    provider_authority = AuthorityEnvelopeV1(
        issuer_kind=IssuerKind.AI_PROVIDER,
        issuer_id="ease005-provider-1",
        grants=all_roles,
    )
    cases = [
        _case_record(
            f"provider-rejected-{role.value}",
            provider_authority,
            role,
        )
        for role in AuthorityRole
    ]
    cases.append(
        _case_record(
            "independent-human-verification-admitted",
            AuthorityEnvelopeV1(
                issuer_kind=IssuerKind.HUMAN_AUTHORITY,
                issuer_id="ease005-reviewer-1",
                grants=frozenset({AuthorityRole.VERIFICATION_DISCHARGE}),
            ),
            AuthorityRole.VERIFICATION_DISCHARGE,
        )
    )

    payload: dict[str, Any] = {
        "schemaId": "agentic-ai-lab.ai-security.ease005-replay-receipt.v1",
        "claimId": "EASE-005",
        "referenceTransitionId": (
            "python://src/agentic_ai_lab_proof/"
            "embodied_ai_provider_non_authority.py"
            "#item/function/evaluate_provider_admission"
        ),
        "implementationArtifactId": (
            "src/agentic_ai_lab_proof/embodied_ai_provider_non_authority.py"
        ),
        "implementationArtifactDigest": _implementation_artifact_digest(),
        "cases": cases,
    }
    trace_root = hashlib.sha256(_canonical_json(payload).encode()).hexdigest()
    return {**payload, "traceRoot": f"sha256:{trace_root}"}


def main() -> None:
    print(_canonical_json(build_ease005_replay_receipt()))


if __name__ == "__main__":
    main()
