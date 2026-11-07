# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Phase for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import json
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import canonical, save, sha
from ._transport import EvidenceEngine
from ._workload import judge_init, request_for, same_check


def charge(usage):
    if not isinstance(usage, dict) or any(
        type(usage.get(k)) is not int or usage[k] < 0
        for k in ("input_tokens", "output_tokens")
    ):
        raise ValueError("unknown_usage")
    total = usage["input_tokens"] + usage["output_tokens"]
    if usage.get("total_tokens", total) != total:
        raise ValueError("inconsistent_usage")
    for field, key, limit in [
        ("output_tokens_details", "reasoning_tokens", "output_tokens"),
        ("input_tokens_details", "cached_tokens", "input_tokens"),
    ]:
        n = (usage.get(field) or {}).get(key)
        if n is not None and (type(n) is not int or not 0 <= n <= usage[limit]):
            raise ValueError("inconsistent_usage_details")
    return total


def reasoning(meta, path):
    term = meta.get("terminal") or {}
    text = "\n".join(
        p.get("text", "")
        for item in term.get("output", [])
        if item.get("type") == "reasoning"
        for p in item.get("content", [])
        if p.get("type") == "reasoning_text"
    )
    if not text and path.with_suffix(".events.jsonl").exists():
        text = "".join(
            e.get("delta", "")
            for line in path.with_suffix(".events.jsonl").read_text().splitlines()
            if (e := json.loads(line)).get("type") == "response.reasoning_text.delta"
        )
    return text


def phase(run, plan, case, arm, calibration=False, native=None, judge=None):
    folder = run / ("calibration" if calibration else "paid") / f"{case}-{arm}"
    folder.mkdir(parents=True, exist_ok=False)
    row = {
        "case": case,
        "arm": arm,
        "calls": [],
        "expansions": [],
        "grossTokens": 0,
        "failure": None,
        "stopReason": None,
        "budget": plan["budget"],
    }
    with contextlib.ExitStack() as stack:
        native = native or stack.enter_context(EvidenceEngine(run))
        judge = judge or stack.enter_context(EvidenceEngine(run, True))
        init = native.call(op="init", case=case, arm=arm)
        task = init["task"]
        judge_init(judge, task)
        save(folder / "certificate.json", init["certificate"])
        save(folder / "library-lifecycle.json", init["libraryLifecycle"])
        row["seedGrade"] = judge.call(
            op="grade", goal=task["goal"], selection=task["seed"]
        )
        consecutive = 0
        for turn in range(1 if calibration else plan["maxCalls"]):
            step = native.call(op="next")
            if step["done"]:
                row["stopReason"] = "tree_exhausted"
                break
            request = request_for(plan, step["context"])
            reserve = (
                len(canonical(request).encode()) + 4096 + 128 * len(request["input"])
            )
            if row["grossTokens"] + reserve + plan["maxOutputTokens"] > plan["budget"]:
                row["stopReason"] = "remaining_below_input_output_reservation"
                break
            save(folder / f"{turn}.request.json", request)
            response = folder / f"{turn}.response.json"
            _, meta = provider(request, provider_key(), response)
            term = meta.get("terminal") or {}
            text = reasoning(meta, response)
            (folder / f"{turn}.thinking.txt").write_text(text)
            call = {
                "turn": turn,
                "status": term.get("status"),
                "usage": term.get("usage"),
                "failure": None,
                "providerSeconds": meta.get("providerSeconds"),
                "thinkingSha256": sha(text.encode()),
                "inputReserve": reserve,
            }
            row["calls"].append(call)
            try:
                call["grossTokens"] = charge(call["usage"])
                row["grossTokens"] += call["grossTokens"]
                call["atGrossTokens"] = row["grossTokens"]
                if (
                    call["usage"]["input_tokens"] > reserve
                    or call["usage"]["output_tokens"] > plan["maxOutputTokens"]
                    or row["grossTokens"] > plan["budget"]
                ):
                    raise ValueError("budget_violation")
            except ValueError as error:
                call["failure"] = str(error)
                row["failure"] = str(error)
                row["stopReason"] = "unqualified_cost"
                save(folder / "receipt.json", row)
                break
            try:
                if meta.get("error") or term.get("status") != "completed":
                    raise ValueError("provider_incomplete_or_error")
                actions = [
                    x
                    for x in term.get("output", [])
                    if x.get("type") == "function_call"
                ]
                if len(actions) != 1 or actions[0].get("name") != "expand":
                    raise ValueError("expected_one_expand")
                args = json.loads(actions[0]["arguments"])
                if set(args) != {"optionId"} or type(args["optionId"]) is not int:
                    raise ValueError("invalid_action_schema")
                event = native.call(op="expand", **args)
                same_check(
                    event["prefix"],
                    judge.call(
                        op="inspect", goal=task["goal"], selection=event["child"]
                    ),
                )
                same_check(
                    event["evaluation"],
                    judge.call(
                        op="evaluate", goal=task["goal"], selection=event["completion"]
                    ),
                )
                event.update(turn=turn, atGrossTokens=row["grossTokens"])
                row["expansions"].append(event)
                consecutive = 0
            except (ValueError, KeyError, TypeError) as error:
                call["failure"] = str(error)
                consecutive += 1
                if "disagreement" in str(error):
                    row["failure"] = str(error)
                    row["stopReason"] = "judge_disagreement"
                    break
                if consecutive >= plan["maxConsecutiveFailures"]:
                    row["failure"] = "consecutive_failed_calls"
                    row["stopReason"] = "failed_calls"
                    break
            save(folder / "receipt.json", row)
            report_text(
                "\nSOLVER",
                case,
                arm,
                turn,
                "gross",
                row["grossTokens"],
                "failure",
                call["failure"],
                flush=True,
            )
        state = native.call(op="summary")
        row["state"] = state
        row["grade"] = judge.call(
            op="grade", goal=task["goal"], selection=state["incumbent"]["selection"]
        )
        same_check(state["incumbent"]["evaluation"], row["grade"])
        row["unusedBudget"] = plan["budget"] - row["grossTokens"]
        row["stopReason"] = row["stopReason"] or (
            "calibration_one_call" if calibration else "call_limit"
        )
        save(folder / "native.json", {"scenario": native.trace, "judge": judge.trace})
        save(folder / "receipt.json", row)
    report_text(
        "\nPHASE",
        case,
        arm,
        len(row["calls"]),
        row["grossTokens"],
        "gap",
        row["grade"]["gap"],
        flush=True,
    )
    return row
