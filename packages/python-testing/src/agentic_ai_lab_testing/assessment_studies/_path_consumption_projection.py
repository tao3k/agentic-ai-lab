# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Decode original path feedback and account for reported thinking without fabricating missing usage."

import hashlib
import copy
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import expand_feedback


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def count_thinking(call):
    return (
        (call.get("usage") or {})
        .get("output_tokens_details", {})
        .get("reasoning_tokens")
    )


def decode_historical(packet):
    if packet.get("encoding") != "ascent.branch-columns.v1":
        return expand_feedback(packet)
    packet = copy.deepcopy(packet)
    packet.pop("encoding")
    groups = packet.pop("groups")
    order = packet.pop("branchOrder")
    rows = []
    for group in groups:
        for values, present in zip(group["rows"], group["present"]):
            rows.append(
                {
                    **group["common"],
                    **{k: v for k, v, p in zip(group["fields"], values, present) if p},
                }
            )
    by_id = {b["id"]: b for b in rows}
    packet["branches"] = [by_id[i] for i in order]
    return packet
