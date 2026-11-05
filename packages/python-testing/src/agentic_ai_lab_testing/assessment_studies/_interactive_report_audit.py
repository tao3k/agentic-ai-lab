# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Audit every frozen interaction and independently check exposed local support."

import json, hashlib
from agentic_ai_lab_testing.assessment_studies.interactive_study import (
    obligation_acceptance,
    balanced_oracle,
    tagged_oracle,
)


def thinking(c):
    return (
        (c.get("usage") or {}).get("output_tokens_details", {}).get("reasoning_tokens")
    )


def _collect_run(p, root, results, allrecords, protocols, audit, incorrect):
    """Own the collect run phase and retain its evidence checks."""
    plan = json.loads((p / "plan.json").read_text())
    record = json.loads((p / "records.json").read_text())
    calls = record["calls"]
    vs = record["verdicts"]
    checks = record["checks"]
    accepted, first = obligation_acceptance(vs)
    complete = bool(calls) and all(isinstance(thinking(c), int) for c in calls)
    repaired = set()
    failed = False
    for c in calls:
        if failed:
            repaired.add(c["id"])
        v = next((v for v in vs if v["providerCall"] == c["id"]), None)
        if v:
            failed = not v["correct"]
    total = sum(thinking(c) or 0 for c in calls)
    row = {
        "run": p.name,
        "case": plan["case"]["case"],
        "arm": plan["arm"],
        "stagesCorrect": sum(accepted),
        "wholeTaskCorrect": all(accepted),
        "usageComplete": complete,
        "calls": len(calls),
        "thinkingObserved": total,
        "firstWholeCorrectThinking": total if all(accepted) and complete else None,
        "repairCalls": len(repaired),
        "repairThinking": sum(thinking(c) or 0 for c in calls if c["id"] in repaired),
        "failedFinalAnswers": sum(not v["correct"] for v in vs),
        "toolCalls": len(checks),
        "branches": sum(len(x["feedback"].get("branches", [])) for x in checks),
        "reusedBranches": sum(
            bool(b.get("reusedComponents"))
            for x in checks
            for b in x["feedback"].get("branches", [])
        ),
        "providerErrors": sum(
            bool(c.get("error")) or c.get("status") != "completed" for c in calls
        ),
        "completedRun": (p / "result.json").exists(),
        "runState": "complete" if (p / "result.json").exists() else "host-aborted",
        "sourceHashes": plan["sourceHashes"],
        "endpointCorrected": (p / "result.json").exists()
        and json.loads((p / "result.json").read_text()).get("wholeTaskCorrect")
        != all(accepted),
    }
    results.append(row)
    allrecords[p.name] = record
    protocols[p.name] = plan
    for f in p.glob("*-provider.json"):
        meta = json.loads(f.read_text())
        terminal = meta.get("terminal") or {}
        key = terminal.get("id") or hashlib.sha256(f.read_bytes()).hexdigest()
        audit.setdefault(
            key,
            {
                "responseId": terminal.get("id"),
                "status": terminal.get("status"),
                "usage": terminal.get("usage"),
                "seconds": meta.get("providerSeconds"),
                "error": meta.get("error"),
                "paths": [],
            },
        )["paths"].append(str(f.relative_to(root)))
    # Independent check of every exposed native local verdict.
    c, positions = _audit_checked_branches(plan, calls, checks, row, p, incorrect)
    # Missing final candidates with fully exposed support before the wrong answer.
    _audit_supported_omissions(vs, checks, positions, c, row)


def _audit_checked_branches(plan, calls, checks, row, p, incorrect):
    """Own the audit checked branches phase and retain its evidence checks."""
    c = plan["case"]
    positions = {x["id"]: i for i, x in enumerate(calls)}
    checked = 0
    bad = 0
    for x in checks:
        sources = c["changed"] if x["stage"] == 2 else c["sources"]
        s = {r["name"]: r["rows"] for r in sources}
        sets = {n: set(map(tuple, r)) for n, r in s.items()}
        if c["family"] == "context-balanced-paths":
            pairs = balanced_oracle(sources)
            sets.update(
                balanced=pairs,
                bridged={
                    (a, b, y) for a, b, z in pairs for z2, y in s["bridge"] if z == z2
                },
            )
        else:
            flow, permit = tagged_oracle(sources)
            sets.update(flow=flow, permit=permit)
        for b in x["feedback"].get("branches", []):
            conditions = b.get(
                "conditions",
                [
                    {
                        "operation": b.get("operation"),
                        "arguments": b.get("arguments", []),
                    }
                ],
            )
            if b["status"] == "unknown" or any(
                q.get("operation") not in sets for q in conditions
            ):
                continue
            checked += 1
            valid = all(
                tuple(q["arguments"]) in sets[q["operation"]] for q in conditions
            )
            if (b["status"] == "supported") != valid:
                bad += 1
                incorrect.append({"run": p.name, "branch": b})
    row["independentLocalChecks"] = checked
    row["incorrectLocalChecks"] = bad
    row["multiPremiseBranches"] = sum(
        len(b.get("conditions", [])) > 1
        for x in checks
        for b in json.loads(x["arguments"]).get("branches", [])
    )
    row["hostRevalidationToolCalls"] = sum(bool(x.get("revalidation")) for x in checks)
    return c, positions


def _audit_supported_omissions(vs, checks, positions, c, row):
    """Own the audit supported omissions phase and retain its evidence checks."""
    row["supportedOmissions"] = []
    for v in vs:
        if v["correct"] or v["prediction"] is None:
            continue
        observed = {}
        for x in checks:
            if x["stage"] != v["stage"] or positions.get(
                x["providerCall"], 9999
            ) > positions.get(v["providerCall"], 0):
                continue
            for b in x["feedback"].get("branches", []):
                if b.get("operation"):
                    observed[(b["operation"], tuple(b.get("arguments", [])))] = b[
                        "status"
                    ]
        sources = c["changed"] if v["stage"] == 2 else c["sources"]
        needs = next(s for s in sources if s["name"] == "needs")["rows"]
        for n in needs:
            if n[0] not in set(v["expected"]) - set(v["prediction"]):
                continue
            required = (
                [
                    ("bridged" if v["stage"] == 2 else "balanced", tuple(n[1:4])),
                    ("balanced", tuple(n[4:7])),
                ]
                if c["family"] == "context-balanced-paths"
                else [("flow", tuple(n[i : i + 2])) for i in range(1, 9, 2)]
            )
            if all(observed.get(q) == "supported" for q in required):
                row["supportedOmissions"].append(
                    {"call": v["providerCall"], "job": n[0]}
                )
