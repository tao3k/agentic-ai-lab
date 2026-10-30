# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Decode one unambiguous permitted-transition answer and reject malformed or duplicate IDs."

import json


def shared_action(terminal):
    def unique(items):
        d = {}
        for k, v in items:
            if k in d:
                raise ValueError("duplicate answer key")
            d[k] = v
        return d

    out = terminal.get("output", [])
    calls = [x for x in out if x.get("type") == "function_call"]
    if calls:
        assert len(calls) == 1 and calls[0]["name"] == "submit_answer", (
            "ambiguous action"
        )
        payload = calls[0]["arguments"]
    else:
        messages = [x for x in out if x.get("type") == "message"]
        assert len(messages) == 1, "missing action"
        parts = messages[0]["content"]
        assert parts and all(p["type"] == "output_text" for p in parts)
        payload = "".join(p["text"] for p in parts)
    answer = json.loads(payload, object_pairs_hook=unique)
    assert set(answer) == {"permitted"} and isinstance(answer["permitted"], list), (
        "invalid answer schema"
    )
    assert all(type(i) is int for i in answer["permitted"]) and len(
        set(answer["permitted"])
    ) == len(answer["permitted"]), "invalid IDs"
    return answer["permitted"], calls
