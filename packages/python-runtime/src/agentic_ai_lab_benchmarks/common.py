# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Benchmark native LangChain/LangGraph flows against Agentic AI Lab runtime surfaces.

The benchmark intentionally avoids real LLM/network calls. It measures framework
orchestration, graph execution, runtime handoff, and C ABI materialization costs
for deterministic agent-flow shapes.
"""
from __future__ import annotations
import argparse
import gc
import json
import operator
import platform
import statistics
import sys
import time
import traceback
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, Any, TypedDict
Subject = Callable[[int], Any]

@dataclass(frozen=True)
class BenchmarkCase:
    name: str
    family: str
    description: str
    features: tuple[str, ...]
    make_subject: Callable[[], Subject]
    max_iterations: int | None = None

@dataclass(frozen=True)
class BenchmarkResult:
    name: str
    family: str
    description: str
    features: tuple[str, ...]
    iterations: int
    warmup: int
    mean_us: float
    p50_us: float
    p95_us: float
    min_us: float
    max_us: float
    ops_per_second: float
    checksum: int

@dataclass(frozen=True)
class BenchmarkFailure:
    name: str
    family: str
    description: str
    features: tuple[str, ...]
    phase: str
    error_type: str
    error: str

@dataclass(frozen=True)
class GateCheck:
    name: str
    family: str
    description: str
    features: tuple[str, ...]
    status: str
    receipt: str = ''
    error_type: str = ''
    error: str = ''

@dataclass(frozen=True)
class Report:
    generated_at: str
    command: str
    python: str
    platform: str
    iterations: int
    warmup: int
    gc_enabled_during_measurement: bool
    case_caps_enabled: bool
    results: tuple[BenchmarkResult, ...] = field(default_factory=tuple)
    failures: tuple[BenchmarkFailure, ...] = field(default_factory=tuple)
    gates: tuple[GateCheck, ...] = field(default_factory=tuple)

class AgentRouterState(TypedDict, total=False):
    session_id: str
    question: str
    intent: str
    documents: list[str]
    tool_result: str
    answer: str
    trace: list[str]

class HandoffState(TypedDict, total=False):
    tasks: list[str]
    messages: Annotated[list[str], operator.add]
    task: str
    final: str

class ApprovalState(TypedDict, total=False):
    approved: bool
    draft: str
    final: str

class LongGraphState(TypedDict, total=False):
    value: int
    trace: Annotated[list[str], operator.add]

def _linear_node_names(count: int=32) -> tuple[str, ...]:
    return tuple((f'step_{index:02d}' for index in range(count)))

def _agent_input(iteration: int) -> dict[str, str]:
    mode = iteration % 3
    if mode == 0:
        question = 'Need docs for durable checkpoint policy and proof receipt.'
    elif mode == 1:
        question = 'Ask tool permission scope before running sandbox command.'
    else:
        question = 'Escalate a risky patch to a reviewer for approval.'
    return {'session_id': f'session-{iteration % 64}', 'question': question}

def _classify(question: str) -> str:
    lower = question.lower()
    if 'docs' in lower or 'checkpoint' in lower or 'proof' in lower:
        return 'rag'
    if 'tool' in lower or 'sandbox' in lower or 'permission' in lower:
        return 'tool'
    return 'handoff'

def _checksum(value: Any) -> int:
    if value is None:
        return 0
    if isinstance(value, Mapping):
        total = 17
        for key in sorted(value.keys(), key=str):
            total = (total * 131 + len(str(key)) + _checksum(value[key])) % 1000003
        return total
    if isinstance(value, (list, tuple)):
        total = 19
        for item in value:
            total = (total * 131 + _checksum(item)) % 1000003
        return total
    return len(str(value)) % 1000003

def _percentile(sorted_values: Sequence[float], percentile: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return sorted_values[0]
    rank = (len(sorted_values) - 1) * percentile
    lower = int(rank)
    upper = min(lower + 1, len(sorted_values) - 1)
    weight = rank - lower
    return sorted_values[lower] * (1.0 - weight) + sorted_values[upper] * weight

def _run_case(case: BenchmarkCase, *, iterations: int, warmup: int, keep_gc: bool) -> BenchmarkResult | BenchmarkFailure:
    try:
        subject = case.make_subject()
    except Exception as exc:
        return _failure(case, 'setup', exc)
    try:
        for index in range(warmup):
            subject(index)
    except Exception as exc:
        return _failure(case, 'warmup', exc)
    durations_us: list[float] = []
    checksum = 0
    was_gc_enabled = gc.isenabled()
    if not keep_gc:
        gc.disable()
    try:
        for index in range(iterations):
            started = time.perf_counter_ns()
            value = subject(index)
            ended = time.perf_counter_ns()
            durations_us.append((ended - started) / 1000.0)
            checksum = (checksum + _checksum(value)) % 1000003
    except Exception as exc:
        return _failure(case, 'measure', exc)
    finally:
        if was_gc_enabled and (not keep_gc):
            gc.enable()
    ordered = sorted(durations_us)
    mean_us = statistics.fmean(durations_us) if durations_us else 0.0
    return BenchmarkResult(name=case.name, family=case.family, description=case.description, features=case.features, iterations=iterations, warmup=warmup, mean_us=mean_us, p50_us=_percentile(ordered, 0.5), p95_us=_percentile(ordered, 0.95), min_us=min(durations_us) if durations_us else 0.0, max_us=max(durations_us) if durations_us else 0.0, ops_per_second=1000000.0 / mean_us if mean_us else 0.0, checksum=checksum)

def _failure(case: BenchmarkCase, phase: str, exc: Exception) -> BenchmarkFailure:
    return BenchmarkFailure(name=case.name, family=case.family, description=case.description, features=case.features, phase=phase, error_type=type(exc).__name__, error=str(exc))
