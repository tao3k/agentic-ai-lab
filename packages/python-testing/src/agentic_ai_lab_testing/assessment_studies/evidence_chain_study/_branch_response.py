# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Retain raw branch thinking and reject unknown, over-reserved or failed provider usage."

import copy, hashlib
from ..model_study import provider
from ..movie_study import provider_key


def _admit_branch_response(
    req, folder, rec, row, step, entry_request, entry_input, bound, cap, plan
):
    """Own the admit branch response phase and retain its evidence checks."""
    _, meta = provider(req, provider_key(), folder / "response.json")
    terminal = meta.get("terminal") or {}
    u = terminal.get("usage")
    rec.update(
        status=terminal.get("status"),
        usage=u,
        providerError=meta.get("error"),
        incompleteDetails=terminal.get("incomplete_details"),
    )
    thinking = "".join(
        p.get("text", "")
        for x in terminal.get("output", [])
        if x.get("type") == "reasoning"
        for p in x.get("content", [])
        if p.get("type") == "reasoning_text"
    )
    (folder / "thinking.txt").write_text(thinking)
    rec["thinkingSha256"] = hashlib.sha256(thinking.encode()).hexdigest()
    assert isinstance(u, dict) and all(
        type(u.get(k)) is int and u[k] >= 0 for k in ("input_tokens", "output_tokens")
    ), "unknown usage"
    rec["grossTokens"] = u["input_tokens"] + u["output_tokens"]
    row["grossTokens"] += rec["grossTokens"]
    rec["atGrossTokens"] = row["grossTokens"]
    if step == 0:
        entry_request = copy.deepcopy(req)
        entry_input = u["input_tokens"]
    assert (
        u["input_tokens"] <= bound
        and u["output_tokens"] <= cap
        and row["grossTokens"] <= plan["totalBudget"]
    ), "budget violation"
    assert not meta.get("error"), "provider failure"
    return terminal, entry_request, entry_input
