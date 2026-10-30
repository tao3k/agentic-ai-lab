#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute authority/source-separation contracts with retained corrected replay."""

import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess


HERE = Path(__file__).resolve().parent
MODEL = HERE / "22-policy-migration.sysml"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


ORDERS = [p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)]


def facts(case):
    pos = {event: case["order"].index(event) for event in range(1, 6)}
    accepted = case["profile"] != 2 and pos[2] < pos[1] and (not case["expired"] or pos[2] < pos[3])
    terminal = not case["expired"] and pos[3] < pos[1] and pos[3] < pos[4] and (not accepted or pos[3] < pos[2])
    return pos, accepted, terminal


def expected(case):
    pos, accepted, terminal = facts(case)
    return dict(replacementAccepted=str(accepted).lower(), finalGeneration="2", terminalCount=str(int(terminal)),
                oldCurrent="false", affectedInvalid="true", independentCurrent="true", originalEvidenceRetained="true")


def unsafe(case):
    pos, accepted, terminal = facts(case)
    mode = case["mode"]
    if mode == 1:
        return case["profile"] != 2 and not accepted
    if mode == 2:
        return case["profile"] == 2 or not accepted
    if mode == 3:
        return accepted and pos[2] < pos[1]
    if mode in (4, 5):
        return terminal
    if mode == 6:
        return case["profile"] != 0
    return False


def subject(case):
    if tuple(case["order"]) not in ORDERS or case["profile"] not in range(3) or type(case["expired"]) is not bool or case["mode"] not in range(7):
        raise ValueError("Invalid migration schedule")
    values = [*(str(x) for x in case["order"]), str(case["profile"]), str(case["expired"]).lower(), str(case["mode"])]
    return "ContextPolicyMigration::Race(" + ",".join(values) + ")"


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
        cases = [dict(order=list(order), profile=profile, expired=expired, mode=mode)
                 for order in ORDERS for profile in range(3) for expired in (False, True) for mode in range(7)]
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
