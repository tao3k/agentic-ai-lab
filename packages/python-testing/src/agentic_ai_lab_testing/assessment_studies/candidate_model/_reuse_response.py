# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Retain raw branch responses and reject unknown usage, reservation violations and incomplete results."

from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import digest


def _admit_branch_response(req, out, call, row, plan):
    """Own the admit branch response phase and retain its evidence checks."""
    _, meta = provider(req, provider_key(), out / "response.json")
    term = meta.get("terminal") or {}
    u = term.get("usage")
    call["usage"] = u
    thinking = "\n".join(
        p.get("text", "")
        for x in term.get("output", [])
        if x.get("type") == "reasoning"
        for p in x.get("content", [])
        if p.get("type") == "reasoning_text"
    )
    (out / "thinking.txt").write_text(thinking)
    call["thinkingSha256"] = digest(out / "thinking.txt")
    call["status"] = term.get("status")
    call["incompleteDetails"] = term.get("incomplete_details")
    call["providerError"] = meta.get("error")
    if not isinstance(u, dict) or any(
        type(u.get(k)) is not int or u[k] < 0 for k in ("input_tokens", "output_tokens")
    ):
        raise ValueError("unknown_usage")
    call["grossTokens"] = u["input_tokens"] + u["output_tokens"]
    row["grossTokens"] += call["grossTokens"]
    call["atGrossTokens"] = row["grossTokens"]
    if u["input_tokens"] > call["inputReservation"]:
        raise ValueError("input_reservation_violation")
    if (
        row["grossTokens"] > plan["budget"]
        or u["output_tokens"] > req["max_output_tokens"]
    ):
        raise ValueError("budget_violation")
    if meta.get("error") or term.get("status") != "completed":
        raise ValueError("incomplete_provider")
    return term
