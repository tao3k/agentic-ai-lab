# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

import pytest

from agentic_ai_lab_runtime.benchmarks import scheme_load_aot as benchmark
from agentic_ai_lab_runtime.benchmarks import _scheme_load_aot_cases as benchmark_cases
from agentic_ai_lab_runtime.benchmarks import __main__ as benchmark_main
from agentic_ai_lab_runtime import _scheme_load_artifact as scheme_artifact
from agentic_ai_lab_runtime import _scheme_load_cache as scheme_cache


def _runtime_projection_fixture(root: Path) -> Path:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    projection.parent.mkdir(parents=True)
    projection.write_text(";; projection fixture\n", encoding="utf-8")
    return projection


def _source_fixture(root: Path) -> Path:
    source = root / "flow.ss"
    source.write_text("(user-composition benchmark-flow BenchmarkProfile)\n", encoding="utf-8")
    return source


def _aot_binary(root: Path, source: Path) -> Path:
    return benchmark_cases.scheme_load_aot_binary(source.resolve(), root.resolve())


def _materialize_aot_binary(root: Path, source: Path) -> Path:
    binary = _aot_binary(root, source)
    binary.parent.mkdir(parents=True)
    binary.write_text("#!/bin/sh\n", encoding="utf-8")
    return binary


def test_scheme_load_aot_benchmark_reports_exact_samples(
    tmp_path, monkeypatch
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    _materialize_aot_binary(tmp_path, source)
    calls: list[tuple[bool, bool]] = []

    def fake_load_projection_rows(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        cache: bool = True,
        projection_artifact: bool = True,
        aot: bool = True,
        compile_aot: bool = False,
    ) -> tuple[tuple[str, str]]:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        assert projection_artifact is False
        assert compile_aot is False
        calls.append((cache, aot))
        return (("schema", "yuanxu.funflow-plan-projection.v1"),)

    monkeypatch.setattr(
        benchmark_cases, "load_projection_rows", fake_load_projection_rows
    )

    results = benchmark.run_scheme_load_aot_benchmarks(
        source=source,
        cwd=tmp_path,
        iterations=3,
        include_fresh_process=False,
        include_interpreter=True,
    )

    assert tuple(result.scenario for result in results) == (
        "scheme-load-cache-hit",
        "scheme-load-in-process-aot-reuse",
        "scheme-load-interpreter-no-cache",
    )
    assert all(len(result.samples_micros) == 3 for result in results)
    assert all(result.min_micros <= result.median_micros for result in results)
    assert calls[:4] == [(True, True), (True, True), (True, True), (True, True)]
    assert calls[-3:] == [(False, False), (False, False), (False, False)]


def test_scheme_load_aot_benchmark_can_include_projection_artifact(
    tmp_path, monkeypatch
) -> None:
    projection = _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    _materialize_aot_binary(tmp_path, source)
    scheme_artifact.write_projection_artifact(
        scheme_artifact.cached_projection_artifact(
            tmp_path.resolve(),
            scheme_cache.scheme_load_cache_key(
                source.resolve(),
                tmp_path.resolve(),
                projection.resolve(),
            ),
        ),
        module_path=source,
        projection_path=projection,
        rows=(("schema", "yuanxu.funflow-plan-projection.v1"),),
    )

    def fake_load_projection_rows(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        cache: bool = True,
        projection_artifact: bool = True,
        aot: bool = True,
        compile_aot: bool = False,
    ) -> tuple[tuple[str, str]]:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        assert compile_aot is False
        if projection_artifact and not aot:
            return (("schema", "yuanxu.funflow-plan-projection.v1"),)
        return (("schema", "yuanxu.funflow-plan-projection.v1"),)

    monkeypatch.setattr(
        benchmark_cases, "load_projection_rows", fake_load_projection_rows
    )

    results = benchmark.run_scheme_load_aot_benchmarks(
        source=source,
        cwd=tmp_path,
        iterations=2,
        include_artifact=True,
        include_fresh_process=False,
    )

    assert results[0].scenario == "scheme-load-projection-artifact"
    assert len(results[0].samples_micros) == 2


def test_scheme_load_aot_benchmark_receipt_is_line_oriented() -> None:
    result = benchmark.SchemeLoadAotBenchmark(
        scenario="scheme-load-in-process-aot-reuse",
        iterations=3,
        source=Path("/tmp/source.ss"),
        cwd=Path("/tmp/root"),
        samples_micros=(10, 20, 30),
        detail={"process": "in-process", "cache": False, "aot": True},
    )

    receipt = result.receipt()

    assert 'schema: "agentic-ai-lab.scheme-load-aot-benchmark.v1"' in receipt
    assert 'scenario: "scheme-load-in-process-aot-reuse"' in receipt
    assert "samples-us: (10 20 30)" in receipt
    assert "median-us: 20.000" in receipt
    assert "mean-us: 20.000" in receipt
    assert "cache: #f" in receipt
    assert "aot: #t" in receipt


def test_scheme_load_aot_benchmark_requires_aot_binary(tmp_path) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)

    with pytest.raises(FileNotFoundError, match="missing Scheme AOT runner"):
        benchmark.run_scheme_load_aot_benchmarks(
            source=source,
            cwd=tmp_path,
            iterations=1,
            include_fresh_process=False,
        )


def test_scheme_load_aot_benchmark_cli_emits_receipts(
    tmp_path, monkeypatch, capsys
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    _materialize_aot_binary(tmp_path, source)

    def fake_load_projection_rows(
        _path: str | Path,
        **_kwargs: object,
    ) -> tuple[tuple[str, str]]:
        return (("schema", "yuanxu.funflow-plan-projection.v1"),)

    monkeypatch.setattr(
        benchmark_cases, "load_projection_rows", fake_load_projection_rows
    )

    assert (
        benchmark.main(
            [
                "--iterations",
                "2",
                "--source",
                str(source),
                "--cwd",
                str(tmp_path),
                "--skip-fresh-process",
            ]
        )
        == 0
    )

    output = capsys.readouterr().out
    assert output.count("agentic-ai-lab.scheme-load-aot-benchmark.v1") == 2


def test_benchmark_dispatcher_runs_scheme_load_aot_suite(
    tmp_path, monkeypatch, capsys
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    _materialize_aot_binary(tmp_path, source)

    def fake_load_projection_rows(
        _path: str | Path,
        **_kwargs: object,
    ) -> tuple[tuple[str, str]]:
        return (("schema", "yuanxu.funflow-plan-projection.v1"),)

    monkeypatch.setattr(
        benchmark_cases, "load_projection_rows", fake_load_projection_rows
    )

    assert (
        benchmark_main.main(
            [
                "scheme-load-aot",
                "--iterations",
                "1",
                "--source",
                str(source),
                "--cwd",
                str(tmp_path),
                "--skip-fresh-process",
            ]
        )
        == 0
    )

    output = capsys.readouterr().out
    assert output.count("agentic-ai-lab.scheme-load-aot-benchmark.v1") == 2
