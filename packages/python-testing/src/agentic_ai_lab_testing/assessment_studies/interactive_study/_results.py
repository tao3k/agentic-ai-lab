# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Account for every interaction call, failure, repair and unresolved stage."

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from ._cases import obligation_acceptance


def _publish_interaction_result(
    output, case, arm, all_correct, calls, verdicts, checks
):
    """Own the publish interaction result phase and retain its evidence checks."""
    complete = all(
        isinstance(c.get("usage"), dict)
        and isinstance(
            (c["usage"].get("output_tokens_details") or {}).get("reasoning_tokens"),
            int,
        )
        for c in calls
    )
    thinking = sum(
        (c.get("usage") or {})
        .get("output_tokens_details", {})
        .get("reasoning_tokens", 0)
        for c in calls
    )
    repairing = set()
    failed = False
    for c in calls:
        if failed:
            repairing.add(c["id"])
        verdict = next((v for v in verdicts if v["providerCall"] == c["id"]), None)
        if verdict:
            failed = not verdict["correct"]
    repair_thinking = sum(
        (c.get("usage") or {})
        .get("output_tokens_details", {})
        .get("reasoning_tokens", 0)
        for c in calls
        if c["id"] in repairing
    )
    result = {
        "case": case["case"],
        "family": case["family"],
        "arm": arm,
        "wholeTaskCorrect": all_correct,
        "censored": not all_correct,
        "stagesCorrect": sum(obligation_acceptance(verdicts)[0]),
        "obligationFirstSuccess": obligation_acceptance(verdicts)[1],
        "providerCalls": len(calls),
        "thinkingObserved": thinking,
        "thinkingComplete": complete,
        "throughFirstWholeCorrectThinking": thinking
        if all_correct and complete
        else None,
        "repairCalls": len(repairing),
        "repairThinkingObserved": repair_thinking,
        "failedFinalAnswers": sum(not v["correct"] for v in verdicts),
        "toolCalls": len(checks),
        "toolBranches": sum(len(x["feedback"].get("branches", [])) for x in checks),
        "reusedBranches": sum(
            bool(b.get("reusedComponents"))
            for x in checks
            for b in x["feedback"].get("branches", [])
        ),
        "unknownBranches": sum(
            b.get("status") == "unknown"
            for x in checks
            for b in x["feedback"].get("branches", [])
        ),
        "providerErrors": sum(
            bool(c["error"]) or c["status"] != "completed" for c in calls
        ),
    }
    (output / "result.json").write_text(json.dumps(result, indent=2))
    report_text(json.dumps(result), flush=True)
