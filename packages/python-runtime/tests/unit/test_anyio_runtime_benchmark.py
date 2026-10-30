# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime.benchmarks import anyio_runtime as benchmark
from agentic_ai_lab_runtime.benchmarks import __main__ as benchmark_cli
from agentic_ai_lab_runtime.benchmarks import _anyio_runtime_runner as benchmark_runner


def _phase(
    *,
    phase: str = "warm",
    candidate: tuple[float, ...] = (90.0, 100.0, 110.0),
    reference: tuple[float, ...] = (100.0, 100.0, 100.0),
    gated: bool = True,
) -> benchmark.AnyIORuntimeBenchmark:
    return benchmark.summarize_phase(
        phase=phase,
        candidate_samples=candidate,
        reference_samples=reference,
        target_observations_per_side=24,
        items_per_pair=8,
        available_cpus=4,
        anyio_limiter_capacity=40,
        selected_capacity=4,
        relative_tolerance=0.20,
        gated=gated,
        detail="synthetic-test",
    )


def test_anyio_runtime_capacity_is_host_bounded() -> None:
    assert benchmark.select_runtime_capacity(
        available_cpus=12, anyio_limiter_capacity=40
    ) == 12
    assert benchmark.select_runtime_capacity(
        available_cpus=4, anyio_limiter_capacity=40, requested=8
    ) == 4
    assert benchmark.select_runtime_capacity(
        available_cpus=16, anyio_limiter_capacity=6, requested=8
    ) == 6

    with pytest.raises(ValueError, match="positive"):
        benchmark.select_runtime_capacity(
            available_cpus=0, anyio_limiter_capacity=40
        )


def test_anyio_runtime_gate_uses_same_run_median_and_mad() -> None:
    stable = _phase(candidate=(110.0, 110.0, 110.0))
    noisy_reference = _phase(
        candidate=(130.0, 130.0, 130.0),
        reference=(80.0, 100.0, 120.0),
    )
    regression = _phase(candidate=(150.0, 150.0, 150.0))

    assert stable.ratio == pytest.approx(1.1)
    assert stable.passed
    assert noisy_reference.threshold_ratio == pytest.approx(1.6)
    assert noisy_reference.passed
    assert not regression.passed


def test_anyio_runtime_receipts_separate_cold_warm_and_reused_input() -> None:
    phases = (
        _phase(phase="cold", gated=False),
        _phase(phase="warm"),
        _phase(phase="reused-input"),
    )

    receipts = tuple(result.receipt() for result in phases)

    assert all(
        'schema: "agentic-ai-lab.anyio-runtime-benchmark.v1"' in receipt
        for receipt in receipts
    )
    assert tuple(result.phase for result in phases) == (
        "cold",
        "warm",
        "reused-input",
    )
    assert "gated: #f" in receipts[0]
    assert all("gated: #t" in receipt for receipt in receipts[1:])
    assert all('time-unit: "ns/item"' in receipt for receipt in receipts)
    assert all("target-observations-per-side: 24" in receipt for receipt in receipts)
    assert all("timing-pairs: 3" in receipt for receipt in receipts)
    assert all("items-per-pair: 8" in receipt for receipt in receipts)
    assert all(
        "actual-observations-per-side: 24" in receipt for receipt in receipts
    )
    assert all("qualification-volume-met: #t" in receipt for receipt in receipts)
    assert all("anyio-limiter-capacity: 40" in receipt for receipt in receipts)
    assert all("selected-capacity: 4" in receipt for receipt in receipts)


def test_anyio_runtime_module_cli_returns_nonzero_for_regression(
    monkeypatch, capsys
) -> None:
    monkeypatch.setattr(
        benchmark,
        "run_anyio_runtime_benchmarks",
        lambda **kwargs: [_phase(candidate=(200.0, 200.0, 200.0))],
    )

    assert benchmark.main(["--observations-per-side", "10000"]) == 1
    assert "passed: #f" in capsys.readouterr().out


def test_benchmark_dispatcher_propagates_anyio_gate_status(
    monkeypatch, capsys
) -> None:
    monkeypatch.setattr(
        benchmark_cli.anyio_runtime,
        "run_anyio_runtime_benchmarks",
        lambda **kwargs: [_phase(candidate=(200.0, 200.0, 200.0))],
    )

    assert (
        benchmark_cli.main(
            ["anyio-runtime", "--observations-per-side", "10000"]
        )
        == 1
    )
    assert "passed: #f" in capsys.readouterr().out


def test_anyio_runtime_requires_qualification_observation_volume() -> None:
    with pytest.raises(ValueError, match="observations per side.*5000"):
        benchmark.run_anyio_runtime_benchmarks(
            target_observations_per_side=4_999
        )

    benchmark_runner._validate_inputs(5_000, None, 1_000)


def test_anyio_runtime_plans_large_observation_volume_as_balanced_pairs() -> None:
    assert (
        benchmark.plan_timing_pairs(
            target_observations_per_side=10_000,
            items_per_pair=24,
        )
        == 418
    )
    assert (
        benchmark.plan_timing_pairs(
            target_observations_per_side=5_000,
            items_per_pair=10_000,
        )
        == 100
    )


def test_anyio_runtime_qualification_defaults_to_ten_thousand_observations() -> None:
    assert benchmark.ANYIO_RUNTIME_MIN_TARGET_OBSERVATIONS_PER_SIDE == 5_000
    assert benchmark.ANYIO_RUNTIME_DEFAULT_TARGET_OBSERVATIONS_PER_SIDE == 10_000
    assert benchmark.ANYIO_RUNTIME_MIN_TIMING_PAIRS == 100
    assert benchmark._parse_args([]).observations_per_side == 10_000
    assert (
        benchmark_cli.parse_args(["anyio-runtime"]).observations_per_side
        == 10_000
    )
