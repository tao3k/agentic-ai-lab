# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Turso-backed append-only AC-08 evidence root journal."""

from __future__ import annotations

import hashlib
from pathlib import Path

from .durable_turso_backend import connect_turso_runtime_graph
from .evidence_model import (
    AuthorizedEffectEvidenceError,
    AuthorizedEffectEvidenceReconciliation,
    AuthorizedEffectEvidenceReservation,
    AuthorizedEffectEvidenceReceipt,
    BatchedEvidenceCommitReceipt,
    evidence_nonce_text,
    parse_evidence_nonce,
    authorized_effect_evidence_receipt,
    validate_authorized_effect_evidence_receipt,
)
from .batched_evidence_store import (
    create_batched_evidence_schema,
    flush_batched_evidence,
    stage_batched_evidence,
    staged_reconciliation,
)

_ZERO_ROOT = bytes(32)


class TursoAuthorizedEffectEvidenceStore:
    """Append-only per-session evidence roots owned by the runtime boundary."""

    def __init__(self, database: str | Path = ":memory:") -> None:
        self._conn = connect_turso_runtime_graph(database)
        self._create_schema()

    def _create_schema(self) -> None:
        self._conn.execute(
            "create table if not exists authorized_effect_evidence ("
            "session_id text not null, mediation_sequence integer not null, "
            "first_sequence integer not null, last_sequence integer not null, "
            "nonce text not null, semantic_root blob not null, "
            "before_root blob not null, after_root blob not null, "
            "outcome text not null, observation_digest blob not null, "
            "evidence_reference text not null, kernel_signature blob not null, "
            "signature_verified integer not null, "
            "inclusion_proof_verified integer not null, "
            "created_at_ns integer not null, "
            "primary key (session_id, mediation_sequence), "
            "unique (session_id, nonce))"
        )
        self._conn.execute(
            "create table if not exists authorized_effect_reservations ("
            "session_id text not null, mediation_sequence integer not null, "
            "first_sequence integer not null, last_sequence integer not null, "
            "nonce text not null, semantic_root blob not null, "
            "before_root blob not null, state text not null, "
            "primary key (session_id, mediation_sequence), "
            "unique (session_id, nonce))"
        )
        self._conn.execute(
            "create table if not exists authorized_effect_evidence_heads ("
            "session_id text primary key, mediation_sequence integer not null, "
            "execution_root blob not null)"
        )
        self._conn.execute(
            "create index if not exists authorized_effect_reservation_state "
            "on authorized_effect_reservations(session_id, state)"
        )
        create_batched_evidence_schema(self._conn)
        self._conn.commit()

    def stage_batched(
        self, receipt: AuthorizedEffectEvidenceReceipt, input_digest: bytes
    ) -> bytes:
        return stage_batched_evidence(self, receipt, input_digest)

    def flush_batched(
        self,
        session_id: str,
        leaf_digests: tuple[bytes, ...],
        *,
        kernel_signature: bytes = b"",
        verification_flags: int = 0,
    ) -> BatchedEvidenceCommitReceipt:
        return flush_batched_evidence(
            self, session_id, leaf_digests,
            kernel_signature=kernel_signature,
            verification_flags=verification_flags,
        )

    def reserve(self, reservation: AuthorizedEffectEvidenceReservation) -> None:
        _validate_reservation(reservation)
        try:
            self._conn.execute("begin immediate")
            existing = self._reservation(
                reservation.session_id, reservation.mediation_sequence
            )
            if existing is not None:
                if not _reservation_matches(reservation, existing):
                    raise AuthorizedEffectEvidenceError(
                        "durable reservation binding mismatch"
                    )
                self._conn.commit()
                return
            unresolved = self._conn.execute(
                "select 1 from authorized_effect_reservations "
                "where session_id = ? and state = 'reserved'",
                (reservation.session_id,),
            ).fetchone()
            if unresolved is not None:
                raise AuthorizedEffectEvidenceError(
                    "unresolved durable reservation blocks new effect"
                )
            expected = self._next_reservation_sequence(reservation.session_id)
            if reservation.mediation_sequence != expected:
                raise AuthorizedEffectEvidenceError(
                    "reservation does not extend mediation sequence"
                )
            head = self._load_head(reservation.session_id)
            expected_root = _ZERO_ROOT if head is None else bytes(head[1])
            if reservation.before_execution_root != expected_root:
                raise AuthorizedEffectEvidenceError(
                    "reservation forks durable execution root"
                )
            self._conn.execute(
                "insert into authorized_effect_reservations values "
                "(?, ?, ?, ?, ?, ?, ?, 'reserved')",
                (
                    reservation.session_id, reservation.mediation_sequence,
                    reservation.first_sequence, reservation.last_sequence,
                    evidence_nonce_text(reservation.nonce),
                    reservation.semantic_root, reservation.before_execution_root,
                ),
            )
            self._conn.commit()
        except AuthorizedEffectEvidenceError:
            self._conn.rollback()
            raise
        except Exception as exc:
            self._conn.rollback()
            raise AuthorizedEffectEvidenceError(
                "durable evidence reservation failed"
            ) from exc

    def append(self, receipt: AuthorizedEffectEvidenceReceipt) -> None:
        validate_authorized_effect_evidence_receipt(receipt)
        try:
            self._conn.execute("begin immediate")
            self._assert_reserved(receipt)
            self._assert_extends(receipt, self._load_head(receipt.session_id))
            self._insert_receipt(receipt)
            self._conn.execute(
                "update authorized_effect_reservations set state = 'finalized' "
                "where session_id = ? and mediation_sequence = ?",
                (receipt.session_id, receipt.mediation_sequence),
            )
            self._advance_head(receipt)
            self._conn.commit()
        except AuthorizedEffectEvidenceError:
            self._conn.rollback()
            raise
        except Exception as exc:
            self._conn.rollback()
            raise AuthorizedEffectEvidenceError(
                "durable evidence append failed"
            ) from exc

    def _load_head(self, session_id: str):
        return self._conn.execute(
            "select mediation_sequence, execution_root "
            "from authorized_effect_evidence_heads where session_id = ?",
            (session_id,),
        ).fetchone()

    def _reservation(self, session_id: str, sequence: int):
        return self._conn.execute(
            "select first_sequence, last_sequence, nonce, semantic_root, "
            "before_root, state from authorized_effect_reservations "
            "where session_id = ? and mediation_sequence = ?",
            (session_id, sequence),
        ).fetchone()

    def _next_reservation_sequence(self, session_id: str) -> int:
        row = self._conn.execute(
            "select max(mediation_sequence) from authorized_effect_reservations "
            "where session_id = ?",
            (session_id,),
        ).fetchone()
        return 1 if row is None or row[0] is None else int(row[0]) + 1

    def _assert_reserved(self, receipt: AuthorizedEffectEvidenceReceipt) -> None:
        row = self._reservation(receipt.session_id, receipt.mediation_sequence)
        if row is None or row[5] != "reserved" or not _reservation_matches(
            AuthorizedEffectEvidenceReservation(
                receipt.session_id, receipt.mediation_sequence,
                receipt.first_sequence, receipt.last_sequence, receipt.nonce,
                receipt.semantic_root, receipt.before_execution_root,
            ),
            row,
        ):
            raise AuthorizedEffectEvidenceError(
                "evidence finalize requires matching durable reservation"
            )

    @staticmethod
    def _assert_extends(receipt: AuthorizedEffectEvidenceReceipt, head) -> None:
        expected_sequence = 1 if head is None else int(head[0]) + 1
        expected_root = _ZERO_ROOT if head is None else bytes(head[1])
        if receipt.mediation_sequence != expected_sequence:
            raise AuthorizedEffectEvidenceError(
                "mediation sequence does not extend durable evidence head"
            )
        if receipt.before_execution_root != expected_root:
            raise AuthorizedEffectEvidenceError(
                "before execution root forks durable evidence head"
            )

    def _insert_receipt(self, receipt: AuthorizedEffectEvidenceReceipt) -> None:
        self._conn.execute(
            "insert into authorized_effect_evidence values "
            "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                receipt.session_id, receipt.mediation_sequence,
                receipt.first_sequence, receipt.last_sequence,
                evidence_nonce_text(receipt.nonce), receipt.semantic_root,
                receipt.before_execution_root, receipt.after_execution_root,
                receipt.outcome, receipt.observation_digest,
                receipt.evidence_reference, receipt.kernel_signature,
                int(receipt.signature_verified),
                int(receipt.inclusion_proof_verified), receipt.created_at_ns,
            ),
        )

    def _advance_head(self, receipt: AuthorizedEffectEvidenceReceipt) -> None:
        self._conn.execute(
            "insert or replace into authorized_effect_evidence_heads "
            "(session_id, mediation_sequence, execution_root) values (?, ?, ?)",
            (receipt.session_id, receipt.mediation_sequence,
             receipt.after_execution_root),
        )

    def head(self, session_id: str) -> AuthorizedEffectEvidenceReceipt | None:
        row = self._conn.execute(
            "select mediation_sequence, first_sequence, last_sequence, "
            "nonce, semantic_root, before_root, "
            "after_root, outcome, observation_digest, evidence_reference, "
            "kernel_signature, signature_verified, inclusion_proof_verified, "
            "created_at_ns from authorized_effect_evidence "
            "where session_id = ? order by mediation_sequence desc limit 1",
            (session_id,),
        ).fetchone()
        return None if row is None else _receipt_from_row(session_id, row)

    def history(self, session_id: str) -> tuple[AuthorizedEffectEvidenceReceipt, ...]:
        rows = self._conn.execute(
            "select mediation_sequence, first_sequence, last_sequence, "
            "nonce, semantic_root, before_root, after_root, outcome, "
            "observation_digest, evidence_reference, kernel_signature, "
            "signature_verified, inclusion_proof_verified, created_at_ns "
            "from authorized_effect_evidence where session_id = ? "
            "order by mediation_sequence",
            (session_id,),
        ).fetchall()
        return tuple(_receipt_from_row(session_id, row) for row in rows)

    def reconciliation(
        self, session_id: str
    ) -> AuthorizedEffectEvidenceReconciliation | None:
        reservations = self._conn.execute(
            "select mediation_sequence, first_sequence, last_sequence, nonce, "
            "semantic_root, before_root, state from authorized_effect_reservations "
            "where session_id = ? order by mediation_sequence",
            (session_id,),
        ).fetchall()
        if not reservations:
            return None
        semantic_root = bytes(reservations[0][4])
        if any(bytes(item[4]) != semantic_root for item in reservations):
            raise AuthorizedEffectEvidenceError(
                "durable evidence history changes semantic root"
            )
        head = self._load_head(session_id)
        execution_root = _ZERO_ROOT if head is None else bytes(head[1])
        staged_sequences, staged_digests = staged_reconciliation(
            self._conn, session_id
        )
        return AuthorizedEffectEvidenceReconciliation(
            semantic_root=semantic_root,
            execution_root=execution_root,
            mediation_sequence=int(reservations[-1][0]),
            runtime_sequence=int(reservations[-1][2]),
            consumed_nonces=tuple(
                parse_evidence_nonce(item[3]) for item in reservations
            ),
            staged_mediation_sequences=staged_sequences,
            staged_leaf_digests=staged_digests,
        )

    def close(self) -> None:
        self._conn.close()

    def native_sink(
        self,
        *,
        session_id: str,
        committed_execution_root: bytes,
        evidence_reference: str,
        kernel_signature: bytes,
        signature_verified: bool = False,
        inclusion_proof_verified: bool = False,
    ):
        from .native_evidence_sink import build_turso_native_evidence_sink

        return build_turso_native_evidence_sink(
            self,
            session_id=session_id,
            committed_execution_root=committed_execution_root,
            evidence_reference=evidence_reference,
            kernel_signature=kernel_signature,
            signature_verified=signature_verified,
            inclusion_proof_verified=inclusion_proof_verified,
        )

    def append_and_digest(self, receipt: AuthorizedEffectEvidenceReceipt) -> bytes:
        self.append(receipt)
        return _evidence_digest(receipt)


def _receipt_from_row(session_id: str, row) -> AuthorizedEffectEvidenceReceipt:
    return AuthorizedEffectEvidenceReceipt(
        session_id=session_id, mediation_sequence=int(row[0]),
        first_sequence=int(row[1]), last_sequence=int(row[2]),
        nonce=parse_evidence_nonce(row[3]), semantic_root=bytes(row[4]),
        before_execution_root=bytes(row[5]), after_execution_root=bytes(row[6]),
        outcome=str(row[7]), observation_digest=bytes(row[8]),
        evidence_reference=str(row[9]), kernel_signature=bytes(row[10]),
        signature_verified=bool(row[11]), inclusion_proof_verified=bool(row[12]),
        created_at_ns=int(row[13]),
    )


def _evidence_digest(receipt: AuthorizedEffectEvidenceReceipt) -> bytes:
    return hashlib.sha256(
        b"|".join(
            (
                receipt.session_id.encode(),
                str(receipt.mediation_sequence).encode(),
                str(receipt.first_sequence).encode(),
                str(receipt.last_sequence).encode(),
                evidence_nonce_text(receipt.nonce).encode(),
                receipt.semantic_root,
                receipt.before_execution_root,
                receipt.after_execution_root,
                receipt.outcome.encode(),
                receipt.observation_digest,
                receipt.evidence_reference.encode(),
            )
        )
    ).digest()


def _validate_reservation(reservation: AuthorizedEffectEvidenceReservation) -> None:
    if (not reservation.session_id or reservation.mediation_sequence <= 0 or
            reservation.first_sequence <= 0 or
            reservation.first_sequence > reservation.last_sequence or
            len(reservation.semantic_root) != 32 or
            len(reservation.before_execution_root) != 32):
        raise AuthorizedEffectEvidenceError("invalid evidence reservation")
    evidence_nonce_text(reservation.nonce)


def _reservation_matches(
    reservation: AuthorizedEffectEvidenceReservation, row
) -> bool:
    return (
        reservation.first_sequence == int(row[0])
        and reservation.last_sequence == int(row[1])
        and evidence_nonce_text(reservation.nonce) == row[2]
        and reservation.semantic_root == bytes(row[3])
        and reservation.before_execution_root == bytes(row[4])
    )
