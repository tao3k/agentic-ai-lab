# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Own a negotiated runtime-v0 instance, Bundle, and session."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
from typing import TYPE_CHECKING, Self

from .errors import NativeRuntimeError, NativeRuntimeLoadError
from .loader import BUNDLE_SCHEMA, NativeRuntimeHealth, native_library_path

if TYPE_CHECKING:
    from ..evidence_model import AuthorizedEffectEvidenceReconciliation


@dataclass(frozen=True, slots=True)
class NativeBundleDescriptor:
    digest: bytes
    epoch: int
    canonical_packet: bytes
    digest_algorithm: int = 1
    schema: bytes = BUNDLE_SCHEMA

    def __post_init__(self) -> None:
        if len(self.digest) != 32:
            raise ValueError("native Bundle digest must be exactly 32 bytes")
        if self.epoch < 0:
            raise ValueError("native Bundle epoch cannot be negative")
        if not self.canonical_packet:
            raise ValueError("native Bundle canonical packet cannot be empty")


class NativeRuntimeSession:
    def __init__(
        self,
        bundle: NativeBundleDescriptor,
        *,
        library_path: str | Path | None = None,
        batched_evidence: bool = False,
    ) -> None:
        from ._runtime_v0_cffi import ffi, lib

        self._ffi = ffi
        self._lib = lib
        self._closed = False
        self.bundle_epoch = bundle.epoch
        self._library_path = (
            Path(library_path).resolve()
            if library_path is not None
            else native_library_path()
        )
        schema = ffi.new("uint8_t[]", bundle.schema)
        identity_bytes = b"agentic-ai-lab-python-runtime"
        identity = ffi.new("uint8_t[]", identity_bytes)
        digest = ffi.new("uint8_t[]", bundle.digest)
        packet = ffi.new("uint8_t[]", bundle.canonical_packet)
        health = ffi.new("agentic_ai_lab_python_runtime_v0_health *")
        self._context = lib.agentic_ai_lab_python_runtime_v0_open(
            str(self._library_path).encode(),
            schema,
            len(bundle.schema),
            identity,
            len(identity_bytes),
            bundle.digest_algorithm,
            digest,
            len(bundle.digest),
            bundle.epoch,
            packet,
            len(bundle.canonical_packet),
            int(batched_evidence),
            health,
        )
        if self._context == ffi.NULL:
            message = ffi.string(health.error).decode("utf-8", "replace")
            raise NativeRuntimeLoadError(message, status=int(health.status))
        self.health = NativeRuntimeHealth(
            self._library_path,
            int(health.abi_major),
            int(health.abi_minor),
            int(health.capabilities),
            int(health.max_payload_bytes),
        )

    @property
    def closed(self) -> bool:
        return self._closed

    def close(self) -> None:
        if self._closed:
            return
        status = int(self._lib.agentic_ai_lab_python_runtime_v0_close(self._context))
        self._context = self._ffi.NULL
        self._closed = True
        if status != 0:
            raise NativeRuntimeError("native runtime session close failed", status=status)

    def arena(
        self,
        buffer: bytearray | memoryview,
        *,
        generation: int = 1,
    ):
        if self._closed:
            raise NativeRuntimeError("native runtime session is closed")
        from .arena import NativeArena

        return NativeArena(self, buffer, generation=generation)

    def reconcile_evidence(
        self, reconciliation: AuthorizedEffectEvidenceReconciliation
    ) -> None:
        if self._closed:
            raise NativeRuntimeError("native runtime session is closed")
        ffi = self._ffi
        nonce_count = len(reconciliation.consumed_nonces)
        nonce_high = ffi.new("uint64_t[]", nonce_count)
        nonce_low = ffi.new("uint64_t[]", nonce_count)
        for index, (high, low) in enumerate(reconciliation.consumed_nonces):
            nonce_high[index] = high
            nonce_low[index] = low
        semantic_root = ffi.new("uint8_t[]", reconciliation.semantic_root)
        execution_root = ffi.new("uint8_t[]", reconciliation.execution_root)
        staged_count = len(reconciliation.staged_mediation_sequences)
        if staged_count != len(reconciliation.staged_leaf_digests):
            raise ValueError("staged evidence reconciliation shape mismatch")
        staged_sequences = ffi.new(
            "uint64_t[]", reconciliation.staged_mediation_sequences
        )
        staged_digests = ffi.new("uint8_t[]", b"".join(
            reconciliation.staged_leaf_digests
        ))
        status = int(
            self._lib.agentic_ai_lab_python_runtime_v0_reconcile_evidence(
                self._context,
                reconciliation.mediation_sequence,
                reconciliation.runtime_sequence,
                nonce_high,
                nonce_low,
                nonce_count,
                staged_sequences,
                staged_digests,
                staged_count,
                semantic_root,
                execution_root,
            )
        )
        if status != 0:
            raise NativeRuntimeError(
                "native evidence reconciliation failed", status=status
            )

    def flush_batched(self, expected_execution_root: bytes, evidence_sink):
        if self._closed:
            raise NativeRuntimeError("native runtime session is closed")
        if len(expected_execution_root) != 32:
            raise ValueError("expected execution root must be exactly 32 bytes")
        from .evidence import (
            NativeEvidenceFlushCommit,
            build_native_evidence_callbacks,
        )

        _, _, native_flush = build_native_evidence_callbacks(
            self._ffi, evidence_sink
        )
        if native_flush == self._ffi.NULL:
            raise ValueError("Batched evidence sink requires flush callback")
        expected = self._ffi.new("uint8_t[]", expected_execution_root)
        result = self._ffi.new(
            "agentic_ai_lab_python_runtime_v0_evidence_flush_result *"
        )
        status = int(self._lib.agentic_ai_lab_python_runtime_v0_flush_batched(
            self._context, expected, native_flush, self._ffi.NULL, result
        ))
        if status != 0:
            raise NativeRuntimeError("native Batched flush failed", status=status)
        return NativeEvidenceFlushCommit(
            bytes(self._ffi.buffer(result.after_execution_root, 32)),
            bytes(self._ffi.buffer(result.batch_root, 32)),
            bytes(self._ffi.buffer(result.evidence_digest, 32)),
            bytes(self._ffi.buffer(result.attestation_digest, 32)),
            int(result.verification_flags),
        )

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.close()

    def __del__(self) -> None:
        if not getattr(self, "_closed", True):
            try:
                self.close()
            except Exception:
                pass
