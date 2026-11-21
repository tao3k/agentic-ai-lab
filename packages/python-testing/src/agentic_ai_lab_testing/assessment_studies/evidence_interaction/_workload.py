# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the evidence interaction study."""

from ._artifacts import canonical


def judge_init(judge, task):
    return judge.call(
        op="init",
        identity=task["id"],
        arm="baseline",
        edges=task["edges"],
        needs=task["needs"],
        options=task["options"],
    )


def same_check(a, b):
    for key in ("valid", "cost", "risk", "value", "depth"):
        if a.get(key) != b.get(key):
            raise ValueError("independent judge disagreement: " + key)


def request_for(plan, context):
    return {
        "model": plan["model"],
        "input": [{"role": "user", "content": canonical(context)}],
        "tools": plan["tools"],
        "tool_choice": "auto",
        "reasoning": {"effort": plan["reasoningEffort"]},
        "max_output_tokens": plan["maxOutputTokens"],
        "stream": True,
        "store": False,
    }


def independent_atom(judge, task, atom, memo):
    key = canonical(atom)
    if key in memo:
        return memo[key]
    if (
        not isinstance(atom, list)
        or len(atom) not in (2, 3)
        or atom[0] not in ("ready", "path", "edge")
        or any(type(x) is not int for x in atom[1:])
    ):
        raise ValueError("malformed label atom")
    if atom[0] == "ready":
        if len(atom) != 2 or not any(n[0] == atom[1] for n in task["needs"]):
            raise ValueError("unknown fragment")
        needs = task["needs"]
        fragment = atom[1]
        edges = task["edges"]
    else:
        if len(atom) != 3:
            raise ValueError("wrong path/edge arity")
        fragment = 0
        needs = [[0, *atom[1:], *atom[1:]]]
        # Direct-edge checking projects literal source records, not transitive inference.
        edges = (
            task["edges"]
            if atom[0] == "path"
            else [e for e in task["edges"] if e == atom[1:]]
        )
    options = [
        {"id": 0, "stage": 0, "fragment": fragment, "cost": 0, "risk": 0, "values": [0]}
    ]
    judge.call(
        op="init",
        identity=task["id"] + "-atomic-check",
        arm="baseline",
        edges=edges,
        needs=needs,
        options=options,
    )
    checked = judge.call(
        op="evaluate",
        goal={"index": 0, "stages": 1, "costLimit": 0, "riskLimit": 0, "bonuses": []},
        selection=[0],
    )
    memo[key] = checked["valid"]
    return memo[key]
