# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Bind the durable evidence journal to synchronous native callbacks."""

from __future__ import annotations

import hashlib

from .evidence_model import (
    AuthorizedEffectEvidenceError,
    AuthorizedEffectEvidenceReservation,
    authorized_effect_evidence_receipt,
)
from ._native.evidence import (
    NativeEvidenceCommit,
    NativeEvidenceFlushCommit,
    NativeEvidenceInvocation,
    NativeEvidenceReservation,
    NativeEvidenceSink,
)


def build_turso_native_evidence_sink(
    store,
    *,
    session_id: str,
    committed_execution_root: bytes,
    evidence_reference: str,
    kernel_signature: bytes,
    signature_verified: bool = False,
    inclusion_proof_verified: bool = False,
) -> NativeEvidenceSink:
    def reserve(value: NativeEvidenceReservation) -> None:
        store.reserve(AuthorizedEffectEvidenceReservation(
            session_id, value.mediation_sequence, value.first_sequence,
            value.last_sequence, value.nonce, value.semantic_root,
            value.before_execution_root,
        ))

    def commit(invocation: NativeEvidenceInvocation) -> NativeEvidenceCommit:
        outcomes = {1: "committed", 2: "buffered", 4: "indeterminate"}
        outcome = outcomes.get(invocation.outcome, "indeterminate")
        after_root = (
            committed_execution_root
            if outcome == "committed" else invocation.before_execution_root
        )
        receipt = authorized_effect_evidence_receipt(
            session_id=session_id,
            mediation_sequence=invocation.mediation_sequence,
            first_sequence=invocation.first_sequence,
            last_sequence=invocation.last_sequence,
            nonce=invocation.nonce,
            semantic_root=invocation.semantic_root,
            before_execution_root=invocation.before_execution_root,
            after_execution_root=after_root,
            outcome=outcome,
            observation_digest=invocation.observation_digest,
            evidence_reference=evidence_reference,
            kernel_signature=kernel_signature,
            signature_verified=signature_verified,
            inclusion_proof_verified=inclusion_proof_verified,
        )
        evidence_digest = (
            store.stage_batched(receipt, invocation.input_digest)
            if outcome == "buffered" else store.append_and_digest(receipt)
        )
        flags = int(signature_verified) | (int(inclusion_proof_verified) << 1)
        attestation = (
            hashlib.sha256(kernel_signature).digest()
            if kernel_signature else bytes(32)
        )
        return NativeEvidenceCommit(after_root, evidence_digest, attestation, flags)

    def flush(invocation) -> NativeEvidenceFlushCommit:
        batch = store.flush_batched(
            session_id, invocation.leaf_digests,
            kernel_signature=kernel_signature,
            verification_flags=(
                int(signature_verified) | (int(inclusion_proof_verified) << 1)
            ),
        )
        if batch.before_execution_root != invocation.before_execution_root:
            raise AuthorizedEffectEvidenceError(
                "native flush forks durable execution root"
            )
        return NativeEvidenceFlushCommit(
            batch.after_execution_root, batch.batch_root, batch.evidence_digest,
            batch.attestation_digest, batch.verification_flags,
        )

    return NativeEvidenceSink(reserve, commit, flush)
