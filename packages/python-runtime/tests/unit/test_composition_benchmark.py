# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime.benchmarks import composition as benchmark


def test_composition_benchmark_runs_all_scenarios() -> None:
    results = benchmark.run_composition_benchmarks(iterations=1, fanout=3)

    assert tuple(result.scenario for result in results) == (
        "strategy-combinator-pipeline",
        "durable-fanout-strategy",
        "nested-subgraph-stream-projection",
        "funflow-cicd-sandbox-dag",
    )
    assert all(result.elapsed_micros >= 0 for result in results)


def test_composition_benchmark_receipt_is_line_oriented() -> None:
    result = benchmark.run_composition_benchmarks(iterations=1, fanout=2)[0]

    receipt = result.receipt()

    assert "schema: \"agentic-ai-lab.composition-benchmark.v1\"" in receipt
    assert "scenario: \"strategy-combinator-pipeline\"" in receipt
    assert "stages: 8" in receipt


def test_composition_benchmark_cli_emits_receipts(capsys) -> None:
    assert benchmark.main(["--iterations", "1", "--fanout", "2"]) == 0

    output = capsys.readouterr().out
    assert output.count("agentic-ai-lab.composition-benchmark.v1") == 4
