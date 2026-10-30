# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Audit every complete and interrupted run against original branch conditions and source versions."

import json
from .interactive_study import balanced_oracle, tagged_oracle, obligation_acceptance
from ._path_consumption_projection import sha, count_thinking, decode_historical


def _audit_path_runs(
    root, cache, records, plans, results, audit, partial, disagreements, stage_costs
):
    """Own the audit path runs phase without weakening its checks."""
    for folder in sorted(
        p for p in cache.iterdir() if p.is_dir() and (p / "records.json").exists()
    ):
        data = json.loads((folder / "records.json").read_text())
        plan = json.loads((folder / "plan.json").read_text())
        records[folder.name] = data
        plans[folder.name] = plan
        accepted, first = obligation_acceptance(data["verdicts"])
        calls = data["calls"]
        checks = data["checks"]
        totals = sum(count_thinking(c) or 0 for c in calls)
        known = all(isinstance(count_thinking(c), int) for c in calls)
        repairing = set()
        failed = False
        for c in calls:
            if failed:
                repairing.add(c["id"])
            v = next(
                (v for v in data["verdicts"] if v["providerCall"] == c["id"]), None
            )
            if v:
                failed = not v["correct"]
        size_raw = sum(
            len(json.dumps(x["feedback"], separators=(",", ":"))) for x in checks
        )
        size_exposed = sum(
            len(
                json.dumps(
                    x.get("exposedFeedback", x["feedback"]), separators=(",", ":")
                )
            )
            for x in checks
        )
        row = {
            "run": folder.name,
            "case": plan["case"]["case"],
            "arm": plan["arm"],
            "finished": (folder / "result.json").exists(),
            "wholeTaskCorrect": all(accepted),
            "acceptedObligations": sum(accepted),
            "calls": len(calls),
            "thinkingObserved": totals,
            "thinkingComplete": known,
            "firstWholeCorrectThinking": totals if all(accepted) and known else None,
            "repairCalls": len(repairing),
            "repairThinking": sum(
                count_thinking(c) or 0 for c in calls if c["id"] in repairing
            ),
            "failedFinalAnswers": sum(not v["correct"] for v in data["verdicts"]),
            "inputTokens": sum(
                (c.get("usage") or {}).get("input_tokens", 0) for c in calls
            ),
            "cachedInputTokens": sum(
                (c.get("usage") or {})
                .get("input_tokens_details", {})
                .get("cached_tokens", 0)
                for c in calls
            ),
            "outputTokens": sum(
                (c.get("usage") or {}).get("output_tokens", 0) for c in calls
            ),
            "providerSeconds": sum(c["seconds"] for c in calls),
            "nativeToolSeconds": sum(x["feedback"].get("seconds", 0) for x in checks),
            "toolCalls": len(checks),
            "hostRevalidationCalls": sum(bool(x.get("revalidation")) for x in checks),
            "reuseToolCalls": sum(x.get("toolName") == "reuse_paths" for x in checks),
            "extendToolCalls": sum(x.get("toolName") == "extend_paths" for x in checks),
            "branchChecks": sum(len(x["feedback"].get("branches", [])) for x in checks),
            "multiPremiseChecks": sum(
                len(b.get("conditions", [])) > 1
                for x in checks
                for b in x["feedback"].get("branches", [])
            ),
            "reusedBranches": sum(
                bool(b.get("reusedComponents"))
                for x in checks
                for b in x["feedback"].get("branches", [])
            ),
            "unknownBranches": sum(
                b["status"] == "unknown"
                for x in checks
                for b in x["feedback"].get("branches", [])
            ),
            "rawFeedbackBytes": size_raw,
            "exposedFeedbackBytes": size_exposed,
            "providerErrors": sum(
                bool(c["error"]) or c["status"] != "completed" for c in calls
            ),
            "runtimeInteractionSha256": plan["runtimeInteractionSha256"],
            "librarySha256": plan["librarySha256"],
        }
        checked = 0
        wrong = 0
        case = plan["case"]
        for x in checks:
            if (
                "exposedFeedback" in x
                and decode_historical(x["exposedFeedback"]) != x["feedback"]
            ):
                raise ValueError("feedback was not lossless: " + folder.name)
            sources = case["changed"] if x["stage"] == 2 else case["sources"]
            s = {r["name"]: r["rows"] for r in sources}
            if case["family"] == "context-balanced-paths":
                pairs = balanced_oracle(sources)
                truth = {
                    "balanced": pairs,
                    "bridged": {
                        (c, a, y)
                        for c, a, z in pairs
                        for z2, y in s["bridge"]
                        if z == z2
                    },
                }
            else:
                flow, permit = tagged_oracle(sources)
                truth = {"flow": flow, "permit": permit}
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
                    c.get("operation") not in truth for c in conditions
                ):
                    continue
                checked += 1
                expected = all(
                    tuple(c["arguments"]) in truth[c["operation"]] for c in conditions
                )
                if (b["status"] == "supported") != expected:
                    wrong += 1
                    disagreements.append(
                        {"run": folder.name, "call": x["providerCall"], "branch": b}
                    )
        row.update(independentLocalChecks=checked, incorrectLocalChecks=wrong)
        results.append(row)
        for stage in range(3):
            current = [c for c in calls if c["stage"] == stage]
            stage_costs.append(
                {
                    "run": folder.name,
                    "stage": stage,
                    "thinking": sum(count_thinking(c) or 0 for c in current),
                    "calls": len(current),
                    "firstCorrectCall": first[stage],
                    "failedFinalAnswers": sum(
                        not v["correct"] and v["stage"] == stage
                        for v in data["verdicts"]
                    ),
                }
            )
        for p in folder.glob("*-provider.json"):
            metadata = json.loads(p.read_text())
            terminal = metadata.get("terminal") or {}
            key = terminal.get("id") or sha(p)
            audit.setdefault(
                key,
                {
                    "responseId": terminal.get("id"),
                    "status": terminal.get("status"),
                    "usage": terminal.get("usage"),
                    "error": metadata.get("error"),
                    "seconds": metadata["providerSeconds"],
                    "files": [],
                },
            )["files"].append(str(p.relative_to(root)))
        for p in folder.glob("*-request.json"):
            stem = p.name.removesuffix("-request.json")
            if (
                not (folder / (stem + "-provider.json")).exists()
                and (folder / (stem + "-provider.events.jsonl")).exists()
            ):
                partial.append(str(p.relative_to(root)))
