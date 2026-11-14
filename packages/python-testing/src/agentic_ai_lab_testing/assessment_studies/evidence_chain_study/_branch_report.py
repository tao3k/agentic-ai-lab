# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch report for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json, shutil
from .. import inference_reuse_study as s
from ._branch_contracts import branch_grade
from ._shared_check import shared_check


def branch_report(directory, output):
    import tarfile

    plan = shared_check(directory)
    rows = json.loads((output / "ledger.json").read_text())
    labels = json.loads((output / "annotation-ledger.json").read_text())
    summaries = []
    for row in rows:
        task = plan["tasks"][row["case"]]
        grades = {b["turn"]: b for b in row["branches"]}
        optima = plan["independentJudge"]["frozenOptima"][row["case"]]
        starts = [branch_grade(task, b, b["start"])["score"] for b in task["branches"]]
        achieved = [
            grades[i]["grade"]["score"]
            if i in grades and grades[i]["grade"]["feasible"]
            else starts[i]
            for i in range(len(starts))
        ]
        summary = {
            "case": row["case"],
            "arm": row["arm"],
            "grossTokens": row["grossTokens"],
            "stop": row["stop"],
            "failure": row["failure"],
            "submittedBranches": len(grades),
            "feasibleSubmittedBranches": sum(
                b["grade"]["feasible"] for b in row["branches"]
            ),
            "optimalSubmittedBranches": sum(
                b["grade"]["feasible"] and b["grade"]["score"] == optima[b["turn"]]
                for b in row["branches"]
            ),
            "truncatedThinkingCalls": sum(
                c.get("outputTruncated", False) for c in row["calls"]
            ),
            "finalizationCalls": sum(c["step"] > 0 for c in row["calls"]),
            "startScores": starts,
            "incumbentScores": achieved,
            "optimumScores": optima,
            "meanNormalizedImprovement": sum(
                (a - s) / (o - s) for a, s, o in zip(achieved, starts, optima)
            )
            / len(starts),
            "nativeStats": row["nativeStats"],
            "unusedBudget": row["unusedBudget"],
            "annotation": [],
        }
        for phase in [
            x for x in labels if (x["case"], x["arm"]) == (row["case"], row["arm"])
        ]:
            accepted = [e for c in phase["calls"] for e in c["accepted"]]
            summary["annotation"].append(
                {
                    "pass": phase["pass"],
                    "qualifiedDerivations": sum(
                        e["qualifiedPositive"] for e in accepted
                    ),
                    "crossBranchRepeats": sum(
                        e.get("crossBranchRepeat", False) for e in accepted
                    ),
                    "sameBranchRepeats": sum(
                        e.get("sameBranchRepeat", False) for e in accepted
                    ),
                    "withinResponseRepeats": sum(
                        e.get("withinResponseRepeat", False) for e in accepted
                    ),
                    "suppliedPremiseRederivations": sum(
                        e.get("suppliedPremiseRederived", False) for e in accepted
                    ),
                    "consumedPremises": sum(
                        e["category"] == "premise_consumed" for e in accepted
                    ),
                    "newConsequencesAfterFirst": sum(
                        e["qualifiedPositive"]
                        and e["newConsequence"]
                        and e["afterFirstQuestion"]
                        for e in accepted
                    ),
                    "coveredCharacters": sum(
                        c.get("coveredCharacters", 0) for c in phase["calls"]
                    ),
                    "visibleCharacters": sum(
                        c.get("characters", 0) for c in phase["calls"]
                    ),
                    "unresolvedSemanticLines": sum(
                        c.get("unresolvedSemanticLines", 0) for c in phase["calls"]
                    ),
                    "rejectedLabels": sum(len(c["rejected"]) for c in phase["calls"]),
                    "failedCalls": sum(
                        c["failure"] is not None for c in phase["calls"]
                    ),
                }
            )
        summaries.append(summary)
    checkpoints = []
    for case in range(2):
        for cap in plan["checkpoints"]:
            data = []
            for row in [r for r in rows if r["case"] == case]:
                task = plan["tasks"][case]
                included = {
                    b["turn"]: b for b in row["branches"] if b["atGrossTokens"] <= cap
                }
                scores = [
                    included[b["id"]]["grade"]["score"]
                    if b["id"] in included and included[b["id"]]["grade"]["feasible"]
                    else branch_grade(task, b, b["start"])["score"]
                    for b in task["branches"]
                ]
                data.append(
                    {
                        "arm": row["arm"],
                        "submittedBranches": len(included),
                        "incumbentScores": scores,
                    }
                )
            checkpoints.append({"case": case, "cap": cap, "arms": data})
    report = {
        "planSha256": hashlib.sha256(
            (directory / "plan.json").read_bytes()
        ).hexdigest(),
        "summaries": summaries,
        "checkpoints": checkpoints,
        "solverKnownTokens": sum(
            c["grossTokens"] or 0 for r in rows for c in r["calls"]
        ),
        "solverUnknownUsageCalls": sum(
            c["grossTokens"] is None for r in rows for c in r["calls"]
        ),
        "annotationKnownTokens": sum(
            c["grossTokens"] or 0 for x in labels for c in x["calls"]
        ),
        "annotationUnknownUsageCalls": sum(
            c["modelCalled"] and c["grossTokens"] is None
            for x in labels
            for c in x["calls"]
        ),
        "claims": "Two finite fixtures and one stochastic trajectory per cell. Native reuse, model tool consumption, literal derivation counts and optimization quality are separate. Literal chain counts have limited grammar recall; complete character partition does not certify semantic completeness. Unresolved lines are retained. Thinking truncated at a checkpoint remains censored even if finalization returns an answer. Unused budget is not savings. Budget/call stops are censored and all failures remain.",
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = [
        "# Sibling-search Library diagnostic",
        "",
        report["claims"],
        "",
        "| Source | Arm | Input + all output | Submitted / feasible / optimal branches | Mean normalized incumbent improvement | Stop |",
        "|---|---|---:|---|---:|---|",
    ]
    for r in summaries:
        lines.append(
            f"| {r['case']} | {r['arm']} | {r['grossTokens']} | {r['submittedBranches']} / {r['feasibleSubmittedBranches']} / {r['optimalSubmittedBranches']} | {r['meanNormalizedImprovement']:.3f} | {r['stop']} {r['failure'] or ''} |"
        )
    lines += [
        "",
        "| Source / arm / annotation pass | Cross-branch repetitions | Supplied premise rederived | Rejected labels | Failed annotation calls |",
        "|---|---:|---:|---:|---:|",
    ]
    for r in summaries:
        for a in r["annotation"]:
            lines.append(
                f"| {r['case']} / {r['arm']} / {a['pass']} | {a['crossBranchRepeats']} | {a['suppliedPremiseRederivations']} | {a['rejectedLabels']} | {a['failedCalls']} |"
            )
    lines += [
        "",
        f"Solver known tokens: {report['solverKnownTokens']}; annotation known tokens: {report['annotationKnownTokens']}. Unknown usage solver/annotation calls: {report['solverUnknownUsageCalls']} / {report['annotationUnknownUsageCalls']}.",
        "",
        "All arms fork sibling histories from the same root and receive identical initial feasible incumbents and branch constraints. At each branch entry, Fact receives native conclusions and Scheme receives the same conclusions plus named supports from the same public Python binding. Baseline has neither. Only the common submission tool is exposed; no anti-repetition instruction is supplied. Incomplete thinking is a retained censored failure and is never salvaged by non-thinking finalization. A completed plain response may use structured finalization only within the same total budget. The independent exhaustive grader is never given to the solver. A stale handle never becomes a verified tool conclusion.",
        "",
        "The producer is a locally committed clean checkout. Native build, formal checks and source identities are explicit in plan/receipts; this does not qualify another machine or remote CI. raw.tar.gz retains every request, thinking, response, tool packet, failure and annotation.",
    ]
    (output / "report.md").write_text("\n".join(lines) + "\n")
    doc = (
        s.ROOT
        / ".cache/ascent/research-reports/agent-inference/fact-reuse-results"
        / plan.get("artifactDirectory", "sibling-search")
    )
    doc.mkdir(parents=True, exist_ok=False)
    for name in ["report.json", "report.md", "ledger.json", "annotation-ledger.json"]:
        shutil.copy2(output / name, doc / name)
    for name in [
        "plan.json",
        "plan.sha256",
        "qualification.json",
        "pyo3-runtime-receipt.json",
        "native-build-receipt.json",
    ]:
        shutil.copy2(directory / name, doc / name)
    with tarfile.open(doc / "raw.tar.gz", "w:gz") as archive:
        archive.add(directory, arcname="frozen")
        archive.add(output, arcname="run")
    (doc / "integrity.json").write_text(
        json.dumps(
            {
                p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                for p in doc.iterdir()
                if p.is_file()
            },
            indent=2,
        )
        + "\n"
    )
    report_text("BRANCH_REPORT_OK", doc, flush=True)
