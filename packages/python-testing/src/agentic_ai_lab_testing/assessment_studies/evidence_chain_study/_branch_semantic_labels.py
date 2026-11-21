# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch semantic labels for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json
from ..model_study import provider
from ..movie_study import provider_key
from ._branch_semantics import (
    branch_semantic_block_admit,
    branch_semantic_blocks,
    branch_semantic_partition,
    branch_semantic_summary,
)
from ._shared_check import shared_check
from ._shared_validation import shared_validate_label


def branch_semantic_label(directory, output):
    """Blind model proposal plus local truth/span admission; never solver feedback.

    Line classifications are proposals, not verified semantics. Atomic inference
    episodes undergo the existing independent directed-truth and stated-premise
    validation. One correlated model pass cannot establish annotation recall.
    """
    plan = shared_check(directory)
    rows = json.loads((output / "ledger.json").read_text())
    ledger = []
    calls = 0
    dest = output / "semantic-annotations"
    dest.mkdir(exist_ok=False)
    for row in rows:
        task = plan["tasks"][row["case"]]
        prior = []
        for c in row["calls"]:
            if c["step"] != 0:
                continue
            folder = (
                output
                / "calls"
                / f"{row['case']}-{row['arm']}"
                / f"{c['turn']}-{c['step']}"
            )
            text = (folder / "thinking.txt").read_text()
            blind = hashlib.sha256(text.encode()).hexdigest()
            out = dest / blind
            out.mkdir(exist_ok=False)
            rec = {
                "case": row["case"],
                "arm": row["arm"],
                "turn": c["turn"],
                "thinkingSha256": blind,
                "modelCalled": False,
                "grossTokens": None,
                "failure": None,
                "accepted": [],
                "rejected": [],
                "lineProposals": [],
                "characters": len(text),
            }
            ledger.append(rec)
            try:
                assert text, "no thinking to annotate"
                assert calls < plan["maxSemanticCalls"], (
                    "semantic call bound; unreviewed trace retained"
                )
                tool = plan["semanticTool"]
                blocks = (
                    branch_semantic_blocks(text, plan["semanticReviewBlockChars"])
                    if plan.get("semanticReviewBlockChars")
                    else None
                )
                reasoning = (
                    {
                        "reasoningBlocks": [
                            {"id": b["id"], "text": b["text"]} for b in blocks
                        ]
                    }
                    if blocks is not None
                    else {"reasoningText": text}
                )
                req = {
                    "model": plan["model"],
                    "input": [
                        {
                            "role": "user",
                            "content": json.dumps(
                                {
                                    "edges": task["edges"],
                                    "needs": task["needs"],
                                    **reasoning,
                                    "earlierConclusions": [
                                        o["conclusion"]
                                        for o in (c.get("entryEvidence") or {}).get(
                                            "observations", []
                                        )
                                    ],
                                },
                                separators=(",", ":"),
                            ),
                        }
                    ],
                    "instructions": plan["semanticRubric"],
                    "tools": [tool],
                    "tool_choice": {"type": "function", "name": "annotate"},
                    "reasoning": {"effort": "none"},
                    "max_output_tokens": plan["semanticOutputCap"],
                    "stream": True,
                    "store": False,
                }
                (out / "request.json").write_text(json.dumps(req, indent=2) + "\n")
                rec["modelCalled"] = True
                calls += 1
                _, meta = provider(req, provider_key(), out / "response.json")
                terminal = meta.get("terminal") or {}
                u = terminal.get("usage")
                if isinstance(u, dict):
                    rec["usage"] = u
                    rec["grossTokens"] = u["input_tokens"] + u["output_tokens"]
                assert (
                    not meta.get("error") and terminal.get("status") == "completed"
                ), "semantic provider incomplete or failed"
                tc = terminal.get("output", [])
                tc = [x for x in tc if x.get("type") == "function_call"]
                assert len(tc) == 1 and tc[0]["name"] == "annotate", (
                    "semantic submission shape"
                )
                payload = json.loads(tc[0]["arguments"])
                assert set(payload) == (
                    {"episodes", "blocks"} if blocks is not None else {"episodes"}
                ) and isinstance(payload["episodes"], list), "semantic quote schema"
                if blocks is not None:
                    rec["blockReviews"] = branch_semantic_block_admit(
                        blocks, payload["blocks"]
                    )
                    rec["reviewProposalCoverageComplete"] = True
                    rec["unclearBlockCharacters"] = sum(
                        b["span"][1] - b["span"][0]
                        for b in rec["blockReviews"]
                        if b["status"] == "unclear"
                    )
                for item in payload["episodes"]:
                    try:
                        e = shared_validate_label(
                            text,
                            item,
                            task,
                            c["suppliedAtoms"],
                            prior,
                            supplied_absent=[
                                o["conclusion"]["atom"]
                                for o in (c.get("entryEvidence") or {}).get(
                                    "observations", []
                                )
                                if o["conclusion"]["status"] == "finite-absent"
                            ],
                        )
                        e.update(turn=c["turn"], step=c["step"])
                        old = [
                            x
                            for x in prior
                            if x["qualifiedPositive"] and x["atom"] == e["atom"]
                        ]
                        e["crossBranchRepeat"] = any(
                            x["turn"] != c["turn"] for x in old
                        )
                        assert (
                            not rec["accepted"]
                            or e["span"][0] >= rec["accepted"][-1]["span"][1]
                        ), "overlapping or unordered quote"
                        rec["accepted"].append(e)
                        prior.append(e)
                    except Exception as error:
                        rec["rejected"].append(
                            {"proposal": item, "failure": str(error)}
                        )
            except Exception as error:
                rec["failure"] = str(error)
            rec["characterPartition"] = branch_semantic_partition(text, rec["accepted"])
            rec["unreviewedCharacters"] = sum(
                p["span"][1] - p["span"][0]
                for p in rec["characterPartition"]
                if p["category"] == "unreviewed_semantics"
            )
            rec["fullSemanticRecallCertified"] = False
            rec.setdefault("reviewProposalCoverageComplete", False)
            rec["notReviewedByBlockProposalsCharacters"] = (
                0 if rec["reviewProposalCoverageComplete"] else len(text)
            )
            rec["semanticSummary"] = branch_semantic_summary(text, rec["accepted"])
            (out / "receipt.json").write_text(json.dumps(rec, indent=2) + "\n")
            (output / "semantic-ledger.json").write_text(
                json.dumps(ledger, indent=2) + "\n"
            )
            report_text(
                "SEMANTIC_REVIEW",
                row["case"],
                row["arm"],
                c["turn"],
                len(rec["accepted"]),
                len(rec["rejected"]),
                rec["failure"],
                flush=True,
            )
    shared_check(directory)
