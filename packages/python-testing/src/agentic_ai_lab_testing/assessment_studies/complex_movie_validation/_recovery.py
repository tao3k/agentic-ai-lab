# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Recovery for the complex movie validation study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
from ascent import Engine
from .. import complex_movie_study as study
from ..query_contract import output_format
from ..model_study import provider, response_outcome
from ..movie_study import provider_key, MAX_OUTPUT_TOKENS
from agentic_ai_lab_runtime.reasoning import rows_equal


def recover(preview, results, library, output):
    """Two adaptive calls: self-review and a schema-only matched control."""
    plan = json.loads((preview / "plan.json").read_text())
    original = json.loads((results / "result.json").read_text())
    i = next(
        i
        for i, r in enumerate(original["records"])
        if r["outcome"] == "admission_or_execution_failure"
    )
    record = original["records"][i]
    raw = (results / f"{i:02d}" / "raw.txt").read_text()
    item = next(
        x
        for x in plan["order"]
        if x["case"] == record["case"] and x["arm"] == record["arm"]
    )
    request = json.loads((preview / item["request"]).read_text())
    control = {**request, "text": {"format": output_format()}}
    review = {
        "model": "deepseek-flash",
        "reasoning": {"effort": "high"},
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "stream": True,
        "store": False,
        "input": [
            {
                "role": "user",
                "content": "Review this observable protocol failure. The provider completed; the engine expected rule head "
                "to be an array of atoms but received an object. Explain the defect and suggest an interface improvement. "
                "Do not infer hidden reasoning or solve the movie query. Return JSON with diagnosis and recommendations.\n"
                + raw,
            }
        ],
    }
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    report = {
        "schema": "ascent.complex-movie-recovery.v1",
        "purpose": "adaptive diagnostic; original scores unchanged",
        "maxCalls": 2,
        "changedControlFields": ["text"],
        "originalCase": record["case"],
        "originalArm": record["arm"],
        "calls": [],
    }
    (output / "plan.json").write_text(json.dumps(report, indent=2) + "\n")
    for index, req in enumerate((review, control)):
        (output / f"{index:02d}.request.json").write_text(
            json.dumps(req, ensure_ascii=False, indent=2) + "\n"
        )
        report_text("COMPLEX-RECOVERY-CALL", index + 1, "/2", flush=True)
        answer, meta = provider(req, key, output / f"{index:02d}.response.json")
        (output / f"{index:02d}.raw.txt").write_text(answer)
        result = {
            "outcome": response_outcome(meta),
            "usage": (meta["terminal"] or {}).get("usage"),
            "providerSeconds": meta["providerSeconds"],
            "requestSha256": hashlib.sha256(study.encoded(req)).hexdigest(),
        }
        if result["outcome"] == "completed_ungraded":
            try:
                candidate = json.loads(answer)
                if index == 0:
                    result["review"] = candidate
                else:
                    case = next(c for c in plan["cases"] if c["name"] == record["case"])
                    source = study.source_for(plan["source"], case)
                    with Engine() as engine:
                        views = (
                            study.materialize(engine, source)
                            if record["arm"] == "reuse"
                            else None
                        )
                        actual = study.case_program(
                            engine, source, case, candidate, views
                        )
                        correct = rows_equal(actual, plan["gold"][case["name"]])
                    result["outcome"] = response_outcome(meta, correct)
                    result["answer"] = actual
            except Exception as error:
                result["outcome"] = "invalid_recovery"
                result["failure"] = str(error)[:2048]
        report["calls"].append(result)
        (output / "result.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        )
        report_text("\nCOMPLEX-RECOVERY-RESULT", result["outcome"], flush=True)
        if meta["error"] or (meta["terminal"] or {}).get("status") == "failed":
            break
