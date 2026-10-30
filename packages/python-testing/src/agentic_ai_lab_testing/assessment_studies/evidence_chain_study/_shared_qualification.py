# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared qualification for the evidence chain study study."""

import copy, json
from .. import inference_reuse_study as s
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_packet, shared_source, shared_tasks, shared_truth


def shared_qualify(engine):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence

    results = []
    for task in shared_tasks():
        with ComputationalEvidence(engine) as store:
            src = shared_source(task)
            first = store.resolve(src, SHARED_CANDIDATE)
            assert first["status"] == "verified"
            assert sorted(first["rows"]) == [
                [n[0]] for n in task["needs"] if shared_truth(task, ["ready", n[0]])
            ]
            packets = [shared_packet(store, task, ids) for ids in task["schedule"]]
            assert all(
                p["nativeStats"]["proof-builds"] == 1 and p["reused"] for p in packets
            )
            shared = [
                next(f for f in p["fragments"] if f["atom"] == task["sharedAtom"])
                for p in packets
            ]
            assert shared[0] == shared[1] == shared[2]
            for p in packets:
                for f in p["fragments"]:
                    ids = set()
                    assert all(
                        not any(parent not in ids for parent in n[5])
                        and not (n[0] in ids)
                        and (ids.add(n[0]) is None)
                        for n in f["nodes"]
                    )
                    assert set(f["roots"]) <= ids
            handle = first["handle"]
            remaining = [e for e in task["edges"] if e != [1, 2]]
            alt = shared_source(task, 1, remaining)
            assert (
                store.fact(alt, SHARED_CANDIDATE, handle, task["sharedAtom"])["status"]
                == "unknown"
            )
            ar = store.resolve(alt, SHARED_CANDIDATE)
            assert ar["status"] == "verified"
            assert (
                store.fact(alt, SHARED_CANDIDATE, ar["handle"], task["sharedAtom"])[
                    "status"
                ]
                == "verified"
            )
            removed = shared_source(task, 2, [e for e in remaining if e != [10, 2]])
            assert (
                store.fragment(
                    removed, SHARED_CANDIDATE, ar["handle"], task["sharedAtom"]
                )["status"]
                == "unknown"
            )
            rr = store.resolve(removed, SHARED_CANDIDATE)
            assert rr["status"] == "verified" and rr["rows"] == []
            assert (
                store.fact(removed, SHARED_CANDIDATE, rr["handle"], task["sharedAtom"])[
                    "status"
                ]
                == "finite-absent"
            )
            mutants = []
            for kind in ("missing-rule", "wrong-join"):
                mutant = copy.deepcopy(SHARED_CANDIDATE)
                if kind == "missing-rule":
                    mutant.pop(4)
                else:
                    mutant[4][-1] = ["edge", "?x", "?z"]
                bad = store.resolve(src, mutant)
                assert bad["status"] == "verified"
                # Grade intermediate shared P too: final ready rows alone miss this wrong join.
                assert (
                    store.fact(src, mutant, bad["handle"], ["path", 0, 2])["status"]
                    == "finite-absent"
                )
                assert shared_truth(task, ["path", 0, 2])
                assert (
                    store.fact(src, mutant, handle, ["path", 0, 2])["status"]
                    == "unknown"
                )
                mutants.append(kind)
            results.append(
                {
                    "task": task["id"],
                    "packets": packets,
                    "alternativeSupportPreserved": True,
                    "staleHandlesRefused": True,
                    "withdrawalRecomputed": True,
                    "mutantsDistinguished": mutants,
                }
            )
    import subprocess

    model = s.ROOT / "packages/proofs/quint/SharedPremiseReuse.qnt"
    raw = subprocess.check_output(
        [
            "quint",
            "repl",
            "-q",
            "--backend",
            "typescript",
            "-r",
            str(model) + "::SharedPremiseReuse",
            "conformance",
        ],
        text=True,
        timeout=30,
    )
    expected = json.loads(raw)
    observed = []
    with ComputationalEvidence(engine) as store:
        for i in range(32):
            edges = [
                e
                for bit, e in zip(
                    [1, 2, 4, 8, 16], [[0, 1], [1, 2], [0, 10], [10, 2], [3, 4]]
                )
                if i & bit
            ]
            task = {
                "id": f"quint-conformance-{i}",
                "edges": edges,
                "needs": [[0, 0, 2, 3, 4]],
            }
            src = shared_source(task)
            r = store.resolve(src, SHARED_CANDIDATE)
            assert r["status"] == "verified"
            p = store.fact(src, SHARED_CANDIDATE, r["handle"], ["path", 0, 2])
            observed.append([i, int(p["status"] == "verified"), int([0] in r["rows"])])
    assert observed == expected, "Scheme/Quint finite observation mismatch"
    return {
        "taskChecks": results,
        "nativeQuintRows": observed,
        "quintCommand": [
            "quint",
            "repl",
            "-q",
            "--backend",
            "typescript",
            "-r",
            "packages/proofs/quint/SharedPremiseReuse.qnt::SharedPremiseReuse",
            "conformance",
        ],
    }
