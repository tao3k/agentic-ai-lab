# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the trajectory study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import contextlib
import io
import json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..movie_study import provider_key
from ..model_study import provider
from ._plan import _build_plan
from ._projection import extract
from ._workload import task


from ._repeat_qualification import _qualify_repeat_and_withdrawal


def run(library, output, live):
    output.mkdir(parents=True, exist_ok=False)
    cases = [
        task(family, 2026101300 + family * 17 + repeat)
        for repeat in range(2)
        for family in range(4)
    ]
    plan = _build_plan(cases, library)
    (output / "plan.json").write_text(json.dumps(plan, indent=2))
    engine = ReasoningRuntime()
    records = []
    key = provider_key() if live else None
    try:
        for index, case in enumerate(cases):
            # Independently derived closure must agree with actual Scheme execution.
            with EvidenceChain(engine, case["sources"]) as preflight:
                feedback = preflight.query(case["program"])
                native = sorted(x[0] for x in feedback["result"]["relations"]["answer"])
                if native != case["gold"]:
                    raise AssertionError(f"oracle mismatch: {case['case']}")
                dag = evidence_graph(case["program"])
                positions = {n["id"]: i for i, n in enumerate(dag["nodes"])}
                assert all(
                    positions[e["from"]] < positions[e["to"]] for e in dag["edges"]
                )
                (output / f"{case['case']}-dag.json").write_text(
                    json.dumps(dag, indent=2)
                )
            if not live:
                continue
            arms = plan["arms"] if index % 2 == 0 else list(reversed(plan["arms"]))
            for arm in arms:
                folder = output / f"{case['case']}-{arm}"
                folder.mkdir()
                trajectory = Trajectory(engine, case["case"], identity(case["sources"]))
                chain = (
                    EvidenceChain(engine, case["sources"], trajectory=trajectory)
                    if arm == "native-evidence"
                    else None
                )
                history = ResponseHistory(case["question"])
                calls = []
                reference = None
                for attempt in range(1, 4):
                    request = {
                        "model": plan["model"],
                        "input": history.input(),
                        "reasoning": {"effort": plan["effort"]},
                        "max_output_tokens": plan["maxOutputTokens"],
                        "stream": True,
                        "store": False,
                    }
                    (folder / f"{attempt}-request.json").write_text(
                        json.dumps(request, indent=2)
                    )
                    report_text(
                        f"CALL {case['case']} {arm} attempt={attempt}", flush=True
                    )
                    with contextlib.redirect_stdout(io.StringIO()):
                        raw, meta = provider(
                            request, key, folder / f"{attempt}-provider.json"
                        )
                    (folder / f"{attempt}-answer.txt").write_text(raw)
                    terminal = meta.get("terminal") or {}
                    usage = terminal.get("usage")
                    trajectory.model_call(
                        f"{case['case']}:{arm}:{attempt}", attempt, usage
                    )
                    prediction = extract(raw)
                    correct = prediction == case["gold"]
                    trajectory.verify(
                        correct,
                        "independent-fixed-point-oracle.v1",
                        round=attempt,
                        candidate=prediction,
                    )
                    calls.append(
                        {
                            "attempt": attempt,
                            "correct": correct,
                            "prediction": prediction,
                            "usage": usage,
                            "error": meta.get("error"),
                            "status": terminal.get("status"),
                            "providerSeconds": meta["providerSeconds"],
                        }
                    )
                    report_text(
                        f"RESULT correct={correct} usagePresent={bool(usage)} status={terminal.get('status')}",
                        flush=True,
                    )
                    if meta.get("error") or terminal.get("status") in (
                        "failed",
                        "incomplete",
                    ):
                        break
                    if correct:
                        break
                    history.append_response(terminal)
                    if chain:
                        feedback = chain.query(case["program"])
                        reference = feedback["resultReference"]
                        history.append_feedback(
                            {
                                "instruction": "Reflect on the previous error. Continue using these source-bound native facts.",
                                "evidence": feedback,
                            }
                        )
                    else:
                        history.append_feedback(
                            {
                                "correct": False,
                                "instruction": "Reflect on the previous error and recompute the complete answer relation, including all joins and scoped negative conditions.",
                            }
                        )
                primary = trajectory.snapshot()
                repeated, invalidation = _qualify_repeat_and_withdrawal(
                    chain,
                    primary,
                    reference,
                    trajectory,
                    case,
                    plan,
                    folder,
                    arm,
                    key,
                    calls,
                )
                closed = trajectory.close(
                    "first-correct"
                    if primary["verified"]
                    else "attempt-budget-or-provider-error"
                )
                if chain:
                    chain.close()
                record = {
                    "case": case["case"],
                    "arm": arm,
                    "calls": calls,
                    "primary": primary,
                    "trajectory": closed,
                    "repeat": repeated,
                    "invalidation": invalidation,
                }
                records.append(record)
                (output / "records.json").write_text(json.dumps(records, indent=2))
                if calls and calls[-1]["error"]:
                    # A transport rejection is not a model reasoning failure: stop
                    # further paid requests, preserve this censored trajectory.
                    raise RuntimeError(
                        "Provider transport rejected; see recorded provider response, not output schema."
                    )
        result = {
            "preparedCases": len(cases),
            "records": records,
            "offlineOracleAgreement": len(cases),
        }
        (output / "result.json").write_text(json.dumps(result, indent=2))
        report_text(f"DONE cases={len(cases)} trajectories={len(records)}", flush=True)
    finally:
        engine.close()
