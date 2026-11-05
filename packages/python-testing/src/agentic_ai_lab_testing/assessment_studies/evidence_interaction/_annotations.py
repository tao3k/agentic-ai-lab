# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Annotations for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import re
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import canonical, save, sha
from ._phase import charge
from ._sources import verify
from ._transport import EvidenceEngine
from ._workload import independent_atom


from ._annotation_validation import anchor, validate_episode, _admit_annotation_episodes


def _request_annotation(plan, task, text, out, result):
    """Own the request annotation phase and retain its evidence checks."""
    request = {
        "model": plan["model"],
        "input": [
            {
                "role": "user",
                "content": canonical(
                    {
                        "edges": task["edges"],
                        "needs": task["needs"],
                        "reasoningText": text,
                    }
                ),
            }
        ],
        "instructions": plan["annotationRubric"],
        "tools": [plan["annotationTool"]],
        "tool_choice": {"type": "function", "name": "annotate"},
        "reasoning": {"effort": "none"},
        "max_output_tokens": plan["annotationOutputCap"],
        "stream": True,
        "store": False,
    }
    save(out / "request.json", request)
    _, meta = provider(request, provider_key(), out / "response.json")
    term = meta.get("terminal") or {}
    result["usage"] = term.get("usage")
    result["providerSeconds"] = meta.get("providerSeconds")
    return meta, term


def annotate(run, plan):
    verify(run, plan)
    dest = run / "annotations"
    dest.mkdir(exist_ok=False)
    phases = []
    for row in json.loads((run / "ledger.json").read_text())["phases"]:
        folder = run / "paid" / f"{row['case']}-{row['arm']}"
        task = next(
            t for t in plan["tasks"] if t["id"] == f"evidence-search-{row['case']}"
        )
        measurement = {
            "case": row["case"],
            "arm": row["arm"],
            "calls": [],
            "accepted": [],
            "rejected": [],
            "grossTokens": 0,
            "failure": None,
        }
        memo = {}
        with EvidenceEngine(run) as native, EvidenceEngine(run, True) as judge:
            native.call(op="init", case=row["case"], arm="baseline")
            for call in row["calls"]:
                text = (folder / f"{call['turn']}.thinking.txt").read_text()
                assert sha(text.encode()) == call["thinkingSha256"]
                blind = sha((task["id"] + "\n" + text).encode())[:24]
                out = dest / f"{blind}-{len(phases)}-{call['turn']}"
                out.mkdir(exist_ok=False)
                result = {
                    "turn": call["turn"],
                    "atGrossTokens": call.get("atGrossTokens"),
                    "textSha256": sha(text.encode()),
                    "blindId": out.name,
                    "failure": None,
                    "accepted": [],
                    "rejected": [],
                    "grossTokens": 0,
                }
                if not text:
                    result["failure"] = "no_returned_reasoning"
                else:
                    meta, term = _request_annotation(plan, task, text, out, result)
                    try:
                        result["grossTokens"] = charge(result["usage"])
                        measurement["grossTokens"] += result["grossTokens"]
                        if meta.get("error") or term.get("status") != "completed":
                            raise ValueError("annotation_incomplete_or_error")
                        actions = [
                            x
                            for x in term.get("output", [])
                            if x.get("type") == "function_call"
                            and x.get("name") == "annotate"
                        ]
                        if len(actions) != 1:
                            raise ValueError("expected_one_annotation_action")
                        raw = json.loads(actions[0]["arguments"])["episodes"]
                        result["rawEpisodes"] = raw
                        _admit_annotation_episodes(
                            raw,
                            text,
                            task,
                            native,
                            judge,
                            memo,
                            measurement,
                            call,
                            result,
                        )
                    except (ValueError, KeyError, TypeError) as error:
                        result["failure"] = str(error)
                if result["failure"]:
                    measurement["failure"] = "one_or_more_missing_measurements"
                save(out / "receipt.json", result)
                measurement["calls"].append(result)
                save(dest / f"phase-{row['case']}-{row['arm']}.json", measurement)
                report_text(
                    "\nANNOTATION",
                    row["case"],
                    row["arm"],
                    call["turn"],
                    "labels",
                    len(result["accepted"]),
                    "rejected",
                    len(result["rejected"]),
                    "failure",
                    result["failure"],
                    flush=True,
                )
            save(
                dest / f"native-{row['case']}-{row['arm']}.json",
                {"scenario": native.trace, "independentAtomJudge": judge.trace},
            )
        phases.append(measurement)
        save(
            run / "annotation-ledger.json",
            {"planSha256": sha((run / "plan.json").read_bytes()), "phases": phases},
        )
    verify(run, plan)
    report_text("ANNOTATION_COMPLETE", flush=True)
