# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from types import SimpleNamespace

import pytest

from agentic_ai_lab_runtime import (
    AuthorizedEffectEvidenceError,
    AuthorizedEffectEvidenceReservation,
    TursoAuthorizedEffectEvidenceStore,
    authorized_effect_evidence_from_native,
    authorized_effect_evidence_receipt,
)


def _receipt(sequence: int, before: bytes, after: bytes, **overrides):
    fields = {
        "session_id": "session-1",
        "mediation_sequence": sequence,
        "first_sequence": sequence,
        "last_sequence": sequence,
        "nonce": (0, sequence),
        "semantic_root": bytes.fromhex("55" * 32),
        "before_execution_root": before,
        "after_execution_root": after,
        "outcome": "committed",
        "observation_digest": bytes.fromhex("66" * 32),
        "evidence_reference": f"evidence-{sequence}",
        "kernel_signature": b"kernel-signature",
        "signature_verified": True,
        "inclusion_proof_verified": True,
    }
    fields.update(overrides)
    return authorized_effect_evidence_receipt(**fields)


def _finalize(store, receipt) -> None:
    store.reserve(
        AuthorizedEffectEvidenceReservation(
            receipt.session_id,
            receipt.mediation_sequence,
            receipt.first_sequence,
            receipt.last_sequence,
            receipt.nonce,
            receipt.semantic_root,
            receipt.before_execution_root,
        )
    )
    store.append(receipt)


def test_evidence_journal_persists_linear_root_chain(tmp_path) -> None:
    database = tmp_path / "evidence.db"
    first_root = bytes.fromhex("aa" * 32)
    second_root = bytes.fromhex("bb" * 32)
    store = TursoAuthorizedEffectEvidenceStore(database)
    _finalize(store, _receipt(1, bytes(32), first_root))
    _finalize(store, _receipt(2, first_root, second_root))
    assert store.head("session-1").claim_level == "l3-verified"
    store.reserve(
        AuthorizedEffectEvidenceReservation(
            "session-1", 3, 3, 3, (0, 3),
            bytes.fromhex("55" * 32), second_root,
        )
    )
    store.close()

    reopened = TursoAuthorizedEffectEvidenceStore(database)
    head = reopened.head("session-1")
    assert head is not None
    assert head.mediation_sequence == 2
    assert head.after_execution_root == second_root
    reconciliation = reopened.reconciliation("session-1")
    assert reconciliation is not None
    assert reconciliation.mediation_sequence == 3
    assert reconciliation.runtime_sequence == 3
    assert reconciliation.execution_root == second_root
    assert reconciliation.consumed_nonces == ((0, 1), (0, 2), (0, 3))
    reopened.close()


def test_native_result_projects_without_recomputing_runtime_roots() -> None:
    semantic_root = bytes.fromhex("55" * 32)
    before_root = bytes(32)
    after_root = bytes.fromhex("aa" * 32)
    observation = bytes.fromhex("66" * 32)
    mediation = SimpleNamespace(
        nonce=(7, 9),
        semantic_root=semantic_root,
        before_execution_root=before_root,
    )
    result = SimpleNamespace(
        mediation_outcome=1,
        mediation_sequence=1,
        execution_root=after_root,
        observation_digest=observation,
    )
    receipt = authorized_effect_evidence_from_native(
        session_id="session-native",
        mediation=mediation,
        result=result,
        evidence_reference="native-row-1",
        kernel_signature=b"kernel-signature",
        signature_verified=True,
        inclusion_proof_verified=True,
        first_sequence=1,
        last_sequence=1,
    )
    assert receipt.after_execution_root is after_root
    assert receipt.observation_digest is observation
    assert receipt.claim_level == "l3-verified"
    assert _receipt(
        1, bytes(32), after_root, signature_verified=False
    ).claim_level == "l2-evidenced"

def test_evidence_journal_rejects_replay_fork_and_unknown_root_advance() -> None:
    store = TursoAuthorizedEffectEvidenceStore()
    first_root = bytes.fromhex("aa" * 32)
    _finalize(store, _receipt(1, bytes(32), first_root))
    with pytest.raises(AuthorizedEffectEvidenceError):
        _finalize(store, _receipt(1, bytes(32), first_root))
    with pytest.raises(AuthorizedEffectEvidenceError):
        _finalize(store,
            _receipt(
                2,
                first_root,
                bytes.fromhex("cc" * 32),
                outcome="indeterminate",
            )
        )
    with pytest.raises(AuthorizedEffectEvidenceError):
        _finalize(store, _receipt(2, bytes(32), bytes.fromhex("bb" * 32)))
    recovery = store.reconciliation("session-1")
    assert recovery is not None
    assert recovery.execution_root == first_root
    assert recovery.consumed_nonces == ((0, 1),)
    store.close()

    store = TursoAuthorizedEffectEvidenceStore()
    _finalize(store, _receipt(1, bytes(32), first_root))
    unknown = _receipt(
        2,
        first_root,
        first_root,
        outcome="indeterminate",
        evidence_reference="unknown-effect",
        kernel_signature=b"kernel-signature",
    )
    _finalize(store, unknown)
    assert store.head("session-1").claim_level == "l1-mediated"
    store.close()


def test_batched_leaves_survive_restart_and_flush_atomically(tmp_path) -> None:
    database = tmp_path / "batched-evidence.db"
    store = TursoAuthorizedEffectEvidenceStore(database)
    leaves = []
    for sequence in (1, 2):
        receipt = _receipt(
            sequence,
            bytes(32),
            bytes(32),
            outcome="buffered",
            nonce=(0, sequence),
        )
        store.reserve(
            AuthorizedEffectEvidenceReservation(
                receipt.session_id,
                receipt.mediation_sequence,
                receipt.first_sequence,
                receipt.last_sequence,
                receipt.nonce,
                receipt.semantic_root,
                receipt.before_execution_root,
            )
        )
        leaves.append(store.stage_batched(receipt, bytes([sequence]) * 32))
    assert store.head("session-1").claim_level == "l1-mediated"
    store.close()

    reopened = TursoAuthorizedEffectEvidenceStore(database)
    recovery = reopened.reconciliation("session-1")
    assert recovery is not None
    assert recovery.execution_root == bytes(32)
    assert recovery.staged_mediation_sequences == (1, 2)
    assert recovery.staged_leaf_digests == tuple(leaves)
    with pytest.raises(AuthorizedEffectEvidenceError):
        reopened.flush_batched("session-1", (leaves[1], leaves[0]))
    assert reopened.reconciliation("session-1").staged_leaf_digests == tuple(leaves)

    batch = reopened.flush_batched("session-1", tuple(leaves))
    assert batch.first_mediation_sequence == 1
    assert batch.last_mediation_sequence == 2
    assert batch.leaf_count == 2
    assert batch.before_execution_root == bytes(32)
    assert batch.after_execution_root != bytes(32)
    recovery = reopened.reconciliation("session-1")
    assert recovery is not None
    assert recovery.execution_root == batch.after_execution_root
    assert recovery.staged_mediation_sequences == ()
    assert recovery.staged_leaf_digests == ()
    reopened.close()
