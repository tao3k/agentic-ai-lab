# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Report for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import tarfile
from ._artifacts import canonical, fields, save, sha
from ._config import ROOT, RUNTIME
from ._sources import verify


from ._report_bundle import _publish_report_bundle


def _build_point_result(
    accepted, boundary, covered, expansions, measurement, repeats, row, valid
):
    """Assemble the retained point result structure."""
    return {
        "checkpoint": boundary,
        "reached": row["grossTokens"] >= boundary,
        "value": max(
            [row["seedGrade"]["value"], *[e["evaluation"]["value"] for e in valid]]
        ),
        "expansions": len(expansions),
        "validDepth": max(
            [len(e["child"]) for e in expansions if e["prefix"]["valid"]], default=0
        ),
        "uniqueFeasibleCandidates": len({canonical(e["completion"]) for e in valid}),
        "positiveRepeatedDerivations": repeats
        if all(not c["failure"] for c in measurement)
        and len(measurement) == len(covered)
        else None,
        "availableRepeatedLabels": repeats,
        "qualifiedPositiveDerivations": sum(
            e["qualifiedPositiveDerivation"] for e in accepted
        ),
        "reuseLabels": sum(
            e["kind"] == "reuse" and e["truthMatches"] for e in accepted
        ),
        "uncertainLabels": sum(e["kind"] == "uncertain" for e in accepted),
        "repeatsPerExpansion": repeats / len(expansions) if expansions else None,
        "failedMeasurementCalls": sum(bool(c["failure"]) for c in measurement),
    }


def point(row, labels, boundary):
    expansions = [e for e in row["expansions"] if e["atGrossTokens"] <= boundary]
    valid = [e for e in expansions if e["evaluation"]["valid"]]
    covered = [
        c for c in row["calls"] if c.get("atGrossTokens", float("inf")) <= boundary
    ]
    measurement = [
        c for c in labels["calls"] if c["turn"] in {x["turn"] for x in covered}
    ]
    accepted = [
        e
        for e in labels["accepted"]
        if e.get("atGrossTokens", float("inf")) <= boundary
    ]
    repeats = sum(e["definiteRepeat"] for e in accepted)
    return _build_point_result(
        accepted, boundary, covered, expansions, measurement, repeats, row, valid
    )


def _build_result(ann, cal, run, solver, table):
    """Assemble the retained result structure."""
    return {
        "planSha256": sha((run / "plan.json").read_bytes()),
        "table": table,
        "solverGrossTokens": sum(r["grossTokens"] for r in solver["phases"]),
        "calibrationGrossTokens": sum(r["grossTokens"] for r in cal["phases"]),
        "measurementGrossTokens": sum(x["grossTokens"] for x in ann["phases"]),
        "limitations": [
            "Two deterministic tasks, one stochastic run per arm; descriptive study, not a causal/statistical effect estimate.",
            "All arms retain Scheme execution and post-choice checking. Baseline omits model-visible Fact evidence and Fact prepruning.",
            "Task/action contracts are common; there are no solver system instructions, anti-repetition directives or requested audit narration.",
            "Only actual completed native-admitted prefixes measure depth; full seed-suffix candidates do not establish explored depth.",
            "Unused ceiling is not savings. Matched checkpoints credit only observed completed calls before the common gross-token boundary.",
            "Positive repeated labels require exact quotes, literal IDs/endpoints, independently true atoms and native-qualified explicit edge-chain/conjunction support. This narrow metric omits unsupported/negative/ambiguous derivations.",
            "Same-provider extraction is partially blind but not independently validated for completeness or semantic category accuracy. Counts are qualified labels, not cognitive ground truth.",
            "This is a Library consumer test, not a Library Search/Fact workflow API or MRR integration. Agentic AI Lab revision projection and reevaluation planning are exercised before model calls at fixed cuts; live revision during the model dialogue remains unqualified.",
            "Retained Session publication is checked against independently replayed finite evidence. Proof replay costs are additional; no cross-generation retained-proof algorithm or source authentication is claimed.",
            "Native proof builds/hits are not end-to-end speed or model-thinking savings. Negative and failed outcomes remain in all records.",
        ],
    }


def _render_annotation_reports(run, table, spans, result):
    """Own the render annotation reports phase without weakening its checks."""
    lines = [
        "# Native Fact interaction study",
        "",
        f"Frozen plan `{result['planSha256']}`. One implementation; three configured treatments. No solver instructions or anti-repetition prompt.",
        "",
        "| Task / arm | Gross / unused | Seed → best | Gap | Calls / failures / truncation | Native Fact prunings |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for r in table:
        lines.append(
            f"| {r['case']} / {r['arm']} | {r['grossTokens']} / {r['unusedBudget']} | {r['seedValue']} → {r['bestValue']} | {r['gap']} | {r['calls']} / {r['failedCalls']} / {r['truncatedCalls']} | {r['automaticPrunedBranches']} |"
        )
    lines += [
        "",
        "## Matched input + all-output checkpoints",
        "",
        "| Task / arm | Gross checkpoint / reached | Value | Expansions / admitted depth | Qualified positive repeats / derives / reuse | Missing measurements |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for r in table:
        for cp in r["checkpoints"]:
            lines.append(
                f"| {r['case']} / {r['arm']} | {cp['checkpoint']} / {cp['reached']} | {cp['value']} | {cp['expansions']} / {cp['validDepth']} | {cp['positiveRepeatedDerivations']} / {cp['qualifiedPositiveDerivations']} / {cp['reuseLabels']} | {cp['failedMeasurementCalls']} |"
            )
    lines += [
        "",
        f"Solver gross tokens {result['solverGrossTokens']}; separate calibration {result['calibrationGrossTokens']}; separate measurement {result['measurementGrossTokens']}.",
        "",
        *result["limitations"],
    ]
    (run / "report.md").write_text("\n".join(lines) + "\n")
    quotes = ["# Source-anchored returned-thinking episodes", ""]
    for e in spans:
        quotes += [
            f"- task {e['case']}, {e['arm']}, call {e['turn']}, atom {e['atom']}, kind {e['kind']}, span {e['span']}, repeat {e['definiteRepeat']}, prior {e['prior']}",
            "",
            "> " + e["quote"].replace("\n", "\n> "),
            "",
        ]
    (run / "thinking-episodes.md").write_text("\n".join(quotes) + "\n")


def _audit_annotation_measurements(solver, labels, run, plan):
    """Own the audit annotation measurements phase without weakening its checks."""
    table = []
    spans = []
    for row in solver["phases"]:
        lab = labels[row["case"], row["arm"]]
        folder = run / "paid" / f"{row['case']}-{row['arm']}"
        assert (
            sum(c.get("grossTokens", 0) for c in row["calls"])
            == row["grossTokens"]
            <= plan["budget"]
        )
        for call in row["calls"]:
            request = json.loads((folder / f"{call['turn']}.request.json").read_text())
            assert "instructions" not in request and request["tools"] == plan["tools"]
            assert (
                sha((folder / f"{call['turn']}.thinking.txt").read_bytes())
                == call["thinkingSha256"]
            )
        for episode in lab["accepted"]:
            text = (folder / f"{episode['turn']}.thinking.txt").read_text()
            assert text[slice(*episode["span"])] == episode["quote"]
            spans.append({"case": row["case"], "arm": row["arm"], **episode})
        table.append(
            {
                "case": row["case"],
                "arm": row["arm"],
                "calls": len(row["calls"]),
                "failedCalls": sum(bool(c["failure"]) for c in row["calls"]),
                "truncatedCalls": sum(
                    c["status"] == "incomplete" for c in row["calls"]
                ),
                "grossTokens": row["grossTokens"],
                "unusedBudget": row["unusedBudget"],
                "thinkingTokens": sum(
                    (c["usage"].get("output_tokens_details") or {}).get(
                        "reasoning_tokens", 0
                    )
                    for c in row["calls"]
                    if isinstance(c.get("usage"), dict)
                ),
                "seedValue": row["seedGrade"]["value"],
                "bestValue": row["grade"]["value"],
                "gap": row["grade"]["gap"],
                "valid": row["grade"]["valid"],
                "nativeStats": fields(row["state"]["nativeStats"]),
                "automaticPrunedBranches": sum(
                    len(fields(p[1])["pruned"]) for p in row["state"]["prunings"]
                ),
                "measurementFailure": lab["failure"],
                "rejectedLabels": len(lab["rejected"]),
                "checkpoints": [point(row, lab, cp) for cp in plan["checkpoints"]],
            }
        )
    # Assert the common root task and Fact-only/pruning packet parity on real payloads.
    for case in (0, 1):
        roots = {
            arm: json.loads(
                json.loads(
                    (run / "paid" / f"{case}-{arm}" / "0.request.json").read_text()
                )["input"][0]["content"]
            )
            for arm in ("baseline", "facts", "prune")
        }
        f = roots["facts"].copy()
        p = roots["prune"].copy()
        packet = f.pop("evidence")
        assert p.pop("evidence") == packet
        assert roots["baseline"] == f
        for key in f:
            if key != "unvisitedChildren":
                assert f[key] == p[key]
    return table, spans


def report(run, plan):
    verify(run, plan)
    solver = json.loads((run / "ledger.json").read_text())
    ann = json.loads((run / "annotation-ledger.json").read_text())
    cal = json.loads((run / "calibration-ledger.json").read_text())
    labels = {(x["case"], x["arm"]): x for x in ann["phases"]}
    table, spans = _audit_annotation_measurements(solver, labels, run, plan)
    result = _build_result(ann, cal, run, solver, table)
    prior = (
        ROOT
        / ".cache/ascent/archived-runs/docs/research/agent-inference/history/consumer-calibration-failure.tar.gz"
    )
    if prior.exists():
        result["priorProtocolFailureArchiveSha256"] = sha(prior.read_bytes())
        result["priorProtocolCostBoundary"] = (
            "Earlier HTTP 400 requests returned no usage. Their cost is unknown, not zero; they are excluded from known-token sums and retained in the failure archive."
        )
    save(run / "report.json", result)
    save(run / "thinking-episodes.json", spans)
    _render_annotation_reports(run, table, spans, result)
    _publish_report_bundle(run, plan, result, prior)
