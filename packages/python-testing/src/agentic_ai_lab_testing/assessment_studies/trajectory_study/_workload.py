# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the trajectory study study."""

import json
import random


def relation(name, source, arity, rows=()):
    return {
        "name": name,
        "source": source,
        "columns": [{"kind": "symbol"} for _ in range(arity)],
        "rows": list(rows),
    }


def atom(name, *variables, negative=False):
    return {
        "relation": name,
        "terms": [{"var": v} for v in variables],
        **({"not": True} if negative else {}),
    }


def rule(head, *body):
    return {"head": [head], "body": list(body)}


def closure(edges, seeds, blocked):
    found = set(seeds)
    while True:
        next_found = found | {b for a, b in edges if a in found and b not in blocked}
        if next_found == found:
            return found
        found = next_found


def task(family, seed):
    rng = random.Random(seed)
    count = 36 + family * 4
    nodes = [f"v{seed:x}_{i:x}" for i in range(count)]
    islands = 3 if family % 2 == 0 else 4
    edges = set()
    for i, a in enumerate(nodes):
        choices = [
            b for j, b in enumerate(nodes) if j % islands == i % islands and a != b
        ]
        for b in rng.sample(choices, 3):
            edges.add((a, b))
    bridges = [
        (
            nodes[rng.randrange(count // islands) * islands],
            nodes[1 + islands * rng.randrange(count // islands)],
        )
    ]
    edges.update(bridges)
    blocked = set(rng.sample(nodes, 5 + family))
    seeds = [nodes[0], nodes[islands]]
    blocked -= set(seeds)
    targets = rng.sample(nodes, 22)
    inputs = [
        relation("edge", True, 2, sorted(map(list, edges))),
        relation("start", True, 1, [[x] for x in seeds]),
        relation("blocked", True, 1, [[x] for x in sorted(blocked)]),
    ]
    derived = [relation("reach", False, 1), relation("answer", False, 1)]
    rules = [
        rule(atom("reach", "x"), atom("start", "x")),
        rule(
            atom("reach", "y"),
            atom("reach", "x"),
            atom("edge", "x", "y"),
            atom("blocked", "y", negative=True),
        ),
    ]
    reached = closure(edges, seeds, blocked)
    if family == 0:
        label = "recursive-scoped-reachability"
        inputs.append(relation("target", True, 1, [[x] for x in targets]))
        rules.append(rule(atom("answer", "x"), atom("reach", "x"), atom("target", "x")))
        gold = sorted(reached & set(targets))
    elif family == 1:
        label = "taint-propagation-with-sanitizers"
        excluded = set(rng.sample(targets, 6))
        inputs += [
            relation("sink", True, 1, [[x] for x in targets]),
            relation("approved", True, 1, [[x] for x in sorted(excluded)]),
        ]
        rules.append(
            rule(
                atom("answer", "x"),
                atom("reach", "x"),
                atom("sink", "x"),
                atom("approved", "x", negative=True),
            )
        )
        gold = sorted((reached & set(targets)) - excluded)
    elif family == 2:
        label = "conjunctive-prerequisite-closure"
        needs = [[f"job{seed:x}_{i}", *rng.sample(nodes, 2)] for i in range(24)]
        deferred = {n[0] for n in rng.sample(needs, 5)}
        inputs += [
            relation("needs", True, 3, needs),
            relation("deferred", True, 1, [[x] for x in sorted(deferred)]),
        ]
        rules.append(
            rule(
                atom("answer", "job"),
                atom("needs", "job", "a", "b"),
                atom("reach", "a"),
                atom("reach", "b"),
                atom("deferred", "job", negative=True),
            )
        )
        gold = sorted(
            job
            for job, a, b in needs
            if a in reached and b in reached and job not in deferred
        )
    else:
        label = "bidirectional-recursive-impact"
        finish = rng.sample(nodes, 3)
        reverse = closure({(b, a) for a, b in edges}, finish, blocked)
        inputs += [
            relation("finish", True, 1, [[x] for x in finish]),
            relation("target", True, 1, [[x] for x in targets]),
        ]
        derived.append(relation("back", False, 1))
        rules += [
            rule(atom("back", "x"), atom("finish", "x")),
            rule(
                atom("back", "x"),
                atom("back", "y"),
                atom("edge", "x", "y"),
                atom("blocked", "x", negative=True),
            ),
            rule(
                atom("answer", "x"),
                atom("reach", "x"),
                atom("back", "x"),
                atom("target", "x"),
            ),
        ]
        gold = sorted(reached & reverse & set(targets))
    program = {"relations": inputs + derived, "rules": rules, "queries": ["answer"]}
    prompt = (
        "Compute the COMPLETE answer relation of this finite least-fixed-point program. "
        "Rules are conjunctive; shared variables join; not means scoped absence from the declared source relation. "
        "Blocked nodes cannot be entered by recursive propagation, but explicitly supplied start/finish seeds are initial facts. "
        "Cycles do not bound the number of fixed-point rounds. No external tools are available. "
        'Reason carefully and finish with FINAL_JSON: {"answer": ["symbol", ...]}. '
        "Explanations are welcome; the API does not enforce a JSON schema.\n"
        + json.dumps(program, separators=(",", ":"))
    )
    return {
        "case": f"{label}-{seed}",
        "family": label,
        "seed": seed,
        "program": program,
        "sources": inputs,
        "gold": gold,
        "question": prompt,
        "complexity": {
            "nodes": count,
            "edges": len(edges),
            "negativeSourceRows": len(blocked),
            "rules": len(rules),
            "derivedRelations": len(derived),
            "answerRows": len(gold),
        },
        "provenance": "Fresh seeded relational instances inspired by DatalogBench recursive/dataflow use cases; not official benchmark items or a claim of training-set exclusion.",
    }
