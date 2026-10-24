# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Registry selection and missing-module reporting contracts."""

from __future__ import annotations

import pytest

from agentic_ai_lab_testing import CaseRegistry, CaseSpec, ModulePart
from agentic_ai_lab_testing.catalog import build_catalog

def test_catalog_selects_single_part_and_cross_module_cases() -> None:
    catalog = build_catalog()
    selected = catalog.select(module="gerbil-ascent", part="candidate/reasoning")
    assert {case.spec.identity for case in selected} == {
        "ascent.source-withdrawal", "runtime-ascent.candidate-graph"
    }
    cross = catalog.select(composition="cross")
    assert {case.spec.identity for case in cross} == {
        "runtime-ascent.candidate-graph", "evidence-ascent.hypothesis-status",
        "model-study.native-fixtures",
    }
    assert all(len({target.module for target in case.spec.targets}) > 1 for case in cross)
    assert catalog.select(identity="ascent.source-withdrawal")[0].spec.mode == "native"


def test_session_native_cases_register_the_two_quint_models() -> None:
    catalog = build_catalog()
    assert {case.spec.identity for case in catalog.select(module="session", mode="native")} == {
        "session.quint-lifecycle", "session.quint-worktree"
    }


def test_registry_rejects_ambiguous_declarations() -> None:
    target = ModulePart("gerbil-ascent", "candidate/reasoning")
    with pytest.raises(ValueError, match="distinct"):
        CaseSpec("duplicate.targets", (target, target))
    with pytest.raises(ValueError, match="module"):
        ModulePart("../escape", "reasoning")
    assert ModulePart("cubeSandbox", "bridge").module == "cubeSandbox"
    catalog = CaseRegistry()
    case = CaseSpec("one.case", (target,))
    catalog.register(case, lambda _context: None)
    with pytest.raises(ValueError, match="duplicate"):
        catalog.register(case, lambda _context: None)


def test_coverage_lists_unregistered_public_modules(tmp_path) -> None:
    for module in ("covered", "uncovered"):
        directory = tmp_path / "modules" / module
        directory.mkdir(parents=True)
        (directory / "interface.ss").write_text("", encoding="utf-8")
    catalog = CaseRegistry()
    catalog.register(CaseSpec("covered.case", (ModulePart("covered", "part"),)),
                     lambda _context: None)
    assert list(catalog.module_coverage(tmp_path)) == [
        ("covered", ("covered.case",)), ("uncovered", ())
    ]
