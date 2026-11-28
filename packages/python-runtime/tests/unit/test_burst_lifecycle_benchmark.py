# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import tracemalloc

import pytest

from agentic_ai_lab_runtime.benchmarks import __main__ as benchmark_cli
from agentic_ai_lab_runtime.benchmarks import _burst_lifecycle_measurement as measurement
from agentic_ai_lab_runtime.benchmarks import _burst_lifecycle_runner as runner
from agentic_ai_lab_runtime.benchmarks import burst_lifecycle as benchmark


def test_burst_lifecycle_measures_mixed_case_startup_and_drain() -> None:
    receipt = benchmark.run_burst_lifecycle_benchmarks(
        populations=(12,),
        max_concurrency=4,
        serial_steps=2,
        parallel_fanout=3,
        parallel_steps=1,
        trace_memory=True,
    )[0]

    assert receipt.population == 12
    assert receipt.capacity_source == "manual"
    assert receipt.capacity_policy == "manual-override-v1"
    assert receipt.selected_capacity == 4
    assert receipt.calibration_population == 0
    assert receipt.calibration_capacities == ()
    assert receipt.completed == 12
    assert receipt.failed == 0
    assert receipt.peak_active_cases <= 4
    assert receipt.throughput_cases_per_second > 0
    assert receipt.startup_p50_ms <= receipt.startup_p95_ms
    assert receipt.startup_p95_ms <= receipt.startup_p99_ms
    assert receipt.service_p50_ms <= receipt.service_p95_ms
    assert receipt.completion_p50_ms <= receipt.completion_p99_ms
    assert receipt.memory_profile
    assert receipt.python_traced_peak_bytes is not None
    assert receipt.python_traced_peak_bytes > 0
    assert receipt.passed


def test_burst_lifecycle_receipt_names_units_and_parallel_boundary() -> None:
    receipt = benchmark.run_burst_lifecycle_benchmarks(
        populations=(9,), max_concurrency=3
    )[0].receipt()

    assert 'schema: "agentic-ai-lab.burst-lifecycle-benchmark.v1"' in receipt
    assert 'arrival-profile: "instant"' in receipt
    assert 'parallel-kind: "action-internal-fanout-join"' in receipt
    assert 'time-unit: "ms"' in receipt
    assert 'throughput-unit: "cases/s"' in receipt
    assert 'memory-unit: "bytes"' in receipt
    assert 'capacity-policy: "manual-override-v1"' in receipt
    assert "calibration-population: 0" in receipt
    assert 'calibration-capacities: ""' in receipt
    assert "memory-profile: #f" in receipt
    assert "python-traced-peak-bytes: #f" in receipt
    assert "population: 9" in receipt


def test_burst_lifecycle_streams_compact_progress(capsys) -> None:
    benchmark.run_burst_lifecycle_benchmarks(
        populations=(6,), max_concurrency=3, stream_progress=True
    )

    progress = capsys.readouterr().err
    assert "|agentic-ai-lab-benchmark-progress " in progress
    assert "population: 6" in progress
    assert "completed: 6" in progress
    assert "startup-p99-ms" not in progress


def test_burst_memory_profile_does_not_take_over_caller_tracemalloc() -> None:
    tracemalloc.start()
    try:
        with pytest.raises(RuntimeError, match="requires ownership"):
            benchmark.run_burst_lifecycle_benchmarks(
                populations=(6,),
                max_concurrency=3,
                trace_memory=True,
            )
        assert tracemalloc.is_tracing()
    finally:
        tracemalloc.stop()


def test_burst_memory_profile_stops_after_setup_failure(monkeypatch) -> None:
    def fail_clock() -> int:
        raise RuntimeError("synthetic clock failure")

    monkeypatch.setattr(measurement, "perf_counter_ns", fail_clock)

    with pytest.raises(RuntimeError, match="synthetic clock failure"):
        benchmark.run_burst_lifecycle_benchmarks(
            populations=(6,),
            max_concurrency=3,
            trace_memory=True,
        )
    assert not tracemalloc.is_tracing()


def test_burst_lifecycle_cli_accepts_multiple_populations(monkeypatch, capsys) -> None:
    captured: dict[str, object] = {}

    def run(**kwargs: object) -> list[object]:
        captured.update(kwargs)
        return []

    monkeypatch.setattr(
        benchmark_cli.burst_lifecycle,
        "run_burst_lifecycle_benchmarks",
        run,
    )

    assert (
        benchmark_cli.main(
            [
                "burst-lifecycle",
                "--population",
                "1000",
                "--population",
                "10000",
            ]
        )
        == 0
    )
    assert captured["populations"] == (1_000, 10_000)
    assert not any(key.startswith("calibration") for key in captured)
    assert capsys.readouterr().out == "\n"


def test_burst_lifecycle_dispatcher_rejects_calibration_flags() -> None:
    with pytest.raises(SystemExit):
        benchmark_cli.parse_args(
            ["burst-lifecycle", "--calibration-samples", "3"]
        )
