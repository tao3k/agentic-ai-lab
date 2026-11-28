# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from ._artifacts import save, sha
from ._phase import phase
from ._sources import verify
from ._transport import EvidenceEngine


def calibrate(run, plan):
    verify(run, plan)
    rows = []
    with EvidenceEngine(run) as native, EvidenceEngine(run, True) as judge:
        for arm in ("baseline", "facts", "prune"):
            rows.append(phase(run, plan, 2, arm, True, native, judge))
            save(run / "calibration-ledger.json", {"phases": rows, "passed": False})
    passed = all(
        len(r["expansions"]) == 1
        and r["calls"][0]["status"] == "completed"
        and not r["calls"][0]["failure"]
        for r in rows
    )
    save(run / "calibration-ledger.json", {"phases": rows, "passed": passed})
    if not passed:
        raise ValueError("calibration gate failed; no confirmatory study")
    report_text("CALIBRATION_PASSED", flush=True)


def solve(run, plan):
    verify(run, plan)
    if not json.loads((run / "calibration-ledger.json").read_text())["passed"]:
        raise ValueError("calibration failed")
    if (run / "ledger.json").exists():
        raise ValueError("study already started; do not overwrite failures")
    rows = []
    with EvidenceEngine(run) as native, EvidenceEngine(run, True) as judge:
        for case, arm in plan["schedule"]:
            rows.append(phase(run, plan, case, arm, native=native, judge=judge))
            save(
                run / "ledger.json",
                {"planSha256": sha((run / "plan.json").read_bytes()), "phases": rows},
            )
    verify(run, plan)
    report_text("SOLVER_STUDY_COMPLETE", flush=True)
