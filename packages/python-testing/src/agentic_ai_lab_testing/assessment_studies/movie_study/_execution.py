# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import os
from pathlib import Path
import time
from ._native import scheme
from ._provider import provider_fatal, provider_key
from ._snapshot import validate
from ._sources import digest


def live(preview, output):
    from ..model_study import provider

    plan = validate(preview)
    if (
        plan.get("purpose") != "mechanism-regression"
        or plan.get("capabilityEvaluationEligible") is not False
    ):
        raise ValueError("expected frozen mechanism regression plan")
    bound = (
        sum(
            (len((preview / item["request"]).read_bytes()) + 1024) * 0.3
            + plan["maxOutputTokens"] * 1.2
            for item in plan["order"]
        )
        / 1_000_000
    )
    if len(plan["order"]) != 9 or bound > 1:
        raise ValueError("pilot exceeds nine-call / one-dollar bound")
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    with (preview / "paid-batch-claim.json").open("x") as claim:
        claim.write(
            json.dumps(
                {
                    "planSha256": digest((preview / "plan.json").read_bytes()),
                    "output": str(output),
                    "maxCalls": 9,
                    "budgetCeilingUsd": 1,
                }
            )
            + "\n"
        )
        claim.flush()
        os.fsync(claim.fileno())
    records = []
    commands = []
    started = time.monotonic()
    try:
        for index, item in enumerate(plan["order"]):
            validate(preview)
            request = json.loads((preview / item["request"]).read_text())
            if (
                request.get("model") != "deepseek-flash"
                or request.get("max_output_tokens") != plan["maxOutputTokens"]
            ):
                raise ValueError("provider request limits changed")
            directory = output / f"{index:02d}"
            directory.mkdir()
            (directory / "request.json").write_text(json.dumps(request) + "\n")
            report_text(
                f"MOVIE-CALL {index + 1}/9 {item['arm']} {item['id']}", flush=True
            )
            raw, response = provider(request, key, directory / "response.json")
            raw_path = directory / "raw-output.txt"
            raw_path.write_text(raw)
            terminal = response["terminal"] or {}
            record = {
                **item,
                "providerCompleted": terminal.get("status") == "completed"
                and not provider_fatal(response),
                "resolvedModel": terminal.get("model"),
                "responseId": terminal.get("id"),
                "usage": terminal.get("usage"),
                "providerError": response["error"],
                "providerSeconds": response["providerSeconds"],
                "gradePath": str(directory / "grade.json"),
            }
            records.append(record)
            with (output / "calls.jsonl").open("a") as ledger:
                ledger.write(json.dumps(record) + "\n")
                ledger.flush()
                os.fsync(ledger.fileno())
            mode = "baseline" if item["arm"] == "baseline" else "family"
            commands.append([mode, item["id"], str(raw_path), record["gradePath"]])
            report_text(
                f"\nMOVIE-RESPONSE complete={record['providerCompleted']}", flush=True
            )
            if provider_fatal(response):
                break  # Capped answers remain scheduled failures.
        batch = output / "commands.json"
        batch.write_text(json.dumps(commands) + "\n")
        scheme("batch", batch)
        for record in records:
            record["engineObservation"] = json.loads(
                Path(record["gradePath"]).read_text()
            )
    finally:
        result = {
            "purpose": "mechanism-regression",
            "capabilityEvaluationEligible": False,
            "scheduledCalls": 9,
            "executedCalls": len(records),
            "budgetCeilingUsd": 1,
            "seconds": time.monotonic() - started,
            "records": records,
            "capabilityConclusion": None,
            "costSavingsConclusion": None,
        }
        (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    report_text("MOVIE-LIVE-PILOT-RECORDED", flush=True)
