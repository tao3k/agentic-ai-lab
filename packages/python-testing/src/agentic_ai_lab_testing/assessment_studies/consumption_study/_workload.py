# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the consumption study study."""

import copy, random
from ..correction_study import balanced
from ..trajectory_study import atom, rule


def oracle(sources):
    s = {r["name"]: r["rows"] for r in sources}
    pairs = {(c, x, y) for (c,) in s["context"] for x, y in s["epsilon"]}
    blocked = set(map(tuple, s["denied"]))
    while True:
        more = pairs | {
            (c, x, z) for c, x, y in pairs for d, y2, z in pairs if c == d and y == y2
        }
        more |= {
            (c, x, z)
            for c, a, b in pairs
            for x, a2, k in s["opening"]
            for b2, z, l in s["closing"]
            if a == a2
            and b == b2
            and k == l
            and (c, x, a) not in blocked
            and (c, b, z) not in blocked
        }
        if more == pairs:
            return pairs
        pairs = more


def corpus():
    cases = [balanced(2026105301, 34, 4, 160), balanced(2026105302, 36, 5, 192)]
    for c in cases:
        rng = random.Random(c["seed"] + 1123)
        jobs = [
            r[0] for r in next(s for s in c["sources"] if s["name"] == "needs")["rows"]
        ]
        rename = {
            j: f"job_{v:012x}"
            for j, v in zip(jobs, rng.sample(range(1 << 48), len(jobs)))
        }
        for source in c["sources"]:
            source["rows"] = [[rename.get(x, x) for x in r] for r in source["rows"]]
        c["program"]["relations"] = copy.deepcopy(c["sources"]) + [
            r for r in c["program"]["relations"] if not r["source"]
        ]
        expected = copy.deepcopy(c["program"])
        expected["rules"][-1] = rule(
            atom("answer", "j"),
            atom("needs", "j", "c", "x", "y", "d", "u", "v"),
            atom("balanced", "c", "x", "y"),
            atom("balanced", "d", "u", "v", negative=True),
            atom("excluded", "j", negative=True),
        )
        pairs = oracle(c["sources"])
        excluded = {
            r[0]
            for r in next(s for s in c["sources"] if s["name"] == "excluded")["rows"]
        }
        need = next(s for s in c["sources"] if s["name"] == "needs")["rows"]
        first = sorted(
            j
            for j, a, x, y, b, u, v in need
            if (a, x, y) in pairs and (b, u, v) in pairs and j not in excluded
        )
        changed = sorted(
            j
            for j, a, x, y, b, u, v in need
            if (a, x, y) in pairs and (b, u, v) not in pairs and j not in excluded
        )
        assert first and changed and first != changed
        base = copy.deepcopy(c["program"])
        base["rules"] = base["rules"][:-1]
        base["queries"] = ["balanced"]
        base["relations"] = [r for r in base["relations"] if r["name"] != "answer"]
        c.update(
            base=base,
            programs=[c["program"], c["program"], expected],
            gold=[first, first, changed],
            goals=[
                "Return all non-excluded jobs for which BOTH requested context-specific balanced paths exist.",
                "Select every eligible job whose first path is balanced in its own context AND whose second path is balanced in its respective context. Omit excluded jobs. This is the complete set, not an update delta.",
                "Return all non-excluded jobs whose FIRST context-specific path exists but whose SECOND context-specific balanced path does NOT exist.",
            ],
            schema="needs(j,c,x,y,d,u,v): first path is (c,x,y); second is (d,u,v). balanced(context,from,to) is completed recursive evidence. answer(j) is unary.",
        )
    return cases
