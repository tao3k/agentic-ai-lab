# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch contracts for the evidence chain study study."""

import copy, json
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_truth


def branch_grade(task, branch, selected):
    if (
        not isinstance(selected, list)
        or len(selected) != 4
        or any(type(x) is not int for x in selected)
        or len(set(selected)) != 4
    ):
        return {
            "feasible": False,
            "score": None,
            "reason": "four distinct integer IDs required",
        }
    by_id = {x["id"]: x for x in task["items"]}
    if any(x not in by_id for x in selected):
        return {"feasible": False, "score": None, "reason": "unknown ID"}
    chosen = [by_id[x] for x in selected]
    ids = set(selected)
    checks = [
        all(shared_truth(task, ["ready", x]) for x in ids),
        sum(x["weight"] for x in chosen) <= branch["weightLimit"],
        sum(x["risk"] for x in chosen) <= branch["riskLimit"],
        len({x["group"] for x in chosen}) >= 3,
        branch["required"] in ids,
        branch["excluded"] not in ids,
    ]
    if not all(checks):
        return {
            "feasible": False,
            "score": None,
            "reason": "constraint violation",
            "checks": checks,
        }
    score = sum(x["value"] for x in chosen) + sum(
        x["value"] for x in task["bonuses"] if set(x["pair"]) <= ids
    )
    return {"feasible": True, "score": score, "reason": None}


def branch_candidates(task, branch):
    from itertools import combinations

    return [
        (r["score"], list(ids))
        for ids in combinations(range(len(task["items"])), 4)
        if (r := branch_grade(task, branch, list(ids)))["feasible"]
    ]


def branch_observe(store, task, source, *, support):
    """Read all required path atoms through the public native binding before a branch."""
    resolved = store.resolve(source, SHARED_CANDIDATE)
    assert resolved["status"] == "verified"
    atoms = list(
        dict.fromkeys(
            tuple(["path", *pair]) for x in task["items"] for pair in x["paths"]
        )
    )
    packet = store.observe(
        source,
        SHARED_CANDIDATE,
        resolved["handle"],
        [list(a) for a in atoms],
        support=support,
    )
    return packet


def branch_payload(terminal):
    calls = [x for x in terminal.get("output", []) if x.get("type") == "function_call"]
    assert len(calls) == 1 and calls[0]["name"] == "submit_selection", (
        "one selection tool required"
    )

    def unique(pairs):
        result = {}
        for key, value in pairs:
            assert key not in result, "duplicate selection key"
            result[key] = value
        return result

    payload = json.loads(calls[0]["arguments"], object_pairs_hook=unique)
    assert isinstance(payload, dict) and set(payload) == {"selected"}, (
        "selection schema"
    )
    assert isinstance(payload["selected"], list) and len(payload["selected"]) == 4
    assert (
        all(type(x) is int for x in payload["selected"])
        and len(set(payload["selected"])) == 4
    )
    return payload["selected"]


def branch_partial_output(terminal):
    """Only complete opaque reasoning items may be replayed after a known output limit.

    Partial messages/tool calls are not salvaged as answers. Their raw output is
    retained in the receipt. No new instructions or synthetic tool results.
    """
    assert terminal.get("status") == "incomplete"
    assert (terminal.get("incomplete_details") or {}).get(
        "reason"
    ) == "max_output_tokens"
    output = terminal.get("output", [])
    assert output and all(x.get("type") == "reasoning" for x in output), (
        "partial nonreasoning output"
    )
    return copy.deepcopy(output)


def branch_submission_context(terminal):
    """Lossless visible replay for a non-thinking output phase.

    The provider may ignore opaque reasoning items with effort none. Preserve
    their exact text as an ordinary assistant message; add no instructions.
    """
    items = (
        branch_partial_output(terminal)
        if terminal.get("status") == "incomplete"
        else terminal["output"]
    )
    parts = []
    for item in items:
        for part in item.get("content", []):
            assert item.get("type") in ("reasoning", "message") and part.get(
                "type"
            ) in ("reasoning_text", "output_text"), "unsupported submission content"
            parts.append(part["text"])
    text = "".join(parts)
    assert text, "no visible reasoning to submit"
    return [
        {
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": text}],
        }
    ]
