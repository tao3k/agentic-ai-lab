# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Session and Worktree proof orchestration through the shared Quint gate."""
from ..model import CaseContext, CaseEvidence
from .quint import check_quint
from .quint_cases import GROUPS


def check_quint_model(context: CaseContext, model: str) -> CaseEvidence:
    cases = [c for c in GROUPS["session"] if c.model.startswith(model + "_")]
    if not cases:
        raise ValueError("unknown Session Quint model: " + model)
    return CaseEvidence({"model": model,
                         "runs": [dict(check_quint(context, c).details) for c in cases]})
