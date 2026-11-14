# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the complex movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
from pathlib import Path
import time
from ascent import Engine
from ..movie_study import provider_key
from ..model_study import provider, response_outcome
from ..query_contract import output_format
from agentic_ai_lab_runtime.reasoning import rows_equal
from ._config import FIXTURE, ROOT
from ._contracts import identity
from ._workload import case_program, materialize, source_for


def live(directory, output):
    plan = json.loads((directory / "plan.json").read_text())
    if (
        identity(plan["source"]) != plan["sourceSha256"]
        or identity(json.loads(FIXTURE.read_text())) != plan["sourceSha256"]
    ):
        raise ValueError("frozen source changed")
    if plan["driverSha256"] != hashlib.sha256(Path(__file__).read_bytes()).hexdigest():
        raise ValueError("driver changed")
    if plan.get("contractSchemaSha256") != identity(output_format()):
        raise ValueError("contract schema changed")
    for name, sha in plan.get("producerHashes", {}).items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != sha:
            raise ValueError(f"producer changed: {name}")
    lib = directory / plan["library"]
    if plan["librarySha256"] != hashlib.sha256(lib.read_bytes()).hexdigest():
        raise ValueError("library changed")
    if (
        len(plan["order"]) != plan["maxCalls"]
        or plan["maxCalls"] not in (9, 24)
        or plan["conservativeScheduledUpperUsd"] > 5
    ):
        raise ValueError("pilot bounds")
    for item in plan["order"]:
        if (
            item["sha256"]
            != hashlib.sha256((directory / item["request"]).read_bytes()).hexdigest()
        ):
            raise ValueError("request changed")
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    (directory / "paid-claim.json").open("x").close()
    receipt = {
        "schema": "ascent.complex-movie-result.v1",
        "planSha256": hashlib.sha256(
            (directory / "plan.json").read_bytes()
        ).hexdigest(),
        "purpose": plan["purpose"],
        "records": [],
        "savingsConclusion": None,
    }
    cache = {}
    startup = time.monotonic()
    with Engine() as engine:
        receipt["engineInitializationSeconds"] = time.monotonic() - startup
        for i, item in enumerate(plan["order"]):
            case = next(c for c in plan["cases"] if c["name"] == item["case"])
            s = source_for(plan["source"], case)
            d = output / f"{i:02d}"
            d.mkdir()
            req = json.loads((directory / item["request"]).read_text())
            views = None
            hit = False
            setup = time.monotonic()
            if item["arm"] == "reuse":
                sid = identity(s)
                hit = sid in cache
                if not hit:
                    cache[sid] = materialize(engine, s)
                views = cache[sid]
                frozen = json.loads(req["input"][0]["content"].split("\n", 1)[1])[
                    "materializedViews"
                ]
                if not all(
                    rows_equal(rows, frozen[name]) for name, rows in views.items()
                ):
                    raise ValueError("runtime views differ from frozen context")
            setup_seconds = time.monotonic() - setup
            report_text(
                "COMPLEX-CALL",
                i + 1,
                "/",
                plan["maxCalls"],
                item["case"],
                item["arm"],
                flush=True,
            )
            raw, meta = provider(req, key, d / "response.json")
            (d / "raw.txt").write_text(raw)
            record = {
                **item,
                "outcome": response_outcome(meta),
                "usage": (meta["terminal"] or {}).get("usage"),
                "providerSeconds": meta["providerSeconds"],
                "correct": False,
                "sourceIdentity": identity(s),
                "viewSetupSeconds": setup_seconds,
                "viewCacheHit": hit,
            }
            if record["outcome"] == "completed_ungraded":
                started = time.monotonic()
                try:
                    candidate = json.loads(raw)
                    if item["arm"] == "direct":
                        if not isinstance(candidate, list) or not all(
                            isinstance(x, str) and x in s["domains"]["Actor"]
                            for x in candidate
                        ):
                            raise ValueError("answer domain")
                        answer = [[x] for x in candidate]
                    else:
                        answer = case_program(engine, s, case, candidate, views)
                    record["correct"] = rows_equal(answer, plan["gold"][case["name"]])
                    record["answer"] = answer
                    record["viewCacheHit"] = hit
                    record["outcome"] = response_outcome(meta, record["correct"])
                except Exception as error:
                    record["outcome"] = "admission_or_execution_failure"
                    record["failure"] = str(error)[:2048]
                record["schemeAndAdmissionSeconds"] = time.monotonic() - started
            receipt["records"].append(record)
            (output / "result.json").write_text(
                json.dumps(receipt, ensure_ascii=False, indent=2) + "\n"
            )
            report_text("\nCOMPLEX-RESULT", record["outcome"], flush=True)
            if meta["error"] or (meta["terminal"] or {}).get("status") == "failed":
                break
