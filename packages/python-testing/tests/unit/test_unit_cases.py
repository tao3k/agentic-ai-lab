# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run registered Python-only module cases."""

from __future__ import annotations

from pathlib import Path

import pytest

from agentic_ai_lab_testing import CaseContext
from agentic_ai_lab_testing.catalog import build_catalog

ROOT = Path(__file__).resolve().parents[4]


@pytest.mark.parametrize("case", build_catalog().select(mode="unit"),
                         ids=lambda case: case.spec.identity)
def test_unit_case(case) -> None:
    case.check(CaseContext(ROOT, {}))
