# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tasks for the candidate model study."""

import json
from ._config import TASKS, TOOL


def task(case, examples):
    return {
        **TASKS[case],
        "sourceRelations": [["edge", 2]]
        + ([["left", 1], ["right", 1]] if case == 2 else []),
        "domain": [0, 1, 2],
        "ruleEncoding": "A rule is [headAtom, bodyAtom1, ...]. An atom is [relationName, argument1, ...]. Strings beginning ? are variables. Other argument values are integer constants. All body atoms are positive and conjunctive. Rules are evaluated to their least fixed point using set semantics. Only declared relations are allowed. The host supplies declarations, the fixed query and limits; submit only rules.",
        "examples": [
            {"edges": r["edges"], "queryRows": r["expected"]} for r in examples
        ],
    }


def request(context):
    return {
        "model": "deepseek-flash",
        "input": [
            {"role": "user", "content": json.dumps(context, separators=(",", ":"))}
        ],
        "tools": [TOOL],
        "tool_choice": "auto",
        "reasoning": {"effort": "low"},
        "max_output_tokens": 8192,
        "stream": True,
        "store": False,
    }


# Bounded consumer experiment only. Library owns computational evidence;
# this host fixture owns the search objective and the independent judge.
def study_annotations():
    # Reuse the canonical annotation API, without a second loader epoch.
    from .. import evidence_interaction

    return evidence_interaction


def branch_request(plan, context, history, pending_call, spent, history_tokens=None):
    """Provider framing and budget reservation only; no search or truth decisions."""
    if not history:
        inputs = [
            {"role": "user", "content": json.dumps(context, separators=(",", ":"))}
        ]
        new_items = inputs
    else:
        # The immutable task and original question remain in the first message.
        # Feed the observed state back as the result of the chosen extension.
        state = {k: v for k, v in context.items() if k not in ("task", "question")}
        if pending_call is not None:
            new_items = [
                {
                    "type": "function_call_output",
                    "call_id": pending_call,
                    "output": json.dumps(state, separators=(",", ":")),
                },
                {
                    "role": "user",
                    "content": json.dumps(
                        {"question": context["question"]}, separators=(",", ":")
                    ),
                },
            ]
        else:
            new_items = [
                {
                    "role": "user",
                    "content": json.dumps(
                        {"extensionResult": state, "question": context["question"]},
                        separators=(",", ":"),
                    ),
                }
            ]
        inputs = history + new_items
    req = {
        "model": plan["model"],
        "input": inputs,
        "tools": [plan["tool"]],
        "tool_choice": "auto",
        "reasoning": {"effort": "low"},
        "max_output_tokens": plan["outputCap"],
        "stream": True,
        "store": False,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "branch_action",
                "schema": plan["tool"]["parameters"],
            }
        },
    }
    if not history:
        input_bound = (
            len(json.dumps(req, ensure_ascii=False).encode())
            + plan["inputReservationPadding"]
        )
    else:
        assert type(history_tokens) is int and history_tokens >= 0, (
            "missing_history_usage"
        )
        # The previous billed input plus output bounds the replayed token text.
        # Reserve new tool-result bytes and framing; do not multiply old thinking
        # tokens by its JSON byte length on every continuation.
        input_bound = (
            history_tokens
            + sum(
                len(json.dumps(item, ensure_ascii=False).encode()) for item in new_items
            )
            + plan["inputReservationPadding"]
        )
    cap = min(plan["outputCap"], plan["budget"] - spent - input_bound)
    if cap < plan["minimumOutputCap"]:
        return None, input_bound + plan["minimumOutputCap"]
    req["max_output_tokens"] = cap
    return req, input_bound + cap


def branch_action(terminal):
    """Decode one untrusted action; semantic admission remains with the judge."""
    outputs = terminal.get("output", [])

    def unique_object(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate_action_key")
            value[key] = item
        return value

    calls = [x for x in outputs if x.get("type") == "function_call"]
    if calls:
        assert len(calls) == 1 and calls[0].get("name") == "expand", "invalid_action"
        call_id = calls[0].get("call_id")
        assert isinstance(call_id, str) and call_id, "missing_call_id"
        action = json.loads(calls[0]["arguments"], object_pairs_hook=unique_object)
        encoding = "function_call"
    else:
        messages = [x for x in outputs if x.get("type") == "message"]
        assert len(messages) == 1, "invalid_action"
        parts = messages[0].get("content", [])
        assert parts and all(
            x.get("type") == "output_text" and isinstance(x.get("text"), str)
            for x in parts
        ), "invalid_action_content"
        action = json.loads(
            "".join(x["text"] for x in parts), object_pairs_hook=unique_object
        )
        encoding = "json_message"
        call_id = None
    assert (
        isinstance(action, dict)
        and set(action) == {"parentId", "optionId"}
        and all(type(v) is int for v in action.values())
    ), "invalid_submission"
    return action, encoding, call_id
