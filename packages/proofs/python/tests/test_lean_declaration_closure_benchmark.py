# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Benchmark failures must leave evidence and must not become warm samples."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

from agentic_ai_lab_proof.lean_declaration_closure import LeanClosureError


@pytest.fixture
def benchmark():
    path = Path(__file__).parents[1] / "tools/benchmark_lean_declaration_closure.py"
    spec = importlib.util.spec_from_file_location("closure_benchmark", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_failure_writes_typed_receipt_and_stops_without_retry(benchmark, monkeypatch, tmp_path):
    calls = []

    def fail(**kwargs):
        calls.append(kwargs)
        kwargs["phase_observer"]({"phase": "generation-lake-build", "returncode": 1})
        raise LeanClosureError("lake-build-failed", "original root cause")

    monkeypatch.setattr(benchmark, "export_declaration_closures", fail)
    output = tmp_path / "receipt.json"
    monkeypatch.setattr(sys, "argv", ["benchmark", "--runs", "3", "--output", str(output)])
    assert benchmark.main() == 1
    receipt = json.loads(output.read_text())
    assert len(calls) == 1
    assert receipt["status"] == "failed"
    assert receipt["requested_sample_count"] == 3
    assert receipt["summary"]["sample_count"] == 1
    assert receipt["summary"]["failed_sample_count"] == 1
    assert receipt["summary"]["warm_sample_count"] == 0
    assert receipt["summary"]["warm_p95_ms"] is None
    assert receipt["samples"][0]["error"] == {
        "code": "lake-build-failed",
        "detail": "original root cause",
    }
    assert receipt["samples"][0]["phases"][0]["returncode"] == 1
    assert receipt["samples"][0]["closure_digests"] == []


def test_timeout_is_not_lost(benchmark, monkeypatch):
    def fail(**kwargs):
        raise LeanClosureError(
            "lean-declaration-closure-export-timeout",
            "phase=generation-lake-build; budget_seconds=30",
        )

    monkeypatch.setattr(benchmark, "export_declaration_closures", fail)
    sample = benchmark._sample(Path("unused"), 30)
    assert sample["status"] == "failed"
    assert sample["error"]["detail"] == "phase=generation-lake-build; budget_seconds=30"


def test_success_preserves_digests_and_warm_summary(benchmark, monkeypatch, capsys):
    def export(**kwargs):
        for _ in benchmark.REQUESTS:
            kwargs["phase_observer"]({"phase": "closure-cache-read", "cache_state": "hit"})
        return [
            SimpleNamespace(closure_digest="sha256:first"),
            SimpleNamespace(closure_digest="sha256:second"),
        ]

    monkeypatch.setattr(benchmark, "export_declaration_closures", export)
    monkeypatch.setattr(sys, "argv", ["benchmark", "--runs", "2"])
    assert benchmark.main() == 0
    receipt = json.loads(capsys.readouterr().out)
    assert receipt["status"] == "completed"
    assert receipt["summary"]["warm_sample_count"] == 2
    assert receipt["summary"]["failed_sample_count"] == 0
    assert receipt["samples"][0]["closure_digests"] == ["sha256:first", "sha256:second"]


@pytest.mark.parametrize("timeout", ["0", "-1", "nan", "inf"])
def test_invalid_budget_fails_before_export(benchmark, monkeypatch, timeout):
    monkeypatch.setattr(sys, "argv", ["benchmark", "--timeout-seconds", timeout])
    with pytest.raises(SystemExit) as failure:
        benchmark.main()
    assert failure.value.code == 2
