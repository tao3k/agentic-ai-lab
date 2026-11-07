# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Benchmark Agentic AI Lab runtime patterns aligned with LangGraph semantics."""

from __future__ import annotations

import argparse
import sys
import time
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from typing import Any

from ..builder import RuntimeGraphBuilder
from ..checkpoints import MemoryRuntimeGraphCheckpointer
from ..runtime_graph import RuntimeGraphSend
from ..subgraphs import RuntimeGraphSubgraph


BENCHMARK_SCHEMA = "agentic-ai-lab.langgraph-alignment-benchmark.v1"


@dataclass(frozen=True)
class LangGraphAlignmentBenchmark:
    scenario: str
    iterations: int
    elapsed_micros: int
    detail: Mapping[str, Any]

    @property
    def per_iteration_micros(self) -> float:
        return self.elapsed_micros / max(1, self.iterations)

    def receipt(self) -> str:
        detail = " ".join(
            f"{key}: {_receipt_value(value)}" for key, value in self.detail.items()
        )
        return (
            "|agentic-ai-lab-benchmark "
            f"(schema: \"{BENCHMARK_SCHEMA}\" "
            f"scenario: {_receipt_value(self.scenario)} "
            f"iterations: {self.iterations} "
            f"elapsed-micros: {self.elapsed_micros} "
            f"per-iteration-micros: {self.per_iteration_micros:.3f} "
            f"detail: ({detail}))"
        )


def run_sequence_composition(iterations: int) -> LangGraphAlignmentBenchmark:
    builder = RuntimeGraphBuilder()
    builder.add_sequence(
        tuple((f"step-{index}", _increment_state) for index in range(8))
    )
    builder.set_entry_point("step-0")
    builder.set_finish_point("step-7")
    executor = builder.compile()

    elapsed = _elapsed_micros(lambda: executor.invoke({"value": 0}), iterations)
    return LangGraphAlignmentBenchmark(
        scenario="sequence-composition",
        iterations=iterations,
        elapsed_micros=elapsed,
        detail={"nodes": 8},
    )


def run_dynamic_send_fanout(
    iterations: int,
    *,
    fanout: int = 24,
) -> LangGraphAlignmentBenchmark:
    builder = RuntimeGraphBuilder()
    builder.add_node("fanout", _empty_update)
    builder.add_node("worker", _fanout_worker)
    builder.add_reducer("results", _append_results)
    builder.set_entry_point("fanout")
    builder.add_conditional_edges("fanout", _fanout_route)
    builder.set_finish_point("worker")
    executor = builder.compile()

    payload = {"items": tuple(range(fanout)), "results": []}
    elapsed = _elapsed_micros(lambda: executor.invoke(payload), iterations)
    return LangGraphAlignmentBenchmark(
        scenario="dynamic-send-fanout",
        iterations=iterations,
        elapsed_micros=elapsed,
        detail={"fanout": fanout},
    )


def run_subgraph_composition(iterations: int) -> LangGraphAlignmentBenchmark:
    child = (
        RuntimeGraphBuilder()
        .add_node("child-step", _increment_state)
        .set_entry_point("child-step")
        .set_finish_point("child-step")
        .compile()
    )
    subgraph = RuntimeGraphSubgraph(
        child,
        input_keys=("value",),
        output_keys=("value",),
    )
    parent = (
        RuntimeGraphBuilder()
        .add_node("first", _increment_state)
        .add_node("child", subgraph.as_action())
        .add_node("last", _increment_state)
        .add_edge("first", "child")
        .add_edge("child", "last")
        .set_entry_point("first")
        .set_finish_point("last")
        .compile()
    )

    elapsed = _elapsed_micros(lambda: parent.invoke({"value": 0}), iterations)
    return LangGraphAlignmentBenchmark(
        scenario="subgraph-composition",
        iterations=iterations,
        elapsed_micros=elapsed,
        detail={"parent-nodes": 3, "child-nodes": 1},
    )


def run_thread_state_facade(iterations: int) -> LangGraphAlignmentBenchmark:
    checkpointer = MemoryRuntimeGraphCheckpointer()
    program = (
        RuntimeGraphBuilder()
        .add_node("step", _increment_state)
        .set_entry_point("step")
        .set_finish_point("step")
        .compile_reference_program()
    )

    def invoke_and_update() -> None:
        thread_id = "bench-thread"
        execution = program.invoke_thread(thread_id, {"value": 0}, checkpointer)
        program.update_state(
            thread_id,
            {"value": execution.state["value"] + 1},
            checkpointer,
        )
        program.get_state_history(thread_id, checkpointer)

    elapsed = _elapsed_micros(invoke_and_update, iterations)
    return LangGraphAlignmentBenchmark(
        scenario="thread-state-facade",
        iterations=iterations,
        elapsed_micros=elapsed,
        detail={"checkpointer": "memory"},
    )


def run_benchmarks(
    *,
    iterations: int,
    fanout: int,
) -> tuple[LangGraphAlignmentBenchmark, ...]:
    return (
        run_sequence_composition(iterations),
        run_dynamic_send_fanout(iterations, fanout=fanout),
        run_subgraph_composition(iterations),
        run_thread_state_facade(iterations),
    )


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Agentic AI Lab benchmarks for LangGraph-aligned runtime patterns.",
    )
    parser.add_argument("--iterations", type=int, default=250)
    parser.add_argument("--fanout", type=int, default=24)
    return parser.parse_args(None if argv is None else tuple(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    if args.iterations <= 0:
        raise SystemExit("--iterations must be positive")
    if args.fanout <= 0:
        raise SystemExit("--fanout must be positive")
    for result in run_benchmarks(iterations=args.iterations, fanout=args.fanout):
        sys.stdout.write(result.receipt() + "\n")
    return 0


def _elapsed_micros(call: Callable[[], object], iterations: int) -> int:
    call()
    started = time.perf_counter_ns()
    for _index in range(iterations):
        call()
    return (time.perf_counter_ns() - started) // 1000


def _increment_state(state: Mapping[str, Any]) -> dict[str, Any]:
    return {"value": int(state.get("value", 0)) + 1}


def _empty_update(_state: Mapping[str, Any]) -> dict[str, Any]:
    return {}


def _fanout_route(state: Mapping[str, Any]) -> tuple[RuntimeGraphSend, ...]:
    return tuple(
        RuntimeGraphSend("worker", {"item": item})
        for item in state.get("items", ())
    )


def _fanout_worker(state: Mapping[str, Any]) -> dict[str, Any]:
    return {"results": [state["item"]]}


def _append_results(left: Any, right: Any) -> list[Any]:
    return list(left) + list(right)


def _receipt_value(value: object) -> str:
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
        return f"\"{escaped}\""
    return str(value)


if __name__ == "__main__":
    raise SystemExit(main())
