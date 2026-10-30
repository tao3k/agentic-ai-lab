# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Auditable repository study statistics; censored work is never a savings win."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price
from .repository_metrics import trajectory_metrics, integrated_metrics, metric_report


from ._repository_report_rendering import (
    _render_research_expense,
    _render_outcome_comparisons,
    report,
)


def repair_effort(attempts):
    start = None
    kind = None
    for index, attempt in enumerate(attempts):
        for action in attempt["actions"]:
            result = action.get("result")
            if not isinstance(result, dict):
                continue
            rejected = (
                action["name"] in ("submit_patch", "implicit_submit")
                and result.get("verified") is False
            )
            failed_controls = (
                action["name"] == "run_checks"
                and result.get("allChecksPassed") is False
            )
            if rejected or failed_controls:
                start = index
                kind = action["name"]
                break
        if start is not None:
            break
    if start is None:
        return {
            "failedCandidateDetected": False,
            "observedReasoningTokens": 0,
            "modelCalls": 0,
            "peakDollarEstimate": 0,
        }
    effort = until_verified(attempts[start:])
    selected = attempts[start : start + effort["attempts"]]
    dollars = (
        sum(price(a["usage"]) for a in selected)
        if effort["modelUsageComplete"]
        else None
    )
    return {
        "failedCandidateDetected": True,
        "firstFailureFeedbackTurn": attempts[start].get("turn", start + 1),
        "failureFeedbackKind": kind,
        "peakDollarEstimate": dollars,
        **effort,
    }


def billing(directory):
    totals = Counter()
    artifacts = {}
    unknown = []
    requests = sorted(directory.glob("*/*.request.json"))
    for request in requests:
        response = request.with_name(
            request.name.replace(".request.json", ".response.json")
        )
        if not response.exists():
            unknown.append(str(request.relative_to(directory)))
            continue
        data = json.loads(response.read_text())
        terminal = data.get("terminal") or {}
        usage = terminal.get("usage")
        artifacts[str(response.relative_to(directory))] = hashlib.sha256(
            response.read_bytes()
        ).hexdigest()
        if not usage:
            unknown.append(str(request.relative_to(directory)))
            continue
        totals["observedCalls"] += 1
        totals["inputTokens"] += usage["input_tokens"]
        totals["outputIncludingReasoningTokens"] += usage["output_tokens"]
        thinking = usage.get("output_tokens_details", {}).get("reasoning_tokens")
        if thinking is None:
            totals["thinkingUsageMissing"] += 1
        else:
            totals["observedReasoningTokens"] += thinking
        totals["peakDollarEstimate"] += price(usage)
    return {
        "startedRequests": len(requests),
        **dict(totals),
        "unknownUsageRequests": unknown,
        "responseHashes": artifacts,
        "offPeakDollarEstimate": totals["peakDollarEstimate"] / 2,
        "invoiceVerified": False,
    }


def records(directory):
    if not directory.exists():
        return []
    return [
        {
            **json.loads(path.read_text()),
            "episodeReceipt": str(path),
            "episodeSha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        for path in sorted(directory.glob("*/episode.json"))
    ]


def _build_summarize_result(
    continuation, entries, invalid, original, pairs, primary, recovery
):
    """Assemble the retained summarize result structure."""
    return {
        "schema": "ascent.repository-statistics.v2",
        "primaryEpisodes": [
            {
                "task": r["task"],
                "repetition": r["repetition"],
                "arm": r["arm"],
                "status": r["status"],
                "effort": until_verified(r["attempts"]),
            }
            for r in original
        ],
        "episodes": entries,
        "pairs": pairs,
        "integratedMetrics": integrated_metrics(entries, pairs),
        "billing": {
            "invalidExecution": billing(invalid),
            "primary": billing(primary),
            "continuation": billing(continuation),
            **(
                {"responsePreservingRecovery": billing(recovery / "continued")}
                if recovery is not None
                else {}
            ),
        },
        "complete": (
            (recovery if recovery is not None else continuation) / "result.json"
        ).exists()
        and json.loads(
            (
                (recovery if recovery is not None else continuation) / "result.json"
            ).read_text()
        ).get("complete", False),
    }


def summarize(primary, continuation, invalid, recovery=None):
    original = records(primary)
    extensions = records(continuation)
    combined = {(r["task"], r["repetition"], r["arm"]): r for r in original}
    combined.update({(r["task"], r["repetition"], r["arm"]): r for r in extensions})
    if recovery is not None:
        combined.update(
            {
                (r["task"], r["repetition"], r["arm"]): r
                for r in records(recovery / "continued")
            }
        )
    entries = []
    for key, record in sorted(combined.items()):
        journal = record.get("evidenceJournal", [])
        entries.append(
            {
                "task": key[0],
                "repetition": key[1],
                "arm": key[2],
                "status": record["status"],
                "episodeReceipt": record["episodeReceipt"],
                "episodeSha256": record["episodeSha256"],
                "effort": until_verified(record["attempts"]),
                "repairEffort": repair_effort(record["attempts"]),
                "checkedEvidenceQueries": len(journal),
                "reusedComponents": sum(len(x["reusedComponents"]) for x in journal),
                "freshComponents": sum(len(x["freshComponents"]) for x in journal),
                "checkedEvidenceSeconds": sum(x["seconds"] for x in journal),
                "sourceGenerations": sorted({x["generation"] for x in journal}),
                "reconstructionQueries": len(record.get("reconstructionJournal", [])),
                "trajectory": trajectory_metrics(record["attempts"]),
            }
        )
    pairs = []
    for row in entries:
        if row["arm"] == "ordinary-tools":
            continue
        baseline = next(
            x
            for x in entries
            if (x["task"], x["repetition"], x["arm"])
            == (row["task"], row["repetition"], "ordinary-tools")
        )
        reduction = paired_reduction(
            baseline["effort"], row["effort"], "observedReasoningTokens"
        )
        pairs.append(
            {
                "task": row["task"],
                "repetition": row["repetition"],
                "arm": row["arm"],
                "thinkingReduction": reduction,
                "baselineThinking": baseline["effort"]["observedReasoningTokens"],
                "candidateThinking": row["effort"]["observedReasoningTokens"],
                "baselineVerified": baseline["effort"]["verified"],
                "candidateVerified": row["effort"]["verified"],
                "baselineCalls": baseline["effort"]["modelCalls"],
                "candidateCalls": row["effort"]["modelCalls"],
            }
        )
    return _build_summarize_result(
        continuation, entries, invalid, original, pairs, primary, recovery
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("plan", "primary", "continuation", "invalid", "destination"):
        parser.add_argument(name, type=Path)
    parser.add_argument("--recovery", type=Path)
    args = parser.parse_args()
    data = summarize(args.primary, args.continuation, args.invalid, args.recovery)
    data["statisticsProducerHashes"] = _source_hashes(
        {
            name: Path(__file__).with_name(name)
            for name in (
                "repository_statistics.py",
                "repository_metrics.py",
                "inference_effort.py",
                "inference_reuse_study.py",
            )
        }
    )
    data["frozenPlanSha256"] = hashlib.sha256(
        (args.plan / "plan.json").read_bytes()
    ).hexdigest()
    data["primaryResultSha256"] = hashlib.sha256(
        (args.primary / "result.json").read_bytes()
    ).hexdigest()
    data["originalProducerHashes"] = json.loads((args.plan / "plan.json").read_text())[
        "producerHashes"
    ]
    if args.recovery is not None:
        data["recoveryPlanSha256"] = hashlib.sha256(
            (args.recovery / "plan.json").read_bytes()
        ).hexdigest()
        data["recoveryProducerHashes"] = json.loads(
            (args.recovery / "plan.json").read_text()
        )["recoveryProducerHashes"]
        data["recoveryResultSha256"] = (
            hashlib.sha256((args.recovery / "result.json").read_bytes()).hexdigest()
            if (args.recovery / "result.json").exists()
            else None
        )
    args.destination.with_suffix(".json").write_text(json.dumps(data, indent=2) + "\n")
    args.destination.write_text(
        report(data, json.loads((args.plan / "plan.json").read_text()))
    )
    report_text(
        "REPOSITORY-STATISTICS",
        "complete=" + str(data["complete"]),
        "trajectories=" + str(len(data["episodes"])),
    )
