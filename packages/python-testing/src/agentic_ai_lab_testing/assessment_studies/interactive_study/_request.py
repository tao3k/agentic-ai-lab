# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Issue or replay one predeclared interaction request, retaining raw output."

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import io
import json
from ..model_study import provider


def _request_stage_attempt(
    conversation,
    interaction,
    output,
    stem,
    case,
    arm,
    resume_prefix,
    stage,
    attempt,
    key,
):
    """Own the request stage attempt phase and retain its evidence checks."""
    request = {
        "model": "deepseek-flash",
        "input": conversation.history.input(),
        "tools": interaction.tools,
        "tool_choice": "auto",
        "reasoning": {"effort": "high"},
        "max_output_tokens": 131072,
        "stream": True,
        "store": False,
    }
    (output / (stem + "-request.json")).write_text(json.dumps(request, indent=2))
    report_text("CALL", case["case"], arm, stem, flush=True)
    if resume_prefix is not None and stage == 0 and attempt == 0:
        original = json.loads((resume_prefix / (stem + "-request.json")).read_text())
        if original["input"] != request["input"]:
            raise ValueError("recovery must preserve original question bytes")
        raw = (resume_prefix / (stem + "-answer.txt")).read_text()
        meta = json.loads((resume_prefix / (stem + "-provider.json")).read_text())
        (output / (stem + "-provider.json")).write_text(json.dumps(meta, indent=2))
    else:
        with contextlib.redirect_stdout(io.StringIO()):
            raw, meta = provider(request, key, output / (stem + "-provider.json"))
    (output / (stem + "-answer.txt")).write_text(raw)
    return raw, meta
