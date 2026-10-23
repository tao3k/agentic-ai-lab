# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed caller-arena event, mediation, and result values."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class NativeEvent:
    sequence: int
    event_kind: int = 1
    flags: int = 0
    event_identity: tuple[int, int] = (0, 0)
    correlation_identity: tuple[int, int] = (0, 0)
    authorization_identity: tuple[int, int] = (0, 0)
    payload_offset: int = 0
    payload_length: int = 0
    deadline_mono_ns: int = 0
    required_evidence_bits: int = 0


@dataclass(frozen=True, slots=True)
class NativeBatchResult:
    published_count: int
    produced_count: int
    accepted_count: int
    rejected_count: int
    accepted_watermark: int
    item_statuses: tuple[int, ...]
    accepted_bitmap: bytes
    mediation_outcome: int
    adapter_status: int
    evidence_status: int
    verification_flags: int
    mediation_sequence: int
    execution_root: bytes
    observation_digest: bytes
    evidence_digest: bytes
    attestation_digest: bytes


@dataclass(frozen=True, slots=True)
class NativeMediation:
    nonce: tuple[int, int]
    semantic_root: bytes
    before_execution_root: bytes
    after_execution_root: bytes
    observation_digest: bytes
    outcome: int = 1
    durability: int = 1
    input_digest: bytes = bytes(32)

    def __post_init__(self) -> None:
        for name in (
            "semantic_root", "before_execution_root", "after_execution_root",
            "observation_digest", "input_digest",
        ):
            if len(getattr(self, name)) != 32:
                raise ValueError(f"native mediation {name} must be exactly 32 bytes")
