# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the trajectory transfer study study."""

import copy
from ..trajectory_study import atom, rule, closure


def followup(case):
    program = copy.deepcopy(case["program"])
    sources = {r["name"]: r["rows"] for r in case["sources"]}
    edges = {tuple(row) for row in sources["edge"]}
    blocked = {r[0] for r in sources["blocked"]}
    reached = closure(edges, [r[0] for r in sources["start"]], blocked)
    rules = [r for r in program["rules"] if r["head"][0]["relation"] != "answer"]
    family = case["family"]
    if family == "recursive-scoped-reachability":
        rules.append(
            rule(
                atom("answer", "x"),
                atom("reach", "x"),
                atom("target", "x"),
                atom("edge", "x", "y"),
                atom("edge", "y", "z"),
                atom("blocked", "z"),
            )
        )
        targets = {r[0] for r in sources["target"]}
        gold = {
            x
            for x in reached & targets
            if any(
                a == x and c == b and d in blocked for a, b in edges for c, d in edges
            )
        }
    elif family == "taint-propagation-with-sanitizers":
        rules.append(
            rule(
                atom("answer", "x"),
                atom("reach", "x"),
                atom("sink", "x"),
                atom("approved", "x", negative=True),
                atom("edge", "x", "y"),
                atom("approved", "y"),
            )
        )
        sinks = {r[0] for r in sources["sink"]}
        approved = {r[0] for r in sources["approved"]}
        gold = {
            x
            for x in (reached & sinks) - approved
            if any(a == x and b in approved for a, b in edges)
        }
    elif family == "conjunctive-prerequisite-closure":
        rules.append(
            rule(
                atom("answer", "job"),
                atom("needs", "job", "a", "b"),
                atom("reach", "a"),
                atom("blocked", "b"),
                atom("deferred", "job", negative=True),
            )
        )
        deferred = {r[0] for r in sources["deferred"]}
        gold = {
            job
            for job, a, b in sources["needs"]
            if a in reached and b in blocked and job not in deferred
        }
    else:
        rules.append(
            rule(
                atom("answer", "x"),
                atom("reach", "x"),
                atom("back", "x"),
                atom("target", "x"),
                atom("edge", "x", "y"),
                atom("blocked", "y"),
            )
        )
        back = closure(
            {(b, a) for a, b in edges}, [r[0] for r in sources["finish"]], blocked
        )
        targets = {r[0] for r in sources["target"]}
        gold = {
            x
            for x in reached & back & targets
            if any(a == x and b in blocked for a, b in edges)
        }
    program["rules"] = rules
    return program, sorted(gold)
