# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Review for the complex movie validation study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import copy
import hashlib
import json
import time
from ascent import Engine
from .. import complex_movie_study as study
from ..query_contract import output_format, compact_request
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import rows_equal


def review_semantics(preview, results, library, output):
    """Model critiques its wrong contract using original question, not gold rows."""
    plan = json.loads((preview / "plan.json").read_text())
    original = json.loads((results / "result.json").read_text())
    i = next(
        i
        for i, r in enumerate(original["records"])
        if r["outcome"] == "answer_mismatch"
    )
    record = original["records"][i]
    item = next(
        x
        for x in plan["order"]
        if x["case"] == record["case"] and x["arm"] == record["arm"]
    )
    before = json.loads((preview / item["request"]).read_text())
    raw = (results / f"{i:02d}" / "raw.txt").read_text()
    request = copy.deepcopy(before)
    request["input"][0]["content"] += (
        "\nReview your previous executable contract against the original question. "
        "Its answer failed an external exact-set check. No expected answers are supplied. "
        "Inspect how conjunction/union and exclusion attachment are encoded; a shared rule body is conjunction, "
        "multiple rules are union. Return {diagnosis: string, contract: {relations, rules}} with the corrected contract. "
        "Do not enumerate answers. Previous contract:\n" + raw
    )
    schema = {
        "type": "object",
        "properties": {
            "diagnosis": {"type": "string"},
            "contract": output_format()["schema"],
        },
        "required": ["diagnosis", "contract"],
        "additionalProperties": False,
    }
    request["text"] = {
        "format": {
            "type": "json_schema",
            "name": "ascent_contract_review",
            "schema": schema,
        }
    }
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    (output / "request.json").write_text(
        json.dumps(request, ensure_ascii=False, indent=2) + "\n"
    )
    report = {
        "schema": "ascent.complex-movie-semantic-review.v1",
        "purpose": "adaptive failure diagnosis, original score unchanged",
        "maxCalls": 1,
        "originalCase": record["case"],
        "originalArm": record["arm"],
        "goldAnswersSupplied": False,
    }
    (output / "plan.json").write_text(json.dumps(report, indent=2) + "\n")
    report_text("COMPLEX-SEMANTIC-REVIEW-CALL 1/1", flush=True)
    answer, meta = provider(request, key, output / "response.json")
    (output / "raw.txt").write_text(answer)
    report.update(
        outcome=response_outcome(meta),
        usage=(meta["terminal"] or {}).get("usage"),
        providerSeconds=meta["providerSeconds"],
    )
    if report["outcome"] == "completed_ungraded":
        try:
            prediction = json.loads(answer)
            case = next(c for c in plan["cases"] if c["name"] == record["case"])
            source = study.source_for(plan["source"], case)
            with Engine() as engine:
                views = (
                    study.materialize(engine, source)
                    if record["arm"] == "reuse"
                    else None
                )
                actual = study.case_program(
                    engine, source, case, prediction["contract"], views
                )
                equal = rows_equal(actual, plan["gold"][case["name"]])
            report.update(
                outcome=response_outcome(meta, equal),
                diagnosis=prediction["diagnosis"],
                contract=prediction["contract"],
                answer=actual,
            )
        except Exception as error:
            report.update(outcome="invalid_review", failure=str(error)[:2048])
    (output / "result.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    )
    report_text("\nCOMPLEX-SEMANTIC-REVIEW-RESULT", report["outcome"], flush=True)


def compact(preview, results, library, output):
    """Three adaptive interface probes; facts remain in the typed executor."""
    plan = json.loads((preview / "plan.json").read_text())
    if plan.get("stratum") != "country-qualified" or len(plan["cases"]) != 3:
        raise ValueError("country-qualified plan required")
    requests = []
    for case in plan["cases"]:
        item = next(
            x
            for x in plan["order"]
            if x["case"] == case["name"] and x["arm"] == "reuse"
        )
        before = json.loads((preview / item["request"]).read_text())
        req = compact_request(
            before, study.identity(study.source_for(plan["source"], case))
        )
        requests.append((case, req))
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    report = {
        "schema": "ascent.compact-movie-interface.v1",
        "purpose": "adaptive interface probe, not held-out benchmark",
        "maxCalls": 3,
        "retries": 0,
        "contextChange": "remove row enumeration and actor domain; add precise view semantics",
        "basePlanSha256": hashlib.sha256(
            (preview / "plan.json").read_bytes()
        ).hexdigest(),
        "calls": [],
    }
    for i, (_, req) in enumerate(requests):
        (output / f"{i:02d}.request.json").write_text(
            json.dumps(req, ensure_ascii=False, indent=2) + "\n"
        )
    (output / "plan.json").write_text(json.dumps(report, indent=2) + "\n")
    cache = {}
    with Engine() as engine:
        for i, (case, req) in enumerate(requests):
            source = study.source_for(plan["source"], case)
            sid = study.identity(source)
            started = time.monotonic()
            hit = sid in cache
            if not hit:
                cache[sid] = study.materialize(engine, source)
            setup = time.monotonic() - started
            report_text("COMPACT-INTERFACE-CALL", i + 1, "/3", case["name"], flush=True)
            raw, meta = provider(req, key, output / f"{i:02d}.response.json")
            (output / f"{i:02d}.raw.txt").write_text(raw)
            result = {
                "case": case["name"],
                "outcome": response_outcome(meta),
                "usage": (meta["terminal"] or {}).get("usage"),
                "providerSeconds": meta["providerSeconds"],
                "viewSetupSeconds": setup,
                "viewCacheHit": hit,
                "requestSha256": hashlib.sha256(study.encoded(req)).hexdigest(),
            }
            if result["outcome"] == "completed_ungraded":
                try:
                    candidate = json.loads(raw)
                    actual = study.case_program(
                        engine, source, case, candidate, cache[sid]
                    )
                    correct = rows_equal(actual, plan["gold"][case["name"]])
                    result.update(
                        outcome=response_outcome(meta, correct), answer=actual
                    )
                except Exception as error:
                    result.update(
                        outcome="admission_or_execution_failure",
                        failure=str(error)[:2048],
                    )
            report["calls"].append(result)
            (output / "result.json").write_text(
                json.dumps(report, ensure_ascii=False, indent=2) + "\n"
            )
            report_text("\nCOMPACT-INTERFACE-RESULT", result["outcome"], flush=True)
            if meta["error"] or (meta["terminal"] or {}).get("status") == "failed":
                break
