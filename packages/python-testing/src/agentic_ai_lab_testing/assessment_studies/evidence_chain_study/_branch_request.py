# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Reserve full request and finalization costs before permitting any branch provider call."

from ._branch_qualification import branch_entry_reservation, branch_input_reservation


def _reserve_branch_request(
    plan, history, arm, step, entry_request, entry_input, prior_usage, new_results, row
):
    """Own the reserve branch request phase and retain its evidence checks."""
    req = {
        "model": plan["model"],
        "input": history.input(),
        "tools": [plan["tool"]] + ([plan["readTool"]] if arm != "baseline" else []),
        "tool_choice": "auto"
        if step == 0
        else {
            "type": "function",
            "name": "submit_selection",
        },
        "reasoning": {"effort": plan["reasoningEffort"] if step == 0 else "none"},
        "stream": True,
        "store": False,
    }
    if plan.get("evidenceAtBranchEntry"):
        req["tools"] = [plan["tool"]]
    bound = (
        branch_entry_reservation(
            req,
            entry_request,
            entry_input,
            plan["inputPadding"],
        )
        if step == 0
        else branch_input_reservation(
            req,
            prior_usage,
            new_results,
            plan["inputPadding"],
        )
    )
    available = plan["totalBudget"] - row["grossTokens"] - bound
    reserve = (
        bound
        + plan["maxOutputTokens"]
        + plan["inputPadding"]
        + plan["finalizationOutputCap"]
        if step == 0 and not plan.get("requireCompleteThinking")
        else 0
    )
    cap = min(
        plan["maxOutputTokens"] if step == 0 else plan["finalizationOutputCap"],
        available - reserve,
    )
    return req, bound, available, reserve, cap
