# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Caller-owned arena and typed runtime-v0 batch projection."""

from __future__ import annotations

from types import TracebackType
from typing import Self

from .errors import RuntimeExecutionError
from .evidence import RuntimeEvidenceSink, build_runtime_evidence_callbacks
from .arena_model import RuntimeBatchResult, RuntimeEvent, RuntimeMediation


class RuntimeArena:
    def __init__(
        self,
        session,
        buffer: bytearray | memoryview,
        *,
        generation: int = 1,
    ) -> None:
        if generation <= 0:
            raise ValueError("runtime arena generation must be positive")
        view = memoryview(buffer)
        if view.readonly or not view.contiguous:
            raise ValueError("runtime arena requires a writable contiguous buffer")
        self._session = session
        self._buffer_owner = buffer
        self._view = view.cast("B")
        self._generation = generation
        self._closed = False
        self._runtime_buffer = session._ffi.from_buffer("uint8_t[]", self._view)
        alignment = 16
        address = int(session._ffi.cast("size_t", self._runtime_buffer))
        if address % alignment != 0:
            raise ValueError("runtime arena buffer is not 16-byte aligned")
        status = int(
            session._lib.agentic_ai_lab_python_runtime_v0_arena_register(
                session._context,
                self._runtime_buffer,
                len(self._view),
                alignment,
                generation,
            )
        )
        if status != 0:
            raise RuntimeExecutionError("runtime arena registration failed", status=status)

    @property
    def generation(self) -> int:
        return self._generation

    @property
    def closed(self) -> bool:
        return self._closed

    def roundtrip(
        self,
        events: tuple[RuntimeEvent, ...],
        mediation: RuntimeMediation,
        evidence_sink: RuntimeEvidenceSink,
    ) -> RuntimeBatchResult:
        if self._closed:
            raise RuntimeExecutionError("runtime arena is closed")
        if not events:
            raise ValueError("runtime batch cannot be empty")
        ffi = self._session._ffi
        runtime_events = ffi.new("agentic_ai_lab_python_runtime_v0_event[]", len(events))
        for target, event in zip(runtime_events, events, strict=True):
            target.layout_version = 1
            target.event_kind = event.event_kind
            target.flags = event.flags
            target.sequence = event.sequence
            target.event_identity_high, target.event_identity_low = event.event_identity
            target.correlation_identity_high, target.correlation_identity_low = (
                event.correlation_identity
            )
            target.authorization_identity_high, target.authorization_identity_low = (
                event.authorization_identity
            )
            target.payload_offset = event.payload_offset
            target.payload_length = event.payload_length
            target.deadline_mono_ns = event.deadline_mono_ns
            target.required_evidence_bits = event.required_evidence_bits
        statuses = ffi.new("uint32_t[]", len(events))
        bitmap_bytes = len(events) // 8 + (len(events) % 8 != 0)
        bitmap = ffi.new("uint8_t[]", bitmap_bytes)
        result = ffi.new("agentic_ai_lab_python_runtime_v0_batch_result *")
        runtime_mediation = ffi.new("agentic_ai_lab_python_runtime_v0_mediation *")
        runtime_mediation.durability = mediation.durability
        runtime_mediation.outcome = mediation.outcome
        runtime_mediation.bundle_epoch = self._session.bundle_epoch
        runtime_mediation.nonce_high, runtime_mediation.nonce_low = mediation.nonce
        ffi.memmove(runtime_mediation.semantic_root, mediation.semantic_root, 32)
        ffi.memmove(
            runtime_mediation.before_execution_root,
            mediation.before_execution_root,
            32,
        )
        ffi.memmove(
            runtime_mediation.after_execution_root,
            mediation.after_execution_root,
            32,
        )
        ffi.memmove(runtime_mediation.input_digest, mediation.input_digest, 32)
        ffi.memmove(
            runtime_mediation.observation_digest, mediation.observation_digest, 32
        )
        runtime_evidence_reserve, runtime_evidence_finalize, runtime_evidence_flush = (
            build_runtime_evidence_callbacks(ffi, evidence_sink)
        )
        status = int(
            self._session._lib.agentic_ai_lab_python_runtime_v0_roundtrip(
                self._session._context,
                runtime_events,
                len(events),
                statuses,
                len(events),
                bitmap,
                bitmap_bytes,
                runtime_mediation,
                runtime_evidence_reserve,
                runtime_evidence_finalize,
                runtime_evidence_flush,
                ffi.NULL,
                result,
            )
        )
        if status != 0:
            raise RuntimeExecutionError("runtime batch roundtrip failed", status=status)
        return RuntimeBatchResult(
            int(result.published_count),
            int(result.produced_count),
            int(result.accepted_count),
            int(result.rejected_count),
            int(result.accepted_watermark),
            tuple(int(statuses[index]) for index in range(len(events))),
            bytes(ffi.buffer(bitmap, bitmap_bytes)),
            int(result.mediation_outcome),
            int(result.adapter_status),
            int(result.evidence_status),
            int(result.verification_flags),
            int(result.mediation_sequence),
            bytes(ffi.buffer(result.execution_root, 32)),
            bytes(ffi.buffer(result.observation_digest, 32)),
            bytes(ffi.buffer(result.evidence_digest, 32)),
            bytes(ffi.buffer(result.attestation_digest, 32)),
        )

    def recycle(self, next_generation: int) -> None:
        if self._closed:
            raise RuntimeExecutionError("runtime arena is closed")
        status = int(
            self._session._lib.agentic_ai_lab_python_runtime_v0_arena_recycle(
                self._session._context, self._generation, next_generation
            )
        )
        if status != 0:
            raise RuntimeExecutionError("runtime arena recycle failed", status=status)
        self._generation = next_generation

    def close(self) -> None:
        if self._closed:
            return
        status = int(
            self._session._lib.agentic_ai_lab_python_runtime_v0_arena_release(
                self._session._context
            )
        )
        if status != 0:
            raise RuntimeExecutionError("runtime arena release failed", status=status)
        self._closed = True
        self._runtime_buffer = None
        self._view.release()
        self._buffer_owner = None

    def __enter__(self) -> Self:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.close()
