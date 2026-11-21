# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the inference reuse study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
import time
from ascent import Engine
from ..complex_movie_study import identity, ROOT
from ..movie_study import provider_key
from ..model_study import provider, response_outcome
from ._request import completed_contract, price, request
from ._workload import expected, program, updated


def live(directory, library, output):
    plan_path = directory / "plan.json"
    plan = json.loads(plan_path.read_text())
    if "library" in plan:
        library = directory / plan["library"]
    if plan["maxProviderCalls"] != 32 or plan["repetitions"] != 2:
        raise ValueError("plan bounds")
    for name, sha in {**plan["producerHashes"], **plan["reflectionInputs"]}.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != sha:
            raise ValueError("producer/reflection changed")
    if hashlib.sha256(library.read_bytes()).hexdigest() != plan["librarySha256"]:
        raise ValueError("engine changed")
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    (directory / "paid-claim.json").open("x").close()
    receipt = {
        "schema": "ascent.inference-reuse-result.v1",
        "planSha256": hashlib.sha256(plan_path.read_bytes()).hexdigest(),
        "providerCalls": 0,
        "peakEstimateUsd": 0,
        "records": [],
        "scope": plan["scope"],
    }

    def save():
        (output / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def call(case, source, arm, rep, phase):
        req = request(case, source, arm)
        name = f"{case['name']}-{rep}-{arm}-{phase}"
        (output / (name + ".request.json")).write_text(json.dumps(req, indent=2) + "\n")
        report_text(
            "HOLDOUT-MODEL", receipt["providerCalls"] + 1, "/32", name, flush=True
        )
        raw, meta = provider(req, key, output / (name + ".response.json"))
        (output / (name + ".raw.txt")).write_text(raw)
        usage = (meta.get("terminal") or {}).get("usage")
        rec = {
            "case": case["name"],
            "repetition": rep,
            "phase": phase,
            "arm": arm,
            "providerCalls": 1,
            "requestSha256": identity(req),
            "sourceIdentity": identity(source),
            "outcome": response_outcome(meta),
            "usage": usage,
            "providerSeconds": meta["providerSeconds"],
            "correct": False,
            "peakEstimateUsd": price(usage) if usage else None,
        }
        rec["providerOutcome"] = rec["outcome"]
        rec["incompleteDetails"] = (meta.get("terminal") or {}).get(
            "incomplete_details"
        )
        receipt["providerCalls"] += 1
        receipt["peakEstimateUsd"] += rec["peakEstimateUsd"] or 0
        receipt["records"].append(rec)
        save()
        if meta.get("error") or (meta.get("terminal") or {}).get("status") == "failed":
            raise RuntimeError("provider failure; partial receipt retained")
        if not usage:
            raise RuntimeError("missing provider usage; cost cannot be inferred")
        try:
            prediction = (
                json.loads(raw) if rec["outcome"] == "completed_ungraded" else None
            )
        except ValueError:
            prediction = None
        return rec, prediction

    with Engine() as engine:
        for rep in range(2):
            for case in plan["cases"]:
                session = None
                try:
                    for phase in ("cold", "repeat", "updated"):
                        source = updated(case) if phase == "updated" else case["source"]
                        if phase == "cold" and rep == 1:
                            candidate, contract = call(
                                case, source, "compact", rep, phase
                            )
                        baseline, prediction = call(case, source, "direct", rep, phase)
                        baseline["correct"] = (
                            isinstance(prediction, list)
                            and all(isinstance(a, str) for a in prediction)
                            and sorted([[a] for a in prediction])
                            == expected(case, source)
                        )
                        baseline["outcome"] = (
                            response_outcome(
                                {"terminal": {"status": "completed"}},
                                baseline["correct"],
                            )
                            if baseline["outcome"] == "completed_ungraded"
                            else baseline["outcome"]
                        )
                        if phase == "cold":
                            if rep == 0:
                                candidate, contract = call(
                                    case, source, "compact", rep, phase
                                )
                        else:
                            candidate = {
                                "case": case["name"],
                                "repetition": rep,
                                "phase": phase,
                                "arm": "compact",
                                "providerCalls": 0,
                                "peakEstimateUsd": 0,
                                "sourceIdentity": identity(source),
                                "correct": False,
                            }
                            receipt["records"].append(candidate)
                        started = time.monotonic()
                        try:
                            if phase == "cold":
                                contract = completed_contract(
                                    contract, candidate["providerOutcome"]
                                )
                                session = engine.open(program(source, contract))
                                candidate["contractSha256"] = identity(contract)
                            if session is None:
                                raise ValueError("no admitted cold contract")
                            if phase == "updated":
                                session.replace(source["rows"])
                            result = session.run(0 if phase == "repeat" else 1000000000)
                            if not result["complete"]:
                                raise ValueError("Scheme query incomplete")
                            candidate.update(
                                answer=result["relations"]["answer"],
                                correct=sorted(result["relations"]["answer"])
                                == expected(case, source),
                            )
                            candidate["outcome"] = (
                                "correct" if candidate["correct"] else "answer_mismatch"
                            )
                        except Exception as error:
                            candidate.update(
                                outcome=candidate["providerOutcome"]
                                if phase == "cold"
                                and candidate["providerOutcome"] != "completed_ungraded"
                                else "admission_or_execution_failure",
                                failure=str(error)[:2048],
                            )
                        candidate["schemeSeconds"] = time.monotonic() - started
                        candidate["zeroBudgetRetained"] = (
                            phase == "repeat"
                            and candidate["outcome"] != "admission_or_execution_failure"
                        )
                        save()
                        report_text(
                            "HOLDOUT-RESULT",
                            case["name"],
                            rep,
                            phase,
                            baseline["outcome"],
                            candidate["outcome"],
                            flush=True,
                        )
                finally:
                    if session is not None:
                        session.close()
    summary = {}
    for arm in ("direct", "compact"):
        for phase in ("cold", "repeat", "updated"):
            records = [
                r for r in receipt["records"] if r["arm"] == arm and r["phase"] == phase
            ]
            summary[f"{arm}/{phase}"] = {
                "correct": sum(r["correct"] for r in records),
                "tasks": len(records),
                "providerCalls": sum(r["providerCalls"] for r in records),
                "peakEstimateUsd": sum(r.get("peakEstimateUsd") or 0 for r in records),
            }
    direct = sum(
        r["peakEstimateUsd"] for k, r in summary.items() if k.startswith("direct/")
    )
    compact = sum(
        r["peakEstimateUsd"] for k, r in summary.items() if k.startswith("compact/")
    )
    # Identical source/question baseline answer cache can skip repeats too.
    cached_direct = direct - summary["direct/repeat"]["peakEstimateUsd"]
    receipt.update(
        summary=summary,
        threePhaseApiReduction=1 - compact / direct,
        versusExactAnswerCachedDirectApiReduction=1 - compact / cached_direct,
        note="Both reductions are API estimates, not machine cost. Compare quality before admitting savings. Exact repetition alone has no advantage over a correct generic answer cache.",
    )
    save()
    report_text("HOLDOUT-SUMMARY", json.dumps(summary), flush=True)
