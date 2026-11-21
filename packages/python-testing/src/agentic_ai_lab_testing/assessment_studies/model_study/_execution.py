# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import os
import time
from ._native import native_projection, native_score
from ._provider import provider, request_for
from ._report import summary
from ._sources import digest
from ._validation import validate


def live(preview, output, approved):
    plan = validate(preview, approved)
    key = os.environ.get("DEEPSEEK_API_KEY")
    if not key:
        raise ValueError("DEEPSEEK_API_KEY is not configured")
    output.mkdir(parents=True, exist_ok=False)
    with (preview / "paid-batch-claim.json").open("x") as claim:
        claim.write(json.dumps({"planSha256": approved, "output": str(output)}) + "\n")
        claim.flush()
        os.fsync(claim.fileno())
    initial = {}
    records = []
    try:
        for index, item in enumerate(plan["order"]):
            request = request_for(plan, preview, item, initial)
            destination = output / f"{index:02d}"
            destination.mkdir()
            packet = json.dumps(request, ensure_ascii=False, indent=2).encode()
            (destination / "request.json").write_bytes(packet)
            attempt = {
                **item,
                "index": index,
                "planSha256": approved,
                "requestSha256": digest(packet),
            }
            with (output / "attempts.jsonl").open("a") as ledger:
                ledger.write(json.dumps(attempt) + "\n")
                ledger.flush()
                os.fsync(ledger.fileno())
            report_text(
                f"CALL {index + 1}/60 {item['family']} {item['arm']} ",
                end="",
                flush=True,
            )
            raw, response = provider(request, key, destination / "response.json")
            (destination / "raw-output.txt").write_text(raw)
            start = time.monotonic()
            canonical = native_projection(destination / "raw-output.txt", destination)
            raw_score = native_score(item["case"], raw, destination / "raw")
            observation = native_score(
                item["case"], canonical, destination / "normalized"
            )
            truth = (preview / "private" / f"{item['case']}.sexp").read_text().strip()
            if observation["nativeDatum"] != truth or raw_score["nativeDatum"] != truth:
                raise ValueError(
                    "current native truth changed; batch stops without retry"
                )
            terminal = response["terminal"]
            completed = bool(
                terminal
                and terminal.get("status") == "completed"
                and response["error"] is None
            )
            record = {
                **attempt,
                "raw": raw,
                "responseId": terminal.get("id") if terminal else None,
                "resolvedModel": terminal.get("model") if terminal else None,
                "providerStatus": terminal.get("status") if terminal else None,
                "providerCompleted": completed,
                "providerError": response["error"],
                "usage": terminal.get("usage") if terminal else None,
                "rawObservation": raw_score,
                "nativeObservation": observation,
                "endToEndCorrect": bool(completed and observation["correct"]),
                "providerSeconds": response["providerSeconds"],
                "nativeSeconds": time.monotonic() - start,
                "firstVisibleTextSeconds": response["firstVisibleTextSeconds"],
                "reasoningEvents": response["reasoningEvents"],
            }
            with (output / "calls.jsonl").open("a") as ledger:
                ledger.write(json.dumps(record, ensure_ascii=False) + "\n")
                ledger.flush()
                os.fsync(ledger.fileno())
            records.append(record)
            if item["arm"] == "initial-high":
                initial[item["family"]] = record
            report_text(
                f" DONE complete={completed} correct={record['endToEndCorrect']}",
                flush=True,
            )
    finally:
        (output / "result.json").write_text(
            json.dumps(summary(records, plan), indent=2) + "\n"
        )
