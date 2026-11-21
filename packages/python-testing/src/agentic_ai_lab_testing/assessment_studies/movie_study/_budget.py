# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Budget for the movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import shutil
from ._config import MAX_OUTPUT_TOKENS
from ._native import ffi_grade
from ._provider import provider_key
from ._sources import digest


def budget_control(preview, pilot, output, wire_path, library):
    """Matched control: change only the output ceiling, keep original failure."""
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from ..model_study import provider, response_outcome

    plan = json.loads((preview / "plan.json").read_text())
    item = plan["order"][2]
    original = (preview / item["request"]).read_bytes()
    if digest(original) != item["sha256"]:
        raise ValueError("original prompt changed")
    request = json.loads(original)
    before = dict(request)
    if MAX_OUTPUT_TOKENS <= request["max_output_tokens"]:
        raise ValueError("expected increased output ceiling")
    request["max_output_tokens"] = MAX_OUTPUT_TOKENS
    if {k: v for k, v in request.items() if k != "max_output_tokens"} != {
        k: v for k, v in before.items() if k != "max_output_tokens"
    }:
        raise ValueError("matched control changed context")
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    copied = output / library.name
    shutil.copyfile(library, copied)
    shutil.copyfile(wire_path, output / "wire.json")
    (output / "request.json").write_text(json.dumps(request, sort_keys=True) + "\n")
    receipt = {
        "schema": "ascent.movie-output-budget-control.v1",
        "purpose": "adaptive single-case diagnostic",
        "changedFields": ["max_output_tokens"],
        "previousMaxOutputTokens": before["max_output_tokens"],
        "maxOutputTokens": request["max_output_tokens"],
        "maxCalls": 1,
        "retries": 0,
        "originalRequestSha256": digest(original),
        "originalScoresChanged": False,
        "librarySha256": digest(copied.read_bytes()),
        "wireSha256": digest((output / "wire.json").read_bytes()),
    }
    (output / "plan.json").write_text(json.dumps(receipt, indent=2) + "\n")
    report_text(
        "OUTPUT-BUDGET-CONTROL",
        before["max_output_tokens"],
        "->",
        request["max_output_tokens"],
        flush=True,
    )
    raw, meta = provider(request, key, output / "response.json")
    (output / "raw-output.txt").write_text(raw)
    with ReasoningRuntime(copied) as engine:
        grade = ffi_grade(
            engine,
            json.loads((output / "wire.json").read_text()),
            preview,
            plan,
            item,
            raw,
        )
    terminal = meta["terminal"] or {}
    receipt.update(
        outcome=response_outcome(meta, all(g["correct"] for g in grade)),
        grade=grade,
        usage=terminal.get("usage"),
        providerSeconds=meta["providerSeconds"],
        status=terminal.get("status"),
        incompleteDetails=terminal.get("incomplete_details"),
    )
    (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
    report_text("\nOUTPUT-BUDGET-CONTROL-RESULT", receipt["outcome"], flush=True)
