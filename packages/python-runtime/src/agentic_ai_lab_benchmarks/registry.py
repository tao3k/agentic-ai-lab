# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Stable registry and selection rules for framework benchmark cases."""

from collections.abc import Iterable

from . import crewai, langchain, langgraph, agentic_ai_lab
from .model import BenchmarkCase

_FRAMEWORKS = {
    "langchain": langchain.cases,
    "langgraph": langgraph.cases,
    "crewai": crewai.cases,
    "agentic-ai-lab": agentic_ai_lab.cases,
}


def all_cases() -> tuple[BenchmarkCase, ...]:
    return tuple(case for factory in _FRAMEWORKS.values() for case in factory())


def select_cases(
    frameworks: Iterable[str] = (), case_ids: Iterable[str] = (),
) -> tuple[BenchmarkCase, ...]:
    framework_filter = frozenset(frameworks)
    case_filter = frozenset(case_ids)
    unknown = framework_filter.difference(_FRAMEWORKS)
    if unknown:
        raise ValueError(f"unknown benchmark framework: {sorted(unknown)!r}")
    selected = tuple(
        case for framework, factory in _FRAMEWORKS.items()
        for case in factory()
        if (not framework_filter or framework in framework_filter)
        and (not case_filter or case.name in case_filter)
    )
    missing = case_filter.difference(case.name for case in selected)
    if missing:
        raise ValueError(f"unknown benchmark case: {sorted(missing)!r}")
    return selected
