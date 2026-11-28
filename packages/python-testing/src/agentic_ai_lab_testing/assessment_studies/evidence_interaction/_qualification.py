# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Qualification for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
from ._artifacts import canonical, fields, save, sha
from ._config import KERNEL, ROOT
from ._transport import EvidenceEngine
from ._workload import independent_atom, judge_init, same_check


def qualify(run):
    run.mkdir(parents=True, exist_ok=False)
    records = []
    with EvidenceEngine(run) as native, EvidenceEngine(run, True) as judge:
        for case in (0, 1, 2):
            contexts = []
            cert_hashes = []
            task = native.call(op="task", case=case)
            judge_init(judge, task)
            seed = judge.call(op="grade", goal=task["goal"], selection=task["seed"])
            if not seed["valid"] or seed["optimal"]:
                raise ValueError("common seed must be feasible and nonoptimal")
            for arm in ("baseline", "facts", "prune"):
                init = native.call(op="init", case=case, arm=arm)
                cert_hashes.append(sha(canonical(init["certificate"]).encode()))
                q = native.call(op="next")["context"]
                contexts.append(q)
                # Fixed probes, not outcome-tuned model policies. Native/independent checker parity.
                for _ in range(12):
                    step = native.call(op="next")
                    if step["done"]:
                        break
                    oid = step["context"]["unvisitedChildren"][0]["option"]["id"]
                    event = native.call(op="expand", optionId=oid)
                    same_check(
                        event["prefix"],
                        judge.call(
                            op="inspect", goal=task["goal"], selection=event["child"]
                        ),
                    )
                    same_check(
                        event["evaluation"],
                        judge.call(
                            op="evaluate",
                            goal=task["goal"],
                            selection=event["completion"],
                        ),
                    )
                state = native.call(op="summary")
                if fields(state["nativeStats"])["proof-builds"] != len(
                    init["libraryLifecycle"]["records"]
                ):
                    raise ValueError("proof rebuilt across branches")
                if arm != "prune" and state["prunings"]:
                    raise ValueError("control unexpectedly pruned")
                native.call(op="init", case=case, arm=arm)
                native.call(op="next")
                try:
                    native.call(op="expand", optionId=9999)
                except ValueError:
                    pass
                else:
                    raise ValueError("invalid action admitted")
            if len(set(cert_hashes)) != 1:
                raise ValueError("treatments use different proof")
            baseline, facts, pruned = contexts
            fact_packet = facts["evidence"]
            facts = {k: v for k, v in facts.items() if k != "evidence"}
            if baseline != facts:
                raise ValueError("Fact-only root context parity failed")
            if pruned["evidence"] != fact_packet:
                raise ValueError("Fact/pruning evidence parity failed")
            for key in baseline:
                if key != "unvisitedChildren" and baseline[key] != pruned[key]:
                    raise ValueError("pruning changed task contract")
            # Independent raw-source judge checks every published Session row
            # at each temporal cut; the fixture never supplies the judge's verdict.
            lifecycle = init["libraryLifecycle"]
            for record in lifecycle["records"]:
                atom_task = {**task, "edges": record["edges"]}
                memo = {}
                expected = {
                    n[0]
                    for n in task["needs"]
                    if independent_atom(judge, atom_task, ["ready", n[0]], memo)
                }
                if {r[0] for r in record["sessionReady"]} != expected:
                    raise ValueError("Session/independent temporal Fact parity failed")
                expected_paths = {
                    (a, b)
                    for a in range(12)
                    for b in range(12)
                    if independent_atom(judge, atom_task, ["path", a, b], memo)
                }
                if {tuple(p) for p in record["sessionPaths"]} != expected_paths:
                    raise ValueError("Session/independent full path parity failed")
            native.call(op="init", case=case, arm="baseline")
            if not native.call(
                op="episode",
                atom=["path", 0, 7],
                premises=[["edge", 0, 2], ["edge", 2, 4], ["edge", 4, 7]],
            )["supportQualified"]:
                raise ValueError("true explicit chain rejected")
            if native.call(
                op="episode",
                atom=["path", 0, 7],
                premises=[["edge", 1, 2], ["edge", 2, 4], ["edge", 4, 7]],
            )["supportQualified"]:
                raise ValueError("wrong chain admitted")
            if native.call(op="episode", atom=["path", 0, 7], premises=[])[
                "supportQualified"
            ]:
                raise ValueError("assertion counted as derivation")
            records.append(
                {
                    "case": case,
                    "task": task,
                    "seedGrade": seed,
                    "certificateSha256": cert_hashes[0],
                    "libraryLifecycle": lifecycle,
                    "rootContexts": contexts,
                    "probeParity": True,
                }
            )
        save(
            run / "qualification-native.json",
            {"scenario": native.trace, "judge": judge.trace},
        )
    # Both candidate implementation and original checker kernel remain byte bound.
    for dirname in ("candidate", "program"):
        for p in (KERNEL / dirname).glob("*.ss"):
            if p.read_bytes() != (ROOT / dirname / p.name).read_bytes():
                raise ValueError("kernel source drift: " + dirname + "/" + p.name)
    save(
        run / "qualification.json",
        {
            "tasks": records,
            "rootTaskParity": True,
            "nativeProbeJudgeParity": True,
            "judgeSha256": sha((KERNEL / ".gerbil/bin/crosspath-search").read_bytes()),
        },
    )
    report_text("QUALIFIED", len(records), flush=True)
