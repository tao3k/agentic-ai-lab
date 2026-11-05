# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Complete domain intervention accounting without reading private reasoning."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path

from ascent import Engine
from .inference_effort import until_verified, paired_reduction
from .inference_reuse_study import price
from .repository_statistics import records, billing, repair_effort
from .repository_metrics import trajectory_metrics, integrated_metrics, metric_report


from ._domain_report_rendering import report


def candidate_repair(attempts):
    """Whole-turn work after a uniformly assessed failing candidate.

    An initial defect observation before any edit is diagnosis. An independently
    rejected submission always counts as a rejected candidate. Offline checks
    are labelled assessments, not feedback invented in the model history.
    """
    edited = False

    def repair_at(index, kind):
        effort = until_verified(attempts[index:])
        selected = attempts[index : index + effort["attempts"]]
        return {
            "firstFailureTurn": attempts[index]["turn"],
            "failureKind": kind,
            **effort,
            "peakDollarEstimate": sum(price(a["usage"]) for a in selected)
            if effort["modelUsageComplete"]
            else None,
        }

    for index, attempt in enumerate(attempts):
        for action in attempt["actions"]:
            result = action.get("result")
            if not isinstance(result, dict):
                continue
            if action["name"] == "edit_source" and result.get("edited"):
                edited = True
            rejected = (
                action["name"] in ("submit_patch", "implicit_submit")
                and result.get("verified") is False
            )
            bad_control = (
                action["name"] == "run_checks"
                and result.get("allChecksPassed") is False
            )
            bad_domain = any(
                not flag
                for c in result.get("auditDomainChecks", [])
                for _, flag in c["claims"]
            )
            if rejected or (edited and (bad_control or bad_domain)):
                return repair_at(
                    index,
                    "independent-submission"
                    if rejected
                    else "domain-assessment"
                    if bad_domain
                    else "development-check",
                )
        if any(g.get("verified") is False for g in attempt.get("candidateChecks", [])):
            return repair_at(index, "independent-candidate-check")
    return {
        "firstFailureTurn": None,
        "observedReasoningTokens": 0,
        "modelCalls": 0,
        "peakDollarEstimate": 0,
    }


def _build_summarize_result(
    audit, complete, entries, output, pairs, plan, plan_dir, runtime_path
):
    """Assemble the retained summarize result structure."""
    return {
        "schema": "ascent.domain-repository-report.v1",
        "complete": complete,
        "planSha256": hashlib.sha256((plan_dir / "plan.json").read_bytes()).hexdigest(),
        "engineLibrarySha256": plan["librarySha256"],
        "frozenProducerHashes": plan["producerHashes"],
        "questions": [
            {
                k: c[k]
                for k in (
                    "name",
                    "question",
                    "editable",
                    "domainKind",
                    "qualification",
                    "provenance",
                    "snapshotIdentity",
                    "graderSha256",
                )
            }
            for c in plan["tasks"]
        ],
        "observedRuntime": json.loads(runtime_path.read_text())
        if runtime_path.exists()
        else None,
        "candidateDiscoveryAudit": audit,
        "episodes": entries,
        "pairs": pairs,
        "integratedMetrics": integrated_metrics(entries, pairs),
        "billing": billing(output),
        "analysisProducerHashes": _source_hashes(
            {
                name: Path(__file__).with_name(name)
                for name in (
                    "domain_repository_report.py",
                    "repository_statistics.py",
                    "repository_metrics.py",
                    "inference_effort.py",
                    "inference_reuse_study.py",
                )
            }
        ),
    }, plan


def _audit_episode_entries(raw, plan, engine):
    """Own the audit episode entries phase without weakening its checks."""
    entries = []
    for r in raw:
        case = next(c for c in plan["tasks"] if c["name"] == r["task"])
        assessed = copy.deepcopy(r["attempts"])
        domain_observations = 0
        for attempt in assessed:
            for action in attempt["actions"]:
                result = action.get("result")
                if isinstance(result, dict) and result.get("domainObservations"):
                    checked = engine.request(
                        {
                            "operation": "domain-check",
                            "kind": case["domainKind"],
                            "observations": result["domainObservations"],
                        }
                    )
                    result["auditDomainChecks"] = checked["checks"]
                    domain_observations += 1
        journal = r.get("evidenceJournal", [])
        domain = r.get("domainJournal", [])
        rejections = Counter(
            a["result"]["error"][:180]
            for attempt in r["attempts"]
            for a in attempt["actions"]
            if isinstance(a.get("result"), dict) and a["result"].get("error")
        )
        entries.append(
            {
                "task": r["task"],
                "repetition": r["repetition"],
                "arm": r["arm"],
                "status": r["status"],
                "episodeReceipt": r["episodeReceipt"],
                "episodeSha256": r["episodeSha256"],
                "effort": until_verified(r["attempts"]),
                "repairEffort": repair_effort(r["attempts"]),
                "candidateRepairEffort": candidate_repair(assessed),
                "domainObservationCalls": domain_observations,
                "toolRejectionReasons": dict(rejections),
                "checkedEvidenceQueries": len(journal) + len(domain),
                "reusedComponents": sum(
                    len(j["reusedComponents"]) for j in journal + domain
                ),
                "freshComponents": sum(
                    len(j["freshComponents"]) for j in journal + domain
                ),
                "checkedEvidenceSeconds": sum(j["seconds"] for j in journal + domain),
                "reconstructionQueries": 0,
                "trajectory": trajectory_metrics(
                    assessed, primary_turns=plan["maxTurns"]
                ),
            }
        )
    return entries


def summarize(plan_dir, output, engine=None):
    plan = json.loads((plan_dir / "plan.json").read_text())
    raw = records(output)
    if (
        hashlib.sha256((plan_dir / "libascent.dylib").read_bytes()).hexdigest()
        != plan["librarySha256"]
    ):
        raise ValueError("checker library differs from frozen qualification")
    engine = engine or Engine(plan_dir / "libascent.dylib")
    entries = _audit_episode_entries(raw, plan, engine)
    entries.sort(key=lambda r: (r["task"], r["repetition"], r["arm"]))
    pairs = []
    for row in entries:
        if row["arm"] == "ordinary-tools":
            continue
        baseline = next(
            (
                r
                for r in entries
                if (r["task"], r["repetition"], r["arm"])
                == (row["task"], row["repetition"], "ordinary-tools")
            ),
            None,
        )
        if baseline is None:
            continue
        pairs.append(
            {
                "task": row["task"],
                "repetition": row["repetition"],
                "arm": row["arm"],
                "thinkingReduction": paired_reduction(
                    baseline["effort"], row["effort"], "observedReasoningTokens"
                ),
                "baselineThinking": baseline["effort"]["observedReasoningTokens"],
                "candidateThinking": row["effort"]["observedReasoningTokens"],
                "baselineVerified": baseline["effort"]["verified"],
                "candidateVerified": row["effort"]["verified"],
                "baselineCalls": baseline["effort"]["modelCalls"],
                "candidateCalls": row["effort"]["modelCalls"],
            }
        )
    terminal = output / "result.json"
    complete = terminal.exists() and json.loads(terminal.read_text()).get(
        "complete", False
    )
    runtime_path = plan_dir.parent / "runtime-versions.json"
    audit_path = output / "candidate-audit.json"
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else None
    if audit:
        for r in audit["trajectories"]:
            original = next(
                x
                for x in entries
                if (x["task"], x["arm"], x["repetition"])
                == (r["task"], r["arm"], r["repetition"])
            )
            if original["episodeSha256"] != r["episodeSha256"]:
                raise ValueError("candidate audit episode identity differs")
    return _build_summarize_result(
        audit, complete, entries, output, pairs, plan, plan_dir, runtime_path
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("plan", "output", "destination"):
        parser.add_argument(name, type=Path)
    parser.add_argument("--guard-plan", type=Path)
    parser.add_argument("--guard-output", type=Path)
    args = parser.parse_args()
    engine = Engine(args.plan / "libascent.dylib")
    data, plan = summarize(args.plan, args.output, engine)
    if args.guard_plan or args.guard_output:
        if not (args.guard_plan and args.guard_output):
            parser.error("both guard paths required")
        if (
            hashlib.sha256(
                (args.guard_plan / "libascent.dylib").read_bytes()
            ).hexdigest()
            != plan["librarySha256"]
        ):
            parser.error(
                "different checker libraries require separate analysis processes"
            )
        followup, _ = summarize(args.guard_plan, args.guard_output, engine)
        data["candidateGuardValidation"] = followup
    args.destination.write_text(report(data, plan) + "\n")
    args.destination.with_suffix(".json").write_text(json.dumps(data, indent=2) + "\n")
    report_text(
        "DOMAIN-REPORT",
        data["complete"],
        len(data["episodes"]),
        data["billing"].get("observedCalls", 0),
        flush=True,
    )
