# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reporting for the candidate model study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import tarfile
from ._artifacts import digest, save, shutil_copy
from ._config import CANONICAL, ROOT, RUNTIME
from ._reuse_snapshot import reuse_verify


def reuse_report(run):
    plan = reuse_verify(run)
    rows = json.loads((run / "reuse-ledger.json").read_text())
    labels = json.loads((run / "reuse-annotation-ledger.json").read_text())
    qualification = json.loads((run / "qualification.json").read_text())
    points = []
    for row in rows:
        measurement = next(
            x for x in labels if x["case"] == row["case"] and x["arm"] == row["arm"]
        )
        for boundary in plan["checkpoints"]:
            calls = [
                c
                for c in row["calls"]
                if c.get("atGrossTokens") is not None and c["atGrossTokens"] <= boundary
            ]
            states = [c for c in calls if "incumbentValue" in c]
            last = states[-1] if states else None
            annot = [
                c
                for c in measurement["calls"]
                if any(s["turn"] == c["turn"] for s in calls)
            ]
            missing = sum(bool(c["failure"]) for c in annot) + len(calls) - len(annot)
            episodes = [e for c in annot for e in c["accepted"]]
            in_flight = any(
                c.get("atGrossTokens") is not None
                and c["atGrossTokens"] - c["grossTokens"]
                < boundary
                < c["atGrossTokens"]
                for c in row["calls"]
            )
            reached = row["grossTokens"] >= boundary and all(
                c["grossTokens"] is not None for c in row["calls"]
            )
            points.append(
                {
                    "case": row["case"],
                    "arm": row["arm"],
                    "checkpoint": boundary,
                    "reached": reached,
                    "value": last["incumbentValue"]
                    if last
                    else qualification["tasks"][row["case"]]["seed"]["value"],
                    "maxDepth": last["maxDepth"] if last else 0,
                    "admittedExpansions": sum(c["evaluation"]["valid"] for c in states),
                    "missingAnnotations": missing,
                    "rejectedLabels": sum(len(c["rejected"]) for c in annot),
                    "inFlightAtCheckpoint": in_flight,
                    "observedRepeatFacts": sum(e["repeatFact"] for e in episodes)
                    if not missing and not in_flight
                    else None,
                    "observedExactRepeatDerivations": sum(
                        e["definiteRepeat"] for e in episodes
                    )
                    if not missing and not in_flight
                    else None,
                    "observedDerivations": sum(
                        e["qualifiedPositiveDerivation"] for e in episodes
                    ),
                    "observedReuse": sum(e["kind"] == "reuse" for e in episodes),
                    "solverFailure": row.get("failure"),
                }
            )
    joint = [
        {
            "case": case,
            "checkpoint": boundary,
            "points": [
                p for p in points if p["case"] == case and p["checkpoint"] == boundary
            ],
        }
        for case in range(2)
        for boundary in plan["checkpoints"]
        if all(
            next(
                p
                for p in points
                if p["case"] == case and p["arm"] == arm and p["checkpoint"] == boundary
            )["reached"]
            for arm in plan["arms"]
        )
    ]
    known = sum(c["grossTokens"] or 0 for r in rows for c in r["calls"])
    unknown = sum(c["grossTokens"] is None for r in rows for c in r["calls"])
    measurement_cost = sum(c["grossTokens"] or 0 for r in labels for c in r["calls"])
    report = {
        "planSha256": digest(run / "plan.json"),
        "solverKnownTokens": known,
        "solverUnknownCostCalls": unknown,
        "annotationKnownTokens": measurement_cost,
        "budgetPerTrajectory": plan["budget"],
        "jointlyReachedCheckpoints": joint,
        "trajectories": rows,
        "annotationResults": labels,
        "limits": "Two unchanged fixed tasks, one stochastic trajectory per arm/task. Scheme combines proof fragments and finite-absence partition; this does not isolate their individual effects. All arms replay their own prior thinking and paired tool outputs, charging all repeated input. Repeat metrics are observed, exact-quote supported lower bounds; extraction completeness and inter-rater agreement are unvalidated. At checkpoints inside a model call, repeat counts are unknown because per-token usage timing is unavailable. Unknown or rejected labels remain explicit. No hidden model reasoning is inferred. Current captured native and full gxi qualification passes; prior dyld cleanup failures remain retained and no global runtime fix is claimed. Unused budget is censored, not savings.",
    }
    save(run / "reuse-report.json", report)
    lines = [
        "# Library Fact and proof-fragment reuse pilot",
        "",
        report["limits"],
        "",
        "| Task | Arm | Input + all output | Depth | Best value / optimum | Stop |",
        "|---|---|---:|---:|---:|---|",
    ]
    for row in rows:
        best = qualification["tasks"][row["case"]]["optimum"]["evaluation"]["value"]
        lines.append(
            f"| {row['case']} | {row['arm']} | {row['grossTokens']} | {row['maxDepth']} | {row['incumbent']['evaluation']['value']} / {best} | {row['stop']} {row.get('failure', '')} |"
        )
    lines += [
        "",
        f"Solver known cost: {known} tokens; unknown-cost calls: {unknown}. Independent annotation cost: {measurement_cost} tokens, recorded separately.",
        "",
        "## Jointly reached input + all-output checkpoints",
        "",
        "| Task / budget | Arm | Value | Depth | Observed repeated Facts / exact derivations | Missing / rejected labels |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for group in joint:
        for p in group["points"]:
            lines.append(
                f"| {p['case']} / {p['checkpoint']} | {p['arm']} | {p['value']} | {p['maxDepth']} | {p['observedRepeatFacts']} / {p['observedExactRepeatDerivations']} | {p['missingAnnotations']} / {p['rejectedLabels']} |"
            )
    lines += [
        "",
        "A checkpoint excludes a model action that completes after the boundary. Unreached checkpoints are excluded from matched comparisons. Full outcomes, invalid branches, provider failures, forced cleanup, raw thinking, anchored labels and rejected annotations are retained. The unchanged ordinary search question contains no anti-repetition instructions.",
    ]
    (run / "reuse-report.md").write_text("\n".join(lines) + "\n")
    snippets = []
    for phase in labels:
        for call in phase["calls"]:
            for e in call["accepted"]:
                snippets += [
                    f"- task {phase['case']}, arm {phase['arm']}, call {call['turn']}, span {e['span']}, atom {e['atom']}, kind {e['kind']}, repeated Fact {e['repeatFact']}, exact repeated derivation {e['definiteRepeat']}",
                    "",
                    "> " + e["quote"].replace("\n", "\n> "),
                    "",
                ]
    (run / "thinking-episodes.md").write_text("\n".join(snippets) + "\n")
    doc = (
        ROOT
        / ".cache/ascent/research-reports/agent-inference/fact-reuse-results"
        / run.name
    )
    doc.mkdir(parents=True, exist_ok=False)
    for src, dst in [
        ("reuse-report.json", "report.json"),
        ("reuse-report.md", "report.md"),
        ("plan.json", "plan.json"),
        ("qualification.json", "qualification.json"),
        ("reuse-ledger.json", "ledger.json"),
        ("reuse-annotation-ledger.json", "annotation-ledger.json"),
        ("thinking-episodes.md", "thinking-episodes.md"),
    ]:
        shutil_copy(run / src, doc / dst)
    with tarfile.open(doc / "raw.tar.gz", "w:gz") as tar:
        tar.add(run, arcname="run")
        tar.add(RUNTIME, arcname="runtime")
        tar.add(CANONICAL.parent, arcname="canonical-runtime")
        base = RUNTIME.parent
        for p in sorted(base.glob("shutdown-*")):
            tar.add(p, arcname="shutdown/" + p.name)
        for p in sorted(base.glob("reuse*.json")):
            tar.add(p, arcname="receipts/" + p.name)
        for p in sorted(base.glob("reuse*.log")):
            tar.add(p, arcname="logs/" + p.name)
    save(
        doc / "integrity.json",
        {
            "bindingVerified": True,
            "files": {
                p.name: digest(p)
                for p in doc.iterdir()
                if p.is_file() and p.name != "integrity.json"
            },
        },
    )
    report_text("REUSE_REPORT_COMPLETE", known, measurement_cost, flush=True)
