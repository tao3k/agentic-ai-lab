# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared execution for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..model_study import provider
from ..movie_study import provider_key
from ._shared_cases import shared_packet, shared_truth
from ._shared_check import shared_check


from ._shared_action import shared_action


from ._shared_context import _shared_turn_context


def shared_live(directory, output):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence

    plan = shared_check(directory)
    output.mkdir(parents=True, exist_ok=False)
    rows = []
    save = lambda: (output / "ledger.json").write_text(
        json.dumps(rows, indent=2) + "\n"
    )
    with ReasoningRuntime() as engine:
        for case, task in enumerate(plan["tasks"]):
            for arm in plan["orders"][case]:
                row = {
                    "case": case,
                    "arm": arm,
                    "calls": [],
                    "grossTokens": 0,
                    "stop": None,
                    "failure": None,
                }
                rows.append(row)
                save()
                history = None
                prior_usage = None
                with ComputationalEvidence(engine) as store:
                    try:
                        for turn, ids in enumerate(task["schedule"]):
                            context, packet = _shared_turn_context(
                                plan, task, ids, store, arm
                            )
                            if history is None:
                                context["task"] = {
                                    "edges": task["edges"],
                                    "needColumns": ["id", "a", "b", "c", "d"],
                                    "rules": plan["candidate"][3:6],
                                    "query": ["ready", "?f"],
                                    "semantics": "Positive rules with conjunctive bodies; path is directed reachability over edge; ready(id) requires both paths in its need row.",
                                }
                                history = ResponseHistory(
                                    json.dumps(context, separators=(",", ":"))
                                )
                                new_items = history.snapshot()
                            else:
                                history.append_feedback(context)
                                new_items = [history.snapshot()[-1]]
                            req = {
                                "model": plan["model"],
                                "input": history.input(),
                                "tools": [plan["tool"]],
                                "tool_choice": "auto",
                                "reasoning": {"effort": plan["reasoningEffort"]},
                                "stream": True,
                                "store": False,
                                "text": {
                                    "format": {
                                        "type": "json_schema",
                                        "name": "permitted_transitions",
                                        "schema": plan["tool"]["parameters"],
                                    }
                                },
                                "max_output_tokens": plan["maxOutputTokens"],
                            }
                            bound = (
                                len(json.dumps(req, ensure_ascii=False).encode())
                                if prior_usage is None
                                else prior_usage
                                + sum(
                                    len(json.dumps(x, ensure_ascii=False).encode())
                                    for x in new_items
                                )
                            ) + plan["inputPadding"]
                            cap = min(
                                plan["maxOutputTokens"],
                                plan["totalBudget"] - row["grossTokens"] - bound,
                            )
                            if cap < plan["minimumOutputTokens"]:
                                row.update(
                                    stop="budget_reservation",
                                    nextInputReservation=bound,
                                )
                                break
                            req["max_output_tokens"] = cap
                            folder = output / "calls" / f"{case}-{arm}" / str(turn)
                            folder.mkdir(parents=True)
                            record = {
                                "turn": turn,
                                "usage": None,
                                "grossTokens": None,
                                "failure": None,
                                "correct": False,
                                "inputReservation": bound,
                                "outputCap": cap,
                                "nativePacket": packet,
                            }
                            row["calls"].append(record)
                            save()
                            (folder / "request.json").write_text(
                                json.dumps(req, indent=2) + "\n"
                            )
                            _, meta = provider(
                                req, provider_key(), folder / "response.json"
                            )
                            term = meta.get("terminal") or {}
                            text = "".join(
                                p.get("text", "")
                                for x in term.get("output", [])
                                if x.get("type") == "reasoning"
                                for p in x.get("content", [])
                                if p.get("type") == "reasoning_text"
                            )
                            (folder / "thinking.txt").write_text(text)
                            record["thinkingSha256"] = hashlib.sha256(
                                text.encode()
                            ).hexdigest()
                            record.update(
                                status=term.get("status"),
                                providerError=meta.get("error"),
                                incompleteDetails=term.get("incomplete_details"),
                                usage=term.get("usage"),
                            )
                            u = record["usage"]
                            if not isinstance(u, dict) or any(
                                type(u.get(k)) is not int or u[k] < 0
                                for k in ("input_tokens", "output_tokens")
                            ):
                                raise ValueError("unknown usage")
                            record["grossTokens"] = (
                                u["input_tokens"] + u["output_tokens"]
                            )
                            row["grossTokens"] += record["grossTokens"]
                            record["atGrossTokens"] = row["grossTokens"]
                            assert (
                                u["input_tokens"] <= bound
                                and u["output_tokens"] <= cap
                                and row["grossTokens"] <= plan["totalBudget"]
                            ), "budget violation"
                            if meta.get("error") or term.get("status") != "completed":
                                raise ValueError("provider incomplete or failed")
                            answer, calls = shared_action(term)
                            assert set(answer) <= set(ids), "unknown transition ID"
                            record.update(
                                answer=answer,
                                expected=[
                                    i for i in ids if shared_truth(task, ["ready", i])
                                ],
                            )
                            record["correct"] = sorted(answer) == record["expected"]
                            history.append_response(term)
                            for call in calls:
                                history.append_result(
                                    call["call_id"], {"recorded": True}
                                )
                            prior_usage = record["grossTokens"]
                            # A paired result is extra input too, not part of the previous usage.
                            if calls:
                                prior_usage += sum(
                                    len(json.dumps(x, ensure_ascii=False).encode())
                                    for x in history.snapshot()[-len(calls) :]
                                )
                            (folder / "receipt.json").write_text(
                                json.dumps(record, indent=2) + "\n"
                            )
                            save()
                            report_text(
                                "SHARED_TURN",
                                case,
                                arm,
                                turn,
                                row["grossTokens"],
                                "correct",
                                record["correct"],
                                flush=True,
                            )
                        row["stop"] = row["stop"] or "schedule_complete"
                    except Exception as error:
                        row.update(stop="failure", failure=str(error))
                        if row["calls"]:
                            row["calls"][-1]["failure"] = str(error)
                            (
                                output
                                / "calls"
                                / f"{case}-{arm}"
                                / str(row["calls"][-1]["turn"])
                                / "receipt.json"
                            ).write_text(json.dumps(row["calls"][-1], indent=2) + "\n")
                    finally:
                        row["unusedBudget"] = (
                            plan["totalBudget"] - row["grossTokens"]
                            if all(c["grossTokens"] is not None for c in row["calls"])
                            else None
                        )
                        save()
    shared_check(directory)
    report_text("SHARED_MODEL_COMPLETE", flush=True)
