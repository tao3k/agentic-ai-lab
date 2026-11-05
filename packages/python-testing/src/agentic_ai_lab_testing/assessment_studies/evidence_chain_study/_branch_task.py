# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Execute the predeclared branch schedule with unchanged budgets, finalization, failure and replay evidence."

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from ._branch_contracts import branch_submission_context
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_source
from ._branch_request import _reserve_branch_request
from ._branch_response import _admit_branch_response
from ._branch_actions import _apply_branch_actions
from ._branch_entry import _branch_entry_history
from ._branch_receipt import _branch_call_receipt


def _run_task_branches(plan, task, case, arm, store, row, rows, save, output):
    """Own the run task branches phase and retain its evidence checks."""
    source = shared_source(task)
    resolved = None
    entry_request = None
    entry_input = None
    if arm != "baseline":
        resolved = store.resolve(source, SHARED_CANDIDATE)
        assert resolved["status"] == "verified"
    for branch in task["branches"]:
        # Every arm starts from the same known feasible nonoptimal selection.
        context, history, supplied, entry_packet = _branch_entry_history(
            plan, task, branch, arm, store, source
        )
        done = False
        prior_usage = None
        new_results = []
        try:
            for step in range(plan["maxCallsPerBranch"]):
                if sum(len(r["calls"]) for r in rows) >= plan["maxTotalSolverCalls"]:
                    row["stop"] = "global_call_bound"
                    break
                req, bound, available, reserve, cap = _reserve_branch_request(
                    plan,
                    history,
                    arm,
                    step,
                    entry_request,
                    entry_input,
                    prior_usage,
                    new_results,
                    row,
                )
                if cap < (
                    plan["minimumOutputTokens"]
                    if step == 0
                    else plan["finalizationOutputCap"]
                ):
                    row["stop"] = "budget_reservation"
                    break
                req["max_output_tokens"] = cap
                folder = output / "calls" / f"{case}-{arm}" / f"{branch['id']}-{step}"
                folder.mkdir(parents=True)
                rec = _branch_call_receipt(
                    case,
                    arm,
                    branch,
                    step,
                    req,
                    bound,
                    cap,
                    reserve,
                    entry_packet,
                    supplied,
                )
                row["calls"].append(rec)
                save()
                (folder / "request.json").write_text(json.dumps(req, indent=2) + "\n")
                terminal, entry_request, entry_input = _admit_branch_response(
                    req,
                    folder,
                    rec,
                    row,
                    step,
                    entry_request,
                    entry_input,
                    bound,
                    cap,
                    plan,
                )
                if terminal.get("status") == "incomplete":
                    assert step == 0, "finalization incomplete"
                    rec["outputTruncated"] = True
                    if plan.get("requireCompleteThinking"):
                        raise ValueError(
                            "thinking incomplete under total budget; no nonthinking salvage"
                        )
                    history.append_response(
                        {"output": branch_submission_context(terminal)}
                    )
                    rec["outputTruncated"] = True
                    rec["failure"] = (
                        "thinking max_output_tokens; finalization scheduled"
                    )
                    prior_usage = rec["grossTokens"]
                    new_results = []
                    (folder / "receipt.json").write_text(
                        json.dumps(rec, indent=2) + "\n"
                    )
                    save()
                    report_text(
                        "BRANCH_CHECKPOINT",
                        case,
                        arm,
                        branch["id"],
                        row["grossTokens"],
                        flush=True,
                    )
                    continue
                assert terminal.get("status") == "completed", "provider incomplete"
                if step == 0 and not any(
                    x.get("type") == "function_call" for x in terminal["output"]
                ):
                    history.append_response(
                        {"output": branch_submission_context(terminal)}
                    )
                    rec["submissionContinuation"] = True
                    prior_usage = rec["grossTokens"]
                    new_results = []
                    (folder / "receipt.json").write_text(
                        json.dumps(rec, indent=2) + "\n"
                    )
                    save()
                    continue
                calls = [x for x in terminal["output"] if x["type"] == "function_call"]
                history.append_response(terminal)
                done, prior_usage, new_results = _apply_branch_actions(
                    calls,
                    terminal,
                    history,
                    arm,
                    step,
                    plan,
                    store,
                    source,
                    task,
                    branch,
                    row,
                    rec,
                    done,
                    prior_usage,
                    new_results,
                    supplied,
                )
                (folder / "receipt.json").write_text(json.dumps(rec, indent=2) + "\n")
                save()
                report_text(
                    "BRANCH_CALL",
                    case,
                    arm,
                    branch["id"],
                    step,
                    row["grossTokens"],
                    "done",
                    done,
                    flush=True,
                )
                if done:
                    break
            if row["stop"] in (
                "budget_reservation",
                "global_call_bound",
            ):
                break
            assert done, "branch did not submit before call bound"
        except Exception as error:
            row["failure"] = str(error)
            row["stop"] = "failure"
            if row["calls"]:
                row["calls"][-1]["failure"] = str(error)
                (folder / "receipt.json").write_text(
                    json.dumps(row["calls"][-1], indent=2) + "\n"
                )
            break
        finally:
            save()
