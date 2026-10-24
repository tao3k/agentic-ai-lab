# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Executable refinement for EASE-005 AI-provider non-authority."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class IssuerKind(str, Enum):
    AI_PROVIDER = "ai-provider"
    HUMAN_AUTHORITY = "human-authority"
    ORGANIZATIONAL_AUTHORITY = "organizational-authority"


class AuthorityRole(str, Enum):
    EFFECT_AUTHORIZATION = "effect-authorization"
    VERIFICATION_DISCHARGE = "verification-discharge"
    RESIDUAL_RISK_ACCEPTANCE = "residual-risk-acceptance"


@dataclass(frozen=True)
class ProviderIdentityV1:
    provider_id: str
    model_id: str
    input_context_id: str
    generation_version: str

    def validation_errors(self) -> tuple[str, ...]:
        fields = (
            ("provider_id", self.provider_id),
            ("model_id", self.model_id),
            ("input_context_id", self.input_context_id),
            ("generation_version", self.generation_version),
        )
        return tuple(name for name, value in fields if not value.strip())


@dataclass(frozen=True)
class AnalysisCandidateV1:
    candidate_id: str
    provider: ProviderIdentityV1


@dataclass(frozen=True)
class AuthorityEnvelopeV1:
    issuer_kind: IssuerKind
    issuer_id: str
    grants: frozenset[AuthorityRole]


@dataclass(frozen=True)
class AdmissionDecisionV1:
    admitted: bool
    reason_kind: str
    role: AuthorityRole
    candidate_id: str
    provider_id: str
    authority_id: str


@dataclass(frozen=True)
class ProviderAdmissionTraceV1:
    schema_id: str
    candidate: AnalysisCandidateV1
    authority: AuthorityEnvelopeV1
    role: AuthorityRole
    role_only_would_admit: bool
    decision: AdmissionDecisionV1


def _role_only_admission(
    authority: AuthorityEnvelopeV1,
    role: AuthorityRole,
) -> bool:
    """Unsafe reference policy used to retain the EASE-005 counterexample."""

    return role in authority.grants


def evaluate_provider_admission(
    candidate: AnalysisCandidateV1,
    authority: AuthorityEnvelopeV1,
    role: AuthorityRole,
) -> ProviderAdmissionTraceV1:
    """Evaluate a provider candidate without granting the provider authority."""

    role_only_would_admit = _role_only_admission(authority, role)
    provider_errors = candidate.provider.validation_errors()

    if not candidate.candidate_id.strip() or provider_errors:
        admitted = False
        reason_kind = "provider-provenance-invalid"
    elif authority.issuer_kind is IssuerKind.AI_PROVIDER:
        admitted = False
        reason_kind = "ai-provider-non-authority"
    elif not authority.issuer_id.strip():
        admitted = False
        reason_kind = "authority-id-missing"
    elif role not in authority.grants:
        admitted = False
        reason_kind = "authority-role-not-granted"
    else:
        admitted = True
        reason_kind = "independent-authority-admitted"

    decision = AdmissionDecisionV1(
        admitted=admitted,
        reason_kind=reason_kind,
        role=role,
        candidate_id=candidate.candidate_id,
        provider_id=candidate.provider.provider_id,
        authority_id=authority.issuer_id,
    )
    return ProviderAdmissionTraceV1(
        schema_id="agentic-ai-lab.ai-security.provider-admission-trace.v1",
        candidate=candidate,
        authority=authority,
        role=role,
        role_only_would_admit=role_only_would_admit,
        decision=decision,
    )
