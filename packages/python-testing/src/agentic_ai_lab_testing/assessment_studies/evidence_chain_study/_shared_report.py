# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared report for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json, shutil
from .. import inference_reuse_study as s
from ._shared_check import shared_check


def shared_report(directory, output):
    import tarfile

    plan = shared_check(directory)
    rows = json.loads((output / "ledger.json").read_text())
    labels = json.loads((output / "annotation-ledger.json").read_text())
    points = []
    summaries = []
    for row in rows:
        for pass_id in range(plan["annotationPasses"]):
            phase = next(
                x
                for x in labels
                if (x["case"], x["arm"], x["pass"])
                == (row["case"], row["arm"], pass_id)
            )
            accepted = [e for c in phase["calls"] for e in c["accepted"]]
            summaries.append(
                {
                    "case": row["case"],
                    "arm": row["arm"],
                    "pass": pass_id,
                    "qualifiedPositive": sum(e["qualifiedPositive"] for e in accepted),
                    "sharedPremiseDerivations": sum(
                        e["qualifiedPositive"]
                        and e["atom"] == plan["tasks"][row["case"]]["sharedAtom"]
                        for e in accepted
                    ),
                    "observedRepeatedFacts": sum(e["repeatFact"] for e in accepted),
                    "observedExactRepeats": sum(e["exactRepeat"] for e in accepted),
                    "newConsequencesAfterFirst": sum(
                        e["qualifiedPositive"]
                        and e["newConsequence"]
                        and e["afterFirstQuestion"]
                        for e in accepted
                    ),
                    "consumedPremises": sum(
                        e["category"] == "premise_consumed" for e in accepted
                    ),
                    "absenceLabels": sum(
                        e["category"] == "absence_recheck" for e in accepted
                    ),
                    "rejected": sum(len(c["rejected"]) for c in phase["calls"]),
                    "failedCalls": sum(
                        c["failure"] is not None for c in phase["calls"]
                    ),
                }
            )
    for case in range(len(plan["tasks"])):
        case_rows = [r for r in rows if r["case"] == case]
        for budget in plan["checkpoints"]:
            # Completed schedules can be compared at a larger common cap; reservation failures cannot.
            if not all(
                r["grossTokens"] >= budget or r["stop"] == "schedule_complete"
                for r in case_rows
            ):
                continue
            points.append(
                {
                    "case": case,
                    "budget": budget,
                    "arms": [
                        {
                            "arm": r["arm"],
                            "correctDownstreamAnswers": sum(
                                c["correct"]
                                and c.get("atGrossTokens", budget + 1) <= budget
                                for c in r["calls"]
                            ),
                            "correctNewAnswersAfterFirst": sum(
                                c["correct"]
                                and c["turn"] > 0
                                and c.get("atGrossTokens", budget + 1) <= budget
                                for c in r["calls"]
                            ),
                        }
                        for r in case_rows
                    ],
                }
            )
    concordance = []
    for row in rows:
        sets = []
        for pass_id in range(plan["annotationPasses"]):
            phase = next(
                x
                for x in labels
                if (x["case"], x["arm"], x["pass"])
                == (row["case"], row["arm"], pass_id)
            )
            sets.append(
                {
                    json.dumps([e["turn"], e["atom"], e["premises"]], sort_keys=True)
                    for c in phase["calls"]
                    for e in c["accepted"]
                    if e["qualifiedPositive"]
                }
            )
        concordance.append(
            {
                "case": row["case"],
                "arm": row["arm"],
                "intersection": len(sets[0] & sets[1]),
                "union": len(sets[0] | sets[1]),
                "qualifiedEpisodeJaccard": len(sets[0] & sets[1])
                / len(sets[0] | sets[1])
                if sets[0] | sets[1]
                else None,
            }
        )
    report = {
        "planSha256": hashlib.sha256(
            (directory / "plan.json").read_bytes()
        ).hexdigest(),
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
        "trajectories": rows,
        "annotationSummaries": summaries,
        "annotationConcordance": concordance,
        "jointCheckpoints": points,
        "claims": "Observed literal derivation counts are lower bounds. Two passes use the same stochastic model, so concordance does not establish independent-rater reliability or completeness. No depth/optimization/causal efficacy claim follows from two small fixtures. Unused budget is not savings. Native cache reuse and model behavior are separate.",
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = [
        "# Shared-premise Library diagnostic",
        "",
        report["claims"],
        "",
        "| Case | Arm | Total input + all output | Correct obligations | Correct new answers after first | Stop |",
        "|---|---|---:|---:|---:|---|",
    ]
    for r in rows:
        lines.append(
            f"| {r['case']} | {r['arm']} | {r['grossTokens']} | {sum(c['correct'] for c in r['calls'])} | {sum(c['correct'] and c['turn'] > 0 for c in r['calls'])} | {r['stop']} {r['failure'] or ''} |"
        )
    lines += [
        "",
        "| Case / arm / annotation pass | Shared-premise derivations | Observed repeated Facts | New consequences after first | Consumed premises | Rejected labels |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for a in summaries:
        lines.append(
            f"| {a['case']} / {a['arm']} / {a['pass']} | {a['sharedPremiseDerivations']} | {a['observedRepeatedFacts']} | {a['newConsequencesAfterFirst']} | {a['consumedPremises']} | {a['rejected']} |"
        )
    lines += [
        "",
        f"Known solver tokens: {report['solverKnownTokens']}; unknown-usage calls: {report['solverUnknownUsageCalls']}. Known annotation tokens: {report['annotationKnownTokens']}; unknown annotation calls: {report['annotationUnknownUsageCalls']}.",
        "",
        "The source-bound native qualification proves support reuse across three distinct downstream obligations, alternative-support preservation, stale-handle rejection and withdrawal recomputation on this fixture. Quint correspondence and Lean premises are separate gates. The baseline/Fact/Scheme arms share the same questions and full reasoning-history replay, and do not prune alternatives. Failures remain in the ledger. No anti-repetition instruction is supplied.",
        "",
        "See plan.json for relative source hashes, paper lessons, formal scope, exact tasks, independent grader and frozen annotation rules; raw.tar.gz retains inputs, native artifacts, requests, SSE events, returned thinking and rejected labels. This is a local Darwin source snapshot, not a portable binary wheel or a verified clean Git checkout reproduction.",
    ]
    (output / "report.md").write_text("\n".join(lines) + "\n")
    doc = (
        s.ROOT
        / ".cache/ascent/research-reports/agent-inference/fact-reuse-results/shared-premise-diagnostic"
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
    report_text("SHARED_REPORT", doc, flush=True)
