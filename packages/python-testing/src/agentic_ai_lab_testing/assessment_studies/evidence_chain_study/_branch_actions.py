# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Check requested paths against native evidence and independently grade every submitted branch selection."

import json
from ._branch_contracts import branch_grade, branch_payload
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_truth


def _apply_branch_actions(
    calls,
    terminal,
    history,
    arm,
    step,
    plan,
    store,
    source,
    task,
    branch,
    row,
    rec,
    done,
    prior_usage,
    new_results,
    supplied,
):
    """Own the apply branch actions phase and retain its evidence checks."""
    if calls and all(x["name"] == "read_paths" for x in calls):
        assert arm != "baseline" and step + 1 < plan["maxCallsPerBranch"], (
            "unresolved read at call bound"
        )
        packets = []
        for c in calls:
            args = json.loads(c["arguments"])
            assert (
                set(args) == {"pairs"}
                and isinstance(args["pairs"], list)
                and 0 < len(args["pairs"]) <= 32
            )
            assert all(
                isinstance(p, list) and len(p) == 2 and all(type(n) is int for n in p)
                for p in args["pairs"]
            ), "unknown path request"
            hit = store.resolve(source, SHARED_CANDIDATE)
            assert hit["status"] == "verified"
            packet = store.observe(
                source,
                SHARED_CANDIDATE,
                hit["handle"],
                [["path", *p] for p in args["pairs"]],
                support=arm == "scheme",
            )
            for o in packet["observations"]:
                f = o["conclusion"]
                assert f["status"] in (
                    "verified",
                    "finite-absent",
                )
                assert (f["status"] == "verified") == shared_truth(task, f["atom"])
                if f["status"] == "verified" and f["atom"] not in supplied:
                    supplied.append(f["atom"])
            history.append_result(c["call_id"], packet)
            packets.append(packet)
        rec["nativePacket"] = {
            "returnedToolPackets": packets,
            "nativeStats": store.stats(),
        }
        prior_usage = rec["grossTokens"]
        new_results = history.snapshot()[-len(calls) :]
    else:
        if calls:
            assert len(calls) == 1 and calls[0]["name"] == "submit_selection", (
                "mixed or unknown tool calls"
            )
            payload = json.loads(calls[0]["arguments"])
        else:
            messages = [
                p["text"]
                for x in terminal["output"]
                if x["type"] == "message"
                for p in x.get("content", [])
                if p.get("type") == "output_text"
            ]
            assert len(messages) == 1, "one answer required"
            payload = json.loads(messages[0])
        assert isinstance(payload, dict) and set(payload) == {"selected"}, (
            "selection schema"
        )
        selected = branch_payload(terminal)
        grade = branch_grade(task, branch, selected)
        for c in calls:
            history.append_result(c["call_id"], {"recorded": True})
        row["branches"].append(
            {
                "turn": branch["id"],
                "selected": selected,
                "grade": grade,
                "atGrossTokens": row["grossTokens"],
                "startScore": branch_grade(task, branch, branch["start"])["score"],
            }
        )
        done = True
    return done, prior_usage, new_results
