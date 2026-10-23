# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import subprocess
import sys

from agentic_ai_lab_benchmarks.comparison import COMPARISONS
from agentic_ai_lab_benchmarks.common import Report
from agentic_ai_lab_benchmarks.report import render_text
from agentic_ai_lab_benchmarks.registry import all_cases, select_cases


def test_registry_exposes_unique_framework_case_ids() -> None:
    cases = all_cases()

    assert len(cases) == 14
    assert len({case.name for case in cases}) == len(cases)
    assert {case.family for case in cases} == {
        "crewai-native",
        "langchain-native",
        "langgraph-native",
        "agentic-ai-lab-executor",
    }


def test_registry_selects_by_framework_and_case_id() -> None:
    langchain_cases = select_cases(frameworks={"langchain"})
    router_case = select_cases(case_ids={"langgraph-router-agent-native"})

    assert {case.name for case in langchain_cases} == {
        "langchain-linear-agent-native",
        "langchain-branch-tool-native",
    }
    assert [case.name for case in router_case] == ["langgraph-router-agent-native"]


def test_comparisons_reference_registered_cases() -> None:
    registered = {case.name for case in all_cases()}

    assert COMPARISONS
    assert all(spec.native_case in registered for spec in COMPARISONS)
    assert all(spec.agentic_ai_lab_case in registered for spec in COMPARISONS)


def test_modular_cli_lists_every_registered_case() -> None:
    completed = subprocess.run(
        [sys.executable, "-m", "agentic_ai_lab_benchmarks", "--list"],
        check=True,
        capture_output=True,
        text=True,
    )
    listed = {
        line.split("\t", maxsplit=1)[1]
        for line in completed.stdout.splitlines()
        if line
    }

    assert listed == {case.name for case in all_cases()}


def test_text_report_does_not_advertise_retired_graph_cabi_gates() -> None:
    report = Report(
        generated_at="2026-07-12T00:00:00+00:00",
        command="benchmark",
        python="3.13",
        platform="test",
        iterations=1,
        warmup=0,
        gc_enabled_during_measurement=False,
        case_caps_enabled=False,
        results=(),
        failures=(),
        gates=(),
    )

    assert "CABI GATES" not in render_text(report)
