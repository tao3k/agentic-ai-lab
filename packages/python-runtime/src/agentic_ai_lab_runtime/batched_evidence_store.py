# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Durable Batched evidence staging, flush, and recovery transactions."""

from __future__ import annotations

import hashlib
from typing import Any

from .batched_evidence import batched_evidence_leaf, batched_merkle_root_digests
from .evidence_model import (
    AuthorizedEffectEvidenceError,
    AuthorizedEffectEvidenceReceipt,
    BatchedEvidenceCommitReceipt,
    evidence_nonce_text,
    validate_authorized_effect_evidence_receipt,
)

_ZERO_ROOT = bytes(32)
_BATCH_ROOT_DOMAIN = b"agentic-ai-lab.batched-execution-root.draft.1|"


def create_batched_evidence_schema(connection: Any) -> None:
    connection.execute(
        "create table if not exists authorized_effect_batched_leaves ("
        "session_id text not null, mediation_sequence integer not null, "
        "leaf_index integer not null, input_digest blob not null, "
        "leaf_digest blob not null, state text not null, batch_id integer, "
        "primary key (session_id, mediation_sequence))"
    )
    connection.execute(
        "create table if not exists authorized_effect_evidence_batches ("
        "session_id text not null, batch_id integer not null, "
        "first_mediation_sequence integer not null, "
        "last_mediation_sequence integer not null, leaf_count integer not null, "
        "before_root blob not null, batch_root blob not null, "
        "after_root blob not null, evidence_digest blob not null, "
        "attestation_digest blob not null, verification_flags integer not null, "
        "primary key (session_id, batch_id))"
    )
    connection.execute(
        "create index if not exists authorized_effect_batched_staged_lookup "
        "on authorized_effect_batched_leaves(session_id, state, leaf_index)"
    )


def stage_batched_evidence(
    store: Any, receipt: AuthorizedEffectEvidenceReceipt, input_digest: bytes
) -> bytes:
    validate_authorized_effect_evidence_receipt(receipt)
    if receipt.outcome != "buffered" or len(input_digest) != 32:
        raise AuthorizedEffectEvidenceError("invalid Batched evidence leaf")
    try:
        store._conn.execute("begin immediate")
        store._assert_reserved(receipt)
        expected_root = _head_root(store, receipt.session_id)
        if receipt.before_execution_root != expected_root:
            raise AuthorizedEffectEvidenceError(
                "Batched leaf forks durable evidence head"
            )
        leaf_index = _staged_count(store._conn, receipt.session_id)
        leaf = batched_evidence_leaf(
            f"{receipt.session_id}:{receipt.mediation_sequence}",
            leaf_index,
            evidence_nonce_text(receipt.nonce),
            receipt.first_sequence,
            receipt.last_sequence,
            input_digest.hex(),
            receipt.semantic_root.hex(),
            receipt.before_execution_root.hex(),
            receipt.observation_digest.hex(),
            receipt.outcome,
        )
        leaf_digest = bytes.fromhex(leaf.digest)
        store._insert_receipt(receipt)
        store._conn.execute(
            "insert into authorized_effect_batched_leaves values "
            "(?, ?, ?, ?, ?, 'staged', null)",
            (receipt.session_id, receipt.mediation_sequence, leaf_index,
             input_digest, leaf_digest),
        )
        store._conn.execute(
            "update authorized_effect_reservations set state = 'staged' "
            "where session_id = ? and mediation_sequence = ?",
            (receipt.session_id, receipt.mediation_sequence),
        )
        store._conn.commit()
        return leaf_digest
    except AuthorizedEffectEvidenceError:
        store._conn.rollback()
        raise
    except Exception as exc:
        store._conn.rollback()
        raise AuthorizedEffectEvidenceError(
            "durable Batched evidence staging failed"
        ) from exc


def flush_batched_evidence(
    store: Any,
    session_id: str,
    leaf_digests: tuple[bytes, ...],
    *,
    kernel_signature: bytes = b"",
    verification_flags: int = 0,
) -> BatchedEvidenceCommitReceipt:
    try:
        store._conn.execute("begin immediate")
        rows = _staged_rows(store._conn, session_id)
        durable_digests = tuple(bytes(row[1]) for row in rows)
        if not rows or durable_digests != leaf_digests:
            raise AuthorizedEffectEvidenceError(
                "flush leaf range does not match durable staged leaves"
            )
        before_root = _head_root(store, session_id)
        batch_root = batched_merkle_root_digests(durable_digests)
        after_root = _batch_execution_root(before_root, batch_root)
        first_sequence, last_sequence = int(rows[0][0]), int(rows[-1][0])
        batch_id = _next_batch_id(store._conn, session_id)
        evidence_digest = _batch_evidence_digest(
            session_id, batch_id, before_root, batch_root, after_root
        )
        attestation_digest = (
            hashlib.sha256(kernel_signature).digest()
            if kernel_signature else _ZERO_ROOT
        )
        _commit_batch(
            store._conn, session_id, batch_id, first_sequence, last_sequence,
            len(rows), before_root, batch_root, after_root, evidence_digest,
            attestation_digest, verification_flags,
        )
        store._conn.commit()
        return BatchedEvidenceCommitReceipt(
            session_id, first_sequence, last_sequence, len(rows), before_root,
            batch_root, after_root, evidence_digest, attestation_digest,
            verification_flags,
        )
    except AuthorizedEffectEvidenceError:
        store._conn.rollback()
        raise
    except Exception as exc:
        store._conn.rollback()
        raise AuthorizedEffectEvidenceError(
            "durable Batched evidence flush failed"
        ) from exc


def staged_reconciliation(
    connection: Any, session_id: str
) -> tuple[tuple[int, ...], tuple[bytes, ...]]:
    rows = _staged_rows(connection, session_id)
    return (
        tuple(int(row[0]) for row in rows),
        tuple(bytes(row[1]) for row in rows),
    )


def _head_root(store: Any, session_id: str) -> bytes:
    head = store._load_head(session_id)
    return _ZERO_ROOT if head is None else bytes(head[1])


def _staged_count(connection: Any, session_id: str) -> int:
    row = connection.execute(
        "select count(*) from authorized_effect_batched_leaves "
        "where session_id = ? and state = 'staged'", (session_id,),
    ).fetchone()
    return int(row[0])


def _staged_rows(connection: Any, session_id: str):
    return connection.execute(
        "select mediation_sequence, leaf_digest from "
        "authorized_effect_batched_leaves where session_id = ? "
        "and state = 'staged' order by leaf_index", (session_id,),
    ).fetchall()


def _next_batch_id(connection: Any, session_id: str) -> int:
    row = connection.execute(
        "select max(batch_id) from authorized_effect_evidence_batches "
        "where session_id = ?", (session_id,),
    ).fetchone()
    return 1 if row[0] is None else int(row[0]) + 1


def _batch_evidence_digest(
    session_id: str, batch_id: int, before: bytes, root: bytes, after: bytes
) -> bytes:
    return hashlib.sha256(
        b"|".join((session_id.encode(), str(batch_id).encode(), before, root, after))
    ).digest()


def _commit_batch(
    connection: Any, session_id: str, batch_id: int, first: int, last: int,
    count: int, before: bytes, root: bytes, after: bytes, evidence: bytes,
    attestation: bytes, flags: int,
) -> None:
    connection.execute(
        "insert into authorized_effect_evidence_batches values "
        "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (session_id, batch_id, first, last, count, before, root, after,
         evidence, attestation, flags),
    )
    connection.execute(
        "update authorized_effect_batched_leaves set state = 'flushed', "
        "batch_id = ? where session_id = ? and state = 'staged'",
        (batch_id, session_id),
    )
    connection.execute(
        "update authorized_effect_reservations set state = 'finalized' "
        "where session_id = ? and state = 'staged'", (session_id,),
    )
    connection.execute(
        "insert or replace into authorized_effect_evidence_heads "
        "(session_id, mediation_sequence, execution_root) values (?, ?, ?)",
        (session_id, last, after),
    )


def _batch_execution_root(before_root: bytes, batch_root: bytes) -> bytes:
    def frame(value: bytes) -> bytes:
        text = value.hex().encode()
        return str(len(text)).encode() + b":" + text

    return hashlib.sha256(
        _BATCH_ROOT_DOMAIN + frame(before_root) + frame(batch_root)
    ).digest()
