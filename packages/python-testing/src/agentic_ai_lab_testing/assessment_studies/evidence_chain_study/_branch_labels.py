# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch labels for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib, json
from ._branch_cases import branch_literal_episodes
from ._shared_check import shared_check


def branch_label(directory, output):
    plan = shared_check(directory)
    rows = json.loads((output / "ledger.json").read_text())
    labels = []
    dest = output / "annotations"
    dest.mkdir(exist_ok=False)
    for row in rows:
        prior = []
        record = {"case": row["case"], "arm": row["arm"], "pass": 0, "calls": []}
        labels.append(record)
        for call in row["calls"]:
            folder = (
                output
                / "calls"
                / f"{row['case']}-{row['arm']}"
                / f"{call['turn']}-{call['step']}"
            )
            text = (folder / "thinking.txt").read_text()
            assert hashlib.sha256(text.encode()).hexdigest() == call["thinkingSha256"]
            coverage = branch_literal_episodes(
                text,
                plan["tasks"][row["case"]],
                call["suppliedAtoms"],
                prior,
                call["turn"],
                call["step"],
            )
            out = (
                dest / f"{row['case']}-{row['arm']}-{call['turn']}-{call['step']}.json"
            )
            out.write_text(json.dumps(coverage, indent=2) + "\n")
            prior.extend(coverage["episodes"])
            record["calls"].append(
                {
                    "turn": call["turn"],
                    "step": call["step"],
                    "modelCalled": False,
                    "grossTokens": 0,
                    "failure": None,
                    "accepted": [
                        dict(
                            e,
                            category="positive_derivation",
                            new_residual=False,
                            afterFirstQuestion=call["turn"] > 0,
                        )
                        for e in coverage["episodes"]
                    ],
                    "rejected": [],
                    "coverageFile": str(out.relative_to(output)),
                    "coveredCharacters": coverage["coveredCharacters"],
                    "characters": coverage["characters"],
                    "unresolvedSemanticLines": coverage["unresolvedSemanticLines"],
                }
            )
    (output / "annotation-ledger.json").write_text(json.dumps(labels, indent=2) + "\n")
    report_text(
        "BRANCH_LITERAL_COVERAGE_OK",
        sum(c["characters"] for r in labels for c in r["calls"]),
        flush=True,
    )
