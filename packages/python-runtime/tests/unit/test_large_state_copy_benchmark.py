# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import json

import pytest

from agentic_ai_lab_runtime.benchmarks import __main__ as benchmark_cli
from agentic_ai_lab_runtime.benchmarks import anyio_runtime
from agentic_ai_lab_runtime.benchmarks import large_state_copy as benchmark
from agentic_ai_lab_runtime.benchmarks import _large_state_copy_workload as workload


def _receipt(**overrides: object) -> benchmark.LargeStateCopyBenchmark:
    values: dict[str, object] = {
        "phase": "steady-fresh-state",
        "target_observations_per_side": 5_000,
        "timing_pairs": 250,
        "items_per_pair": 20,
        "available_cpus": 12,
        "anyio_limiter_capacity": 40,
        "selected_capacity": 10,
        "payload_field_count": 64,
        "payload_field_bytes": 128,
        "root_field_count": 66,
        "candidate_median_ns_per_item": 90.0,
        "candidate_p95_ns_per_item": 110.0,
        "reference_median_ns_per_item": 100.0,
        "reference_p95_ns_per_item": 120.0,
        "ratio": 0.9,
        "threshold_ratio": 1.25,
        "gated": True,
        "passed": True,
        "semantics_verified": True,
        "detail": "synthetic-test",
    }
    values.update(overrides)
    return benchmark.LargeStateCopyBenchmark(**values)


@pytest.mark.parametrize(
    ("kwargs", "message"),
    (
        ({"target_observations_per_side": 4_999}, "at least 5000"),
        ({"items_per_pair": 0}, "items per pair"),
        ({"max_concurrency": None}, "explicitly provided"),
        ({"max_concurrency": 0}, "max concurrency must be positive"),
        ({"payload_field_count": 0}, "payload field count"),
        ({"payload_field_bytes": -1}, "payload field bytes"),
        ({"relative_tolerance": -0.1}, "relative tolerance"),
    ),
)
def test_large_state_copy_rejects_invalid_inputs(kwargs, message) -> None:
    inputs = {
        "target_observations_per_side": 5_000,
        "items_per_pair": None,
        "max_concurrency": 4,
        "payload_field_count": 64,
        "payload_field_bytes": 128,
        "relative_tolerance": 0.25,
    }
    inputs.update(kwargs)

    with pytest.raises(ValueError, match=message):
        benchmark.run_large_state_copy_benchmarks(**inputs)


def test_large_state_copy_accepts_minimum_volume_and_fixed_capacity() -> None:
    benchmark._validate_inputs(5_000, None, 12, 64, 0, 0.25)
    assert benchmark.LARGE_STATE_COPY_MIN_TARGET_OBSERVATIONS_PER_SIDE == 5_000
    assert benchmark.LARGE_STATE_COPY_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE == 10_000


def test_large_state_copy_inputs_are_fresh_equivalent_large_states() -> None:
    program, _executor = workload._program_and_executor(3)
    template = workload._payload_template(3, 7)

    candidate, reference = workload._fresh_equivalent_pair(
        program,
        template,
        2,
        observation_offset=10,
    )

    assert candidate == reference
    assert all(
        left is not right
        for left, right in zip(candidate, reference, strict=True)
    )
    assert len(candidate[0]["payload-000002"]) == 7
    assert candidate[0]["observation-id"] == 10


def test_large_state_copy_semantic_mismatch_fails_closed() -> None:
    with pytest.raises(RuntimeError, match="semantic mismatch"):
        workload._assert_semantics_equal(
            (({"value": 1}, (), ()),),
            (({"value": 2}, (), ()),),
        )


def test_large_state_copy_receipt_is_canonical_json() -> None:
    receipt = _receipt()
    encoded = receipt.receipt()
    payload = json.loads(encoded)

    assert encoded == json.dumps(
        payload,
        allow_nan=False,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    )
    assert payload["schema"] == "agentic-ai-lab.large-state-copy-benchmark.v1"
    assert payload["copy-boundary"] == "program-executor"
    assert payload["copy-kind"] == "shallow-root-dict"
    assert payload["candidate-mode"] == "owned-transfer"
    assert payload["candidate-faster"] is True
    assert payload["absolute-saved-ns-per-item"] == 10.0
    assert payload["reference-mode"] == "public-defensive-copy"
    assert payload["capacity-source"] == "fixed"
    assert payload["gate-purpose"] == "same-run-no-regression"
    assert payload["payload-logical-bytes-per-state"] == 8_192
    assert payload["template-physical-bytes-estimate"] == 8_192
    assert payload[
        "template-physical-bytes-estimate-excludes-object-overhead"
    ] is True
    assert payload["input-root-dictionaries-per-pair"] == 40
    assert payload["input-root-references-per-pair"] == 2_640
    assert payload["actual-observations-per-side"] == 5_000
    assert payload["qualification-volume-met"] is True
    assert payload["semantics-verified"] is True


def test_large_state_copy_pass_does_not_imply_candidate_is_faster() -> None:
    payload = json.loads(
        _receipt(
            candidate_median_ns_per_item=110.0,
            reference_median_ns_per_item=100.0,
            ratio=1.1,
            passed=True,
        ).receipt()
    )

    assert payload["passed"] is True
    assert payload["gate-purpose"] == "same-run-no-regression"
    assert payload["candidate-faster"] is False
    assert payload["absolute-saved-ns-per-item"] == -10.0


def test_benchmark_dispatcher_routes_large_state_copy(
    monkeypatch, capsys
) -> None:
    captured: dict[str, object] = {}

    def run(**kwargs: object) -> list[benchmark.LargeStateCopyBenchmark]:
        captured.update(kwargs)
        return [_receipt()]

    monkeypatch.setattr(
        benchmark_cli.large_state_copy,
        "run_large_state_copy_benchmarks",
        run,
    )

    assert benchmark_cli.main(
        [
            "large-state-copy",
            "--observations-per-side",
            "5000",
            "--items-per-pair",
            "20",
            "--max-concurrency",
            "10",
            "--payload-field-count",
            "64",
            "--payload-field-bytes",
            "128",
        ]
    ) == 0
    assert captured == {
        "target_observations_per_side": 5_000,
        "items_per_pair": 20,
        "max_concurrency": 10,
        "payload_field_count": 64,
        "payload_field_bytes": 128,
        "relative_tolerance": 0.25,
    }
    assert json.loads(capsys.readouterr().out)["schema"] == (
        "agentic-ai-lab.large-state-copy-benchmark.v1"
    )


def test_anyio_runtime_schema_defaults_and_receipt_remain_unchanged() -> None:
    args = benchmark_cli.parse_args(["anyio-runtime"])
    phase = anyio_runtime.summarize_phase(
        phase="warm",
        candidate_samples=(100.0,),
        reference_samples=(100.0,),
        target_observations_per_side=1,
        items_per_pair=1,
        available_cpus=1,
        anyio_limiter_capacity=40,
        selected_capacity=1,
        relative_tolerance=0.25,
        gated=False,
        detail="regression-test",
    )

    assert anyio_runtime.ANYIO_RUNTIME_BENCHMARK_SCHEMA == (
        "agentic-ai-lab.anyio-runtime-benchmark.v1"
    )
    assert anyio_runtime.ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE == 10_000
    assert args.observations_per_side == 10_000
    assert args.max_concurrency is None
    assert phase.receipt().startswith(
        '|agentic-ai-lab-benchmark (schema: "agentic-ai-lab.anyio-runtime-benchmark.v1"'
    )
