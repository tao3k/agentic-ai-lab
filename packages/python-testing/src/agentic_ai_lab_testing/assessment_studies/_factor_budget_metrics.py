# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Calculate descriptive trajectory effort without discarding failures or censored calls."


def metrics(r):
    usages = [c["usage"] for c in r["calls"] if isinstance(c.get("usage"), dict)]
    factors = [t for t in r["tools"] if t["name"] == "factor"]
    valid = [
        t
        for t in r["tools"]
        if t["name"] in ("evaluate", "submit") and t["result"].get("valid")
    ]
    orders = {tuple(t["arguments"]["order"]) for t in valid}
    prefixes = {
        tuple(t["arguments"]["prefix"])
        for t in r["tools"]
        if t["name"] == "explore" and t["result"].get("validPrefix")
    }
    proper = [p for p in prefixes if len(p) < len(r["grade"]["oracle"]["optimalOrder"])]
    parents = {}
    for p in prefixes:
        if p:
            parents.setdefault(p[:-1], set()).add(p[-1])
    return _build_metrics_result(factors, orders, parents, prefixes, proper, r, usages)


def _build_metrics_result(factors, orders, parents, prefixes, proper, r, usages):
    """Assemble the retained metrics result structure."""
    return {
        "inputTokens": sum((u.get("input_tokens", 0) for u in usages)),
        "outputTokens": sum((u.get("output_tokens", 0) for u in usages)),
        "reasoningTokens": sum(
            (
                u.get("output_tokens_details", {}).get("reasoning_tokens", 0)
                for u in usages
            )
        ),
        "providerCachedInputTokens": sum(
            (u.get("input_tokens_details", {}).get("cached_tokens", 0) for u in usages)
        ),
        "totalTokens": r["observedTotalTokens"],
        "missingUsageCalls": sum(
            (not isinstance(c.get("usage"), dict) for c in r["calls"])
        ),
        "factorChecksAlreadyCoveredByPacket": len(factors),
        "duplicateFactRequests": sum(
            (t.get("duplicateWithinPhase", False) for t in factors)
        ),
        "duplicateExploreRequests": sum(
            (
                t.get("duplicateWithinPhase", False)
                for t in r["tools"]
                if t["name"] == "explore"
            )
        ),
        "duplicateEvaluateRequests": sum(
            (
                t.get("duplicateWithinPhase", False)
                for t in r["tools"]
                if t["name"] == "evaluate"
            )
        ),
        "uniqueFeasibleSchedules": len(orders),
        "uniqueValidPrefixes": len(prefixes),
        "maxProperPrefixDepth": max(map(len, proper), default=0),
        "branchedPrefixParents": sum((len(v) > 1 for v in parents.values())),
        "freshNativePacketSolves": int(not r["packet"]["reused"]),
        "retainedNativePacketLookups": int(r["packet"]["reused"]),
        "freshNativeFactorSolves": sum(
            (t.get("nativeReceipt", {}).get("freshNativeSolve", False) for t in factors)
        ),
        "retainedNativeFactorLookups": sum(
            (t.get("nativeReceipt", {}).get("reused", False) for t in factors)
        ),
        "nativePacketAndFactorSeconds": r["packet"]["nativeSeconds"]
        + sum((t.get("nativeSeconds", 0) for t in factors)),
        "totalToolSeconds": sum((t["seconds"] for t in r["tools"])),
        "proofBytesWritten": r["packet"]["proofBytes"]
        + sum((t.get("proofBytes", 0) for t in factors)),
        "objectiveGap": r["grade"]["gap"] if r["grade"]["valid"] else None,
        "relativeGap": r["grade"]["gap"] / r["grade"]["oracle"]["optimum"]
        if r["grade"]["valid"]
        else None,
        "optimal": r["grade"]["optimal"],
        "submitted": r["submitted"],
        "failure": r["failure"],
    }
