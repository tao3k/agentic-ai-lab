# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Assemble frozen raw evidence and auditable total budget result records."

import json, hashlib
from pathlib import Path
from ._factor_budget_metrics import metrics


def _build_ledger(
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
):
    """Assemble the retained ledger structure."""
    return {
        "saturatedPlainCalibrationRecords": saturated,
        "saturatedPlainCalibrationFrozenPlan": json.loads(
            (BASE / "saturated-calibration-plain/frozen-plan.json").read_text()
        ),
        "legacySnapshotPath": "pretransition-snapshot",
        "calibrationSourcePlan": json.loads(
            (BASE / "calibration/frozen-source-plan.json").read_text()
        ),
        "calibrationToConfirmatoryPolicyParity": json.loads(
            (BASE / "calibration-to-confirmatory-policy-parity.json").read_text()
        ),
        "censoredCalibrationRecords": censored,
        "censoredCalibrationFrozenPlan": json.loads(
            (BASE / "censored-calibration-16384/frozen-plan.json").read_text()
        ),
        "archivedPathRemap": {"calibration/": "censored-calibration-16384/"},
        "requests": requests,
        "admittedProofAuditExports": proofs,
        "prepaidDevelopmentLogs": development,
        "inputReservationBackcheck": json.loads(
            (BASE / "input-reservation-backcheck.json").read_text()
        ),
        "schema": "ascent.factor-total-budget-ledger.v1",
        "frozenPlan": plan,
        "qualification": json.loads((BASE / "qualification.json").read_text()),
        "calibrationRecords": cal,
        "confirmatoryRecords": rows,
        "responsesIncludingFailures": responses,
        "rawArtifactHashes": raw,
        "actualInvoiceUsd": None,
    }


def _build_report(
    BASE, DOC, aggregates, cal, censored, pairs, plan, rows, saturated, shared
):
    """Assemble the retained report structure."""
    return {
        "schema": "ascent.factor-total-budget-report.v1",
        "frozenPlanSha256": sha((BASE / "frozen-plan.json").read_bytes()),
        "ledgerSha256": sha((DOC / "factor-total-budget-ledger.json").read_bytes()),
        "pairs": pairs,
        "aggregate": aggregates,
        "calibration": [
            {"case": r["case"], "metrics": metrics(r), "grade": r["grade"]} for r in cal
        ],
        "matchedSharedToolReplies": shared,
        "censoredCalibrationPhases": len(censored),
        "saturatedPlainCalibrationPhases": len(saturated),
        "totalObservedStudyTokensIncludingCensored": sum(
            r["observedTotalTokens"] for r in rows + cal + censored + saturated
        ),
        "protocolViolations": [
            {
                "case": r["case"],
                "arm": r["arm"],
                "phase": r["phase"],
                "failure": r["failure"],
            }
            for r in rows + cal
            if r["failure"]
            in (
                "budget_protocol_violation",
                "missing_usage_budget_unknown",
                "inconsistent_total_usage",
                "inconsistent_usage_breakdown",
            )
        ],
        "allObservedPhaseTotalsWithinBudget": all(
            (r["observedTotalTokens"] <= plan["totalTokenBudget"] for r in rows + cal)
        ),
        "totalBudgetIsCeilingNotIdenticalSpend": True,
        "hiddenSemanticThinkingRepetitionMeasured": False,
        "analysisSourceSha256": sha(Path(__file__).read_bytes()),
        "completeConfirmatoryPhases": len(rows),
        "noInferenceFromStochasticArmDifferences": True,
    }


def sha(b):
    return hashlib.sha256(b).hexdigest()
