# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tasks for the factor budget study."""

import random
from ._artifacts import canonical, sha


def input_reserve(request):
    return len(canonical(request).encode()) + 4096 + 128 * len(request["input"])


def task(seed, n, label):
    rng = random.Random(seed)
    labels = list(range(n))
    rng.shuffle(labels)
    edges = [
        [labels[i], labels[j]]
        for i in range(n)
        for j in range(i + 1, n)
        if rng.random() < 0.18
    ]
    data = {
        "id": label,
        "n": n,
        "edges": edges,
        "durations": [rng.randint(1, 12) for _ in labels],
        "weights": [
            [rng.randint(1, 20) for _ in range(n)],
            [rng.randint(1, 20) for _ in labels],
        ],
    }
    data["transitionPenalties"] = [
        [0 if i == j else rng.randint(0, 250) for j in range(n)] for i in range(n)
    ]
    return data


CASES = [task(3621, 14, "hidden-fork-14"), task(9357, 16, "hidden-diamond-16")]

CALIBRATION = [task(7711, 14, "calibration-14"), task(8819, 16, "calibration-16")]


def packet(native, folder):
    folder.mkdir(exist_ok=True)
    raw, seconds = native.call(op="packet")
    cert = raw["certificate"]
    payload = canonical(cert).encode()
    h = sha(payload)
    store = folder / "proof-store"
    store.mkdir(exist_ok=True)
    (store / (h + ".json")).write_bytes(payload)
    closure = next((x[2] for x in cert["finiteClosure"] if x[0] == "path"))
    evidence = {
        "sourceDigest": cert["sourceDigest"],
        "certificateSha256": h,
        "checkedFacts": sorted(closure),
        "candidateDigest": cert["candidateDigest"],
        "query": cert["query"],
        "roots": sorted(cert["roots"]),
        "derivationNodeColumns": [
            "id",
            "kind",
            "relation",
            "row",
            "ruleOrSourceIndex",
            "inputs",
        ],
        "derivationNodes": [
            [
                z[k]
                for k in (
                    "id",
                    "kind",
                    "relation",
                    "row",
                    "ruleOrSourceIndex",
                    "inputs",
                )
            ]
            for z in sorted(cert["nodes"], key=lambda z: z["id"])
        ],
    }
    return (
        evidence,
        {
            "reused": raw["reused"],
            "nativeSeconds": seconds,
            "proofBytes": len(payload),
            "proofSha256": h,
        },
    )


def question(c, phase, evidence):
    n = c["n"]
    return canonical(
        {
            "task": c["id"],
            "phase": phase,
            "jobs": list(range(n)),
            "durations": c["durations"][:n],
            "weights": c["weights"][phase],
            "sourceEdges": c["edges"],
            "transitionPenalties": c["transitionPenalties"],
            "evidence": evidence,
            "guidance": "Objective changes between phases. History resets; evidence remains source-bound. Optimize under the common total budget.",
        }
    )
