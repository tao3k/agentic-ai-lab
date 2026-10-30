# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reuse execution for the candidate model study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import digest, save
from ._reuse_snapshot import reuse_verify
from ._tasks import branch_action, branch_request
from ._judge import judge_selection
from ._transport import Consumer


from ._reuse_response import _admit_branch_response


def reuse_solve(run):
    plan = reuse_verify(run)
    assert not (run / "reuse-ledger.json").exists()
    rows = []
    save(run / "reuse-ledger.json", rows)
    for case, t in enumerate(plan["tasks"]):
        for arm in plan["orders"][case]:
            folder = run / "calls" / f"{case}-{arm}"
            folder.mkdir(parents=True)
            native = Consumer(folder)
            row = {
                "case": case,
                "arm": arm,
                "calls": [],
                "grossTokens": 0,
                "maxDepth": 0,
                "expandedPrefixes": [],
                "incumbent": {
                    "selection": t["seed"],
                    "evaluation": judge_selection(t, t["seed"], True),
                },
                "stop": None,
            }
            rows.append(row)
            frontier = {0: []}
            tried = set()
            serial = 0
            history = []
            pending_call = None
            history_tokens = None
            try:
                native.call(
                    op="reuse-init",
                    identity=t["id"],
                    edges=t["edges"],
                    needs=t["needs"],
                )
                for turn in range(plan["maxCalls"]):
                    choices = []
                    for parent, selection in frontier.items():
                        if len(selection) == t["stages"]:
                            continue
                        children = [
                            o
                            for o in t["options"]
                            if o["stage"] == len(selection)
                            and (parent, o["id"]) not in tried
                        ]
                        if children:
                            choices.append(
                                {
                                    "parentId": parent,
                                    "selection": selection,
                                    "optionIds": [o["id"] for o in children],
                                }
                            )
                    if not choices:
                        row["stop"] = "frontier_exhausted"
                        break
                    ids = sorted(
                        {
                            next(o["fragment"] for o in t["options"] if o["id"] == i)
                            for x in choices
                            for i in x["optionIds"]
                        }
                    )
                    packet = (
                        native.call(op="reuse-packet", fragments=ids)
                        if arm != "baseline"
                        else None
                    )
                    if arm == "scheme":
                        allowed = set(packet["allowed"])
                        for x in choices:
                            x["optionIds"] = [
                                i
                                for i in x["optionIds"]
                                if next(
                                    o["fragment"] for o in t["options"] if o["id"] == i
                                )
                                in allowed
                            ]
                        choices = [x for x in choices if x["optionIds"]]
                        if not choices:
                            row["stop"] = "verified_frontier_exhausted"
                            break
                    context = {
                        "task": t,
                        "frontier": choices,
                        "incumbent": row["incumbent"],
                        "question": "Choose one available parentId and optionId to expand while searching for the highest-value feasible complete selection.",
                    }
                    if packet:
                        context["evidence"] = {"facts": packet["facts"]}
                    if arm == "scheme":
                        context["evidence"].update(
                            fragments=packet["fragments"],
                            nodes=packet["nodes"],
                            nodeEncoding=[
                                "id",
                                "kind",
                                "relation",
                                "row",
                                "ruleLabel",
                                "inputs",
                            ],
                        )
                    req, reserve = branch_request(
                        plan,
                        context,
                        history,
                        pending_call,
                        row["grossTokens"],
                        history_tokens,
                    )
                    if req is None:
                        row["stop"] = "budget_reservation"
                        row["nextReservation"] = reserve
                        break
                    call = {
                        "turn": turn,
                        "failure": None,
                        "grossTokens": None,
                        "outputCap": req["max_output_tokens"],
                        "reservation": reserve,
                        "inputReservation": reserve - req["max_output_tokens"],
                    }
                    row["calls"].append(call)
                    out = folder / str(turn)
                    out.mkdir()
                    save(out / "request.json", req)
                    save(run / "reuse-ledger.json", rows)
                    term = _admit_branch_response(req, out, call, row, plan)
                    action, encoding, pending_call = branch_action(term)
                    call["wireEncoding"] = encoding
                    history = req["input"] + term["output"]
                    history_tokens = call["grossTokens"]
                    parent = action["parentId"]
                    option = action["optionId"]
                    assert any(
                        x["parentId"] == parent and option in x["optionIds"]
                        for x in choices
                    ), "unavailable_child"
                    tried.add((parent, option))
                    child = frontier[parent] + [option]
                    evaluation = judge_selection(t, child)
                    call.update(
                        action=action,
                        selection=child,
                        evaluation=evaluation,
                        evidenceStats=packet["stats"] if packet else None,
                    )
                    if evaluation["valid"]:
                        row["expandedPrefixes"].append(child)
                        row["maxDepth"] = max(row["maxDepth"], len(child))
                        serial += 1
                        frontier[serial] = child
                        if (
                            len(child) == t["stages"]
                            and evaluation["value"]
                            > row["incumbent"]["evaluation"]["value"]
                        ):
                            row["incumbent"] = {
                                "selection": child,
                                "evaluation": evaluation,
                            }
                    call["incumbentValue"] = row["incumbent"]["evaluation"]["value"]
                    call["maxDepth"] = row["maxDepth"]
                    save(out / "receipt.json", call)
                    save(run / "reuse-ledger.json", rows)
                    report_text(
                        "REUSE_TURN",
                        case,
                        arm,
                        turn,
                        "gross",
                        row["grossTokens"],
                        "depth",
                        row["maxDepth"],
                        "value",
                        row["incumbent"]["evaluation"]["value"],
                        flush=True,
                    )
                row["stop"] = row["stop"] or "call_limit"
            except Exception as error:
                row["stop"] = "failure"
                row["failure"] = str(error)
                if row["calls"]:
                    row["calls"][-1]["failure"] = str(error)
                    save(
                        folder / str(row["calls"][-1]["turn"]) / "receipt.json",
                        row["calls"][-1],
                    )
            finally:
                row["shutdown"] = native.close()
                row["unusedBudget"] = (
                    plan["budget"] - row["grossTokens"]
                    if all(c["grossTokens"] is not None for c in row["calls"])
                    else None
                )
                save(run / "reuse-ledger.json", rows)
    reuse_verify(run)
    report_text("REUSE_MODEL_COMPLETE", flush=True)
