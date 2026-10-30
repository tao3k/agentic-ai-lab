# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run registered unit and native cases through one contract."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from agentic_ai_lab_testing import CaseContext
from agentic_ai_lab_testing.catalog import build_catalog

ROOT = Path(__file__).resolve().parents[4]
CATALOG = build_catalog()


def context() -> CaseContext:
    roots = {}
    if os.environ.get("ASCENT_TEST_ROOT"):
        roots["gerbil-ascent"] = Path(os.environ["ASCENT_TEST_ROOT"])
    if os.environ.get("POO_TEST_PARSER_ROOT"):
        roots["gerbil-parser"] = Path(os.environ["POO_TEST_PARSER_ROOT"])
    return CaseContext(ROOT, roots)


@pytest.mark.parametrize("case", CATALOG.select(mode="native"),
                         ids=lambda case: case.spec.identity)
def test_native_case(case) -> None:
    if not os.environ.get("ASCENT_TEST_ROOT"):
        pytest.skip("ASCENT_TEST_ROOT selects a native Ascent checkout")
    if case.spec.identity == "evidence-ascent.hypothesis-status" and not os.environ.get(
            "POO_TEST_PARSER_ROOT"):
        pytest.skip("POO_TEST_PARSER_ROOT selects the pinned parser source")
    case.check(context())
