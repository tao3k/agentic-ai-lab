# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Retain the exact request, returned response and actual call usage for one study turn."

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib, io, json
from ..trajectory_study import extract
from ..model_study import provider


def _invoke_study_turn(plan, key, calls_audit, output, history, folder, stem):
    request = {
        "model": plan["model"],
        "input": history.input(),
        "reasoning": {"effort": "high"},
        "max_output_tokens": 131072,
        "stream": True,
        "store": False,
    }
    (folder / f"{stem}-request.json").write_text(json.dumps(request, indent=2))
    report_text(f"CALL {folder.name} {stem}", flush=True)
    with contextlib.redirect_stdout(io.StringIO()):
        raw, meta = provider(request, key, folder / f"{stem}-provider.json")
    (folder / f"{stem}-answer.txt").write_text(raw)
    terminal = meta.get("terminal") or {}
    observation = {
        "callId": folder.name + ":" + str(stem),
        "usage": terminal.get("usage"),
        "status": terminal.get("status"),
        "error": meta.get("error"),
        "prediction": extract(raw),
        "providerSeconds": meta["providerSeconds"],
    }
    calls_audit.append(observation)
    (output / "actual-calls.json").write_text(json.dumps(calls_audit, indent=2))
    return observation, terminal
