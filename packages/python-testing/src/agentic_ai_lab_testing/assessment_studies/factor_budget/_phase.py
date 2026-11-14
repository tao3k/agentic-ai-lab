# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Phase for the factor budget study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json, time
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ._artifacts import canonical, save, sha
from ._config import BASE
from ._tasks import input_reserve, packet, question


def charge_usage(usage):
    if not isinstance(usage, dict) or not all(
        (
            type(usage.get(k)) is int and usage[k] >= 0
            for k in ("input_tokens", "output_tokens")
        )
    ):
        raise ValueError("missing_usage_budget_unknown")
    total = usage["input_tokens"] + usage["output_tokens"]
    if "total_tokens" in usage and usage["total_tokens"] != total:
        raise ValueError("inconsistent_total_usage")
    for field, detail, limit in [
        ("output_tokens_details", "reasoning_tokens", "output_tokens"),
        ("input_tokens_details", "cached_tokens", "input_tokens"),
    ]:
        value = (
            usage.get(field, {}).get(detail)
            if isinstance(usage.get(field, {}), dict)
            else None
        )
        if value is not None and (
            type(value) is not int or not 0 <= value <= usage[limit]
        ):
            raise ValueError("inconsistent_usage_breakdown")
    return total


def run_phase(plan, c, phase, arm, native, folder):
    folder.mkdir()
    evidence, build = packet(native, folder)
    expected = next(
        x["packetSha256"]
        for x in json.loads((BASE / "qualification.json").read_text())["matchedPackets"]
        if x["task"] == c["id"]
    )
    if sha(canonical(evidence).encode()) != expected:
        raise RuntimeError("model-visible packet differs from frozen qualification")
    q = question(c, phase, evidence)
    save(folder / "evidence.json", evidence)
    history = ResponseHistory(q)
    n = c["n"]
    ds = c["durations"][:n]
    ws = c["weights"][phase]
    row = {
        "case": c["id"],
        "phase": phase,
        "arm": arm,
        "packet": build,
        "initialInputSha256": sha(q.encode()),
        "calls": [],
        "tools": [],
        "failure": None,
        "totalTokenBudget": plan["totalTokenBudget"],
    }
    used = 0
    best = None
    submitted = None
    seen = set()
    key = provider_key()
    for turn in range(plan["calls"]):
        final_turn = turn == plan["calls"] - 1
        if final_turn:
            history.append_feedback(
                {
                    "instruction": "Call submit now with the best evaluated feasible schedule; no further optimization.",
                    "bestEvaluatedOrder": best[1] if best else None,
                    "bestEvaluatedObjective": best[0] if best else None,
                }
            )
        request = {
            "model": plan["model"],
            "input": history.input(),
            "instructions": plan["instructions"],
            "tools": plan["tools"],
            "tool_choice": {"type": "function", "name": "submit"}
            if final_turn
            else "auto",
            "reasoning": {
                "effort": plan["finalReasoningEffort"]
                if final_turn
                else plan["reasoningEffort"]
            },
            "stream": True,
            "store": False,
        }
        reserve = input_reserve(request)
        cap = min(plan["perCallOutputCap"], plan["totalTokenBudget"] - used - reserve)
        if cap < 256 or len(row["tools"]) >= plan["toolActions"]:
            row["failure"] = "total_budget_reservation_stop"
            break
        request["max_output_tokens"] = cap
        save(folder / f"{turn}.request.json", request)
        _, meta = provider(request, key, folder / f"{turn}.response.json")
        terminal = meta.get("terminal") or {}
        usage = terminal.get("usage")
        call = {
            "turn": turn,
            "usage": usage,
            "inputReserve": reserve,
            "outputCap": cap,
            "seconds": meta["providerSeconds"],
            "outcome": response_outcome(meta),
            "responseFile": str((folder / f"{turn}.response.json").relative_to(BASE)),
        }
        row["calls"].append(call)
        try:
            charge = charge_usage(usage)
        except ValueError as e:
            row["failure"] = str(e)
            charge = None
        if charge is not None:
            used += charge
            if (
                usage["input_tokens"] > reserve
                or usage["output_tokens"] > cap
                or used > plan["totalTokenBudget"]
            ):
                row["failure"] = "budget_protocol_violation"
        save(folder / "receipt.json", row)
        if row["failure"]:
            break
        if meta.get("error") or terminal.get("status") != "completed":
            row["failure"] = call["outcome"]
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
            started = time.monotonic()
            name = fc["name"]
            log = {"name": name, "rawArguments": fc["arguments"]}
            try:
                args = json.loads(fc["arguments"])
                log["arguments"] = args
                sig = (name, canonical(args))
                log["duplicateWithinPhase"] = sig in seen
                seen.add(sig)
                if len(row["tools"]) >= plan["toolActions"]:
                    result = {"error": "tool budget exhausted"}
                elif name == "factor":
                    raw, ipc = native.call(op="factor", **args)
                    cert = raw.pop("admittedCertificate")
                    log["nativeSeconds"] = ipc
                    log["nativeReceipt"] = raw
                    if cert:
                        payload = canonical(cert).encode()
                        h = sha(payload)
                        (folder / "proof-store" / f"{h}.json").write_bytes(payload)
                        log["proofStoreSha256"] = h
                        log["proofBytes"] = len(payload)
                    result = {k: raw[k] for k in ("claim", "precedes", "sourceDigest")}
                    result["evidenceCertificateSha256"] = evidence["certificateSha256"]
                elif name in ("evaluate", "submit"):
                    result, ipc = native.call(
                        op="evaluate", durations=ds, weights=ws, **args
                    )
                    log["nativeSeconds"] = ipc
                    if result["valid"] and (
                        best is None or result["objective"] < best[0]
                    ):
                        best = (result["objective"], args["order"])
                    if name == "submit":
                        submitted = args["order"]
                elif name == "explore":
                    result, ipc = native.call(op="explore", n=n, **args)
                    log["nativeSeconds"] = ipc
                else:
                    raise ValueError("unknown tool")
            except Exception as e:
                result = {"error": str(e)[:2000]}
                log["failure"] = str(e)[:2000]
            log["result"] = result
            log["seconds"] = time.monotonic() - started
            row["tools"].append(log)
            history.append_result(fc["call_id"], result)
        save(folder / "receipt.json", row)
        if submitted is not None:
            break
    candidate = submitted if submitted is not None else best[1] if best else []
    row["submitted"] = submitted is not None
    row["candidate"] = candidate
    row["observedTotalTokens"] = used
    row["grade"], row["graderSeconds"] = native.call(
        op="grade", durations=ds, weights=ws, order=candidate
    )
    if not row["submitted"] and (not row["failure"]):
        row["failure"] = "call_limit_exhausted"
    save(folder / "receipt.json", row)
    report_text(
        "\nPHASE",
        c["id"],
        phase,
        arm,
        "tokens",
        used,
        "gap",
        row["grade"]["gap"],
        "failure",
        row["failure"],
        flush=True,
    )
    return row
