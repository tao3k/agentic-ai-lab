# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Choose the predeclared source-only or evidence operation surface."

from agentic_ai_lab_runtime.reasoning import EvidenceOperation


def _source_operations(case, arm):
    """Own the source operations phase and retain its evidence checks."""
    operations = case["operations"]
    if arm == "source-only":
        operations = {
            s["name"]: EvidenceOperation(
                {"relations": case["sources"], "rules": [], "queries": []},
                s["name"],
                "Arguments are a ground tuple in source "
                + s["name"]
                + ". Checks source membership only.",
                True,
            )
            for s in case["sources"]
        }
    return operations
