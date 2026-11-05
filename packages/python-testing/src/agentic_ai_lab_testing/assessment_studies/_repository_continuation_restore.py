# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Restore exact response history and source state without repeating historical calls or tests."

import copy
import json
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from . import repository_model_study as study


def restored_history(directory, record):
    last = record["attempts"][-1]["turn"]
    request = json.loads((directory / f"{last}.request.json").read_text())
    terminal = json.loads((directory / f"{last}.response.json").read_text())["terminal"]
    history = ResponseHistory.restore(request["input"])
    calls = history.append_response(terminal)
    results = {
        action["callId"]: action["result"]
        for action in record["attempts"][-1]["actions"]
        if "callId" in action
    }
    for call in calls:
        history.append_result(call["call_id"], results[call["call_id"]])
    if not calls:
        actions = record["attempts"][-1]["actions"]
        if not actions:
            raise ValueError(
                "last implicit feedback unavailable; cannot restore exact history"
            )
        history.append_feedback(actions[-1]["result"])
    return history, request


def replay_source(workspace, original, record):
    """Reconstruct actual evidence state without rerunning historical tests or models."""
    for attempt in record["attempts"]:
        terminal = json.loads(
            (original / f"{attempt['turn']}.response.json").read_text()
        )["terminal"]
        actions = {action.get("callId"): action for action in attempt["actions"]}
        for call in terminal["output"]:
            if call.get("type") != "function_call":
                continue
            action = actions[call["call_id"]]
            result = action.get("result")
            if isinstance(result, dict) and ("error" in result or "skipped" in result):
                continue
            args = study.loose_json(call["arguments"])
            if call["name"] == "edit_source":
                workspace.edit(args["edits"])
            elif call["name"] == "read_source":
                workspace.read(args["path"], args.get("start", 1), args.get("end"))
    for relative in workspace.case["editable"]:
        if (workspace.root / relative).read_bytes() != (
            original / "workspace" / relative
        ).read_bytes():
            raise ValueError("replay did not reproduce primary source identity")
    return copy.deepcopy(workspace.journal)
