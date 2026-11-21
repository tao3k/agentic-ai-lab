# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Admit expressed continuation intent, verify exact answers and retain honest repair feedback."

from agentic_ai_lab_runtime.reasoning import ReasoningError
from agentic_ai_lab_runtime.reasoning import identity
from ._projection import proposed


def _assess_consumption_answer(
    obs, case, stage, chain, arm, round, attempt, engine, reference
):
    """Own the assess consumption answer phase and retain its evidence checks."""
    obj = obs["parsed"]
    admission = None
    execution = None
    completed = obs["status"] == "completed" and obs["error"] is None
    if completed and obj:
        try:
            candidate = proposed(case, stage, obj)
            if arm == "executable-evidence":
                execution = chain.consume(
                    reference,
                    candidate,
                    case["programs"][stage],
                    interpretation={
                        "scope": "model-interpreted",
                        "utteranceIdentity": identity(
                            {
                                "goal": case["goals"][stage],
                                "schema": case["schema"],
                            }
                        ),
                        "resolver": "deepseek-flash",
                        "modelCall": "call:" + obs["callId"],
                    },
                )
                admission = execution
            else:
                admission = engine.request(
                    {
                        "operation": "evidence-dag",
                        "action": "check-continuation",
                        "program": candidate,
                        "contract": case["programs"][stage],
                    }
                )
        except (
            ReasoningError,
            KeyError,
            TypeError,
            ValueError,
        ) as e:
            admission = {
                "accepted": False,
                "diagnostic": str(e),
            }
    accepted = bool(admission and admission["accepted"])
    actual = (
        sorted(r[0] for r in execution["result"]["relations"]["answer"])
        if accepted and execution and "result" in execution
        else sorted(obj["answer"])
        if obj
        and isinstance(obj.get("answer"), list)
        and all(isinstance(x, str) for x in obj["answer"])
        else None
    )
    passed = completed and accepted and actual == case["gold"][stage]
    kind = (
        None
        if passed
        else "transport"
        if obs["error"]
        else "budget"
        if not completed
        else "format"
        if obj is None
        else "intent"
        if not accepted
        else "enumeration"
    )
    obs.update(
        stage=stage + 1,
        attempt=attempt,
        round=round,
        correct=passed,
        failureKind=kind,
        admission=admission,
        actualAnswer=actual,
        consumedReference=execution.get("resultReference")
        if passed and arm == "executable-evidence"
        else None,
        reusedComponents=execution.get("reusedComponents", []) if execution else [],
        retainedCompleted=execution.get("retainedCompleted") if execution else None,
    )
    return completed, passed, kind, admission, actual, execution


def _append_repair_feedback(history, case, stage, admission, actual, arm, facts):
    """Own the append repair feedback phase and retain its evidence checks."""
    history.append_feedback(
        {
            "correct": False,
            "goal": case["goals"][stage],
            "schema": case["schema"],
            "intentDiagnostic": admission.get("diagnostic")
            if admission
            else "No usable rule was returned.",
            "answerErrors": {
                "missing": len(set(case["gold"][stage]) - set(actual or [])),
                "extra": len(set(actual or []) - set(case["gold"][stage])),
            },
            "instruction": "Repair the query intent; Scheme executes it. Do not enumerate results."
            if arm == "executable-evidence"
            else "Repair the query and recompute the complete answer using these correct facts.",
            "verifiedIntermediates": {
                "columns": facts["columns"],
                "available": ["balanced"],
            }
            if arm == "executable-evidence"
            else facts,
        }
    )
