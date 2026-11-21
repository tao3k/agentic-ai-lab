# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Report for the model study study."""

import statistics


def summary(records, plan):
    def timing(group, key):
        values = [row[key] for row in group if row.get(key) is not None]
        return {
            "observed": len(values),
            "totalSeconds": sum(values),
            "medianSeconds": statistics.median(values) if values else None,
            "maximumSeconds": max(values) if values else None,
        }

    def cost(group):
        usages = [
            row["usage"]
            for row in group
            if isinstance(row.get("usage"), dict)
            and isinstance(row["usage"].get("input_tokens"), int)
            and isinstance(row["usage"].get("output_tokens"), int)
        ]
        return {
            "usageObserved": len(usages),
            "usageMissing": len(group) - len(usages),
            "inputTokensObserved": sum(x["input_tokens"] for x in usages),
            "outputTokensObserved": sum(x["output_tokens"] for x in usages),
            "observedUsagePeakPriceUpperUsd": sum(
                x["input_tokens"] * 0.3 + x["output_tokens"] * 1.2 for x in usages
            )
            / 1_000_000,
            "actualInvoiceUsd": None,
        }

    results = []
    for arm in (
        "initial-none",
        "initial-high",
        "transfer-fresh",
        "transfer-history",
        "transfer-feedback",
    ):
        group = [row for row in records if row["arm"] == arm]
        results.append(
            {
                "arm": arm,
                "scheduled": 12,
                "attempted": len(group),
                "completed": sum(row["providerCompleted"] for row in group),
                "rawReadable": sum(row["rawObservation"]["readable"] for row in group),
                "normalizedReadable": sum(
                    row["nativeObservation"]["readable"] for row in group
                ),
                "correct": sum(row["endToEndCorrect"] for row in group),
                "nativeCorrectObserved": sum(
                    row["nativeObservation"]["correct"] for row in group
                ),
                "providerFailures": sum(
                    row["providerError"] is not None for row in group
                ),
                "providerTiming": timing(group, "providerSeconds"),
                "nativeScoringTiming": timing(group, "nativeSeconds"),
                "firstVisibleTiming": timing(group, "firstVisibleTextSeconds"),
                "cost": cost(group),
            }
        )
    paired = []
    for a, b in [
        ("initial-none", "initial-high"),
        ("transfer-fresh", "transfer-history"),
        ("transfer-history", "transfer-feedback"),
        ("transfer-fresh", "transfer-feedback"),
    ]:
        left = {row["family"]: row for row in records if row["arm"] == a}
        right = {row["family"]: row for row in records if row["arm"] == b}
        shared = left.keys() & right.keys()
        wins = sum(
            not left[f]["endToEndCorrect"] and right[f]["endToEndCorrect"]
            for f in shared
        )
        losses = sum(
            left[f]["endToEndCorrect"] and not right[f]["endToEndCorrect"]
            for f in shared
        )
        paired.append(
            {
                "baseline": a,
                "comparison": b,
                "matchedFamilies": len(shared),
                "wins": wins,
                "losses": losses,
                "netAccuracyPoints": 100 * (wins - losses) / 12,
            }
        )
    return {
        "schema": "ascent.model-closure-study-result",
        "version": 1,
        "sourceHead": plan["sourceHead"],
        "scheduledCalls": 60,
        "attemptedCalls": len(records),
        "groups": results,
        "paired": paired,
        "cost": cost(records),
        "frozenBudgetCeilingUsd": plan["budgetCeilingUsd"],
        "claimBoundary": "twelve source-bound families; observed accuracy/latency/cost only; no universal gain claim",
    }
