# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Balanced for the correction study study."""

import random
from ..trajectory_study import relation, atom, rule
from ._case_record import make_case


def _build_rules():
    """Assemble the retained rules structure."""
    return [
        rule(
            atom("balanced", "c", "x", "y"),
            atom("context", "c"),
            atom("epsilon", "x", "y"),
        ),
        rule(
            atom("balanced", "c", "x", "z"),
            atom("balanced", "c", "x", "y"),
            atom("balanced", "c", "y", "z"),
        ),
        rule(
            atom("balanced", "c", "x", "z"),
            atom("opening", "x", "a", "k"),
            atom("balanced", "c", "a", "b"),
            atom("closing", "b", "z", "k"),
            atom("denied", "c", "x", "a", negative=True),
            atom("denied", "c", "b", "z", negative=True),
        ),
    ]


def balanced(seed, count=24, contexts_count=2, request_count=96):
    rng = random.Random(seed)
    nodes = [f"p{seed:x}_{i:x}" for i in range(count)]
    contexts = [f"c{i}" for i in range(contexts_count)]
    opening = {(nodes[0], nodes[1], "a"), (nodes[1], nodes[2], "b")}
    closing = {(nodes[3], nodes[4], "b"), (nodes[4], nodes[5], "a")}
    for collection in [opening, closing]:
        for _ in range(count + 8):
            x, y = rng.sample(nodes, 2)
            collection.add((x, y, rng.choice(["a", "b"])))
    epsilon = {(x, x) for x in nodes} | {(nodes[2], nodes[3])}
    denied = {
        (rng.choice(contexts), x, y)
        for x, y, k in rng.sample(sorted(opening | closing), 10)
    }
    closures = {c: set(epsilon) for c in contexts}
    rounds = 0
    while True:
        rounds += 1
        new = {}
        for c in contexts:
            pairs = closures[c]
            add = {(x, z) for x, y in pairs for y2, z in pairs if y == y2}
            add |= {
                (x, z)
                for x, a, k in opening
                for b, z, k2 in closing
                if k == k2
                and (a, b) in pairs
                and (c, x, a) not in denied
                and (c, b, z) not in denied
            }
            new[c] = pairs | add
        if new == closures:
            break
        closures = new
    positive = [(c, x, y) for c in contexts for x, y in sorted(closures[c]) if x != y]
    assert len(positive) > 10
    universe = [(c, x, y) for c in contexts for x in nodes for y in nodes]
    requests = []
    for i in range(request_count):
        a, b = rng.choices(positive if i < request_count // 2 else universe, k=2)
        requests.append([f"j{seed:x}_{i:x}", *a, *b])
    rng.shuffle(requests)
    excluded = {r[0] for r in rng.sample(requests, 12)}
    bridge = {(rng.choice(nodes), rng.choice(nodes)) for _ in range(count * 2)}
    sources = [
        relation("context", True, 1, [[c] for c in contexts]),
        relation("epsilon", True, 2, sorted(epsilon)),
        relation("opening", True, 3, sorted(opening)),
        relation("closing", True, 3, sorted(closing)),
        relation("denied", True, 3, sorted(denied)),
        relation("needs", True, 7, requests),
        relation("excluded", True, 1, [[x] for x in sorted(excluded)]),
        relation("bridge", True, 2, sorted(bridge)),
    ]
    derived = [relation("balanced", False, 3), relation("answer", False, 1)]
    rules = _build_rules()
    first = rules + [
        rule(
            atom("answer", "j"),
            atom("needs", "j", "c", "x", "y", "d", "u", "v"),
            atom("balanced", "c", "x", "y"),
            atom("balanced", "d", "u", "v"),
            atom("excluded", "j", negative=True),
        )
    ]
    second = rules + [
        rule(
            atom("answer", "j"),
            atom("needs", "j", "c", "x", "y", "d", "u", "v"),
            atom("balanced", "c", "x", "z"),
            atom("bridge", "z", "y"),
            atom("balanced", "d", "u", "v"),
            atom("excluded", "j", negative=True),
        )
    ]
    g1 = [
        j
        for j, c, x, y, d, u, v in requests
        if (x, y) in closures[c] and (u, v) in closures[d] and j not in excluded
    ]
    g2 = [
        j
        for j, c, x, y, d, u, v in requests
        if any(a == x and (b, y) in bridge for a, b in closures[c])
        and (u, v) in closures[d]
        and j not in excluded
    ]
    return make_case(
        "context-balanced-paths",
        seed,
        sources,
        derived,
        first,
        second,
        g1,
        g2,
        ["balanced"],
        {
            "nodes": count,
            "contexts": contexts_count,
            "openingEdges": len(opening),
            "closingEdges": len(closing),
            "oracleRounds": rounds,
            "intermediateRows": sum(len(v) for v in closures.values()),
            "requests": request_count,
        },
    )
