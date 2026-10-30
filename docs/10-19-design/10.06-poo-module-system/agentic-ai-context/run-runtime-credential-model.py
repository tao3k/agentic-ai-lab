#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute owner-sealed historical credential scenarios and corrected replay."""

import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess


HERE = Path(__file__).resolve().parent
MODEL = HERE / "24-runtime-credential.sysml"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


ORDERS = list(itertools.permutations(range(1, 6)))


def oracle(case):
    # Independent sequential oracle: historical reads never grant current use.
    supported = replay_valid = original = True
    denied = unsafe_read = unsafe_publish = current = False
    terminals = 0
    mode = case["mode"]
    for move in case["order"]:
        if move == 1 and case["foreign"]:
            denied = mode != 2
            unsafe_read = mode == 2
        elif move == 2:
            supported = current = False
        elif move == 3:
            replay_valid = current = False
        elif move == 4 and (mode == 1 or (supported and replay_valid)):
            unsafe_publish = not (supported and replay_valid)
            terminals += 1
            current = True
        elif move == 5 and mode == 3:
            original = False
    bad = unsafe_read or unsafe_publish or not original or (current and not (supported and replay_valid))
    return bad, dict(steps="5", terminalCount=str(terminals), foreignReadDenied=str(denied).lower(),
                     originalEvidenceRetained=str(original).lower(), resultCurrent=str(current).lower())


def subject(case):
    if tuple(case["order"]) not in ORDERS or case["foreign"] not in (0, 1) or case["mode"] not in range(4):
        raise ValueError("Invalid actor credential scenario")
    values = [*(str(x) for x in case["order"]), str(case["foreign"]), str(case["mode"])]
    return "ContextRuntimeCredential::Read(" + ",".join(values) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--replay", type=Path)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["model_sha256"] != sha(MODEL):
            raise RuntimeError("Stale credential witness")
        cases = [witness["case"], dict(witness["case"], mode=0)]
    else:
        cases = [dict(order=list(order), foreign=foreign, mode=mode)
                 for order in ORDERS for foreign in (0, 1) for mode in range(4)]
    command = ["sysml", "-strict", "-no-record-cache", str(MODEL), "-engine", "run", "-json"]
    for case in cases:
        command.extend(["-analysis", subject(case)])
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (args.artifacts / "sysml.json").write_text(result.stdout)
    (args.artifacts / "stderr.txt").write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get("checks") or []
    if data.get("errors") or data.get("diagnostics") or len(checks) != len(cases):
        raise RuntimeError("Invalid or incomplete credential scenarios")
    failures = 0
    for number, (case, check) in enumerate(zip(cases, checks)):
        bad, expected_values = oracle(case)
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
            raise RuntimeError(f"Unexpected executed credential scenario: {case}")
        if any(values.get(k) != v for k, v in expected_values.items()):
            raise RuntimeError("Wrong safe credential outputs")
        if bad:
            failures += 1
            (args.artifacts / f"counterexample-{number:03d}.json").write_text(
                json.dumps(dict(case=case, model_sha256=sha(MODEL), actual=check), indent=2) + "\n")
    if result.returncode != (1 if failures else 0):
        raise RuntimeError("Unexpected credential CLI exit status")
    (args.artifacts / "summary.json").write_text(json.dumps(dict(
        executed=len(cases), expected_unsafe=failures, unexpected=0,
        model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)), native_refinement_proved=False), indent=2) + "\n")
    print(f"PASS: {len(cases)} executed; {failures} expected unsafe")


if __name__ == "__main__":
    main()
