# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the iterative tool inference study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import concurrent.futures
import hashlib
import json
import multiprocessing
from .. import inference_reuse_study as study
from ..inference_effort import paired_reduction
from ._episode import run_episode


def live(directory, output):
    pp = directory / "plan.json"
    plan = json.loads(pp.read_text())
    for path, sha in plan["producerHashes"].items():
        if hashlib.sha256((study.ROOT / path).read_bytes()).hexdigest() != sha:
            raise ValueError("producer changed")
    if (
        hashlib.sha256((directory / plan["library"]).read_bytes()).hexdigest()
        != plan["librarySha256"]
    ):
        raise ValueError("engine changed")
    output.mkdir(parents=True, exist_ok=False)
    (directory / "paid-claim.json").open("x").close()
    receipt = {
        "schema": "ascent.tool-thinking-result.v1",
        "planSha256": hashlib.sha256(pp.read_bytes()).hexdigest(),
        "scope": plan["scope"],
        "providerCalls": 0,
        "peakEstimateUsd": 0,
        "episodes": [],
    }

    def save():
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")

    save()
    jobs = []
    for ci, case in enumerate(plan["cases"]):
        for rep in range(plan["repetitions"]):
            arms = plan["arms"] if rep % 2 == 0 else list(reversed(plan["arms"]))
            jobs.extend((case, rep, arm) for arm in arms)
    with concurrent.futures.ProcessPoolExecutor(
        max_workers=plan["workers"], mp_context=multiprocessing.get_context("spawn")
    ) as pool:
        iterator = iter(jobs)
        pending = {
            pool.submit(run_episode, plan, directory, output, *next(iterator))
            for _ in range(min(plan["workers"], len(jobs)))
        }
        while pending:
            done, pending = concurrent.futures.wait(
                pending, return_when=concurrent.futures.FIRST_COMPLETED
            )
            for future in done:
                episode = future.result()
                receipt["episodes"].append(episode)
                receipt["providerCalls"] += sum(
                    a["providerCalls"] for a in episode["attempts"]
                )
                receipt["peakEstimateUsd"] += sum(
                    study.price(a["usage"])
                    for a in episode["attempts"]
                    if a.get("usage")
                )
                save()
                report_text(
                    "TOOL-EPISODE-COMPLETE",
                    episode["case"],
                    episode["repetition"],
                    episode["arm"],
                    episode["effort"],
                    flush=True,
                )
                job = next(iterator, None)
                if job is not None:
                    pending.add(pool.submit(run_episode, plan, directory, output, *job))
    receipt["episodes"].sort(key=lambda e: (e["case"], e["repetition"], e["arm"]))
    pairs = []
    for case in plan["cases"]:
        for rep in range(plan["repetitions"]):
            b, a = [
                next(
                    e["effort"]
                    for e in receipt["episodes"]
                    if e["case"] == case["name"]
                    and e["repetition"] == rep
                    and e["arm"] == arm
                )
                for arm in plan["arms"]
            ]
            pairs.append(
                {
                    "case": case["name"],
                    "repetition": rep,
                    "baseline": b,
                    "assisted": a,
                    "reasoningTokenReduction": paired_reduction(
                        b, a, "observedReasoningTokens"
                    ),
                }
            )
    receipt["pairs"] = pairs
    save()
    report_text("TOOL-THINKING-COMPLETE", receipt["providerCalls"], flush=True)
