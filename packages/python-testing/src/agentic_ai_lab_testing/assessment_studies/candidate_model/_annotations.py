# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Annotations for the candidate model study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import digest, save
from ._reuse_snapshot import reuse_verify
from ._tasks import study_annotations
from ._transport import AtomicJudge, Consumer, EpisodeConsumer


def reuse_annotate(run):
    plan = reuse_verify(run)
    old = study_annotations()
    rows = json.loads((run / "reuse-ledger.json").read_text())
    measurements = []
    assert not (run / "reuse-annotation-ledger.json").exists()
    for row in rows:
        t = plan["tasks"][row["case"]]
        folder = run / "annotations" / f"{row['case']}-{row['arm']}"
        folder.mkdir(parents=True)
        native = Consumer(folder)
        accepted = []
        results = []
        try:
            native.call(
                op="reuse-init", identity=t["id"], edges=t["edges"], needs=t["needs"]
            )
            for call in row["calls"]:
                source = (
                    run
                    / "calls"
                    / f"{row['case']}-{row['arm']}"
                    / str(call["turn"])
                    / "thinking.txt"
                )
                out = folder / str(call["turn"])
                out.mkdir()
                result = {
                    "turn": call["turn"],
                    "failure": None,
                    "accepted": [],
                    "rejected": [],
                    "grossTokens": None,
                }
                results.append(result)
                try:
                    text = source.read_text()
                    assert digest(source) == call["thinkingSha256"]
                    assert text, "missing_thinking"
                    req = {
                        "model": plan["model"],
                        "input": [
                            {
                                "role": "user",
                                "content": json.dumps(
                                    {
                                        "edges": t["edges"],
                                        "needs": t["needs"],
                                        "reasoningText": text,
                                    }
                                ),
                            }
                        ],
                        "instructions": plan["annotationRubric"],
                        "tools": [plan["annotationTool"]],
                        "tool_choice": {"type": "function", "name": "annotate"},
                        "reasoning": {"effort": "none"},
                        "max_output_tokens": plan["annotationCap"],
                        "stream": True,
                        "store": False,
                    }
                    save(out / "request.json", req)
                    _, meta = provider(req, provider_key(), out / "response.json")
                    term = meta.get("terminal") or {}
                    u = term.get("usage")
                    result["usage"] = u
                    result["grossTokens"] = old.charge(u)
                    assert (
                        not meta.get("error") and term.get("status") == "completed"
                    ), "annotation_incomplete"
                    actions = [
                        x
                        for x in term.get("output", [])
                        if x.get("type") == "function_call"
                    ]
                    assert len(actions) == 1 and actions[0]["name"] == "annotate", (
                        "annotation_action"
                    )
                    raw = json.loads(actions[0]["arguments"])["episodes"]
                    result["raw"] = raw
                    for item in raw:
                        try:
                            e = old.validate_episode(
                                text,
                                item,
                                t,
                                EpisodeConsumer(native),
                                AtomicJudge(),
                                {},
                            )
                            e["turn"] = call["turn"]
                            e["atGrossTokens"] = call.get("atGrossTokens")
                            e["repeatFact"] = False
                            e["definiteRepeat"] = False
                            if result["accepted"]:
                                assert (
                                    e["span"][0] >= result["accepted"][-1]["span"][1]
                                ), "overlapping_or_unsorted_quotes"
                            if e["qualifiedPositiveDerivation"]:
                                prior = [
                                    p
                                    for p in accepted
                                    if p["qualifiedPositiveDerivation"]
                                    and p["atom"] == e["atom"]
                                ]
                                e["repeatFact"] = bool(prior)
                                e["definiteRepeat"] = any(
                                    p["claimKey"] == e["claimKey"] for p in prior
                                )
                            result["accepted"].append(e)
                            accepted.append(e)
                        except Exception as error:
                            result["rejected"].append(
                                {"item": item, "failure": str(error)}
                            )
                except Exception as error:
                    result["failure"] = str(error)
                save(out / "receipt.json", result)
                report_text(
                    "REUSE_LABELS",
                    row["case"],
                    row["arm"],
                    call["turn"],
                    len(result["accepted"]),
                    result["failure"],
                    flush=True,
                )
        finally:
            shutdown = native.close()
        measurements.append(
            {
                "case": row["case"],
                "arm": row["arm"],
                "calls": results,
                "shutdown": shutdown,
            }
        )
        save(run / "reuse-annotation-ledger.json", measurements)
    reuse_verify(run)
