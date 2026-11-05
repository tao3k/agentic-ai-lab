# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Repository-owned case registrations; add each module at its semantic owner."""

from __future__ import annotations

from .checks.ascent import candidate_boundary, runtime_withdrawal
from .checks.cross import runtime_ascent_candidate
from .checks.evidence import evidence_assessment
from .checks.model_study import runtime_fixtures
from .checks.runtime import graph_transport
from .checks.session import check_quint_model
from .model import CaseSpec, ModulePart
from .registry import CaseRegistry


def build_catalog() -> CaseRegistry:
    catalog = CaseRegistry()
    catalog.register(
        CaseSpec("ascent.candidate-boundary",
                 (ModulePart("gerbil-ascent", "candidate/parser"),)),
        candidate_boundary,
    )
    catalog.register(
        CaseSpec("ascent.source-withdrawal",
                 (ModulePart("gerbil-ascent", "candidate/checked-program"),), "runtime"),
        runtime_withdrawal,
    )
    catalog.register(
        CaseSpec("runtime.graph-transport",
                 (ModulePart("python-runtime", "graph/transport"),)),
        graph_transport,
    )
    catalog.register(
        CaseSpec("runtime-ascent.candidate-graph",
                 (ModulePart("python-runtime", "graph/execution"),
                  ModulePart("gerbil-ascent", "candidate/checked-program")), "runtime"),
        runtime_ascent_candidate,
    )
    catalog.register(
        CaseSpec("evidence-ascent.hypothesis-status",
                 (ModulePart("evidence-assessment", "hypothesis/status"),
                  ModulePart("gerbil-ascent", "program/evaluation")), "runtime"),
        evidence_assessment,
    )
    catalog.register(
        CaseSpec("model-study.runtime-fixtures",
                 (ModulePart("gerbil-ascent", "candidate/finite-evidence"),
                  ModulePart("temporal-causality", "classification")),
                 "runtime"),
        runtime_fixtures,
    )
    catalog.register(CaseSpec("session.quint-lifecycle",
                              (ModulePart("session", "proof/quint/lifecycle"),), "runtime"),
                     lambda context: check_quint_model(context, "ContextSession"))
    catalog.register(CaseSpec("session.quint-worktree",
                              (ModulePart("session", "proof/quint/worktree"),), "runtime"),
                     lambda context: check_quint_model(context, "WorktreeContext"))
    return catalog
