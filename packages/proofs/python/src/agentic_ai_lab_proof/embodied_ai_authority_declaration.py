# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class AuthorityAct(StrEnum):
    DECLARATION = "declaration-authority"
    EXECUTION = "execution-authority"
    EVIDENCE = "evidence-authority"
    VERIFICATION = "verification-authority"
    RESIDUAL_RISK = "residual-risk-acceptance-authority"
    RECOVERY = "recovery-authority"


class AuthorityIssuerKind(StrEnum):
    HUMAN_AUTHORITY = "human-authority"
    CEDAR_ENGINE = "cedar-engine"
    LEAN_ENGINE = "lean-engine"
    AI_PROVIDER = "ai-provider"


@dataclass(frozen=True)
class AuthorizationSubject:
    architecture_id: str
    bundle_digest: str
    policy_id: str
    resource_id: str
    action_id: str
    context_epoch: int


@dataclass(frozen=True)
class AuthorityReceipt:
    receipt_id: str
    issuer_id: str
    issuer_kind: AuthorityIssuerKind
    authority_act: AuthorityAct
    subject: AuthorizationSubject
    valid_from_epoch: int
    valid_until_epoch: int
    revoked_at_epoch: int | None
    receipt_valid: bool
    delegation_root: str
    responsibility_acceptance_digest: str


@dataclass(frozen=True)
class AuthorityActors:
    proposer_id: str
    approver_id: str
    executor_id: str


@dataclass(frozen=True)
class AuthorityDeclarationRequest:
    request_id: str
    candidate_id: str
    provider_id: str
    requested_act: AuthorityAct
    current_subject: AuthorizationSubject
    current_epoch: int
    declared_role: str
    receipt: AuthorityReceipt
    actors: AuthorityActors


@dataclass(frozen=True)
class AuthorityAdmissionDecision:
    admitted: bool
    reason_kind: str
    request_id: str
    requested_act: AuthorityAct
    authority_id: str


def _roles_populated_countermodel(request: AuthorityDeclarationRequest) -> bool:
    return bool(
        request.declared_role
        and request.actors.proposer_id
        and request.actors.approver_id
        and request.actors.executor_id
    )


def _provider_fields_match_countermodel(
    request: AuthorityDeclarationRequest,
) -> bool:
    return request.candidate_id == request.provider_id


def evaluate_authority_declaration_admission(
    request: AuthorityDeclarationRequest,
) -> AuthorityAdmissionDecision:
    def reject(reason_kind: str) -> AuthorityAdmissionDecision:
        return AuthorityAdmissionDecision(
            admitted=False,
            reason_kind=reason_kind,
            request_id=request.request_id,
            requested_act=request.requested_act,
            authority_id=request.receipt.issuer_id,
        )

    if not request.request_id or not request.declared_role:
        return reject("authority-declaration-incomplete")

    receipt = request.receipt
    if receipt.issuer_kind is AuthorityIssuerKind.AI_PROVIDER:
        return reject("ai-provider-non-authority")
    if receipt.issuer_kind is not AuthorityIssuerKind.HUMAN_AUTHORITY:
        return reject("analysis-engine-non-authority")
    if not receipt.receipt_valid:
        return reject("authority-receipt-invalid")
    if not receipt.receipt_id or not receipt.issuer_id:
        return reject("authority-receipt-identity-missing")
    if receipt.issuer_id in {request.candidate_id, request.provider_id}:
        return reject("authority-not-independent")
    if receipt.authority_act is not request.requested_act:
        return reject("authority-act-mismatch")
    if receipt.subject != request.current_subject:
        return reject("authority-subject-mismatch")
    if not (
        receipt.valid_from_epoch
        <= request.current_epoch
        <= receipt.valid_until_epoch
    ):
        return reject("authority-context-stale")
    if (
        receipt.revoked_at_epoch is not None
        and receipt.revoked_at_epoch <= request.current_epoch
    ):
        return reject("authority-revoked")
    if not receipt.delegation_root:
        return reject("delegation-root-missing")
    if not receipt.responsibility_acceptance_digest:
        return reject("responsibility-acceptance-missing")

    actors = request.actors
    actor_ids = {actors.proposer_id, actors.approver_id, actors.executor_id}
    if "" in actor_ids or len(actor_ids) != 3:
        return reject("separation-of-duties-violated")
    if actors.approver_id != receipt.issuer_id:
        return reject("approver-authority-mismatch")
    if request.candidate_id in actor_ids:
        return reject("candidate-participates-in-authority-chain")

    return AuthorityAdmissionDecision(
        admitted=True,
        reason_kind="authority-bearing-declaration-admitted",
        request_id=request.request_id,
        requested_act=request.requested_act,
        authority_id=receipt.issuer_id,
    )
