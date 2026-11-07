# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared labels for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json
from ..model_study import provider
from ..movie_study import provider_key
from ._branch_labels import branch_label
from ._shared_check import shared_check
from ._shared_validation import shared_validate_label


def shared_label(directory, output):
    if shared_check(directory).get("annotationMode") == "literal-partition":
        return branch_label(directory, output)
    plan = shared_check(directory)
    rows = json.loads((output / "ledger.json").read_text())
    all_labels = []
    dest = output / "annotations"
    dest.mkdir(exist_ok=False)
    for row in rows:
        task = plan["tasks"][row["case"]]
        for pass_id in range(plan["annotationPasses"]):
            prior = []
            result = {
                "case": row["case"],
                "arm": row["arm"],
                "pass": pass_id,
                "calls": [],
            }
            all_labels.append(result)
            for call in row["calls"]:
                folder = (
                    output
                    / "calls"
                    / f"{row['case']}-{row['arm']}"
                    / (
                        f"{call['turn']}-{call['step']}"
                        if plan.get("experiment") == "sibling-search"
                        else str(call["turn"])
                    )
                )
                source = folder / "thinking.txt"
                blind = hashlib.sha256(
                    (
                        task["id"]
                        + str(pass_id)
                        + str(call["turn"])
                        + str(call.get("step", 0))
                    ).encode()
                ).hexdigest()[:18]
                out = dest / blind / f"{row['arm']}"
                out.mkdir(parents=True)
                record = {
                    "turn": call["turn"],
                    "step": call.get("step", 0),
                    "modelCalled": False,
                    "grossTokens": None,
                    "failure": None,
                    "accepted": [],
                    "rejected": [],
                }
                result["calls"].append(record)
                try:
                    text = source.read_text()
                    assert (
                        hashlib.sha256(text.encode()).hexdigest()
                        == call["thinkingSha256"]
                    )
                    assert text, "no visible reasoning"
                    req = {
                        "model": plan["model"],
                        "input": [
                            {
                                "role": "user",
                                "content": json.dumps(
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
                    (out / "request.json").write_text(json.dumps(req, indent=2) + "\n")
                    record["modelCalled"] = True
                    _, meta = provider(req, provider_key(), out / "response.json")
                    term = meta.get("terminal") or {}
                    u = term.get("usage")
                    if isinstance(u, dict) and all(
                        type(u.get(k)) is int and u[k] >= 0
                        for k in ("input_tokens", "output_tokens")
                    ):
                        record["grossTokens"] = u["input_tokens"] + u["output_tokens"]
                    assert (
                        not meta.get("error") and term.get("status") == "completed"
                    ), "annotation provider failure"
                    calls = [c for c in term["output"] if c["type"] == "function_call"]
                    assert len(calls) == 1 and calls[0]["name"] == "annotate"
                    raw = json.loads(calls[0]["arguments"])
                    assert set(raw) == {"episodes"} and isinstance(
                        raw["episodes"], list
                    )
                    record["raw"] = raw["episodes"]
                    supplied = (
                        call["suppliedAtoms"]
                        if plan.get("experiment") == "sibling-search"
                        else [
                            f["atom"]
                            for f in (call.get("nativePacket") or {}).get("facts", [])
                            if f["status"] == "verified"
                        ]
                    )
                    for item in raw["episodes"]:
                        try:
                            label = shared_validate_label(
                                text, item, task, supplied, prior
                            )
                            assert (
                                not record["accepted"]
                                or label["span"][0] >= record["accepted"][-1]["span"][1]
                            ), "overlapping labels"
                            label.update(
                                turn=call["turn"],
                                step=call.get("step", 0),
                                afterFirstQuestion=call["turn"] > 0,
                            )
                            old = [
                                p
                                for p in prior
                                if p["qualifiedPositive"] and p["atom"] == label["atom"]
                            ]
                            label.update(
                                crossBranchRepeat=any(
                                    p["turn"] != call["turn"] for p in old
                                ),
                                sameBranchRepeat=any(
                                    p["turn"] == call["turn"]
                                    and p.get("step", 0) != call.get("step", 0)
                                    for p in old
                                ),
                                withinResponseRepeat=any(
                                    p["turn"] == call["turn"]
                                    and p.get("step", 0) == call.get("step", 0)
                                    for p in old
                                ),
                            )
                            record["accepted"].append(label)
                            prior.append(label)
                        except Exception as error:
                            record["rejected"].append(
                                {"item": item, "failure": str(error)}
                            )
                except Exception as error:
                    record["failure"] = str(error)
                (out / "receipt.json").write_text(json.dumps(record, indent=2) + "\n")
                (output / "annotation-ledger.json").write_text(
                    json.dumps(all_labels, indent=2) + "\n"
                )
                report_text(
                    "SHARED_LABEL",
                    row["case"],
                    row["arm"],
                    pass_id,
                    call["turn"],
                    len(record["accepted"]),
                    len(record["rejected"]),
                    record["failure"],
                    flush=True,
                )
    shared_check(directory)
