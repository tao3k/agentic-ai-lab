# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Validation for the complex movie validation study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
from ascent import Engine
from .. import complex_movie_study as study
from agentic_ai_lab_runtime.reasoning import rows_equal
from ._repair import singleton_heads, witnesses


def validate(preview, results, library, output):
    plan = json.loads((preview / "plan.json").read_text())
    original = json.loads((results / "result.json").read_text())
    report = {
        "schema": "ascent.complex-movie-validation.v1",
        "purpose": "post-hoc diagnostics; original scores unchanged",
        "additionalProviderCalls": 0,
        "originalResultSha256": hashlib.sha256(
            (results / "result.json").read_bytes()
        ).hexdigest(),
        "sourceTransfer": [],
        "witnesses": {},
    }
    with Engine() as engine:
        for case in plan["cases"]:
            source = study.source_for(plan["source"], case)
            report["witnesses"][case["name"]] = witnesses(engine, source, case)
        records = original.get("records", original.get("calls", []))
        for i, record in enumerate(records):
            compact_run = "records" not in original
            if compact_run:
                record = {**record, "arm": "reuse"}
            if record["arm"] == "direct":
                continue
            case = next(c for c in plan["cases"] if c["name"] == record["case"])
            try:
                raw_path = (
                    results / f"{i:02d}.raw.txt"
                    if compact_run
                    else results / f"{i:02d}" / "raw.txt"
                )
                candidate, count = singleton_heads(json.loads(raw_path.read_text()))
                grades = []
                for withdrawal in (
                    None,
                    ["Q18002795", "Q208026"],
                    ["Q25188", "Q123351"],
                ):
                    variant = {**case, "withdrawal": withdrawal}
                    source = study.source_for(plan["source"], variant)
                    views = (
                        study.materialize(engine, source)
                        if record["arm"] == "reuse"
                        else None
                    )
                    actual = study.case_program(
                        engine, source, variant, candidate, views
                    )
                    expected = study.case_program(
                        engine, source, variant, study.gold(variant)
                    )
                    equal = rows_equal(actual, expected)
                    grades.append(
                        {
                            "withdrawal": withdrawal,
                            "correct": equal,
                            "answers": len(actual),
                        }
                    )
                diagnostic = {
                    "case": case["name"],
                    "arm": record["arm"],
                    "originalOutcome": record["outcome"],
                    "singletonHeadRepairs": count,
                    "transfers": grades,
                }
            except Exception as error:
                diagnostic = {
                    "case": case["name"],
                    "arm": record["arm"],
                    "originalOutcome": record["outcome"],
                    "failure": str(error)[:2048],
                }
            report["sourceTransfer"].append(diagnostic)
            report_text(
                "COMPLEX-SOURCE-TRANSFER",
                record["case"],
                record["arm"],
                diagnostic.get("transfers", diagnostic.get("failure")),
                flush=True,
            )
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
