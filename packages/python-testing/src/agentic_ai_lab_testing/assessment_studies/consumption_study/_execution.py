# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the consumption study study."""

from functools import partial

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib, copy, io, json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..model_study import provider
from ..movie_study import provider_key
from ._plan import _build_plan
from ._projection import parse, proposed
from ._workload import corpus


from ._request import _invoke_study_turn


from ._admission import _assess_consumption_answer, _append_repair_feedback


def run(library, output, live, index=None):
    output.mkdir(parents=True, exist_ok=False)
    cases = corpus()
    cases = cases if index is None else [cases[index]]
    plan = _build_plan(cases, library)
    (output / "plan.json").write_text(json.dumps(plan, indent=2))
    engine = ReasoningRuntime()
    records = []
    audit = []
    key = provider_key() if live else None

    invoke = partial(_invoke_study_turn, key, audit, output)

    try:
        for case in cases:
            with EvidenceChain(engine, case["sources"]) as preflight:
                for p, g in zip(case["programs"], case["gold"]):
                    assert (
                        sorted(
                            r[0]
                            for r in preflight.query(p)["result"]["relations"]["answer"]
                        )
                        == g
                    )
            if not live:
                continue
            prompt = (
                case["schema"]
                + "\nInterpret the goal as one closed relational rule with head answer(j). Base rules below define balanced paths with matching labels, concatenation and scoped denied edges. Do not change base rules.\n"
                + case["goals"][0]
                + "\nGive the rule AND compute the complete answer set. Explanations/Markdown are allowed; finish with a JSON object containing rule (head/body atoms using var terms and not for negation) and answer (job strings). No external tool is available for this initial response.\n"
                + json.dumps(case["base"], separators=(",", ":"))
            )
            initial, initial_terminal = invoke(
                ResponseHistory(prompt), output / (case["case"] + "-shared"), "initial"
            )
            for arm in (
                ["text-evidence", "executable-evidence"]
                if case["seed"] % 2
                else ["executable-evidence", "text-evidence"]
            ):
                folder = output / (case["case"] + "-" + arm)
                folder.mkdir()
                history = ResponseHistory(prompt)
                calls = []
                round = 0
                all_correct = True
                fatal = False
                with Trajectory(
                    engine, case["case"], identity(case["sources"])
                ) as trajectory:
                    with EvidenceChain(
                        engine, case["sources"], trajectory=trajectory
                    ) as chain:
                        base = chain.query(case["base"])
                        reference = base["resultReference"]
                        # Project via a result whose query is not the intermediate.
                        packet = chain.query(case["programs"][0])
                        facts = chain.intermediates(
                            packet["resultReference"], ["balanced"]
                        )
                        for stage in range(3):
                            if stage:
                                history.append_feedback(
                                    {
                                        "goal": case["goals"][stage],
                                        "schema": case["schema"],
                                        "instruction": "Produce only the closed query rule; Scheme executes admitted intent."
                                        if arm == "executable-evidence"
                                        else "Produce the query rule AND the complete manually computed answer set.",
                                        "verifiedIntermediates": facts
                                        if arm == "text-evidence"
                                        else {
                                            "schema": facts["schema"],
                                            "columns": facts["columns"],
                                            "sourceIdentity": facts["sourceIdentity"],
                                            "available": ["balanced"],
                                        },
                                    }
                                )
                            passed = False
                            for attempt in range(1, 4):
                                round += 1
                                obs, terminal = (
                                    (
                                        copy.deepcopy(initial),
                                        copy.deepcopy(initial_terminal),
                                    )
                                    if stage == 0 and attempt == 1
                                    else invoke(
                                        history, folder, f"{stage + 1}-{attempt}"
                                    )
                                )
                                trajectory.model_call(
                                    obs["callId"], round, obs["usage"]
                                )
                                (
                                    completed,
                                    passed,
                                    kind,
                                    admission,
                                    actual,
                                    execution,
                                ) = _assess_consumption_answer(
                                    obs,
                                    case,
                                    stage,
                                    chain,
                                    arm,
                                    round,
                                    attempt,
                                    engine,
                                    reference,
                                )
                                calls.append(obs)
                                report_text(
                                    "RESULT",
                                    case["case"],
                                    arm,
                                    stage + 1,
                                    attempt,
                                    passed,
                                    kind,
                                    flush=True,
                                )
                                if obs["error"]:
                                    fatal = True
                                    break
                                trajectory.verify(
                                    passed,
                                    "independent-relational-oracle-and-intent.v3",
                                    round=round,
                                    scope="task"
                                    if passed and stage == 2
                                    else "subgoal",
                                    candidate=actual,
                                    consumption_reference=obs["consumedReference"],
                                )
                                if completed:
                                    history.append_response(terminal)
                                if passed:
                                    if arm == "executable-evidence":
                                        reference = execution["resultReference"]
                                    break
                                _append_repair_feedback(
                                    history, case, stage, admission, actual, arm, facts
                                )
                            if not passed:
                                all_correct = False
                                break
                        snapshot = trajectory.close(
                            "all-three-goals-correct"
                            if all_correct
                            else "provider-error"
                            if fatal
                            else "attempt-budget"
                        )
                        records.append(
                            {
                                "case": case["case"],
                                "arm": arm,
                                "verifiedAll": all_correct,
                                "calls": calls,
                                "trajectory": snapshot,
                            }
                        )
                        (output / "records.json").write_text(
                            json.dumps(records, indent=2)
                        )
        (output / "result.json").write_text(
            json.dumps(
                {
                    "records": records,
                    "preparedCases": len(cases),
                    "oracleAgreements": len(cases) * 3,
                    "actualCalls": len(audit),
                },
                indent=2,
            )
        )
        report_text("DONE", len(records), len(audit), flush=True)
    finally:
        engine.close()
