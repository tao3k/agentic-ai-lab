# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Cases for the interactive study study."""

import copy
import random
from agentic_ai_lab_runtime.reasoning import EvidenceOperation
from ..correction_study import balanced, tagged
from ..trajectory_study import atom, rule, relation
from ..consumption_study import oracle as balanced_oracle


def tagged_oracle(sources):
    s = {r["name"]: set(map(tuple, r["rows"])) for r in sources}
    flow = set(s["start"])
    permit = set(s["permission"])
    while True:
        p = permit | {
            (y, t)
            for x, y, t in s["grant"]
            if (x, t) in flow and (y, t) not in s["blocked"]
        }
        f = flow | {
            (y, t)
            for x, y in s["edge"]
            for a, t in flow
            if x == a and (y, t) in p and (y, t) not in s["blocked"]
        }
        f |= {
            (x, u)
            for x, t, u in s["convert"]
            if (x, t) in flow and (x, u) not in s["blocked"]
        }
        if (f, p) == (flow, permit):
            return f, p
        flow, permit = f, p


def corpus(seed_offset=0):
    cases = [
        balanced(2026106301 + seed_offset, 30, 4, 40),
        tagged(2026106302 + seed_offset, True),
    ]
    for c in cases:
        # Opaque identifiers remove construction ordinal hints.
        rng = random.Random(c["seed"] + 819)
        needs = next(s for s in c["sources"] if s["name"] == "needs")
        needs["rows"] = needs["rows"][:40]
        mapping = {r[0]: f"job_{rng.getrandbits(64):016x}" for r in needs["rows"]}
        for s in c["sources"]:
            s["rows"] = [[mapping.get(x, x) for x in r] for r in s["rows"]]
        base = copy.deepcopy(c["program"])
        base["rules"] = base["rules"][:-1]
        base["relations"] = copy.deepcopy(c["sources"]) + [
            r for r in base["relations"] if not r["source"] and r["name"] != "answer"
        ]
        base["queries"] = c["intermediates"]
        if c["family"] == "context-balanced-paths":
            description = (
                "Balanced(c,x,y) is the LEAST relation containing supplied epsilon pairs in context c, closed under concatenation "
                "and matching opening(x,a,k), balanced(c,a,b), closing(b,y,k). Both wrapping edges must not be denied in c. "
                "Opening and closing labels must match; denial is scoped to the exact context and edge. Cycles require a fixed point. "
                "needs(job,c,x,y,d,u,v) asks for those two paths. bridge(z,y) is an ordinary directed edge, not a balanced segment."
            )
            goals = [
                "Return every non-excluded job for which BOTH requested balanced paths exist.",
                "Select all eligible jobs with a balanced first request and a balanced second request, each in its own context. Omit excluded jobs. This is the same intent expressed differently.",
                "After the source update, return every non-excluded job for which SOME balanced segment from x to z in context c is followed by bridge(z,y), AND the second requested balanced path exists. Recheck old support.",
            ]
            bridged = relation("bridged", False, 3)
            base["relations"].append(bridged)
            base["rules"].append(
                rule(
                    atom("bridged", "c", "x", "y"),
                    atom("balanced", "c", "x", "z"),
                    atom("bridge", "z", "y"),
                )
            )
            operations = {
                "balanced": EvidenceOperation(
                    base,
                    "balanced",
                    "Arguments [context,from,to]: a context-specific balanced path exists.",
                    True,
                ),
                "bridged": EvidenceOperation(
                    base,
                    "bridged",
                    "Arguments [context,from,to]: some balanced prefix followed by one bridge exists.",
                    True,
                ),
            }
        else:
            description = (
                "flow and permit are mutually recursive LEAST relations. start(node,tag) seeds flow, permission(node,tag) seeds permit. "
                "A flow(x,t) and grant(x,y,t) give permit(y,t) when blocked(y,t) is absent. "
                "A flow(x,t), edge(x,y), and permit(y,t) give flow(y,t) when blocked(y,t) is absent. "
                "A flow(x,t) and convert(x,t,u) give flow(x,u) when blocked(x,u) is absent. "
                "Blocking is tag-specific; start and permission seeds are unconditional. needs(job,x,t,y,u,z,v,w,q) requires all four flow facts."
            )
            goals = [
                "Return every non-excluded job whose FOUR requested flow facts all hold.",
                "Return the complete set of eligible jobs for which each of the four listed node/tag states is reachable by flow. Exclude the excluded jobs. This repeats the same intent.",
                "After the source update, return every non-excluded job whose FOUR requested flow facts all hold. Recheck old support.",
            ]
            operations = {
                n: EvidenceOperation(
                    base,
                    n,
                    "Arguments [node,tag]: the local "
                    + n
                    + " condition holds under the mutually recursive least fixed point.",
                    True,
                )
                for n in ("flow", "permit")
            }
        changed = copy.deepcopy(c["sources"])
        # Withdraw or change actual assumptions, independently of model behavior.
        if c["family"] == "context-balanced-paths":
            next(s for s in changed if s["name"] == "denied")["rows"] += [
                [context[0], x, y]
                for context in next(s for s in changed if s["name"] == "context")[
                    "rows"
                ]
                for x, y, k in next(s for s in changed if s["name"] == "opening")[
                    "rows"
                ][:8]
            ]
        else:
            next(s for s in changed if s["name"] == "start")["rows"] = next(
                s for s in changed if s["name"] == "start"
            )["rows"][:2]
            next(s for s in changed if s["name"] == "grant")["rows"] = next(
                s for s in changed if s["name"] == "grant"
            )["rows"][::3]
        c.update(
            base=base,
            operations=operations,
            description=description,
            goals=goals,
            changed=changed,
        )
        c["gold"] = [
            gold(c, c["sources"], False),
            gold(c, c["sources"], False),
            gold(c, changed, True),
        ]
        assert c["gold"][0] and c["gold"][0] != c["gold"][2]
    return cases


def gold(case, sources, updated):
    s = {r["name"]: r["rows"] for r in sources}
    excluded = {r[0] for r in s["excluded"]}
    if case["family"] == "context-balanced-paths":
        pairs = balanced_oracle(sources)
        return sorted(
            j
            for j, c, x, y, d, u, v in s["needs"]
            if j not in excluded
            and (d, u, v) in pairs
            and (
                any((c, x, z) in pairs and b == y for z, b in s["bridge"])
                if updated
                else (c, x, y) in pairs
            )
        )
    flow, _ = tagged_oracle(sources)
    return sorted(
        row[0]
        for row in s["needs"]
        if row[0] not in excluded
        and all(tuple(row[i : i + 2]) in flow for i in range(1, 9, 2))
    )


def public(case):
    return {
        k: v
        for k, v in case.items()
        if k
        in (
            "case",
            "seed",
            "family",
            "sources",
            "changed",
            "description",
            "goals",
            "gold",
            "complexity",
        )
    }


def obligation_acceptance(verdicts):
    """Later correction of the same unchanged goal resolves its earlier error.

    Only stages 0/1 have a benchmark-declared identical finite contract.
    A stage-0 success cannot answer the subsequently issued paraphrase; a
    stage-2 answer uses changed sources and cannot repair an earlier obligation.
    """
    accepted = [False] * 3
    first = [None] * 3
    for verdict in verdicts:
        if not verdict["correct"]:
            continue
        stage = verdict["stage"]
        for index in [0, 1] if stage == 1 else [stage]:
            if not accepted[index]:
                first[index] = verdict["providerCall"]
            accepted[index] = True
    return accepted, first
