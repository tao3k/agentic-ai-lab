# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared cases for the evidence chain study study."""

import time
from ._config import SHARED_CANDIDATE


def shared_tasks():
    edges = [[0, 1], [1, 2], [0, 10], [10, 2], [3, 4], [5, 6], [7, 8], [8, 9], [11, 12]]
    needs = [
        [0, 0, 2, 3, 4],
        [1, 0, 2, 4, 3],
        [2, 0, 2, 5, 6],
        [3, 0, 2, 6, 5],
        [4, 0, 2, 7, 9],
        [5, 0, 2, 9, 7],
    ]
    return [
        {
            "id": f"shared-premise-{i}",
            "edges": edges if i == 0 else [e for e in edges if e != [5, 6]] + [[6, 5]],
            "needs": needs,
            "schedule": [[0, 1], [2, 3], [4, 5]],
            "sharedAtom": ["path", 0, 2],
        }
        for i in range(2)
    ]


def shared_source(task, generation=0, edges=None):
    return {
        "identity": task["id"],
        "generation": generation,
        "relations": [
            ["edge", 2, task["edges"] if edges is None else edges],
            ["need", 5, task["needs"]],
        ],
    }


def shared_truth(task, atom):
    """Independent finite graph oracle for this fixture, never production evaluation."""
    if (
        not isinstance(atom, list)
        or not atom
        or atom[0] not in ("edge", "path", "ready")
    ):
        raise ValueError("unknown fixture atom")
    if any(type(n) is not int for n in atom[1:]):
        raise ValueError("noninteger atom")
    if atom[0] == "edge":
        if len(atom) != 3:
            raise ValueError("edge arity")
        return atom[1:] in task["edges"]
    if atom[0] == "ready":
        if len(atom) != 2:
            raise ValueError("ready arity")
        n = next(n for n in task["needs"] if n[0] == atom[1])
        return shared_truth(task, ["path", n[1], n[2]]) and shared_truth(
            task, ["path", n[3], n[4]]
        )
    if len(atom) != 3:
        raise ValueError("path arity")
    todo = [b for a, b in task["edges"] if a == atom[1]]
    seen = set()
    while todo:
        at = todo.pop()
        if at == atom[2]:
            return True
        if at in seen:
            continue
        seen.add(at)
        todo.extend(b for a, b in task["edges"] if a == at)
    return False


def shared_atoms(task, ids):
    return [
        list(a)
        for a in dict.fromkeys(
            tuple(a)
            for n in task["needs"]
            if n[0] in ids
            for a in (["path", n[1], n[2]], ["path", n[3], n[4]])
        )
    ]


def shared_packet(store, task, ids):
    src = shared_source(task)
    begin = time.monotonic()
    r = store.resolve(src, SHARED_CANDIDATE)
    if r["status"] != "verified":
        raise ValueError("unverified native evidence")
    facts = []
    fragments = []
    for atom in shared_atoms(task, ids):
        f = store.fact(src, SHARED_CANDIDATE, r["handle"], atom)
        if f["status"] not in ("verified", "finite-absent"):
            raise ValueError("unknown native fact")
        if (f["status"] == "verified") != shared_truth(task, atom):
            raise ValueError("native/oracle disagreement")
        facts.append({"atom": atom, "status": f["status"]})
        if f["status"] == "verified":
            p = store.fragment(src, SHARED_CANDIDATE, r["handle"], atom)
            if p["status"] != "verified":
                raise ValueError("unverified fragment")
            fragments.append({"atom": atom, "roots": p["roots"], "nodes": p["nodes"]})
    return {
        "scope": dict(r["scope"]),
        "facts": facts,
        "fragments": fragments,
        "nodeEncoding": ["id", "kind", "relation", "row", "ruleLabel", "inputs"],
        "nativeStats": store.stats(),
        "nativeSeconds": time.monotonic() - begin,
        "reused": r["reused"],
    }
