# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import subprocess
from ._config import MAX_INPUT_BYTES, MAX_OUTPUT_TOKENS, ROOT
from ._native import scheme
from ._request import request_for
from ._sources import digest, identities


def prepare(output):
    output.mkdir(parents=True, exist_ok=False)
    scheme("prepare", output / "scheme-scenario.json")
    scenario = json.loads((output / "scheme-scenario.json").read_text())
    private = output / "private"
    private.mkdir()
    public_cases = []
    for case in scenario["cases"]:
        # Gold contract and answers stay outside every provider request.
        public_cases.append(
            {
                k: v
                for k, v in case.items()
                if k not in ("combine", "exclude_scope", "expected")
            }
        )
        (private / (case["id"] + ".answer.json")).write_text(
            json.dumps(case["expected"]) + "\n"
        )
        (private / (case["family"] + ".contract.json")).write_text(
            json.dumps({k: case[k] for k in ("combine", "exclude_scope")}) + "\n"
        )
    order = []
    for index, case in enumerate(public_cases):
        scheduled = [("baseline", case["id"])]
        if case["id"].endswith("-seed"):
            scheduled.append(("scheme-contract", case["family"]))
        if index % 2:
            scheduled.reverse()
        for arm, identity in scheduled:
            request = request_for(scenario["source"], case, arm)
            data = (
                json.dumps(request, ensure_ascii=False, sort_keys=True) + "\n"
            ).encode()
            name = identity + "." + arm + ".request.json"
            (output / name).write_bytes(data)
            order.append(
                {
                    "arm": arm,
                    "id": identity,
                    "request": name,
                    "sha256": digest(data),
                    "inputBytes": len(data),
                }
            )
    plan = {
        "schema": "ascent.movie-cast-plan.v1",
        "sourceHead": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "producerHashes": identities(),
        "model": "deepseek-flash",
        "cases": public_cases,
        "order": order,
        "scheduledBaselineCalls": 6,
        "scheduledContractCalls": 3,
        "retries": 0,
        "maxInputBytes": MAX_INPUT_BYTES,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "providerCallsExecuted": 0,
        "liveAuthorized": False,
        "candidateBudgetCeilingUsd": 1,
        "priceSource": "https://api-docs.deepseek.com/quick_start/pricing/",
        "conservativeScheduledUpperUsd": sum(
            (item["inputBytes"] + 1024) * 0.3 + MAX_OUTPUT_TOKENS * 1.2
            for item in order
        )
        / 1_000_000,
        "purpose": "mechanism-regression",
        "capabilityEvaluationEligible": False,
        "primaryMetric": "Scheme contract admission, scoped evidence and binding substitution only; six questions cannot establish model reasoning ability or economic benefit",
        "reuseBoundary": "Caller-declared identical template only; hashes bind source, implementation, schema and prompt bytes; answers recomputed from current bindings, not reused",
        "target": "No capability or savings target for this regression; the 6:3 call schedule is constructed, not an experimental cost result",
    }
    (output / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    report_text(
        "MOVIE-STUDY-PREPARED cases=6 scheduledCalls=9 executedCalls=0", flush=True
    )


def validate(preview):
    plan = json.loads((preview / "plan.json").read_text())
    if plan["producerHashes"] != identities():
        raise ValueError("movie source/implementation changed: prepare a new plan")
    for item in plan["order"]:
        if digest((preview / item["request"]).read_bytes()) != item["sha256"]:
            raise ValueError("movie prompt changed")
    return plan


def offline(preview, output):
    plan = validate(preview)
    output.mkdir(parents=True, exist_ok=False)
    observations = []
    commands = []
    for item in plan["order"]:
        mode = "baseline" if item["arm"] == "baseline" else "family"
        kind = "answer" if mode == "baseline" else "contract"
        destination = output / (item["id"] + "." + item["arm"] + ".json")
        commands.append(
            [
                mode,
                item["id"],
                str(preview / "private" / (item["id"] + "." + kind + ".json")),
                str(destination),
            ]
        )
    batch = output / "commands.json"
    batch.write_text(json.dumps(commands) + "\n")
    scheme("batch", batch)
    for item in plan["order"]:
        destination = output / (item["id"] + "." + item["arm"] + ".json")
        value = json.loads(destination.read_text())
        observations.append({"arm": item["arm"], "id": item["id"], "scheme": value})
    result = {
        "schema": "ascent.movie-cast-offline.v1",
        "sourceHead": plan["sourceHead"],
        "providerCalls": 0,
        "controlOrigin": "Scheme gold fixture; not model predictions",
        "observations": observations,
        "observedTokenSavings": None,
        "observedCostSavings": None,
        "observedModelAccuracy": None,
        "engineControlsCorrect": all(
            row["correct"]
            for item in observations
            for row in (
                item["scheme"] if isinstance(item["scheme"], list) else [item["scheme"]]
            )
        ),
    }
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    if not result["engineControlsCorrect"]:
        raise RuntimeError("scheme offline control failed; result retained")
    report_text("MOVIE-STUDY-OFFLINE-OK controls=9 providerCalls=0", flush=True)
