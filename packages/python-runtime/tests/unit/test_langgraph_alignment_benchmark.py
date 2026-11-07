# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from agentic_ai_lab_runtime.benchmarks import langgraph_alignment as benchmark


def test_langgraph_alignment_benchmark_runs_all_scenarios() -> None:
    results = benchmark.run_benchmarks(iterations=2, fanout=3)

    assert tuple(result.scenario for result in results) == (
        "sequence-composition",
        "dynamic-send-fanout",
        "subgraph-composition",
        "thread-state-facade",
    )
    assert all(result.elapsed_micros >= 0 for result in results)


def test_langgraph_alignment_benchmark_receipt_is_line_oriented() -> None:
    result = benchmark.run_dynamic_send_fanout(iterations=1, fanout=2)

    receipt = result.receipt()

    assert "schema: \"agentic-ai-lab.langgraph-alignment-benchmark.v1\"" in receipt
    assert "scenario: \"dynamic-send-fanout\"" in receipt
    assert "fanout: 2" in receipt


def test_langgraph_alignment_benchmark_cli_emits_receipts(capsys) -> None:
    assert benchmark.main(["--iterations", "1", "--fanout", "2"]) == 0

    output = capsys.readouterr().out
    assert output.count("agentic-ai-lab.langgraph-alignment-benchmark.v1") == 4
