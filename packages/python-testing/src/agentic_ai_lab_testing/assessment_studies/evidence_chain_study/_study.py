# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Study for the evidence chain study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_label

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.model_study.reporting import report_text
import concurrent.futures, hashlib, json, multiprocessing, shutil
from pathlib import Path
from .. import evidence_chain_workload as workload
from .. import inference_reuse_study as s
from ._config import ARMS
from ._episode import episode


def prepare(library, directory):
    directory.mkdir(parents=True, exist_ok=False)
    shutil.copy2(library, directory / library.name)
    paths = [
        Path(__file__),
        Path(workload.__file__),
        Path(s.__file__),
        (Path(__file__).parent.parent / "model_study/__init__.py"),
        (Path(__file__).parent.parent / "inference_effort.py"),
        (Path(__file__).parent.parent / "movie_study/__init__.py"),
        s.ROOT / "rust/ascent-python/src/api/exports.rs",
        s.ROOT / "rust/ascent/src/derivations.rs",
        s.ROOT / "rust/ascent-python/src/api/evidence.rs",
        s.ROOT / "rust/ascent/src/conversation.rs",
    ]
    plan = {
        "schema": "ascent.evidence-chain-study.v1",
        "corpusKind": "synthetic-mechanism-regression",
        "arms": list(ARMS),
        "repetitions": 2,
        "maxTurns": 8,
        "maxOutputTokens": 131072,
        "workers": 2,
        "library": library.name,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "cases": [workload.workload(i, 20271011 + i * 1009) for i in range(4)],
        "producerHashes": _source_hashes(
            {str(_source_label(p, s.ROOT)): p for p in paths}
        ),
        "primary": "Cumulative thinking through first independently verified correct answer; all failures and repairs charged, censoring retained.",
        "ablation": "Fresh and retained Scheme arms have identical tools, instructions, result references and provider reasoning history; only component persistence differs.",
        "holdout": "New compound structures, 120 entities, new random chords and seeds; no original question/source reused. Frozen before paid calls.",
        "outputPolicy": "Automatic tool choice, no response-format schema, no required tool choice, prose-wrapped JSON accepted, equivalent singleton head normalized locally; Scheme authority/type/stratification validation preserved.",
        "recovery": "Output exhaustion stays charged and full incomplete reasoning is forwarded within the eight-turn bound. No gold feedback.",
        "costBoundary": "Result references available identically in both Scheme arms; this optimization cannot be credited to retained component reuse.",
    }
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")


def live(plan_dir, output):
    pp = plan_dir / "plan.json"
    plan = json.loads(pp.read_text())
    if plan.get("corpusKind") != "admitted-external-source":
        raise ValueError(
            "Paid primary evaluation requires admitted external-source tasks; synthetic cases are offline mechanism regressions."
        )
    for rel, sha in plan["producerHashes"].items():
        if hashlib.sha256((s.ROOT / rel).read_bytes()).hexdigest() != sha:
            raise ValueError("producer drift")
    if (
        hashlib.sha256((plan_dir / plan["library"]).read_bytes()).hexdigest()
        != plan["librarySha256"]
    ):
        raise ValueError("library drift")
    output.mkdir(parents=True, exist_ok=False)
    (plan_dir / "paid-claim.json").open("x").close()
    receipt = {
        "schema": "ascent.evidence-chain-result.v1",
        "planSha256": hashlib.sha256(pp.read_bytes()).hexdigest(),
        "providerCalls": 0,
        "peakEstimateUsd": 0,
        "episodes": [],
    }

    def save():
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def add(e):
        receipt["episodes"].append(e)
        receipt["providerCalls"] += len(e["attempts"])
        receipt["peakEstimateUsd"] += sum(s.price(a["usage"]) for a in e["attempts"])
        save()

    save()
    jobs = []
    for i, case in enumerate(plan["cases"]):
        for rep in range(plan["repetitions"]):
            order = list(ARMS)
            offset = (i + rep) % 3
            order = order[offset:] + order[:offset]
            jobs.extend((case, rep, arm) for arm in order)
    # One real trajectory qualifies transport before any concurrent fan-out.
    add(episode(plan, plan_dir, output, *jobs.pop(0)))
    with concurrent.futures.ProcessPoolExecutor(
        max_workers=2, mp_context=multiprocessing.get_context("spawn")
    ) as pool:
        iterator = iter(jobs)
        pending = {
            pool.submit(episode, plan, plan_dir, output, *next(iterator))
            for _ in range(2)
        }
        while pending:
            done, pending = concurrent.futures.wait(
                pending, return_when=concurrent.futures.FIRST_COMPLETED
            )
            for future in done:
                try:
                    add(future.result())
                except Exception:
                    for other in pending:
                        other.cancel()
                    raise
                job = next(iterator, None)
                if job:
                    pending.add(pool.submit(episode, plan, plan_dir, output, *job))
    receipt["complete"] = True
    save()
    report_text("EVIDENCE-CHAIN-COMPLETE", receipt["providerCalls"], flush=True)
