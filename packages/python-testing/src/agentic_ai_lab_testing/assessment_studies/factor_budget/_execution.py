# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the factor budget study."""

import json
from ._artifacts import save, sha
from ._config import BASE
from ._phase import charge_usage, run_phase
from ._snapshot import verify
from ._transport import SchemeEngine


def run(plan, calibration=False):
    verify(plan)
    dest = BASE / ("calibration" if calibration else "paid")
    dest.mkdir(exist_ok=False)
    rows = []
    if calibration:
        order = [{"case": c["id"], "arm": "fresh"} for c in plan["calibrationCases"]]
        cases = plan["calibrationCases"]
    else:
        calibration_rows = json.loads((BASE / "calibration/records.json").read_text())
        assert len(calibration_rows) == 2 and any(
            (
                r["grade"]["valid"]
                and (not r["grade"]["optimal"])
                and r["failure"]
                in (
                    None,
                    "output_budget_exhausted",
                    "total_budget_reservation_stop",
                    "call_limit_exhausted",
                )
                and r["observedTotalTokens"] <= plan["totalTokenBudget"]
                and all(charge_usage(c["usage"]) >= 0 for c in r["calls"])
                for r in calibration_rows
            )
        ), "hardness gate failed"
        order = plan["order"]
        cases = plan["cases"]
    for item in order:
        c = next((x for x in cases if x["id"] == item["case"]))
        native = SchemeEngine()
        try:
            native.call(
                op="init",
                arm=plan["arms"][item["arm"]],
                edges=c["edges"],
                identity=c["id"],
                penalties=c["transitionPenalties"],
            )
            for phase in [1] if calibration else [0, 1]:
                row = run_phase(
                    plan,
                    c,
                    phase,
                    item["arm"],
                    native,
                    dest / f"{c['id']}-{item['arm']}-{phase}",
                )
                rows.append(row)
                save(dest / "records.json", rows)
        finally:
            native.close()
    verify(plan)
    save(
        dest / "post-run-binding.json",
        {
            "passed": True,
            "artifacts": len(plan["artifactHashes"]),
            "frozenPlanSha256": sha((BASE / "frozen-plan.json").read_bytes()),
        },
    )
    return rows
