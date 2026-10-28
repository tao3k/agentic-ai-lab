# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Episode for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib, json, time
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, normalize_contract
from .. import inference_reuse_study as s
from ..inference_effort import until_verified
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from ._config import ARMS
from ._protocol import grade_answer, loose_json, tools

_ENGINE = None


from ._episode_prompt import _episode_instructions


def episode(plan, plan_dir, output, case, rep, arm):
    global _ENGINE
    directory = output / f"{case['name']}-rep-{rep}-{arm}"
    directory.mkdir()
    (directory / "paid-claim.json").open("x").close()
    with (directory / "progress.txt").open("w") as log, contextlib.redirect_stdout(log):
        if _ENGINE is None:
            _ENGINE = ReasoningRuntime(plan_dir / plan["library"])
        assisted = arm != ARMS[0]
        base = s.program(case["source"], {"relations": [], "rules": []})
        record = {
            "case": case["name"],
            "repetition": rep,
            "arm": arm,
            "attempts": [],
            "evidenceJournal": [],
        }

        def save():
            (directory / "episode.json").write_text(json.dumps(record, indent=2) + "\n")

        history = ResponseHistory(
            json.dumps(
                {"question": case["question"], "schema": s.SCHEMA}, sort_keys=True
            )
        )
        origins = {}
        observed = False
        instructions = _episode_instructions(assisted)
        started = time.monotonic()
        with EvidenceChain(
            _ENGINE, [r for r in base["relations"] if r["source"]], arm == ARMS[2]
        ) as chain:
            record["setupSeconds"] = time.monotonic() - started
            save()
            key = provider_key()
            for turn in range(1, plan["maxTurns"] + 1):
                request = {
                    "model": "deepseek-flash",
                    "input": history.input(),
                    "instructions": instructions,
                    "tools": tools(assisted),
                    "tool_choice": "auto",
                    "reasoning": {"effort": "high"},
                    "max_output_tokens": plan["maxOutputTokens"],
                    "stream": True,
                    "store": False,
                }
                (directory / f"{turn}.request.json").write_text(
                    json.dumps(request, indent=2) + "\n"
                )
                raw, meta = provider(request, key, directory / f"{turn}.response.json")
                (directory / f"{turn}.raw.txt").write_text(raw)
                terminal = meta.get("terminal") or {}
                outcome = response_outcome(meta)
                a = {
                    "turn": turn,
                    "providerCalls": 1,
                    "usage": terminal.get("usage"),
                    "correct": False,
                    "providerOutcome": outcome,
                    "providerSeconds": meta["providerSeconds"],
                    "priorReasoningItems": history.reasoning_items,
                    "toolActions": [],
                    "requestSha256": s.identity(request),
                    "sourceIdentity": chain.source_identity,
                }
                record["attempts"].append(a)
                save()
                if meta.get("error") or not a["usage"]:
                    a["outcome"] = "provider_failure"
                    save()
                    raise RuntimeError(
                        "Transport failed; stop dispatch, retain partial receipt."
                    )
                calls = history.append_response(terminal)
                started = time.monotonic()
                if not calls:
                    try:
                        value = loose_json(raw)
                        args = value if isinstance(value, dict) else {"answer": value}
                        a["correct"] = grade_answer(args, chain, case, observed)
                        a["action"] = {"action": "answer", **args}
                        feedback = {
                            "verification": "verified"
                            if a["correct"]
                            else "not_verified"
                        }
                        a["outcome"] = (
                            "verified_answer" if a["correct"] else "answer_not_verified"
                        )
                    except Exception as error:
                        feedback = {
                            "error": str(error)[:2048],
                            "guidance": "You may use submit_answer, actor indices, or one prose-wrapped JSON answer payload.",
                        }
                        a["outcome"] = (
                            "output_budget_exhausted"
                            if outcome == "output_budget_exhausted"
                            else "action_failure"
                        )
                    a["feedback"] = feedback
                    history.append_feedback(feedback)
                for call in calls:
                    action = {
                        "name": call["name"],
                        "callId": call["call_id"],
                        "correct": False,
                    }
                    a["toolActions"].append(action)
                    try:
                        if call.get("status") == "incomplete":
                            raise ValueError(
                                "Incomplete function call was not executed; continue with a complete call."
                            )
                        args = loose_json(call["arguments"])
                        if call["name"] == "scan_facts":
                            names = args.get("relations", list(s.SCHEMA))
                            feedback = chain.scan(names)
                            feedback["actorIndices"] = case["source"]["domains"][
                                "Actor"
                            ]
                            observed = True
                            kind = "scan"
                        elif call["name"] == "check_evidence" and assisted:
                            contract = normalize_contract(args["contract"])
                            program = s.program(case["source"], contract)
                            program["queries"] = args.get("queries", ["answer"])
                            feedback = chain.query(program)
                            observed = True
                            kind = "query"
                            for component in feedback["freshComponents"]:
                                origins.setdefault(component["fingerprint"], turn)
                            feedback["crossRoundReusedComponents"] = [
                                c
                                for c in feedback["reusedComponents"]
                                if origins.get(c["fingerprint"], turn) < turn
                            ]
                            record["evidenceJournal"].append(feedback)
                        elif call["name"] == "submit_answer":
                            kind = "answer"
                            action["correct"] = grade_answer(
                                args, chain, case, observed
                            )
                            a["correct"] |= action["correct"]
                            feedback = {
                                "verification": "verified"
                                if action["correct"]
                                else "not_verified"
                            }
                        else:
                            raise ValueError("Tool unavailable in this condition.")
                        action.update(
                            action={"action": kind, **args},
                            outcome="verified_answer"
                            if action["correct"]
                            else "answer_not_verified"
                            if kind == "answer"
                            else "evidence_progress",
                        )
                    except Exception as error:
                        feedback = {"error": str(error)[:2048]}
                        action["outcome"] = "action_failure"
                    action["feedback"] = feedback
                    history.append_result(call["call_id"], feedback)
                if calls:
                    a["outcome"] = (
                        "verified_answer"
                        if a["correct"]
                        else "output_budget_exhausted"
                        if outcome == "output_budget_exhausted"
                        else "action_failure"
                        if any(
                            t["outcome"] == "action_failure" for t in a["toolActions"]
                        )
                        else "answer_not_verified"
                        if any(
                            t["outcome"] == "answer_not_verified"
                            for t in a["toolActions"]
                        )
                        else "evidence_progress"
                    )
                a["schemeSeconds"] = time.monotonic() - started
                record["effort"] = until_verified(record["attempts"])
                save()
                report_text(
                    "CHAIN-ROUND",
                    case["name"],
                    rep,
                    arm,
                    turn,
                    a["outcome"],
                    flush=True,
                )
                if a["correct"]:
                    break
            record["effort"] = until_verified(record["attempts"])
            save()
    return record
