# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed AC-08 evidence receipts and native mediation projections."""

from __future__ import annotations

import time
from dataclasses import dataclass

_DIGEST_BYTES = 32


class AuthorizedEffectEvidenceError(RuntimeError):
    """Evidence could not be accepted without violating its contract."""


@dataclass(frozen=True, slots=True)
class AuthorizedEffectEvidenceReceipt:
    session_id: str
    mediation_sequence: int
    first_sequence: int
    last_sequence: int
    nonce: tuple[int, int]
    semantic_root: bytes
    before_execution_root: bytes
    after_execution_root: bytes
    outcome: str
    observation_digest: bytes
    evidence_reference: str
    kernel_signature: bytes
    signature_verified: bool
    inclusion_proof_verified: bool
    created_at_ns: int

    @property
    def claim_level(self) -> str:
        if self._l3_verified():
            return "l3-verified"
        return (
            "l1-mediated"
            if self.outcome in {"buffered", "indeterminate"}
            else "l2-evidenced"
        )

    def _l3_verified(self) -> bool:
        return bool(
            self.outcome == "committed"
            and self.evidence_reference
            and self.kernel_signature
            and self.signature_verified
            and self.inclusion_proof_verified
        )


@dataclass(frozen=True, slots=True)
class AuthorizedEffectEvidenceReconciliation:
    semantic_root: bytes
    execution_root: bytes
    mediation_sequence: int
    runtime_sequence: int
    consumed_nonces: tuple[tuple[int, int], ...]
    staged_mediation_sequences: tuple[int, ...] = ()
    staged_leaf_digests: tuple[bytes, ...] = ()


@dataclass(frozen=True, slots=True)
class BatchedEvidenceCommitReceipt:
    session_id: str
    first_mediation_sequence: int
    last_mediation_sequence: int
    leaf_count: int
    before_execution_root: bytes
    batch_root: bytes
    after_execution_root: bytes
    evidence_digest: bytes
    attestation_digest: bytes
    verification_flags: int


@dataclass(frozen=True, slots=True)
class AuthorizedEffectEvidenceReservation:
    session_id: str
    mediation_sequence: int
    first_sequence: int
    last_sequence: int
    nonce: tuple[int, int]
    semantic_root: bytes
    before_execution_root: bytes


def authorized_effect_evidence_receipt(
    *,
    session_id: str,
    mediation_sequence: int,
    first_sequence: int,
    last_sequence: int,
    nonce: tuple[int, int],
    semantic_root: bytes,
    before_execution_root: bytes,
    after_execution_root: bytes,
    outcome: str,
    observation_digest: bytes,
    evidence_reference: str = "",
    kernel_signature: bytes = b"",
    signature_verified: bool = False,
    inclusion_proof_verified: bool = False,
) -> AuthorizedEffectEvidenceReceipt:
    receipt = AuthorizedEffectEvidenceReceipt(
        session_id, mediation_sequence, first_sequence, last_sequence,
        nonce, semantic_root,
        before_execution_root, after_execution_root, outcome,
        observation_digest, evidence_reference, kernel_signature,
        signature_verified, inclusion_proof_verified, time.time_ns(),
    )
    validate_authorized_effect_evidence_receipt(receipt)
    return receipt


def authorized_effect_evidence_from_native(
    *, session_id: str, mediation, result, evidence_reference: str = "",
    kernel_signature: bytes = b"", signature_verified: bool = False,
    inclusion_proof_verified: bool = False, first_sequence: int,
    last_sequence: int,
) -> AuthorizedEffectEvidenceReceipt:
    outcomes = {1: "committed", 2: "buffered", 4: "indeterminate"}
    try:
        outcome = outcomes[int(result.mediation_outcome)]
    except (KeyError, TypeError, ValueError) as exc:
        raise AuthorizedEffectEvidenceError(
            "native mediation returned an unknown outcome"
        ) from exc
    return authorized_effect_evidence_receipt(
        session_id=session_id, mediation_sequence=int(result.mediation_sequence),
        first_sequence=first_sequence, last_sequence=last_sequence,
        nonce=mediation.nonce, semantic_root=mediation.semantic_root,
        before_execution_root=mediation.before_execution_root,
        after_execution_root=result.execution_root, outcome=outcome,
        observation_digest=result.observation_digest,
        evidence_reference=evidence_reference, kernel_signature=kernel_signature,
        signature_verified=signature_verified,
        inclusion_proof_verified=inclusion_proof_verified,
    )


def validate_authorized_effect_evidence_receipt(
    receipt: AuthorizedEffectEvidenceReceipt,
) -> None:
    if (not receipt.session_id or receipt.mediation_sequence <= 0 or
            receipt.first_sequence <= 0 or
            receipt.first_sequence > receipt.last_sequence):
        raise AuthorizedEffectEvidenceError("invalid evidence session or sequence")
    if receipt.outcome not in {"committed", "buffered", "indeterminate"}:
        raise AuthorizedEffectEvidenceError("unsupported mediation outcome")
    digests = (
        receipt.semantic_root, receipt.before_execution_root,
        receipt.after_execution_root, receipt.observation_digest,
    )
    if any(len(value) != _DIGEST_BYTES for value in digests):
        raise AuthorizedEffectEvidenceError("evidence digest must be 32 bytes")
    if (receipt.outcome in {"buffered", "indeterminate"} and
            receipt.after_execution_root != receipt.before_execution_root):
        raise AuthorizedEffectEvidenceError(
            "non-committed evidence cannot advance execution root"
        )


def evidence_nonce_text(nonce: tuple[int, int]) -> str:
    high, low = nonce
    if not (0 <= high < 2**64 and 0 <= low < 2**64):
        raise AuthorizedEffectEvidenceError("nonce limbs must be uint64")
    return f"{high:016x}{low:016x}"


def parse_evidence_nonce(value: str) -> tuple[int, int]:
    return int(value[:16], 16), int(value[16:], 16)
