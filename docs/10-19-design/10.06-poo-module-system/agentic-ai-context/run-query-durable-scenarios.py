#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute bounded source-crash contracts; retain unsafe and corrected replay."""

import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
MODEL = HERE / "16-query-durable-owner.sysml"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def historical_completions(order):
    """Independent prefix oracle: no old result can finish after source ingress.

    Withdrawal either commits before death or must replay before queued work.
    This oracle uses event positions, without implementing the model reducer.
    """
    pos = {event: order.index(event) for event in order}
    return pos[2] < min(pos[1], pos[4]), pos[3] < pos[1]


def expected_failure(case):
    stage, mode = case["stage"], case["mode"]
    if mode in (1, 3):
        return stage != 3
    if mode == 2:
        return True
    if mode == 4:
        return any(historical_completions(case["order"]))
    return False


def subject(case):
    values = [*case["order"], case["stage"], case["mode"]]
    return "ContextQueryDurability::Recovery(" + ",".join(map(str, values)) + ")"


def validate_case(case):
    order = case["order"]
    if (sorted(order) != list(range(1, 7))
            or order.index(1) >= order.index(6)
            or order.index(4) >= order.index(5)
            or case["stage"] not in (1, 2, 3)
            or case["mode"] not in range(5)):
        raise ValueError("Invalid replay case")


def run_batch(cases, out, index):
    command = ["sysml", "-strict", "-no-record-cache", str(MODEL),
               "-engine", "run", "-json"]
    for case in cases:
        validate_case(case)
        command.extend(["-analysis", subject(case)])
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    raw = out / f"batch-{index:03d}.json"
    raw.write_text(result.stdout)
    (out / f"batch-{index:03d}.stderr.txt").write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get("checks") or []
    if data.get("errors") or data.get("diagnostics") or len(checks) != len(cases):
        raise RuntimeError(f"Incomplete SysML execution: {raw}")

    unsafe = 0
    for offset, (case, check) in enumerate(zip(cases, checks)):
        bad = expected_failure(case)
        values = {v["name"]: v["value"] for v in check.get("values", [])}
        executions = check.get("results") or []
        verifications = check.get("verifications") or []
        if (check.get("subject") != subject(case)
                or check.get("status") != ("fails" if bad else "holds")
                or values.get("steps") != "6"
                or len(executions) != 1
                or executions[0].get("engine") != "run"
                or executions[0].get("claim") != ("violated" if bad else "holds")
                or any(b.get("reached") for b in executions[0].get("bounds", []))
                or len(verifications) != 1
                or verifications[0].get("kind") != ("fail" if bad else "pass")):
            raise RuntimeError(f"Unexpected executed verdict: {case}; {raw}")

        # Verify useful outputs independently, rather than accepting a passing
        # verdict produced by a model whose publication gate does nothing.
        if case["mode"] == 0:
            a_done, b_done = historical_completions(case["order"])
            expected = {
                "sourceApplied": "1", "sourceRevoked": "true",
                "aCurrent": "false", "bCurrent": "false", "cCurrent": "true",
                "aCompletedHistorically": str(a_done).lower(),
                "bCompletedHistorically": str(b_done).lower(),
                "aTerminals": "1", "bTerminals": str(int(b_done)),
                "prematureAck": "false",
            }
            if any(values.get(k) != v for k, v in expected.items()):
                raise RuntimeError(f"Wrong safe-state outputs: {case}; {raw}")

        if bad:
            unsafe += 1
            witness = {"case": case, "model_sha256": sha(MODEL), "actual": check}
            (out / f"counterexample-{index:03d}-{offset:03d}.json").write_text(
                json.dumps(witness, indent=2) + "\n")

    if result.returncode != (1 if unsafe else 0):
        raise RuntimeError(f"Unexpected CLI exit code: {raw}")
    return unsafe


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--replay", type=Path)
    args = parser.parse_args()
    out = args.artifacts or Path(tempfile.mkdtemp(prefix="query-durable-", dir="/private/tmp"))
    out.mkdir(parents=True, exist_ok=True)
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["model_sha256"] != sha(MODEL):
            raise RuntimeError("Stale model witness")
        case = witness["case"]
        cases = [case, dict(case, mode=0)]
    else:
        orders = [p for p in itertools.permutations(range(1, 7))
                  if p.index(1) < p.index(6) and p.index(4) < p.index(5)]
        cases = [dict(order=list(order), stage=stage, mode=mode)
                 for order in orders for stage in (1, 2, 3) for mode in range(5)]

    unsafe = 0
    # Bound each actual CLI invocation; preserve separate machine-readable logs.
    for start in range(0, len(cases), 150):
        unsafe += run_batch(cases[start:start + 150], out, start // 150)
    summary = dict(executed=len(cases), expected_unsafe=unsafe, unexpected=0,
                   model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)),
                   native_implementation_qualified=False)
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"PASS: {len(cases)} executed, {unsafe} expected unsafe; {out}")


if __name__ == "__main__":
    main()
