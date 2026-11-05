# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Audit completed frozen trajectories without changing their outcomes or costs."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import hashlib
import json
from pathlib import Path
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price

FAILURES = {
    "action_failure",
    "answer_not_verified",
    "output_budget_exhausted",
    "provider_failure",
}


from ._compound_report_rendering import (
    _render_mechanism_costs,
    _render_failure_feedback,
    _render_paired_outcomes,
    render_report,
)


def _build_summarize_episode_result(
    aliases,
    answers,
    attempts,
    completed_hits,
    effort,
    episode,
    exposures,
    extensions,
    failures,
    first,
    labels,
    query_calls,
    repair,
):
    """Assemble the retained summarize episode result structure."""
    return {
        "firstAnswerCorrect": bool(answers and answers[0]["correct"]),
        "answerAttempts": len(answers),
        "case": episode["case"],
        "repetition": episode["repetition"],
        "arm": episode["arm"],
        "effort": effort,
        "failureAttempts": len(failures),
        "firstFailureTurn": first + 1 if first is not None else None,
        "failureAndRepairEffort": repair,
        "postFailureModelCalls": max(0, repair["modelCalls"] - 1)
        if first is not None
        else 0,
        "peakEstimateUsd": sum(price(a["usage"]) for a in attempts if a.get("usage")),
        "failureAndRepairPeakEstimateUsd": sum(
            price(a["usage"]) for a in attempts[first:] if a.get("usage")
        )
        if first is not None
        else 0,
        "queryActions": query_calls,
        "evidencePublished": bool(aliases),
        "laterCallsExposedToEvidence": exposures,
        "aliasExtensionQueries": extensions,
        "completedPathHits": completed_hits,
        "actions": labels,
        "failureDetails": [
            {
                "turn": i + 1,
                "outcome": a.get("outcome"),
                "feedback": a.get("feedback")
                or [t.get("feedback") for t in a.get("toolActions", [])],
                "thinkingTokens": (a.get("usage") or {})
                .get("output_tokens_details", {})
                .get("reasoning_tokens"),
            }
            for i, a in enumerate(attempts)
            if i in failures
        ],
    }


def summarize_episode(episode):
    attempts = episode["attempts"]
    effort = until_verified(attempts)
    failures = [
        i
        for i, a in enumerate(attempts)
        if a.get("outcome") in FAILURES
        or a.get("providerOutcome") not in (None, "completed_ungraded")
    ]
    first = failures[0] if failures else None
    # The suffix is observed failure + repair work, not an assertion that every
    # token in it was avoidable. A censored suffix is still charged.
    repair = (
        until_verified(attempts[first:]) if first is not None else until_verified([])
    )
    aliases = set()
    extensions = 0
    exposures = 0
    completed_hits = 0
    query_calls = 0
    answers = []
    labels = []
    for attempt in attempts:
        if aliases:
            exposures += attempt["providerCalls"]
        records = attempt.get("toolActions") or [attempt]
        call_labels = []
        for record in records:
            action = record.get("action", {})
            kind = action.get("action")
            call_labels.append(
                kind if isinstance(kind, str) else "invalid action shape"
            )
            if kind == "answer":
                answers.append(record)
            if kind == "query":
                query_calls += 1
                referenced = {
                    a["relation"]
                    for r in action["contract"]["rules"]
                    for a in r["body"]
                }
                extensions += bool(referenced & aliases)
                feedback = record.get("feedback", {})
                completed_hits += bool(feedback.get("retainedCompleted"))
                aliases.update(
                    x["relation"] for x in feedback.get("publishedEvidence", [])
                )
        labels.append("+".join(call_labels))
    return _build_summarize_episode_result(
        aliases,
        answers,
        attempts,
        completed_hits,
        effort,
        episode,
        exposures,
        extensions,
        failures,
        first,
        labels,
        query_calls,
        repair,
    )


def _summarize_arms(plan, receipt, episodes):
    """Own the summarize arms phase without weakening its checks."""
    groups = {}
    for arm in plan["arms"]:
        values = [e for e in episodes if e["arm"] == arm]
        groups[arm] = {
            "trajectories": len(values),
            "verified": sum(e["effort"]["verified"] for e in values),
            "accuracy": sum(e["effort"]["verified"] for e in values) / len(values),
            "firstAnswerCorrect": sum(e["firstAnswerCorrect"] for e in values),
            "answerAttempts": sum(e["answerAttempts"] for e in values),
            "consumedReasoningTokens": sum(
                e["effort"]["observedReasoningTokens"] for e in values
            ),
            "modelCalls": sum(e["effort"]["modelCalls"] for e in values),
            "consumedInputTokens": sum(e["effort"]["inputTokens"] for e in values),
            "consumedOutputTokens": sum(
                e["effort"]["outputIncludingReasoningTokens"] for e in values
            ),
            "failureAttempts": sum(e["failureAttempts"] for e in values),
            "failureAndRepairReasoningTokens": sum(
                e["failureAndRepairEffort"]["observedReasoningTokens"] for e in values
            ),
            "failureAndRepairModelCalls": sum(
                e["failureAndRepairEffort"]["modelCalls"] for e in values
            ),
            "failureAndRepairPeakEstimateUsd": sum(
                e["failureAndRepairPeakEstimateUsd"] for e in values
            ),
            "peakEstimateUsd": sum(e["peakEstimateUsd"] for e in values),
            "evidenceAdoption": sum(e["evidencePublished"] for e in values),
            "aliasExtensionQueries": sum(e["aliasExtensionQueries"] for e in values),
            "schemeSeconds": sum(e["effort"]["schemeSeconds"] for e in values),
            "providerSeconds": sum(
                a.get("providerSeconds", 0)
                for e in receipt["episodes"]
                if e["arm"] == arm
                for a in e["attempts"]
            ),
            "reasoningUsageComplete": all(
                e["effort"]["reasoningUsageComplete"] for e in values
            ),
            "modelUsageComplete": all(
                e["effort"]["modelUsageComplete"] for e in values
            ),
        }
    return groups


def summarize(plan, receipt):
    episodes = [summarize_episode(e) for e in receipt["episodes"]]
    expected = len(plan["cases"]) * len(plan["arms"]) * plan["repetitions"]
    if len(episodes) != expected or "pairs" not in receipt:
        raise ValueError("experiment incomplete; do not publish a completed report")
    keys = {(e["case"], e["repetition"], e["arm"]) for e in episodes}
    if len(keys) != expected:
        raise ValueError("duplicate trajectories")
    groups = _summarize_arms(plan, receipt, episodes)
    pairs = []
    for case in plan["cases"]:
        for rep in range(plan["repetitions"]):
            b = next(
                e
                for e in episodes
                if e["case"] == case["name"]
                and e["repetition"] == rep
                and e["arm"] == plan["arms"][0]
            )
            a = next(
                e
                for e in episodes
                if e["case"] == case["name"]
                and e["repetition"] == rep
                and e["arm"] == plan["arms"][1]
            )
            pairs.append(
                {
                    "case": case["name"],
                    "repetition": rep,
                    "bothVerified": b["effort"]["verified"] and a["effort"]["verified"],
                    "thinkingReduction": paired_reduction(
                        b["effort"], a["effort"], "observedReasoningTokens"
                    ),
                    "modelTurnReduction": paired_reduction(
                        b["effort"], a["effort"], "modelCalls"
                    ),
                }
            )
    complete = [p for p in pairs if p["bothVerified"]]
    measurable = [p for p in complete if p["thinkingReduction"] is not None]
    selected = {(p["case"], p["repetition"]) for p in measurable}
    matched = {
        arm: sum(
            e["effort"]["observedReasoningTokens"]
            for e in episodes
            if e["arm"] == arm and (e["case"], e["repetition"]) in selected
        )
        for arm in plan["arms"]
    }
    denominator = matched[plan["arms"][0]]
    return {
        "schema": "ascent.compound-thinking-audit.v1",
        "groups": groups,
        "episodes": episodes,
        "pairs": pairs,
        "jointlyVerifiedPairs": len(complete),
        "measurableThinkingPairs": len(measurable),
        "totalPairs": len(pairs),
        "jointlyVerifiedThinkingTokens": matched,
        "jointlyVerifiedThinkingReduction": 1 - matched[plan["arms"][1]] / denominator
        if denominator
        else None,
        "scope": "Observed cumulative thinking effort; does not identify exact redundant internal token spans. Jointly verified subset must be read alongside all-arm accuracy and censored costs.",
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("plan", type=Path)
    p.add_argument("result", type=Path)
    p.add_argument("output", type=Path)
    a = p.parse_args()
    plan = json.loads(a.plan.read_text())
    receipt = json.loads(a.result.read_text())
    if hashlib.sha256(a.plan.read_bytes()).hexdigest() != receipt["planSha256"]:
        raise ValueError("plan identity mismatch")
    result = summarize(plan, receipt)
    result["planSha256"] = receipt["planSha256"]
    result["rawResultSha256"] = hashlib.sha256(a.result.read_bytes()).hexdigest()
    a.output.write_text(json.dumps(result, indent=2) + "\n")
    a.output.with_suffix(".md").write_text(render_report(plan, result, receipt))
    report_text(
        json.dumps(
            {
                "groups": result["groups"],
                "jointlyVerifiedPairs": result["jointlyVerifiedPairs"],
                "thinkingReduction": result["jointlyVerifiedThinkingReduction"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
