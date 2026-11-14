# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reflection for the movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from pathlib import Path
import shutil
from ._config import MAX_INPUT_BYTES, MAX_OUTPUT_TOKENS
from ._native import ffi_grade
from ._provider import provider_key
from ._sources import digest


def reflect(preview, pilot, output, wire_path, library):
    """Two separately recorded diagnostic calls; never rewrite original scores."""
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from ..model_study import provider, response_outcome

    plan = json.loads((preview / "plan.json").read_text())
    original = json.loads((pilot / "ffi-result.json").read_text())
    if original["executedCalls"] != 9:
        raise ValueError("expected completed original pilot")
    item = plan["order"][2]
    data = (preview / item["request"]).read_bytes()
    if digest(data) != item["sha256"]:
        raise ValueError("original request changed")
    response = json.loads((pilot / "02/response.json").read_text())
    if response_outcome(response) != "output_budget_exhausted":
        raise ValueError("expected observed output-budget failure")
    original_request = json.loads(data)
    case = next(c for c in plan["cases"] if c["id"] == item["id"])
    observations = {
        k: response["terminal"].get(k)
        for k in ("status", "error", "incomplete_details", "max_output_tokens", "usage")
    }
    reflection_request = {
        **original_request,
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "input": [
            {
                "role": "user",
                "content": "Review the observable failure below. There was no visible answer, so do not invent a semantic mistake or blame account credits. "
                "Give concise evidence-based diagnosis, not internal chain-of-thought. Do not enumerate actors. "
                "The Scheme executor supports typed Film/Actor relations, branch-scoped exclusion, union/intersection, "
                "deduplication and source-backed evidence; it retains source data and replaces bindings. "
                "Return a JSON object with exactly diagnosis (string), hypotheses (array of strings), "
                "optimizations (array of strings), execution_contract (object with combine:any|all and exclude_scope:none|left|both). "
                "Derive the contract from the question, not from an answer oracle.\n"
                + json.dumps(
                    {
                        "observableFailure": observations,
                        "originalTask": original_request["input"],
                    },
                    ensure_ascii=False,
                ),
            }
        ],
        "text": {"format": {"type": "json_object"}},
    }
    optimized_request = {
        **original_request,
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "input": [
            {
                "role": "user",
                "content": original_request["input"][0]["content"]
                + "\nExecution discipline: treat the finite facts as sets. "
                "Filter each branch with only its declared exclusion, combine the branches, and deduplicate once. "
                "Do not speculate about outside facts or enumerate alternative interpretations. Return the final actor array.",
            }
        ],
    }
    requests = [reflection_request, optimized_request]
    if any(len(json.dumps(r).encode()) > MAX_INPUT_BYTES for r in requests):
        raise ValueError("diagnostic input bound")
    ceiling = (
        sum(
            (len(json.dumps(r).encode()) + 1024) * 0.3 + plan["maxOutputTokens"] * 1.2
            for r in requests
        )
        / 1_000_000
    )
    if ceiling + plan["conservativeScheduledUpperUsd"] > 1:
        raise ValueError("diagnostic cost bound")
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    copied = output / library.name
    shutil.copyfile(library, copied)
    shutil.copyfile(wire_path, output / "wire.json")
    for index, request in enumerate(requests):
        (output / f"{index:02d}.request.json").write_text(
            json.dumps(request, sort_keys=True) + "\n"
        )
    receipt = {
        "schema": "ascent.movie-failure-reflection.v1",
        "purpose": "adaptive diagnostic, not independent benchmark",
        "originalCalls": 9,
        "maxAdditionalCalls": 2,
        "retries": 0,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "originalOutcome": response_outcome(response),
        "originalRequestSha256": digest(data),
        "librarySha256": digest(copied.read_bytes()),
        "wireSha256": digest((output / "wire.json").read_bytes()),
        "driverSha256": digest(Path(__file__).read_bytes()),
        "originalScoresChanged": False,
        "additionalCalls": [],
        "recovery": None,
        "costSavingsConclusion": None,
    }
    (output / "plan.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def call(index):
        request = json.loads((output / f"{index:02d}.request.json").read_text())
        report_text(f"MOVIE-DIAGNOSTIC-CALL {index + 1}/2", flush=True)
        raw, meta = provider(request, key, output / f"{index:02d}.response.json")
        (output / f"{index:02d}.raw.txt").write_text(raw)
        terminal = meta["terminal"] or {}
        record = {
            "requestSha256": digest(
                (output / f"{index:02d}.request.json").read_bytes()
            ),
            "outcome": response_outcome(meta),
            "status": terminal.get("status"),
            "usage": terminal.get("usage"),
            "incompleteDetails": terminal.get("incomplete_details"),
            "providerSeconds": meta["providerSeconds"],
        }
        receipt["additionalCalls"].append(record)
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
        return raw, meta, record

    try:
        raw, meta, record = call(0)
        if response_outcome(meta) != "completed_ungraded":
            return
        reflection = json.loads(raw)
        if not isinstance(reflection, dict) or set(reflection) != {
            "diagnosis",
            "hypotheses",
            "optimizations",
            "execution_contract",
        }:
            raise ValueError("invalid reflection shape")
        receipt["reflection"] = reflection
        wire = json.loads((output / "wire.json").read_text())
        with ReasoningRuntime(copied) as engine:
            recovery = ffi_grade(
                engine,
                wire,
                preview,
                plan,
                {"arm": "scheme-contract", "id": case["family"]},
                json.dumps(reflection["execution_contract"]),
            )
            receipt["recovery"] = recovery
            report_text(
                "\nMODEL-REFLECTION-CONTRACT",
                [g["correct"] for g in recovery],
                flush=True,
            )
            raw, meta, record = call(1)
            grade = ffi_grade(engine, wire, preview, plan, item, raw)
            receipt["optimizedDirectGrade"] = grade
            record["outcome"] = response_outcome(meta, all(g["correct"] for g in grade))
            report_text("\nMODEL-DIAGNOSTIC-DIRECT", record["outcome"], flush=True)
    finally:
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
