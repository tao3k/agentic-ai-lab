# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch execution for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import copy, hashlib, json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..model_study import provider
from ..movie_study import provider_key
from ._branch_contracts import (
    branch_grade,
    branch_observe,
    branch_payload,
    branch_submission_context,
)
from ._branch_qualification import branch_entry_reservation, branch_input_reservation
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_source, shared_truth
from ._shared_check import shared_check


from ._branch_request import _reserve_branch_request


from ._branch_response import _admit_branch_response


from ._branch_actions import _apply_branch_actions


from ._branch_entry import _branch_entry_history


from ._branch_receipt import _branch_call_receipt


from ._branch_task import _run_task_branches


def branch_live(directory, output):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence

    plan = shared_check(directory)
    assert plan["experiment"] == "sibling-search"
    qualification = json.loads((directory / "output-qualification.json").read_text())
    assert (
        qualification["passed"]
        and qualification.get("acceptedForPlanSha256", qualification["planSha256"])
        == hashlib.sha256((directory / "plan.json").read_bytes()).hexdigest()
    ), "live output gate required"
    output.mkdir(parents=True, exist_ok=False)
    rows = []

    def save():
        (output / "ledger.json").write_text(json.dumps(rows, indent=2) + "\n")

    with ReasoningRuntime() as engine:
        for case, task in enumerate(plan["tasks"]):
            for arm in plan["orders"][case]:
                row = {
                    "case": case,
                    "arm": arm,
                    "calls": [],
                    "branches": [],
                    "grossTokens": 0,
                    "stop": None,
                    "failure": None,
                }
                rows.append(row)
                save()
                with ComputationalEvidence(engine) as store:
                    _run_task_branches(
                        plan, task, case, arm, store, row, rows, save, output
                    )
                    row["stop"] = row["stop"] or "schedule_complete"
                    row["unusedBudget"] = plan["totalBudget"] - row["grossTokens"]
                    row["nativeStats"] = store.stats()
                    save()
    shared_check(directory)
    report_text("BRANCH_LIVE_COMPLETE", flush=True)
