# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Independent selection truth and optimum; its original AST remains authority."""


def reachable(edges, a, b):
    pending = [v for u, v in edges if u == a]
    seen = set()
    while pending:
        v = pending.pop()
        if v == b:
            return True
        if v not in seen:
            seen.add(v)
            pending += [y for x, y in edges if x == v]
    return False


def ready(task, f):
    n = next(n for n in task["needs"] if n[0] == f)
    return reachable(task["edges"], n[1], n[2]) and reachable(task["edges"], n[3], n[4])


def search_task(case):
    import random

    rng = random.Random(713 + case)
    edges = [
        [0, 2],
        [1, 3],
        [2, 4],
        [3, 4],
        [0, 5],
        [5, 4],
        [4, 6],
        [6, 7],
        [8, 9],
        [9, 11],
        [8, 10],
        [10, 11],
        [12, 13],
        [13, 14],
    ]
    if case:
        edges.remove([9, 11])
    needs = [
        [i, *pair]
        for i, pair in enumerate(
            [
                (0, 7, 8, 11),
                (1, 7, 8, 11),
                (2, 7, 10, 11),
                (3, 7, 8, 11),
                (0, 7, 9, 11),
                (1, 7, 10, 11),
                (12, 14, 0, 7),
                (12, 14, 8, 11),
                (7, 0, 8, 11),
                (0, 7, 11, 8),
                (0, 14, 8, 11),
                (12, 14, 7, 0),
            ]
        )
    ]
    options = []
    for stage in range(8):
        options.append(
            {
                "id": stage * 4,
                "stage": stage,
                "fragment": stage % 4,
                "cost": 1,
                "risk": 1,
                "value": 9 + stage % 3,
            }
        )
        for j in (1, 2, 3):
            options.append(
                {
                    "id": stage * 4 + j,
                    "stage": stage,
                    "fragment": rng.randrange(12),
                    "cost": rng.randrange(3, 10),
                    "risk": rng.randrange(1, 7),
                    "value": rng.randrange(22, 64),
                }
            )
    bonuses = [
        {
            "pair": [a * 4 + rng.randrange(1, 4), z * 4 + rng.randrange(1, 4)],
            "value": rng.randrange(16, 41),
        }
        for a, z in [(0, 3), (1, 5), (2, 6), (3, 7), (0, 7), (2, 5), (4, 6), (1, 4)]
    ]
    return {
        "id": f"library-crosspath-{case}",
        "edges": edges,
        "needs": needs,
        "options": options,
        "stages": 8,
        "costLimit": 31,
        "riskLimit": 21,
        "bonuses": bonuses,
        "seed": [i * 4 for i in range(8)],
        "semantics": "path(a,b) is positive-length directed reachability. need(f,a,b,c,d) makes ready(f) true iff path(a,b) and path(c,d). A solution selects exactly one option per stage; each selected fragment must be ready. Sum cost and risk must fit the limits. Maximize sum value plus bonuses whose two option IDs are both selected.",
    }


def judge_selection(task, selection, complete=False):
    options = {x["id"]: x for x in task["options"]}
    if not isinstance(selection, list) or any(
        type(i) is not int or i not in options for i in selection
    ):
        return {"valid": False, "reason": "invalid_ids"}
    chosen = [options[i] for i in selection]
    if (
        any(x["stage"] != i for i, x in enumerate(chosen))
        or len(chosen) > task["stages"]
    ):
        return {"valid": False, "reason": "stage_order"}
    cost = sum(x["cost"] for x in chosen)
    risk = sum(x["risk"] for x in chosen)
    valid = (
        cost <= task["costLimit"]
        and risk <= task["riskLimit"]
        and all(ready(task, x["fragment"]) for x in chosen)
    )
    return {
        "valid": valid and (not complete or len(chosen) == task["stages"]),
        "cost": cost,
        "risk": risk,
        "depth": len(chosen),
        "value": sum(x["value"] for x in chosen)
        + sum(x["value"] for x in task["bonuses"] if set(x["pair"]) <= set(selection)),
    }


def optimum(task):
    import itertools

    best = {
        "selection": task["seed"],
        "evaluation": judge_selection(task, task["seed"], True),
    }
    checked = 0
    for selection in itertools.product(
        *[
            [x["id"] for x in task["options"] if x["stage"] == s]
            for s in range(task["stages"])
        ]
    ):
        result = judge_selection(task, list(selection), True)
        checked += 1
        if result["valid"] and result["value"] > best["evaluation"]["value"]:
            best = {"selection": list(selection), "evaluation": result}
    return {**best, "enumerated": checked}
