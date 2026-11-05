# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Episode for the iterative tool inference study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import json
import time
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from .. import iterative_inference_study as loop
from .. import inference_reuse_study as study
from .. import complex_inference_workload as workload
from ..inference_effort import until_verified
from ..movie_study import provider_key
from ..model_study import provider, response_outcome

_ENGINE = None
from ._tools import tool_definitions


from ._instruction import _episode_instruction


from ._request import _episode_request


def run_episode(plan, plan_dir, output, case, rep, arm):
    global _ENGINE
    directory = output / f"{case['name']}-rep-{rep}-{arm}"
    directory.mkdir(exist_ok=False)
    (directory / "paid-claim.json").open("x").close()
    with (directory / "progress.txt").open("w") as log, contextlib.redirect_stdout(log):
        key = provider_key()
        assisted = arm == "scheme-evidence"
        started = time.monotonic()
        if _ENGINE is None:
            _ENGINE = ReasoningRuntime(plan_dir / plan["library"])
        base = study.program(case["source"], {"relations": [], "rules": []})
        history = ResponseHistory(
            json.dumps(
                {"question": case["question"], "schema": study.SCHEMA}, sort_keys=True
            )
        )
        episode = {
            "case": case["name"],
            "repetition": rep,
            "arm": arm,
            "attempts": [],
            "evidenceJournal": [],
            "protocol": "tool-mediated complete reasoning history",
        }

        def save():
            (directory / "episode.json").write_text(
                json.dumps(episode, indent=2) + "\n"
            )

        instruction = _episode_instruction(assisted)
        with EvidenceStore(
            _ENGINE, [r for r in base["relations"] if r["source"]]
        ) as evidence:
            episode["setupSeconds"] = time.monotonic() - started
            observed = False
            save()
            for turn in range(1, plan["maxTurns"] + 1):
                request = _episode_request(plan, instruction, history, assisted)
                (directory / f"{turn}.request.json").write_text(
                    json.dumps(request, indent=2) + "\n"
                )
                report_text("TOOL-THINKING", case["name"], rep, arm, turn, flush=True)
                raw, meta = provider(request, key, directory / f"{turn}.response.json")
                (directory / f"{turn}.raw.txt").write_text(raw)
                terminal = meta.get("terminal") or {}
                outcome = response_outcome(meta)
                attempt = {
                    "turn": turn,
                    "providerCalls": 1,
                    "correct": False,
                    "usage": terminal.get("usage"),
                    "providerSeconds": meta["providerSeconds"],
                    "providerOutcome": outcome,
                    "requestSha256": study.identity(request),
                    "priorReasoningItems": history.reasoning_items,
                    "sourceIdentity": evidence.source_identity,
                    "toolActions": [],
                }
                episode["attempts"].append(attempt)
                save()
                if not attempt["usage"] or meta.get("error"):
                    raise RuntimeError("provider failure; partial trajectory preserved")
                if outcome != "completed_ungraded":
                    attempt["outcome"] = outcome
                    break
                calls = history.append_response(terminal)
                if not calls:
                    # Thinking mode permits auto tool choice. Final messages are
                    # graded independently; malformed prose gets typed feedback.
                    try:
                        value = json.loads(raw)
                        if isinstance(value, dict):
                            value = value["answer"]
                        if not observed:
                            raise ValueError(
                                "acquire facts or checked evidence before answering"
                            )
                        attempt["correct"] = (
                            isinstance(value, list)
                            and all(isinstance(a, str) for a in value)
                            and sorted([[a] for a in value])
                            == workload.expected(case, case["source"])
                        )
                        attempt["action"] = {"action": "answer", "answer": value}
                        feedback = {
                            "verification": "verified"
                            if attempt["correct"]
                            else "not_verified"
                        }
                        attempt["outcome"] = (
                            "verified_answer"
                            if attempt["correct"]
                            else "answer_not_verified"
                        )
                    except Exception as error:
                        feedback = {
                            "error": str(error)[:2048],
                            "guidance": "Use scan_facts, check_evidence if available, or submit_answer. Return actor identifiers, not prose.",
                        }
                        attempt["outcome"] = "action_failure"
                    attempt["feedback"] = feedback
                    history.append_feedback(feedback)
                    episode["effort"] = until_verified(episode["attempts"])
                    save()
                    if attempt["correct"]:
                        break
                    continue
                started = time.monotonic()
                for call in calls:
                    record = {"name": call["name"], "callId": call["call_id"]}
                    attempt["toolActions"].append(record)
                    try:
                        args = json.loads(call["arguments"])
                        record["arguments"] = args
                        if call["name"] == "scan_facts":
                            feedback = evidence.scan(args["relations"])
                            observed = True
                            kind = "scan"
                            action = {"action": kind, **args}
                        elif call["name"] == "check_evidence" and assisted:
                            kind = "query"
                            action = {"action": kind, **args}
                            feedback = evidence.query(
                                loop.evidence_program(case["source"], action)
                            )
                            observed = True
                            episode["evidenceJournal"].append(feedback)
                        elif call["name"] == "submit_answer":
                            kind = "answer"
                            action = {"action": kind, **args}
                            if not observed:
                                raise ValueError(
                                    "acquire facts or checked evidence before answering"
                                )
                            value = args["answer"]
                            correct = (
                                isinstance(value, list)
                                and all(isinstance(a, str) for a in value)
                                and sorted([[a] for a in value])
                                == workload.expected(case, case["source"])
                            )
                            attempt["correct"] |= correct
                            feedback = {
                                "verification": "verified"
                                if correct
                                else "not_verified"
                            }
                        else:
                            raise ValueError("tool unavailable in this arm")
                        record.update(
                            action=action,
                            correct=correct if kind == "answer" else False,
                            outcome="verified_answer"
                            if kind == "answer" and attempt["correct"]
                            else "answer_not_verified"
                            if kind == "answer"
                            else "evidence_progress",
                        )
                    except Exception as error:
                        feedback = {"error": str(error)[:2048]}
                        record["outcome"] = "action_failure"
                    record["feedback"] = feedback
                    history.append_result(call["call_id"], feedback)
                # One response may contain several calls; charge its usage once.
                attempt["outcome"] = (
                    "verified_answer"
                    if attempt["correct"]
                    else "action_failure"
                    if any(
                        x["outcome"] == "action_failure" for x in attempt["toolActions"]
                    )
                    else "answer_not_verified"
                    if any(
                        x["outcome"] == "answer_not_verified"
                        for x in attempt["toolActions"]
                    )
                    else "evidence_progress"
                )
                if len(attempt["toolActions"]) == 1:
                    attempt["action"] = attempt["toolActions"][0].get("action", {})
                    attempt["feedback"] = attempt["toolActions"][0]["feedback"]
                attempt["schemeSeconds"] = time.monotonic() - started
                episode["effort"] = until_verified(episode["attempts"])
                save()
                report_text(
                    "TOOL-FEEDBACK",
                    attempt["outcome"],
                    "retainedReasoningItems",
                    history.reasoning_items,
                    flush=True,
                )
                if attempt["correct"]:
                    break
        episode["effort"] = until_verified(episode["attempts"])
        episode["evidenceAdoption"] = bool(episode["evidenceJournal"])
        save()
    return episode
