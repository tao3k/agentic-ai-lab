# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Canonical receipt for the large-state ownership-copy benchmark."""

from __future__ import annotations

import json
from dataclasses import dataclass

LARGE_STATE_COPY_BENCHMARK_SCHEMA = "agentic-ai-lab.large-state-copy-benchmark.v1"
LARGE_STATE_COPY_BOUNDARY = "program-executor"
LARGE_STATE_COPY_TIME_UNIT = "ns/item"


@dataclass(frozen=True, slots=True)
class LargeStateCopyBenchmark:
    """One paired program-to-executor ownership-copy receipt."""

    phase: str
    target_observations_per_side: int
    timing_pairs: int
    items_per_pair: int
    available_cpus: int
    anyio_limiter_capacity: int
    selected_capacity: int
    payload_field_count: int
    payload_field_bytes: int
    root_field_count: int
    candidate_median_ns_per_item: float
    candidate_p95_ns_per_item: float
    reference_median_ns_per_item: float
    reference_p95_ns_per_item: float
    ratio: float
    threshold_ratio: float
    gated: bool
    passed: bool
    semantics_verified: bool
    detail: str

    @property
    def actual_observations_per_side(self) -> int:
        return self.timing_pairs * self.items_per_pair

    @property
    def qualification_volume_met(self) -> bool:
        return (
            self.actual_observations_per_side
            >= self.target_observations_per_side
        )

    @property
    def payload_logical_bytes_per_state(self) -> int:
        return self.payload_field_count * self.payload_field_bytes

    @property
    def template_physical_bytes_estimate(self) -> int:
        return self.payload_field_count * self.payload_field_bytes

    @property
    def input_root_dictionaries_per_pair(self) -> int:
        return 2 * self.items_per_pair

    @property
    def input_root_references_per_pair(self) -> int:
        return self.input_root_dictionaries_per_pair * self.root_field_count

    @property
    def absolute_saved_ns_per_item(self) -> float:
        return (
            self.reference_median_ns_per_item
            - self.candidate_median_ns_per_item
        )

    @property
    def candidate_faster(self) -> bool:
        return self.absolute_saved_ns_per_item > 0

    def receipt_payload(self) -> dict[str, object]:
        return {
            "absolute-saved-ns-per-item": round(
                self.absolute_saved_ns_per_item, 3
            ),
            "actual-observations-per-side": self.actual_observations_per_side,
            "anyio-limiter-capacity": self.anyio_limiter_capacity,
            "available-cpus": self.available_cpus,
            "candidate-faster": self.candidate_faster,
            "candidate-median-ns-per-item": round(
                self.candidate_median_ns_per_item, 3
            ),
            "candidate-mode": "owned-transfer",
            "candidate-p95-ns-per-item": round(
                self.candidate_p95_ns_per_item, 3
            ),
            "capacity-source": "fixed",
            "copy-boundary": LARGE_STATE_COPY_BOUNDARY,
            "copy-kind": "shallow-root-dict",
            "detail": self.detail,
            "gate-purpose": "same-run-no-regression",
            "gated": self.gated,
            "input-root-dictionaries-per-pair": (
                self.input_root_dictionaries_per_pair
            ),
            "input-root-references-per-pair": (
                self.input_root_references_per_pair
            ),
            "items-per-pair": self.items_per_pair,
            "passed": self.passed,
            "payload-field-bytes": self.payload_field_bytes,
            "payload-field-count": self.payload_field_count,
            "payload-logical-bytes-per-state": (
                self.payload_logical_bytes_per_state
            ),
            "phase": self.phase,
            "qualification-volume-met": self.qualification_volume_met,
            "ratio": round(self.ratio, 6),
            "reference-median-ns-per-item": round(
                self.reference_median_ns_per_item, 3
            ),
            "reference-mode": "public-defensive-copy",
            "reference-p95-ns-per-item": round(
                self.reference_p95_ns_per_item, 3
            ),
            "root-field-count": self.root_field_count,
            "schema": LARGE_STATE_COPY_BENCHMARK_SCHEMA,
            "selected-capacity": self.selected_capacity,
            "semantics-verified": self.semantics_verified,
            "target-observations-per-side": self.target_observations_per_side,
            "template-physical-bytes-estimate": (
                self.template_physical_bytes_estimate
            ),
            "template-physical-bytes-estimate-excludes-object-overhead": True,
            "threshold-ratio": round(self.threshold_ratio, 6),
            "time-unit": LARGE_STATE_COPY_TIME_UNIT,
            "timing-pairs": self.timing_pairs,
        }

    def receipt(self) -> str:
        return json.dumps(
            self.receipt_payload(),
            allow_nan=False,
            ensure_ascii=True,
            separators=(",", ":"),
            sort_keys=True,
        )

