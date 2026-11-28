# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tagged for the correction study study."""

import random
from ..trajectory_study import relation, atom, rule
from ._case_record import make_case


def tagged(seed, mutual=False):
    rng = random.Random(seed)
    n = 72 if mutual else 64
    nodes = [f"n{seed:x}_{i:x}" for i in range(n)]
    tags = [f"t{i}" for i in range(4)]
    states = [(x, t) for x in nodes for t in tags]
    edge = {(nodes[i], nodes[i + 1]) for i in range(n - 1)}
    edge |= {tuple(rng.sample(nodes, 2)) for _ in range(n + 16)}
    blocked = set(rng.sample(states, n))
    starts = set(rng.sample(states, 7))
    converts = {tuple([x, *rng.sample(tags, 2)]) for x in rng.choices(nodes, k=n + 20)}
    blocked -= starts
    sources = [
        relation("edge", True, 2, sorted(edge)),
        relation("start", True, 2, sorted(starts)),
        relation("blocked", True, 2, sorted(blocked)),
        relation("convert", True, 3, sorted(converts)),
    ]
    derived = [relation("flow", False, 2), relation("answer", False, 1)]
    rules = [
        rule(atom("flow", "x", "t"), atom("start", "x", "t")),
        rule(
            atom("flow", "x", "u"),
            atom("flow", "x", "t"),
            atom("convert", "x", "t", "u"),
            atom("blocked", "x", "u", negative=True),
        ),
    ]
    grants = {(a, b, t) for a, b in sorted(edge) for t in rng.sample(tags, 2)}
    permitted = set(rng.sample(states, n + 16))
    if mutual:
        sources += [
            relation("permission", True, 2, sorted(permitted)),
            relation("grant", True, 3, sorted(grants)),
        ]
        derived.append(relation("permit", False, 2))
        rules += [
            rule(atom("permit", "x", "t"), atom("permission", "x", "t")),
            rule(
                atom("permit", "y", "t"),
                atom("flow", "x", "t"),
                atom("grant", "x", "y", "t"),
                atom("blocked", "y", "t", negative=True),
            ),
            rule(
                atom("flow", "y", "t"),
                atom("flow", "x", "t"),
                atom("edge", "x", "y"),
                atom("permit", "y", "t"),
                atom("blocked", "y", "t", negative=True),
            ),
        ]
    else:
        rules.append(
            rule(
                atom("flow", "y", "t"),
                atom("flow", "x", "t"),
                atom("edge", "x", "y"),
                atom("blocked", "y", "t", negative=True),
            )
        )
    flow = set(starts)
    permit = set(permitted)
    rounds = 0
    while True:
        rounds += 1
        p = (
            permit
            | {(b, t) for a, b, t in grants if (a, t) in flow and (b, t) not in blocked}
            if mutual
            else permit
        )
        f = flow | {
            (b, t)
            for a, b in edge
            for t in tags
            if (a, t) in flow and (b, t) not in blocked and (not mutual or (b, t) in p)
        }
        f |= {
            (x, u) for x, t, u in converts if (x, t) in flow and (x, u) not in blocked
        }
        if (f, p) == (flow, permit):
            break
        flow, permit = f, p
    requests = []
    for i in range(96):
        chosen = rng.choices(sorted(flow) if i < 48 else states, k=4)
        requests.append([f"j{seed:x}_{i:x}", *[v for pair in chosen for v in pair]])
    rng.shuffle(requests)
    excluded = {r[0] for r in rng.sample(requests, 13)}
    policy = {r[0] for r in rng.sample(requests, 66)}
    sources += [
        relation("needs", True, 9, requests),
        relation("excluded", True, 1, [[x] for x in sorted(excluded)]),
        relation("policy", True, 1, [[x] for x in sorted(policy)]),
    ]
    head = atom("answer", "j")
    body = [
        atom("needs", "j", "a", "t", "b", "u", "c", "v", "d", "w"),
        atom("flow", "a", "t"),
        atom("flow", "b", "u"),
        atom("flow", "c", "v"),
    ]
    first = rules + [
        rule(head, *body, atom("flow", "d", "w"), atom("excluded", "j", negative=True))
    ]
    second = rules + [
        rule(
            head,
            *body,
            atom("blocked", "d", "w", negative=True),
            atom("policy", "j"),
            atom("excluded", "j", negative=True),
        )
    ]
    gold1 = []
    gold2 = []
    for j, a, t, b, u, c, v, d, w in requests:
        if j in excluded:
            continue
        if {(a, t), (b, u), (c, v)} <= flow:
            if (d, w) in flow:
                gold1.append(j)
            if (d, w) not in blocked and j in policy:
                gold2.append(j)
    label = "mutual-permission-taint" if mutual else "tag-scoped-taint"
    return make_case(
        label,
        seed,
        sources,
        derived,
        first,
        second,
        gold1,
        gold2,
        ["flow", "permit"] if mutual else ["flow"],
        {
            "nodes": n,
            "tags": 4,
            "edges": len(edge),
            "blockedStates": len(blocked),
            "conversions": len(converts),
            "oracleRounds": rounds,
            "intermediateRows": len(flow) + (len(permit) if mutual else 0),
            "requests": 96,
        },
    )
