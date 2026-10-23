# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native proof-case validation through the stable C ABI.

The Python validator and CFFI adapter intentionally consume the same generated
native vector.  This keeps Python useful as a production runtime while making
cross-runtime conformance byte-for-byte testable without a JSON boundary.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from enum import IntEnum
from os import PathLike
from struct import unpack_from
from threading import Lock, local

from cffi import FFI

from agentic_ai_lab_proof.generated.proof_case_vector import (
    ABI_VERSION,
    CASE_KINDS,
    DURABILITY_PROFILES,
    FIELD_OFFSETS,
    MEDIATION_OUTCOMES,
    REQUIRED_OBLIGATION_MASK,
    SCHEMA_FINGERPRINT_HEX,
    VECTOR_DIGEST_DOMAIN,
    VECTOR_ALIGNMENT,
    VECTOR_SIZE,
)


class ProofStatus(IntEnum):
    OK = 0
    INVALID_ARGUMENT = 1
    BUFFER_TOO_SMALL = 2
    STALE_HANDLE = 3
    SCHEMA_MISMATCH = 4
    MALFORMED_EVIDENCE = 5
    UNSUPPORTED_OBLIGATION = 6


class ProofCaseError(ValueError):
    def __init__(self, status: ProofStatus, message: str) -> None:
        super().__init__(message)
        self.status = status


@dataclass(frozen=True)
class ProofCaseLayout:
    required_size: int
    alignment: int
    abi_version: int
    schema_fingerprint: bytes


@dataclass(frozen=True)
class VectorDivergence:
    expected_owner: str
    actual_owner: str
    field: str
    offset: int


def _u32(vector: bytes, field: str) -> int:
    return unpack_from("<I", vector, FIELD_OFFSETS[field])[0]


def _u64(vector: bytes, field: str) -> int:
    return unpack_from("<Q", vector, FIELD_OFFSETS[field])[0]


def validate_proof_case_vector(vector: bytes) -> ProofStatus:
    """Mirror the C boundary checks using generated native-layout constants."""
    if len(vector) != VECTOR_SIZE:
        return ProofStatus.MALFORMED_EVIDENCE
    if _u32(vector, "abi_version") != ABI_VERSION:
        return ProofStatus.SCHEMA_MISMATCH
    fingerprint = vector[
        FIELD_OFFSETS["schema_fingerprint"] : FIELD_OFFSETS["schema_fingerprint"] + 32
    ]
    if fingerprint != bytes.fromhex(SCHEMA_FINGERPRINT_HEX):
        return ProofStatus.SCHEMA_MISMATCH

    required = _u64(vector, "required_obligation_mask")
    present = _u64(vector, "present_obligation_mask")
    if (required | present) & ~REQUIRED_OBLIGATION_MASK:
        return ProofStatus.UNSUPPORTED_OBLIGATION
    if present & ~required:
        return ProofStatus.MALFORMED_EVIDENCE

    if _u32(vector, "case_kind") not in CASE_KINDS.values():
        return ProofStatus.MALFORMED_EVIDENCE
    if _u32(vector, "obligation_count") > 8:
        return ProofStatus.MALFORMED_EVIDENCE
    if _u32(vector, "mediation_outcome") not in MEDIATION_OUTCOMES.values():
        return ProofStatus.MALFORMED_EVIDENCE
    if _u32(vector, "durability_profile") not in DURABILITY_PROFILES.values():
        return ProofStatus.MALFORMED_EVIDENCE
    if any(vector[FIELD_OFFSETS["reserved"] :]):
        return ProofStatus.MALFORMED_EVIDENCE
    return ProofStatus.OK


def proof_case_vector_digest(vector: bytes) -> bytes:
    if len(vector) != VECTOR_SIZE:
        raise ValueError("proof vector digest requires canonical vector size")
    return hashlib.sha256(VECTOR_DIGEST_DOMAIN.encode() + b"\0" + vector).digest()


def first_vector_divergence(
    expected: bytes,
    actual: bytes,
    *,
    expected_owner: str,
    actual_owner: str,
) -> VectorDivergence | None:
    if len(expected) != len(actual):
        return VectorDivergence(expected_owner, actual_owner, "vector_size", 0)
    ordered = sorted(FIELD_OFFSETS.items(), key=lambda item: item[1])
    for index, (field, offset) in enumerate(ordered):
        end = ordered[index + 1][1] if index + 1 < len(ordered) else VECTOR_SIZE
        if expected[offset:end] != actual[offset:end]:
            return VectorDivergence(expected_owner, actual_owner, field, offset)
    return None


_CDEF = """
typedef uint32_t agentic_ai_lab_proof_status;
typedef struct { const unsigned char *data; size_t size; uint64_t generation; }
  agentic_ai_lab_proof_case_handle;
typedef struct {
  size_t required_size;
  size_t alignment;
  uint32_t abi_version;
  unsigned char schema_fingerprint[32];
} agentic_ai_lab_proof_case_layout;
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_init(
  const void *, size_t, agentic_ai_lab_proof_case_handle *);
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_release(agentic_ai_lab_proof_case_handle *);
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_measure(
  const agentic_ai_lab_proof_case_handle *, agentic_ai_lab_proof_case_layout *);
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_write(
  const agentic_ai_lab_proof_case_handle *, void *, size_t, size_t *);
const char *agentic_ai_lab_proof_status_name(agentic_ai_lab_proof_status);
"""


class NativeProofCaseRuntime:
    """Zero-copy input adapter over ``agentic_ai_lab_proof_case_v1``."""

    def __init__(self, library: str | PathLike[str]) -> None:
        self.ffi = FFI()
        self.ffi.cdef(_CDEF)
        self.lib = self.ffi.dlopen(str(library))
        self._layout: ProofCaseLayout | None = None
        self._layout_lock = Lock()
        self._layout_measurements = 0
        self._thread_local = local()

    @property
    def layout_measurements(self) -> int:
        with self._layout_lock:
            return self._layout_measurements

    def _scratch(self) -> tuple[object, object, object]:
        scratch = getattr(self._thread_local, "proof_case_scratch", None)
        if scratch is None:
            scratch = (
                self.ffi.new("agentic_ai_lab_proof_case_handle *"),
                self.ffi.new("size_t *"),
                self.ffi.new("agentic_ai_lab_proof_case_layout *"),
            )
            self._thread_local.proof_case_scratch = scratch
        return scratch

    def _raise(self, raw_status: int) -> None:
        status = ProofStatus(raw_status)
        name = self.ffi.string(self.lib.agentic_ai_lab_proof_status_name(raw_status)).decode()
        raise ProofCaseError(status, name)

    def _negotiate_layout(self, handle: object, raw_layout: object) -> ProofCaseLayout:
        layout = self._layout
        if layout is not None:
            return layout
        with self._layout_lock:
            if self._layout is not None:
                return self._layout
            status = self.lib.agentic_ai_lab_proof_case_measure(handle, raw_layout)
            if status != ProofStatus.OK:
                self._raise(status)
            measured = ProofCaseLayout(
                required_size=raw_layout.required_size,
                alignment=raw_layout.alignment,
                abi_version=raw_layout.abi_version,
                schema_fingerprint=bytes(
                    self.ffi.buffer(raw_layout.schema_fingerprint, 32)
                ),
            )
            expected = ProofCaseLayout(
                VECTOR_SIZE,
                VECTOR_ALIGNMENT,
                ABI_VERSION,
                bytes.fromhex(SCHEMA_FINGERPRINT_HEX),
            )
            if measured != expected:
                raise ProofCaseError(
                    ProofStatus.SCHEMA_MISMATCH,
                    "C ABI layout differs from generated Python contract",
                )
            self._layout = measured
            self._layout_measurements += 1
            return measured

    def validate_and_write(
        self, vector: bytes, output: bytearray
    ) -> ProofCaseLayout:
        """Validate and write into caller-owned output with cached negotiation."""
        backing = self.ffi.from_buffer("const unsigned char[]", vector)
        output_view = self.ffi.from_buffer("unsigned char[]", output)
        handle, written, raw_layout = self._scratch()
        status = self.lib.agentic_ai_lab_proof_case_init(backing, len(vector), handle)
        if status != ProofStatus.OK:
            self._raise(status)
        try:
            layout = self._negotiate_layout(handle, raw_layout)
            written[0] = 0
            status = self.lib.agentic_ai_lab_proof_case_write(
                handle, output_view, len(output), written
            )
            if status != ProofStatus.OK:
                self._raise(status)
            if written[0] != layout.required_size:
                raise RuntimeError("C ABI returned an inconsistent proof-case length")
            return layout
        finally:
            status = self.lib.agentic_ai_lab_proof_case_release(handle)
            if status != ProofStatus.OK:
                self._raise(status)

    def validate_and_copy(self, vector: bytes) -> tuple[ProofCaseLayout, bytes]:
        output = bytearray(VECTOR_SIZE)
        layout = self.validate_and_write(vector, output)
        return layout, bytes(output)


def assert_native_differential(
    runtime: NativeProofCaseRuntime, vector: bytes
) -> ProofCaseLayout:
    python_status = validate_proof_case_vector(vector)
    try:
        layout, copied = runtime.validate_and_copy(vector)
    except ProofCaseError as error:
        if error.status != python_status:
            raise AssertionError(
                f"Python/C proof status mismatch: {python_status.name} != {error.status.name}"
            ) from error
        raise
    if python_status != ProofStatus.OK:
        raise AssertionError(f"C accepted vector rejected by Python: {python_status.name}")
    if copied != vector:
        raise AssertionError("C ABI proof-case round trip changed native bytes")
    if layout != ProofCaseLayout(
        VECTOR_SIZE, VECTOR_ALIGNMENT, ABI_VERSION, bytes.fromhex(SCHEMA_FINGERPRINT_HEX)
    ):
        raise AssertionError("C ABI layout differs from generated Python contract")
    return layout
