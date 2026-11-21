# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class EffectOutcome(StrEnum):
    APPLIED = "applied"
    DUPLICATE = "duplicate"
    ROLLED_BACK = "rolled-back"
    RECOVERED = "recovered"


class EffectReversibility(StrEnum):
    REVERSIBLE = "reversible"
    COMPENSABLE = "compensable"
    IRREVERSIBLE = "irreversible"


class RecoveryPhase(StrEnum):
    COMMITTED = "committed"
    ROLLED_BACK = "rolled-back"
    COMPENSATED = "compensated"
    APPLYING = "applying"


TERMINAL_RECOVERY_PHASES = {
    RecoveryPhase.COMMITTED,
    RecoveryPhase.ROLLED_BACK,
    RecoveryPhase.COMPENSATED,
}


@dataclass(frozen=True)
class EffectAuthorizationReceipt:
    authority_id: str
    subject_id: str
    effect_id: str
    receipt_valid: bool


@dataclass(frozen=True)
class EffectObligation:
    effect_id: str
    reversibility: EffectReversibility


@dataclass(frozen=True)
class PriorCommitReceipt:
    transaction_id: str
    effect_id: str
    receipt_valid: bool


@dataclass(frozen=True)
class CompensationReceipt:
    transaction_id: str
    effect_id: str
    receipt_valid: bool


@dataclass(frozen=True)
class RecoveryReceipt:
    transaction_id: str
    claimant_id: str
    fence_owner_id: str
    phase: RecoveryPhase
    receipt_valid: bool


@dataclass(frozen=True)
class ConstrainedEffectRequest:
    request_id: str
    transaction_id: str
    subject_id: str
    effect_id: str
    outcome: EffectOutcome
    authorization: EffectAuthorizationReceipt
    declared_obligations: tuple[EffectObligation, ...]
    observed_effect_ids: tuple[str, ...]
    prior_commits: tuple[PriorCommitReceipt, ...]
    compensation_receipts: tuple[CompensationReceipt, ...]
    recovery: RecoveryReceipt


@dataclass(frozen=True)
class ConstrainedEffectDecision:
    admitted: bool
    reason_kind: str
    request_id: str
    transaction_id: str
    effect_id: str


def _has_valid_prior_commit(request: ConstrainedEffectRequest) -> bool:
    return any(
        receipt.receipt_valid
        and receipt.transaction_id == request.transaction_id
        and receipt.effect_id == request.effect_id
        for receipt in request.prior_commits
    )


def _has_valid_compensation(
    request: ConstrainedEffectRequest, obligation: EffectObligation
) -> bool:
    return any(
        receipt.receipt_valid
        and receipt.transaction_id == request.transaction_id
        and receipt.effect_id == obligation.effect_id
        for receipt in request.compensation_receipts
    )


def evaluate_constrained_effect(
    request: ConstrainedEffectRequest,
) -> ConstrainedEffectDecision:
    def reject(reason_kind: str) -> ConstrainedEffectDecision:
        return ConstrainedEffectDecision(
            admitted=False,
            reason_kind=reason_kind,
            request_id=request.request_id,
            transaction_id=request.transaction_id,
            effect_id=request.effect_id,
        )

    if not request.request_id or not request.transaction_id or not request.effect_id:
        return reject("missing-effect-identity")

    authorization = request.authorization
    if not authorization.receipt_valid:
        return reject("authorization-receipt-invalid")
    if authorization.subject_id != request.subject_id:
        return reject("authorization-subject-mismatch")
    if authorization.effect_id != request.effect_id:
        return reject("authorization-effect-mismatch")
    if not authorization.authority_id:
        return reject("authorization-authority-missing")

    obligation_by_effect: dict[str, EffectObligation] = {}
    for obligation in request.declared_obligations:
        if not obligation.effect_id or obligation.effect_id in obligation_by_effect:
            return reject("effect-domain-invalid")
        obligation_by_effect[obligation.effect_id] = obligation

    observed_effects = set(request.observed_effect_ids)
    if len(observed_effects) != len(request.observed_effect_ids):
        return reject("effect-domain-invalid")
    if set(obligation_by_effect) != observed_effects:
        return reject("effect-domain-coverage-incomplete")
    obligation = obligation_by_effect.get(request.effect_id)
    if obligation is None:
        return reject("requested-effect-outside-domain")

    if request.outcome is EffectOutcome.DUPLICATE and not _has_valid_prior_commit(
        request
    ):
        return reject("duplicate-without-prior-commit")

    if request.outcome in {EffectOutcome.ROLLED_BACK, EffectOutcome.RECOVERED}:
        if any(
            item.reversibility is EffectReversibility.IRREVERSIBLE
            for item in obligation_by_effect.values()
        ):
            return reject("irreversible-effect-not-recoverable")
        if any(
            item.reversibility is EffectReversibility.COMPENSABLE
            and not _has_valid_compensation(request, item)
            for item in obligation_by_effect.values()
        ):
            return reject("compensation-evidence-missing")

    recovery = request.recovery
    if not recovery.receipt_valid:
        return reject("recovery-receipt-invalid")
    if recovery.transaction_id != request.transaction_id:
        return reject("recovery-transaction-mismatch")
    if not recovery.claimant_id or recovery.claimant_id != recovery.fence_owner_id:
        return reject("recovery-fence-not-exclusive")
    if recovery.phase not in TERMINAL_RECOVERY_PHASES:
        return reject("recovery-not-terminal")

    return ConstrainedEffectDecision(
        admitted=True,
        reason_kind="constrained-system-effect-admitted",
        request_id=request.request_id,
        transaction_id=request.transaction_id,
        effect_id=request.effect_id,
    )


def _authorization_only_countermodel(request: ConstrainedEffectRequest) -> bool:
    return request.authorization.receipt_valid
