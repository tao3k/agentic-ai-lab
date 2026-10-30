#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute partial-acquisition rollback/release contracts with corrected replay."""

import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess


HERE = Path(__file__).resolve().parent
MODEL = HERE / "25-bootstrap-lifecycle.sysml"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


ORDERS = list(itertools.permutations(range(1, 6)))


def prefix(case):
    count = 0
    for actual, expected_step in zip(case["order"], range(1, 6)):
        if actual != expected_step:
            break
        count += 1
    return count


def expected(case):
    stage = prefix(case)
    return dict(phase=str(stage), closedAck=str(stage == 5).lower(), pendingRetained=str(case["pending"]),
                terminalCount="0", originalEvidenceRetained="true")


def unsafe(case):
    stage, mode, pending = prefix(case), case["mode"], case["pending"]
    return ((stage == 5 and mode in (1, 2, 3))
            or (stage >= 3 and mode == 4 and pending > 0)
            or (stage >= 4 and mode == 5)
            or (stage >= 2 and mode == 6))


def subject(case):
    if tuple(case["order"]) not in ORDERS or case["pending"] not in (0, 1) or case["mode"] not in range(7):
        raise ValueError("Invalid resource lifecycle scenario")
    values = [*(str(x) for x in case["order"]), str(case["pending"]), str(case["mode"])]
    return "ContextBootstrapLifecycle::Abort(" + ",".join(values) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--replay", type=Path)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["model_sha256"] != sha(MODEL):
            raise RuntimeError("Stale authority witness")
        cases = [witness["case"], dict(witness["case"], mode=0)]
    else:
        cases = [dict(order=list(order), pending=pending, mode=mode)
                 for order in ORDERS for pending in (0, 1) for mode in range(7)]
    command = ["sysml", "-strict", "-no-record-cache", str(MODEL), "-engine", "run", "-json"]
    for case in cases:
        command.extend(["-analysis", subject(case)])
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (args.artifacts / "sysml.json").write_text(result.stdout)
    (args.artifacts / "stderr.txt").write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get("checks") or []
    if data.get("errors") or data.get("diagnostics") or len(checks) != len(cases):
        raise RuntimeError("Invalid or incomplete policy scenarios")
    failures = 0
    for number, (case, check) in enumerate(zip(cases, checks)):
        bad = unsafe(case)
        values = {v["name"]: v["value"] for v in check.get("values", [])}
        execution = check.get("results") or []
        verification = check.get("verifications") or []
        if (check.get("subject") != subject(case)
                or check.get("status") != ("fails" if bad else "holds")
                or values.get("steps") != "5" or len(execution) != 1
                or execution[0].get("engine") != "run"
                or execution[0].get("claim") != ("violated" if bad else "holds")
                or any(b.get("reached") for b in execution[0].get("bounds", []))
                or len(verification) != 1
                or verification[0].get("kind") != ("fail" if bad else "pass")):
            raise RuntimeError(f"Unexpected executed policy scenario: {case}")
        if case["mode"] == 0 and any(values.get(k) != v for k, v in expected(case).items()):
            raise RuntimeError("Wrong safe policy outputs")
        if bad:
            failures += 1
            (args.artifacts / f"counterexample-{number:03d}.json").write_text(
                json.dumps(dict(case=case, model_sha256=sha(MODEL), actual=check), indent=2) + "\n")
    if result.returncode != (1 if failures else 0):
        raise RuntimeError("Unexpected policy CLI exit status")
    (args.artifacts / "summary.json").write_text(json.dumps(dict(
        executed=len(cases), expected_unsafe=failures, unexpected=0,
        model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)), native_refinement_proved=False), indent=2) + "\n")
    print(f"PASS: {len(cases)} executed; {failures} expected unsafe")


if __name__ == "__main__":
    main()
