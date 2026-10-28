# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the correction study study."""

from functools import partial

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib, copy, io, json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from ..trajectory_study import extract
from ..model_study import provider
from ..movie_study import provider_key
from ._cases import corpus
from ._plan import _build_plan


from ._request import _invoke_study_turn


def run(library, output, live, cases=None):
    output.mkdir(parents=True, exist_ok=False)
    cases = corpus() if cases is None else cases
    plan = _build_plan(cases, library)
    (output / "plan.json").write_text(json.dumps(plan, indent=2))
    engine = ReasoningRuntime()
    records = []
    calls_audit = []
    key = provider_key() if live else None

    invoke = partial(_invoke_study_turn, plan, key, calls_audit, output)

    try:
        for case_index, case in enumerate(cases):
            with EvidenceChain(engine, case["sources"]) as preflight:
                for program, gold in zip(
                    [case["program"], case["secondProgram"]], case["gold"]
                ):
                    feedback = preflight.query(program)
                    assert (
                        sorted(r[0] for r in feedback["result"]["relations"]["answer"])
                        == gold
                    )
                dag = evidence_graph(case["program"])
                (output / f"{case['case']}-dag.json").write_text(
                    json.dumps(dag, indent=2)
                )
            if not live:
                continue
            common = output / (case["case"] + "-shared")
            common.mkdir()
            initial_history = ResponseHistory(case["question"])
            initial, initial_terminal = invoke(initial_history, common, "initial")
            arms = ["reflection", "checked-intermediates"]
            arms = arms if case["seed"] % 2 == 0 else arms[::-1]
            stop = False
            for arm in arms:
                folder = output / (case["case"] + "-" + arm)
                folder.mkdir()
                history = ResponseHistory(case["question"])
                trajectory = Trajectory(engine, case["case"], identity(case["sources"]))
                chain = (
                    EvidenceChain(engine, case["sources"], trajectory=trajectory)
                    if arm == "checked-intermediates"
                    else None
                )
                calls = []
                packets = []
                round = 0
                complete = True
                fatal = False
                reused = []
                try:
                    for stage in [0, 1]:
                        program = [case["program"], case["secondProgram"]][stage]
                        gold = case["gold"][stage]
                        if stage == 1:
                            history.append_feedback(
                                {
                                    "instruction": "SECOND query: sources and derived component rules are unchanged. Compute the complete new answer relation.",
                                    "rules": program["rules"],
                                    "queries": ["answer"],
                                }
                            )
                        passed = False
                        for attempt in range(1, 4):
                            round += 1
                            if stage == 0 and attempt == 1:
                                obs, terminal = (
                                    copy.deepcopy(initial),
                                    copy.deepcopy(initial_terminal),
                                )
                            else:
                                obs, terminal = invoke(
                                    history, folder, f"{stage + 1}-{attempt}"
                                )
                            completed = (
                                obs["status"] == "completed" and obs["error"] is None
                            )
                            budget = (
                                obs["status"] == "incomplete" and obs["error"] is None
                            )
                            passed = completed and obs["prediction"] == gold
                            obs.update(
                                stage=stage + 1,
                                attempt=attempt,
                                round=round,
                                correct=passed,
                                failureKind=None
                                if passed
                                else (
                                    "budget"
                                    if budget
                                    else "transport"
                                    if not completed
                                    else "format"
                                    if obs["prediction"] is None
                                    else "semantic"
                                ),
                            )
                            obs["evidenceAlreadyExposed"] = bool(
                                chain and not (stage == 0 and attempt == 1)
                            )
                            calls.append(obs)
                            trajectory.model_call(obs["callId"], round, obs["usage"])
                            if not completed and not budget:
                                fatal = True
                                complete = False
                                break
                            trajectory.verify(
                                passed,
                                "independent-relational-oracle.v2",
                                round=round,
                                candidate=obs["prediction"],
                                scope="task" if stage == 1 and passed else "subgoal",
                            )
                            # Incomplete output is archived, but cannot be replayed as a completed response.
                            if completed:
                                history.append_response(terminal)
                            report_text(
                                f"RESULT {case['case']} {arm} stage={stage + 1} attempt={attempt} correct={passed}",
                                flush=True,
                            )
                            if chain:
                                feedback = chain.query(program)
                                reused = feedback["reusedComponents"]
                                packet = chain.intermediates(
                                    feedback["resultReference"], case["intermediates"]
                                )
                                assert "answer" not in packet["facts"]
                                packets.append({"round": round, "packet": packet})
                            if passed:
                                if stage == 0 and chain:
                                    history.append_feedback(
                                        {
                                            "verifiedIntermediates": packet,
                                            "instruction": "These completed relations are valid for subsequent queries on these same sources.",
                                        }
                                    )
                                break
                            correction = {
                                "correct": False,
                                "instruction": "Reflect on the incorrect complete answer and repair it. Re-evaluate scoped negation and all recursive joins; do not stop at a bounded path depth.",
                            }
                            if chain:
                                correction["verifiedIntermediates"] = packet
                            history.append_feedback(correction)
                        if not passed:
                            complete = False
                            break
                    snapshot = trajectory.close(
                        "both-correct"
                        if complete
                        else "provider-error"
                        if fatal
                        else "attempt-budget"
                    )
                    record = {
                        "case": case["case"],
                        "arm": arm,
                        "verifiedBoth": complete,
                        "calls": calls,
                        "packets": packets,
                        "nativeReusedComponents": reused,
                        "trajectory": snapshot,
                    }
                    records.append(record)
                    (output / "records.json").write_text(json.dumps(records, indent=2))
                finally:
                    trajectory.close("exception")
                    if chain:
                        chain.close()
                if fatal:
                    stop = True
                    break
            if stop:
                break
        result = {
            "preparedCases": len(cases),
            "records": records,
            "actualProviderRequests": len(calls_audit),
            "offlineQueryAgreement": len(cases) * 2 if not live or not stop else None,
            "unstartedConditionTasks": len(cases) * 2 - len(records),
        }
        (output / "result.json").write_text(json.dumps(result, indent=2))
        report_text(
            f"DONE tasks={len(records)} actualCalls={len(calls_audit)}", flush=True
        )
    finally:
        engine.close()
