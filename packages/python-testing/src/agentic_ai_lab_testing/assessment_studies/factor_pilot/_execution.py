# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the factor pilot study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json, time
from pathlib import Path
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ._artifacts import save, sha
from ._config import BASE, ROOT, SNAP, TOOLS
from ._prompt import question
from ._transport import SchemeEngine


def run(plan):
    expected = (BASE / "frozen-plan.sha256").read_text().strip()
    assert sha((BASE / "frozen-plan.json").read_bytes()) == expected
    assert sha(Path(plan["runtime"]["path"]).read_bytes()) == plan["runtime"]["sha256"]
    for p, h in plan["producerHashes"].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    for p, h in plan["artifactHashes"].items():
        assert sha((SNAP / p).read_bytes()) == h, p
    assert (
        sha((SNAP / "t/research/factor-pilot.ss").read_bytes())
        == plan["producerHashes"]["t/research/factor-pilot.ss"]
    )
    assert (
        sha((BASE / "qualification.json").read_bytes()) == plan["qualificationSha256"]
    )
    for p, h in plan["formalReceipts"].items():
        assert sha((BASE / p).read_bytes()) == h, p
    assert (
        "RETAINED-INFERENCE-LEAN-OK observations=32"
        in (BASE / "lean-native-quint-correspondence.log").read_text()
    )
    assert json.loads((BASE / "qualification.json").read_text())["passed"]
    key = provider_key()
    paid = BASE / "paid"
    paid.mkdir(exist_ok=False)
    records = []
    for item in plan["order"]:
        c = next(c for c in plan["cases"] if c["id"] == item["case"])
        arm = item["arm"]
        began = time.monotonic()
        native = SchemeEngine()
        init, _ = native.call(op="init", arm=arm, edges=c["edges"], identity=c["id"])
        startup = time.monotonic() - began
        seen = set()
        try:
            for phase in range(2):
                folder = paid / f"{c['id']}-{arm}-{phase}"
                folder.mkdir()
                store = folder / "proof-store"
                store.mkdir()
                cards, card_seconds = native.call(op="cards") if arm != "A" else ({}, 0)
                history = ResponseHistory(question(c, phase, cards))
                n = 6 + phase
                ds = c["durations"][:n]
                ws = c["weights"][phase]
                row = {
                    **item,
                    "phase": phase,
                    "calls": [],
                    "tools": [],
                    "grade": None,
                    "failure": None,
                    "budget": 24576,
                    "nativeStartupAndInitSeconds": startup if phase == 0 else 0,
                    "cardsReadSeconds": card_seconds,
                }
                used = 0
                tool_count = 0
                best = None
                submitted = None
                for turn in range(6):
                    if used >= 24576 or tool_count >= 24:
                        row["failure"] = "phase_budget_exhausted"
                        break
                    request = {
                        "model": plan["model"],
                        "input": history.input(),
                        "instructions": plan["instructions"],
                        "tools": TOOLS,
                        "tool_choice": "auto",
                        "reasoning": {"effort": "high"},
                        "max_output_tokens": min(
                            plan["perCallOutputCap"], 24576 - used
                        ),
                        "stream": True,
                        "store": False,
                    }
                    save(folder / f"{turn}.request.json", request)
                    raw, meta = provider(request, key, folder / f"{turn}.response.json")
                    terminal = meta.get("terminal") or {}
                    usage = terminal.get("usage")
                    call = {
                        "turn": turn,
                        "usage": usage,
                        "seconds": meta["providerSeconds"],
                        "outcome": response_outcome(meta),
                        "rawFile": str(
                            (folder / f"{turn}.response.json").relative_to(BASE)
                        ),
                    }
                    row["calls"].append(call)
                    save(folder / "receipt.json", row)
                    if isinstance(usage, dict) and isinstance(
                        usage.get("output_tokens"), int
                    ):
                        used += usage["output_tokens"]
                    if meta.get("error") or terminal.get("status") != "completed":
                        row["failure"] = call["outcome"]
                        break
                    if not isinstance(usage, dict) or not isinstance(
                        usage.get("output_tokens"), int
                    ):
                        row["failure"] = "missing_usage_budget_unknown"
                        break
                    try:
                        calls = history.append_response(terminal)
                    except Exception as e:
                        row["failure"] = "invalid_conversation:" + str(e)
                        break
                    if not calls:
                        row["failure"] = "no_submit"
                        break
                    for fc in calls:
                        name = fc["name"]
                        tool_count += 1
                        started = time.monotonic()
                        log = {"name": name, "rawArguments": fc["arguments"]}
                        args = {}
                        try:
                            args = json.loads(fc["arguments"])
                            log["arguments"] = args
                            if tool_count > 24:
                                result = {"error": "tool budget exhausted"}
                            elif name == "factor":
                                result, ipc = native.call(op="factor", **args)
                                k = (args["u"], args["v"])
                                log["repeatRequest"] = k in seen
                                seen.add(k)
                                log["nativeRoundtripSeconds"] = ipc
                                certificate = result.pop("admittedCertificate", None)
                                if certificate:
                                    payload = json.dumps(
                                        certificate, sort_keys=True
                                    ).encode()
                                    h = sha(payload)
                                    (store / f"{h}.json").write_bytes(payload)
                                    log["proofStoreSha256"] = h
                                    log["proofStoreBytes"] = len(payload)
                                    # D exposes bounded shared derivation structure; others same atomic answer.
                                    if arm == "D":
                                        result["derivationDAG"] = certificate
                                log["factorReceipt"] = result
                            elif name in ("evaluate", "submit"):
                                result, _ = native.call(
                                    op="evaluate", durations=ds, weights=ws, **args
                                )
                                if result["valid"] and (
                                    best is None or result["objective"] < best[0]
                                ):
                                    best = (result["objective"], args["order"])
                                if name == "submit":
                                    submitted = args["order"]
                            elif name == "explore":
                                result, _ = native.call(op="explore", n=n, **args)
                            else:
                                raise ValueError("unknown tool")
                        except Exception as e:
                            result = {"error": str(e)[:2000]}
                            log["failure"] = str(e)[:2000]
                        log["result"] = result
                        log["totalToolSeconds"] = time.monotonic() - started
                        row["tools"].append(log)
                        history.append_result(fc["call_id"], result)
                    save(folder / "receipt.json", row)
                    if submitted is not None:
                        break
                candidate = (
                    submitted if submitted is not None else (best[1] if best else [])
                )
                row["submitted"] = submitted is not None
                row["candidate"] = candidate
                row["observedOutputTokens"] = used
                row["grade"], seconds = native.call(
                    op="grade", durations=ds, weights=ws, order=candidate
                )
                row["graderSeconds"] = seconds
                if not row["submitted"] and not row["failure"]:
                    row["failure"] = "call_budget_exhausted"
                save(folder / "receipt.json", row)
                records.append(row)
                save(paid / "records.json", records)
                report_text(
                    "\nPHASE",
                    c["id"],
                    arm,
                    phase,
                    "calls",
                    len(row["calls"]),
                    "output",
                    used,
                    "grade",
                    row["grade"],
                    "failure",
                    row["failure"],
                    flush=True,
                )
        finally:
            native.close()
    return records
