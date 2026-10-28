# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Descriptive paired summaries, preserving failed trials and all raw receipts."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json, hashlib, statistics
from pathlib import Path

ROOT = Path.cwd()
BASE = ROOT / ".cache/ascent/factor-budget"
DOC = ROOT / ".cache/ascent/research-reports/agent-inference"

DOC.mkdir(parents=True, exist_ok=True)


from ._factor_budget_rendering import _render_budget_text

from ._factor_budget_metrics import metrics, _build_metrics_result


from ._factor_budget_pairing import (
    _aggregate_budget_arms,
    _compare_fact_replies,
    _pair_budget_trials,
)


from ._factor_budget_records import _build_ledger, _build_report, sha


def save(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + "\n")


def main():
    plan = json.loads((BASE / "frozen-plan.json").read_text())
    cal = json.loads((BASE / "calibration/records.json").read_text())
    rows = json.loads((BASE / "paid/records.json").read_text())
    pairs = _pair_budget_trials(plan, rows, BASE)
    shared = _compare_fact_replies(plan, BASE, rows)
    aggregates = _aggregate_budget_arms(rows)
    raw = {
        str(p.relative_to(BASE)): sha(p.read_bytes())
        for d in (
            "calibration",
            "paid",
            "censored-calibration-16384",
            "saturated-calibration-plain",
        )
        for p in (BASE / d).rglob("*")
        if p.is_file()
    }
    responses = {
        str(p.relative_to(BASE)): json.loads(p.read_text())
        for d in (
            "calibration",
            "paid",
            "censored-calibration-16384",
            "saturated-calibration-plain",
        )
        for p in (BASE / d).glob("*/*.response.json")
    }
    requests = {
        str(p.relative_to(BASE)): json.loads(p.read_text())
        for d in (
            "calibration",
            "paid",
            "censored-calibration-16384",
            "saturated-calibration-plain",
        )
        for p in (BASE / d).glob("*/*.request.json")
    }
    proofs = {
        p.stem: json.loads(p.read_text())
        for d in (
            "calibration",
            "paid",
            "censored-calibration-16384",
            "saturated-calibration-plain",
        )
        for p in (BASE / d).glob("*/proof-store/*.json")
    }
    development = {
        p.name: {"sha256": sha(p.read_bytes()), "bytes": p.stat().st_size}
        for p in BASE.glob("*.log")
    }
    saturated = json.loads(
        (BASE / "saturated-calibration-plain/records.json").read_text()
    )
    censored = json.loads(
        (BASE / "censored-calibration-16384/records.json").read_text()
    )
    ledger = _build_ledger(
        BASE,
        DOC,
        cal,
        censored,
        development,
        plan,
        proofs,
        raw,
        requests,
        responses,
        rows,
        saturated,
    )
    save(DOC / "factor-total-budget-ledger.json", ledger)
    report = _build_report(
        BASE, DOC, aggregates, cal, censored, pairs, plan, rows, saturated, shared
    )
    save(DOC / "factor-total-budget-report.json", report)
    text = _render_budget_text(aggregates, pairs, rows, shared, plan)
    (DOC / "factor-total-budget-report.md").write_text(text)
    report_text(json.dumps(report["aggregate"], indent=2))
    report_text("MATCHED-REPORT-OK pairs=", len(pairs))


if __name__ == "__main__":
    main()
