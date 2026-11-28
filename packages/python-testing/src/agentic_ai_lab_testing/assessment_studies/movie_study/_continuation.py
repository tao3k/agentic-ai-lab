# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Continuation for the movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import os
from pathlib import Path
import time
import shutil
from ._config import ROOT
from ._native import ffi_grade
from ._provider import provider_fatal, provider_key
from ._request import continuation_plan
from ._sources import digest


def continue_ffi(preview, output, frozen_root, library, wire_path):
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from ..model_study import provider

    plan, records = continuation_plan(preview, output, frozen_root)
    key = provider_key()
    # Exclusive claim: interrupted paid continuations require explicit audit,
    # never automatic retries or replay of already charged requests.
    cut = output / "ffi-cut"
    cut.mkdir(exist_ok=False)
    copied = cut / library.name
    shutil.copyfile(library, copied)
    shutil.copyfile(library.with_suffix(library.suffix + ".json"), cut / "build.json")
    shutil.copyfile(wire_path, cut / "wire.json")
    (cut / "transition.json").write_text(
        json.dumps(
            {
                "schema": "ascent.movie-backend-transition.v1",
                "paidPrefix": len(records),
                "planSha256": digest((preview / "plan.json").read_bytes()),
                "previousBackend": "frozen temporary Scheme AOT scorer",
                "currentBackend": "general Scheme C ABI via Python CFFI",
                "librarySha256": digest(copied.read_bytes()),
                "wireSha256": digest((cut / "wire.json").read_bytes()),
                "driverSha256": digest(Path(__file__).read_bytes()),
                "bindingSha256": digest(
                    (ROOT / "rust/ascent-python/src/api/exports.rs").read_bytes()
                ),
                "maxTotalCalls": 9,
                "retries": 0,
                "budgetCeilingUsd": 1,
            },
            indent=2,
        )
        + "\n"
    )
    wire = json.loads((cut / "wire.json").read_text())
    started = time.monotonic()
    try:
        with ReasoningRuntime(copied) as engine:
            for index, record in enumerate(records):
                old = json.loads(Path(record["gradePath"]).read_text())
                old = old if isinstance(old, list) else [old]
                grade = ffi_grade(
                    engine,
                    wire,
                    preview,
                    plan,
                    record,
                    (output / f"{index:02d}" / "raw-output.txt").read_text(),
                )
                if [r["correct"] for r in old] != [r["correct"] for r in grade]:
                    raise ValueError("previous AOT/CFFI grading disagreement")
                record["ffiObservation"] = grade
            for index in range(len(records), len(plan["order"])):
                item = plan["order"][index]
                directory = output / f"{index:02d}"
                directory.mkdir()
                data = (preview / item["request"]).read_bytes()
                if digest(data) != item["sha256"]:
                    raise ValueError("request changed during continuation")
                (directory / "request.json").write_bytes(data)
                report_text(
                    f"MOVIE-CFFI-CALL {index + 1}/9 {item['arm']} {item['id']}",
                    flush=True,
                )
                raw, response = provider(
                    json.loads(data), key, directory / "response.json"
                )
                (directory / "raw-output.txt").write_text(raw)
                terminal = response["terminal"] or {}
                record = {
                    **item,
                    "providerCompleted": terminal.get("status") == "completed"
                    and not provider_fatal(response),
                    "providerStatus": terminal.get("status"),
                    "incompleteDetails": terminal.get("incomplete_details"),
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
                grade = ffi_grade(engine, wire, preview, plan, item, raw)
                (directory / "grade.json").write_text(
                    json.dumps(grade, indent=2) + "\n"
                )
                record["ffiObservation"] = grade
                report_text(
                    f"\nMOVIE-CFFI-GRADE completed={record['providerCompleted']} correct={[x['correct'] for x in grade]}",
                    flush=True,
                )
                if provider_fatal(response):
                    break
    finally:
        (output / "ffi-result.json").write_text(
            json.dumps(
                {
                    "purpose": "mechanism-regression",
                    "capabilityEvaluationEligible": False,
                    "scheduledCalls": 9,
                    "executedCalls": len(records),
                    "continuationSeconds": time.monotonic() - started,
                    "records": records,
                    "capabilityConclusion": None,
                    "costSavingsConclusion": None,
                },
                indent=2,
            )
            + "\n"
        )
