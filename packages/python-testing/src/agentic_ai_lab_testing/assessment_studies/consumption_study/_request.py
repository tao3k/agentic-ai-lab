# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Retain the exact request, returned response and actual call usage for one study turn."

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib, copy, io, json
from ..model_study import provider
from ._projection import parse


def _invoke_study_turn(key, audit, output, history, folder, stem):
    folder.mkdir(exist_ok=True)
    request = {
        "model": "deepseek-flash",
        "input": history.input(),
        "reasoning": {"effort": "high"},
        "max_output_tokens": 131072,
        "stream": True,
        "store": False,
    }
    (folder / (stem + "-request.json")).write_text(json.dumps(request, indent=2))
    report_text("CALL", folder.name, stem, flush=True)
    with contextlib.redirect_stdout(io.StringIO()):
        raw, meta = provider(request, key, folder / (stem + "-provider.json"))
    (folder / (stem + "-answer.txt")).write_text(raw)
    terminal = meta.get("terminal") or {}
    call = {
        "callId": folder.name + ":" + stem,
        "usage": terminal.get("usage"),
        "status": terminal.get("status"),
        "error": meta.get("error"),
        "parsed": parse(raw),
        "providerSeconds": meta["providerSeconds"],
    }
    audit.append(copy.deepcopy(call))
    (output / "actual-calls.json").write_text(json.dumps(audit, indent=2))
    return call, terminal
