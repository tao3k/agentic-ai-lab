# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Pair every frozen trial and compare common evidence replies without removing negatives."

import json, statistics
from ._factor_budget_metrics import metrics


def _aggregate_budget_arms(rows):
    """Own the aggregate budget arms phase without weakening its checks."""
    aggregates = {}
    for arm in ("fresh", "retained"):
        rs = [r for r in rows if r["arm"] == arm]
        ms = [metrics(r) for r in rs]
        aggregates[arm] = {
            "phases": len(rs),
            "submitted": sum((m["submitted"] for m in ms)),
            "optimal": sum((m["optimal"] for m in ms)),
            "submittedOptimal": sum(
                m["optimal"] and m["submitted"] and m["failure"] is None for m in ms
            ),
            "failures": sum((m["failure"] is not None for m in ms)),
            "validCandidates": sum((r["grade"]["valid"] for r in rs)),
            "meanRelativeGapOnValid": statistics.mean(
                (m["relativeGap"] for m in ms if m["relativeGap"] is not None)
            )
            if any((m["relativeGap"] is not None for m in ms))
            else None,
            **{
                k: sum((m[k] for m in ms))
                for k in (
                    "inputTokens",
                    "outputTokens",
                    "reasoningTokens",
                    "totalTokens",
                    "providerCachedInputTokens",
                    "missingUsageCalls",
                    "factorChecksAlreadyCoveredByPacket",
                    "duplicateFactRequests",
                    "duplicateExploreRequests",
                    "duplicateEvaluateRequests",
                    "uniqueFeasibleSchedules",
                    "uniqueValidPrefixes",
                    "branchedPrefixParents",
                    "nativePacketAndFactorSeconds",
                    "totalToolSeconds",
                    "proofBytesWritten",
                    "freshNativeFactorSolves",
                    "retainedNativeFactorLookups",
                    "freshNativePacketSolves",
                    "retainedNativePacketLookups",
                )
            },
        }
    return aggregates


def _compare_fact_replies(plan, BASE, rows):
    """Own the compare fact replies phase without weakening its checks."""
    shared = 0
    for c in plan["cases"]:
        for phase in (0, 1):
            group = [r for r in rows if r["case"] == c["id"] and r["phase"] == phase]
            maps = []
            for r in group:
                d = {}
                for t in r["tools"]:
                    if t.get("failure"):
                        continue
                    key = t["name"] + json.dumps(t.get("arguments"), sort_keys=True)
                    if key in d:
                        assert d[key] == t["result"]
                    d[key] = t["result"]
                maps.append(d)
            for key in maps[0].keys() & maps[1].keys():
                assert maps[0][key] == maps[1][key]
                shared += 1
    return shared


def _pair_budget_trials(plan, rows, BASE):
    """Own the pair budget trials phase without weakening its checks."""
    pairs = []
    for c in plan["cases"]:
        for phase in (0, 1):
            f = next(
                (
                    r
                    for r in rows
                    if r["case"] == c["id"]
                    and r["phase"] == phase
                    and (r["arm"] == "fresh")
                )
            )
            t = next(
                (
                    r
                    for r in rows
                    if r["case"] == c["id"]
                    and r["phase"] == phase
                    and (r["arm"] == "retained")
                )
            )
            assert (
                f["initialInputSha256"] == t["initialInputSha256"]
                and f["packet"]["proofSha256"] == t["packet"]["proofSha256"]
            )
            fm, tm = (metrics(f), metrics(t))
            pairs.append(
                {
                    "case": c["id"],
                    "phase": phase,
                    "initialInputsAndPacketsMatched": True,
                    "fresh": fm,
                    "retained": tm,
                    "retainedMinusFresh": {
                        k: tm[k] - fm[k]
                        for k in (
                            "totalTokens",
                            "reasoningTokens",
                            "factorChecksAlreadyCoveredByPacket",
                            "uniqueFeasibleSchedules",
                            "maxProperPrefixDepth",
                            "branchedPrefixParents",
                        )
                    },
                    "qualityGapDelta": tm["objectiveGap"] - fm["objectiveGap"]
                    if tm["objectiveGap"] is not None and fm["objectiveGap"] is not None
                    else None,
                }
            )
    return pairs
