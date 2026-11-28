# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Apply current continuation actions and retain failures without rewriting primary receipts."

from . import repository_model_study as study


def dispatch(workspace, call):
    args = study.loose_json(call["arguments"])
    name = call["name"]
    if name == "read_source":
        return workspace.read(args["path"], args.get("start", 1), args.get("end"))
    if name == "search_source":
        return workspace.search(args["text"], args.get("path"))
    if name == "edit_source":
        return workspace.edit(args["edits"])
    if name == "run_reproducer":
        return workspace.execute(reproducer=True)
    if name == "run_checks":
        return workspace.execute()
    if name == "submit_patch":
        return workspace.execute(grading=True)
    raise ValueError("unknown tool")


def _apply_continuation_response(workspace, history, attempt, calls, raw):
    """Own the apply continuation response phase and retain its evidence checks."""
    if not calls:
        try:
            payload = study.loose_json(raw)
            if isinstance(payload, dict) and "edits" in payload:
                workspace.edit(payload["edits"])
            result = workspace.execute(grading=True)
            attempt["correct"] = result["verified"]
        except Exception as error:
            result = {"error": type(error).__name__ + ": " + str(error)[:1500]}
        attempt["actions"].append({"name": "implicit_submit", "result": result})
        history.append_feedback(result)
    for call in calls:
        try:
            result = (
                {"skipped": "repair already verified"}
                if attempt["correct"]
                else dispatch(workspace, call)
            )
            if call["name"] == "submit_patch" and result.get("verified"):
                attempt["correct"] = True
        except Exception as error:
            result = {"error": type(error).__name__ + ": " + str(error)[:1500]}
        attempt["actions"].append(
            {
                "name": call["name"],
                "callId": call["call_id"],
                "result": result,
            }
        )
        history.append_result(call["call_id"], result)
