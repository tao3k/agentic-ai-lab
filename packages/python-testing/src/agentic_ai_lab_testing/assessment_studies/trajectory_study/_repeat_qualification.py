# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Verify completed-result reuse and source withdrawal against fresh independent answers."

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import io
import json
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..model_study import provider
from ._projection import extract


def _qualify_repeat_and_withdrawal(
    chain,
    primary,
    reference,
    trajectory,
    case,
    plan,
    folder,
    arm,
    key,
    calls,
):
    """Own the qualify repeat and withdrawal phase and retain its evidence checks."""
    repeated = None
    invalidation = None
    if chain and primary["verified"]:
        if reference is None:
            reference = chain.query(case["program"])["resultReference"]
        before = trajectory.snapshot()["totals"]["modelCalls"]
        repeat_answer = sorted(row[0] for row in chain.answer(reference, "answer"))
        trajectory.verify(repeat_answer == case["gold"], "independent-repeat-oracle.v1")
        repeated = {
            "correct": repeat_answer == case["gold"],
            "actualModelCalls": trajectory.snapshot()["totals"]["modelCalls"] - before,
        }
        # Withdraw all starts: old result must be rejected; fresh result is empty.
        changed = json.loads(json.dumps(case["sources"]))
        next(r for r in changed if r["name"] == "start")["rows"] = []
        chain.replace(changed)
        try:
            chain.answer(reference, "answer")
            stale_rejected = False
        except ValueError:
            stale_rejected = True
        changed_program = json.loads(json.dumps(case["program"]))
        changed_program["relations"] = [
            next((r for r in changed if r["name"] == old["name"]), old)
            for old in changed_program["relations"]
        ]
        fresh = chain.query(changed_program)
        fresh_correct = fresh["result"]["relations"]["answer"] == []
        trajectory.verify(fresh_correct, "independent-withdrawal-oracle.v1")
        invalidation = {
            "staleRejected": stale_rejected,
            "freshCorrect": fresh_correct,
            "reusedComponents": len(fresh["reusedComponents"]),
        }
    if chain is None and primary["verified"]:
        repeat_request = {
            "model": plan["model"],
            "input": ResponseHistory(case["question"]).input(),
            "reasoning": {"effort": plan["effort"]},
            "max_output_tokens": plan["maxOutputTokens"],
            "stream": True,
            "store": False,
        }
        (folder / "repeat-request.json").write_text(
            json.dumps(repeat_request, indent=2)
        )
        report_text(f"REPEAT {case['case']} {arm}", flush=True)
        with contextlib.redirect_stdout(io.StringIO()):
            raw, meta = provider(repeat_request, key, folder / "repeat-provider.json")
        (folder / "repeat-answer.txt").write_text(raw)
        usage = (meta.get("terminal") or {}).get("usage")
        trajectory.model_call(f"{case['case']}:{arm}:repeat", len(calls) + 1, usage)
        correct = extract(raw) == case["gold"]
        trajectory.verify(correct, "independent-repeat-oracle.v1")
        repeated = {
            "correct": correct,
            "actualModelCalls": 1,
            "usage": usage,
            "error": meta.get("error"),
        }
    return repeated, invalidation
