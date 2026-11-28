# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the repository model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import concurrent.futures
import hashlib
import json
import multiprocessing
from ..repository_corpus import tree_identity
from ._config import ROOT
from ._episode import episode


def live(plan_dir, output):
    plan_dir = plan_dir.resolve()
    output = output.resolve()
    plan = json.loads((plan_dir / "plan.json").read_text())
    for path, sha in plan["producerHashes"].items():
        if hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != sha:
            raise ValueError("producer drift")
    if (
        hashlib.sha256((plan_dir / "libascent.dylib").read_bytes()).hexdigest()
        != plan["librarySha256"]
    ):
        raise ValueError("engine drift")
    for case in plan["tasks"]:
        if (
            tree_identity(plan_dir / case["name"] / "parent")[0]
            != case["snapshotIdentity"]
        ):
            raise ValueError("parent source drift")
        if (
            hashlib.sha256(
                (plan_dir / case["name"] / "grading.py").read_bytes()
            ).hexdigest()
            != case["graderSha256"]
        ):
            raise ValueError("grader drift")
    output.mkdir(parents=True, exist_ok=False)
    (plan_dir / "paid-claim.json").open("x").close()
    receipt = {
        "schema": "ascent.repository-model-result.v1",
        "planSha256": hashlib.sha256((plan_dir / "plan.json").read_bytes()).hexdigest(),
        "episodes": [],
        "complete": False,
    }

    def add(record):
        receipt["episodes"].append(record)
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")

    jobs = []
    arms = tuple(plan["arms"])
    for i, case in enumerate(plan["tasks"]):
        for rep in range(plan["repetitions"]):
            offset = (i + rep) % len(arms)
            order = arms[offset:] + arms[:offset]
            jobs.extend((case, rep, arm) for arm in order)
    add(episode(plan, plan_dir, output, *jobs.pop(0)))
    if receipt["episodes"][-1]["status"] in ("transport_failure", "harness_failure"):
        raise RuntimeError(
            "first real trajectory did not qualify transport and execution; no fan-out"
        )
    with concurrent.futures.ProcessPoolExecutor(
        max_workers=plan["workers"],
        mp_context=multiprocessing.get_context("spawn"),
        max_tasks_per_child=1,
    ) as pool:
        iterator = iter(jobs)
        pending = {
            pool.submit(episode, plan, plan_dir, output, *next(iterator))
            for _ in range(plan["workers"])
        }
        while pending:
            done, pending = concurrent.futures.wait(
                pending, return_when=concurrent.futures.FIRST_COMPLETED
            )
            for future in done:
                record = future.result()
                add(record)
                if record["status"] in ("transport_failure", "harness_failure"):
                    for other in pending:
                        other.cancel()
                    raise RuntimeError(
                        "stop new dispatch after transport or harness failure"
                    )
                job = next(iterator, None)
                if job:
                    pending.add(pool.submit(episode, plan, plan_dir, output, *job))
    receipt["complete"] = True
    add_marker = output / "result.json"
    add_marker.write_text(json.dumps(receipt, indent=2) + "\n")
    report_text("REPOSITORY-STUDY-COMPLETE", len(receipt["episodes"]), flush=True)
