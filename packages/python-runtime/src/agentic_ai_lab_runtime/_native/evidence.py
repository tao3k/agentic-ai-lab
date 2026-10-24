# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native evidence callback types and CFFI projection."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable


@dataclass(frozen=True, slots=True)
class NativeEvidenceInvocation:
    outcome: int
    adapter_status: int
    mediation_sequence: int
    first_sequence: int
    last_sequence: int
    nonce: tuple[int, int]
    semantic_root: bytes
    before_execution_root: bytes
    input_digest: bytes
    observation_digest: bytes


@dataclass(frozen=True, slots=True)
class NativeEvidenceReservation:
    mediation_sequence: int
    first_sequence: int
    last_sequence: int
    nonce: tuple[int, int]
    semantic_root: bytes
    before_execution_root: bytes


@dataclass(frozen=True, slots=True)
class NativeEvidenceCommit:
    after_execution_root: bytes
    evidence_digest: bytes
    attestation_digest: bytes
    verification_flags: int = 0

    def __post_init__(self) -> None:
        for name in (
            "after_execution_root", "evidence_digest", "attestation_digest"
        ):
            if len(getattr(self, name)) != 32:
                raise ValueError(f"native evidence {name} must be exactly 32 bytes")


@dataclass(frozen=True, slots=True)
class NativeEvidenceFlushInvocation:
    first_mediation_sequence: int
    last_mediation_sequence: int
    leaf_digests: tuple[bytes, ...]
    before_execution_root: bytes


@dataclass(frozen=True, slots=True)
class NativeEvidenceFlushCommit:
    after_execution_root: bytes
    batch_root: bytes
    evidence_digest: bytes
    attestation_digest: bytes
    verification_flags: int = 0

    def __post_init__(self) -> None:
        for name in (
            "after_execution_root", "batch_root", "evidence_digest",
            "attestation_digest",
        ):
            if len(getattr(self, name)) != 32:
                raise ValueError(f"native evidence {name} must be exactly 32 bytes")


NativeEvidenceCommitter = Callable[[NativeEvidenceInvocation], NativeEvidenceCommit]
NativeEvidenceReserver = Callable[[NativeEvidenceReservation], None]
NativeEvidenceFlusher = Callable[
    [NativeEvidenceFlushInvocation], NativeEvidenceFlushCommit
]


@dataclass(frozen=True, slots=True)
class NativeEvidenceSink:
    reserve: NativeEvidenceReserver
    finalize: NativeEvidenceCommitter
    flush: NativeEvidenceFlusher | None = None


def build_native_evidence_callbacks(ffi: Any, sink: NativeEvidenceSink):
    @ffi.callback(
        "uint32_t(void *, "
        "const agentic_ai_lab_python_runtime_v0_evidence_reservation *)"
    )
    def reserve(_context: Any, value: Any) -> int:
        try:
            sink.reserve(
                NativeEvidenceReservation(
                    int(value.mediation_sequence), int(value.first_sequence),
                    int(value.last_sequence),
                    (int(value.nonce_high), int(value.nonce_low)),
                    bytes(ffi.buffer(value.semantic_root, 32)),
                    bytes(ffi.buffer(value.before_execution_root, 32)),
                )
            )
            return 0
        except Exception:
            return 16

    @ffi.callback(
        "uint32_t(void *, "
        "const agentic_ai_lab_python_runtime_v0_evidence_invocation *, "
        "agentic_ai_lab_python_runtime_v0_evidence_result *)"
    )
    def callback(_context: Any, invocation: Any, target: Any) -> int:
        try:
            projected = _project_invocation(ffi, invocation)
            _write_commit(ffi, target, sink.finalize(projected))
            return 0
        except Exception:
            return 16

    @ffi.callback(
        "uint32_t(void *, "
        "const agentic_ai_lab_python_runtime_v0_evidence_flush_invocation *, "
        "agentic_ai_lab_python_runtime_v0_evidence_flush_result *)"
    )
    def flush(_context: Any, invocation: Any, target: Any) -> int:
        if sink.flush is None:
            return 16
        try:
            digests = tuple(
                bytes(ffi.buffer(invocation.leaf_digests + index * 32, 32))
                for index in range(int(invocation.leaf_count))
            )
            committed = sink.flush(
                NativeEvidenceFlushInvocation(
                    int(invocation.first_mediation_sequence),
                    int(invocation.last_mediation_sequence), digests,
                    bytes(ffi.buffer(invocation.before_execution_root, 32)),
                )
            )
            _write_flush_commit(ffi, target, committed)
            return 0
        except Exception:
            return 16

    return reserve, callback, flush if sink.flush is not None else ffi.NULL


def _project_invocation(ffi: Any, value: Any) -> NativeEvidenceInvocation:
    return NativeEvidenceInvocation(
        int(value.outcome), int(value.adapter_status),
        int(value.mediation_sequence), int(value.first_sequence),
        int(value.last_sequence), (int(value.nonce_high), int(value.nonce_low)),
        bytes(ffi.buffer(value.semantic_root, 32)),
        bytes(ffi.buffer(value.before_execution_root, 32)),
        bytes(ffi.buffer(value.input_digest, 32)),
        bytes(ffi.buffer(value.observation_digest, 32)),
    )


def _write_commit(ffi: Any, target: Any, commit: NativeEvidenceCommit) -> None:
    target.verification_flags = commit.verification_flags
    ffi.memmove(target.after_execution_root, commit.after_execution_root, 32)
    ffi.memmove(target.evidence_digest, commit.evidence_digest, 32)
    ffi.memmove(target.attestation_digest, commit.attestation_digest, 32)


def _write_flush_commit(
    ffi: Any, target: Any, commit: NativeEvidenceFlushCommit
) -> None:
    target.verification_flags = commit.verification_flags
    ffi.memmove(target.after_execution_root, commit.after_execution_root, 32)
    ffi.memmove(target.batch_root, commit.batch_root, 32)
    ffi.memmove(target.evidence_digest, commit.evidence_digest, 32)
    ffi.memmove(target.attestation_digest, commit.attestation_digest, 32)


__all__ = (
    "NativeEvidenceCommit",
    "NativeEvidenceCommitter",
    "NativeEvidenceInvocation",
    "NativeEvidenceFlushCommit",
    "NativeEvidenceFlushInvocation",
    "NativeEvidenceReservation",
    "NativeEvidenceSink",
    "build_native_evidence_callbacks",
)
