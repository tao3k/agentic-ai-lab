# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Episode for the repository model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import copy
import json
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..evidence_chain_study import loose_json
from ..inference_effort import until_verified
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from ._tools import tool_definitions
from ._workspace import Workspace


def episode(plan, plan_dir, output, case, rep, arm):
    directory = output / f"{case['name']}-rep-{rep}-{arm}"
    directory.mkdir()
    record = {
        "task": case["name"],
        "repetition": rep,
        "arm": arm,
        "attempts": [],
        "status": "running",
        "evidenceJournal": [],
    }

    def save():
        if workspace is not None and workspace.domain:
            record["domainJournal"] = copy.deepcopy(workspace.domain.journal)
        (directory / "episode.json").write_text(json.dumps(record, indent=2) + "\n")

    workspace = None
    try:
        workspace = Workspace(plan_dir, directory, case, arm)
        history = ResponseHistory(
            json.dumps(
                {
                    "question": case["question"],
                    "implementationFiles": case["editable"],
                    "allowedTools": [x["name"] for x in tool_definitions()],
                },
                sort_keys=True,
            )
        )
        instructions = "Repair the complete real repository problem. Reason naturally; no subproblem-first plan is required. Use source reads, original reproductions and executable controls. Only declared implementation files are editable. No network, git history, grader files or runtime introspection are available. Source reads may include checked syntactic support; it is evidence about extracted references, not proof of runtime behavior. Keep code general and preserve existing semantics. Submit the current repair for independent grading; unsuccessful repairs may be revised. Function calls are automatic, not forced. Prose and an unambiguous JSON edit payload are accepted. Do not alter imports or grading infrastructure in this bounded pilot."
        if case.get("domainKind"):
            instructions += " Reproducer observations may also have Scheme-checked domain constraints. Treat them as scoped facts about observed executions. Retained domain context labels the current snapshot; edits invalidate prior-snapshot claims while checker-qualified mathematical contracts remain applicable."
        key = provider_key()
        save()
        with (
            (directory / "progress.log").open("w") as log,
            contextlib.redirect_stdout(log),
        ):
            for turn in range(1, plan["maxTurns"] + 1):
                if (
                    workspace.domain
                    and workspace.arm == "scheme-retained"
                    and workspace.domain.laws
                ):
                    history.append_feedback(
                        {
                            "retainedDomainContext": workspace.domain.summary(),
                            "guidance": "Reuse these checked contracts and current-snapshot observations when reasoning about the complete problem. Prior-snapshot claims are invalidated after edits.",
                        }
                    )
                request = {
                    "model": "deepseek-flash",
                    "input": history.input(),
                    "instructions": instructions,
                    "tools": tool_definitions(),
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
                terminal = meta.get("terminal") or {}
                attempt = {
                    "turn": turn,
                    "providerCalls": 1,
                    "usage": terminal.get("usage"),
                    "correct": False,
                    "providerOutcome": response_outcome(meta),
                    "providerSeconds": meta["providerSeconds"],
                    "actions": [],
                    "sourceIdentity": workspace.source_identity,
                }
                record["attempts"].append(attempt)
                save()
                if meta.get("error") or not attempt["usage"]:
                    attempt["error"] = meta.get("error")
                    record["status"] = "transport_failure"
                    break
                calls = history.append_response(terminal)
                if not calls:
                    try:
                        try:
                            payload = loose_json(raw)
                        except (ValueError, TypeError):
                            payload = None
                        if isinstance(payload, dict) and "edits" in payload:
                            changed = workspace.edit(payload["edits"])
                            attempt["actions"].append(
                                {"name": "implicit_edit", "result": changed}
                            )
                        feedback = workspace.execute(grading=True)
                        if feedback["verified"] and plan.get("verifyCandidatesOnEdit"):
                            workspace.seal_candidate(feedback)
                        attempt["correct"] = feedback["verified"]
                        attempt["actions"].append(
                            {"name": "implicit_submit", "result": feedback}
                        )
                        history.append_feedback(feedback)
                    except Exception as error:
                        attempt["correct"] = False
                        failure = {
                            "error": type(error).__name__ + ": " + str(error)[:1500],
                            "guidance": "Use the available tools to read, repair and submit the current implementation.",
                        }
                        attempt["actions"].append(
                            {"name": "implicit_submit", "result": failure}
                        )
                        history.append_feedback(failure)
                        if failure["error"].startswith(
                            (
                                "RuntimeError: test environment",
                                "TimeoutError: test execution",
                            )
                        ):
                            record["status"] = "harness_failure"
                for call in calls:
                    action = {"name": call["name"], "callId": call["call_id"]}
                    attempt["actions"].append(action)
                    try:
                        if attempt["correct"]:
                            result = {"skipped": "repair already verified"}
                        elif call.get("status") == "incomplete":
                            raise ValueError(
                                "Incomplete tool arguments; continue with a complete call."
                            )
                        else:
                            args = loose_json(call["arguments"])
                            if call["name"] == "read_source":
                                result = workspace.read(
                                    args["path"], args.get("start", 1), args.get("end")
                                )
                            elif call["name"] == "search_source":
                                result = workspace.search(
                                    args["text"], args.get("path")
                                )
                            elif call["name"] == "edit_source":
                                result = workspace.edit(args["edits"])
                                if plan.get("verifyCandidatesOnEdit"):
                                    grade = workspace.execute(grading=True)
                                    attempt.setdefault("candidateChecks", []).append(
                                        grade
                                    )
                                    if grade["verified"]:
                                        result["verifiedCandidate"] = (
                                            workspace.seal_candidate(grade)
                                        )
                                        attempt["correct"] = True
                            elif call["name"] == "run_reproducer":
                                result = workspace.execute(reproducer=True)
                            elif call["name"] == "run_checks":
                                result = workspace.execute()
                            elif call["name"] == "submit_patch":
                                result = workspace.execute(grading=True)
                                attempt["correct"] = result["verified"]
                            else:
                                raise ValueError("unknown tool")
                    except Exception as error:
                        result = {
                            "error": type(error).__name__ + ": " + str(error)[:1500]
                        }
                    action["result"] = result
                    history.append_result(call["call_id"], result)
                    if isinstance(result, dict) and result.get("exitCode") == 65:
                        record["status"] = "harness_failure"
                    if isinstance(result, dict) and result.get("error", "").startswith(
                        (
                            "RuntimeError: test environment",
                            "TimeoutError: test execution",
                        )
                    ):
                        record["status"] = "harness_failure"
                record["evidenceJournal"] = workspace.journal
                save()
                if record["status"] == "harness_failure":
                    break
                if attempt["correct"]:
                    record["status"] = "verified"
                    break
        if record["status"] == "running":
            record["status"] = "censored"
    except Exception as error:
        record["status"] = "harness_failure"
        record["error"] = type(error).__name__ + ": " + str(error)[:1500]
    finally:
        if workspace:
            workspace.close()
        record["effort"] = until_verified(record["attempts"])
        save()
    report_text(
        "REPOSITORY-EPISODE",
        case["name"],
        rep,
        arm,
        record["status"],
        "calls=" + str(len(record["attempts"])),
        flush=True,
    )
    return record
