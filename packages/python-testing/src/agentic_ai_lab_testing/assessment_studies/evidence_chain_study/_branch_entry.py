# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Start each branch from the same feasible selection and verify any compact evidence roundtrip."

import json
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ._branch_contracts import branch_observe


def _branch_entry_history(plan, task, branch, arm, store, source):
    """Own the branch entry history phase and retain its evidence checks."""
    context = {
        "question": plan["question"],
        "task": {
            "edges": task["edges"],
            "items": task["items"],
            "bonuses": task["bonuses"],
        },
        "branch": branch,
    }
    supplied = []
    entry_packet = None
    if plan.get("evidenceAtBranchEntry") and arm != "baseline":
        entry_packet = branch_observe(store, task, source, support=arm == "scheme")
        context["nativeEvidence"] = entry_packet
        if plan.get("compactEvidence"):
            from agentic_ai_lab_runtime.reasoning import (
                compact_observation,
                expand_observation,
            )

            context["nativeEvidence"] = compact_observation(entry_packet)
            assert expand_observation(context["nativeEvidence"]) == entry_packet
        supplied = [
            o["conclusion"]["atom"]
            for o in entry_packet["observations"]
            if o["conclusion"]["status"] == "verified"
        ]
    history = ResponseHistory(json.dumps(context, separators=(",", ":")))
    return context, history, supplied, entry_packet
