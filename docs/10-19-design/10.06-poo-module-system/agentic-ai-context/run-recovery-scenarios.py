#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute repeated-recovery contracts and retain unsafe/corrected replays."""

import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess


HERE = Path(__file__).resolve().parent
MODEL = HERE / "19-repeated-recovery.sysml"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unsafe(case):
    # Positional trigger oracle, independent of the SysML state reducer.
    cuts, frame, mode = case["cuts"], case["frame"], case["mode"]
    if mode == 1:
        return any(cut > 0 for cut in cuts)
    if mode == 2:
        return 2 in cuts
    if mode == 3:
        return frame == 0 and any(cut > 0 for cut in cuts)
    if mode == 4:
        return frame != 2
    return False


def subject(case):
    if (len(case["cuts"]) != 5 or any(c not in range(3) for c in case["cuts"])
            or case["frame"] not in range(3) or case["mode"] not in range(5)):
        raise ValueError("Invalid recovery replay input")
    values = [*case["cuts"], case["frame"], case["mode"]]
    return "ContextRepeatedRecovery::Restart(" + ",".join(map(str, values)) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--replay", type=Path)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["model_sha256"] != sha(MODEL):
            raise RuntimeError("Stale recovery model witness")
        cases = [witness["case"], dict(witness["case"], mode=0)]
    else:
        cases = [dict(cuts=list(cuts), frame=frame, mode=mode)
                 for cuts in itertools.product(range(3), repeat=5)
                 for frame in range(3) for mode in range(5)]
    failures = 0
    for start in range(0, len(cases), 150):
        selected = cases[start:start + 150]
        command = ["sysml", "-strict", "-no-record-cache", str(MODEL), "-engine", "run", "-json"]
        for case in selected:
            command.extend(["-analysis", subject(case)])
        result = subprocess.run(command, capture_output=True, text=True, timeout=60)
        raw = args.artifacts / f"batch-{start // 150:03d}.json"
        raw.write_text(result.stdout)
        raw.with_suffix(".stderr.txt").write_text(result.stderr)
        data = json.loads(result.stdout)
        checks = data.get("checks") or []
        if data.get("errors") or data.get("diagnostics") or len(checks) != len(selected):
            raise RuntimeError(f"Invalid or incomplete recovery model execution: {raw}")
        batch_failures = 0
        for number, (case, check) in enumerate(zip(selected, checks), start):
            bad = unsafe(case)
            values = {v["name"]: v["value"] for v in check.get("values", [])}
            executions = check.get("results") or []
            verifications = check.get("verifications") or []
            if (check.get("subject") != subject(case)
                    or check.get("status") != ("fails" if bad else "holds")
                    or values.get("steps") != "6" or len(executions) != 1
                    or executions[0].get("engine") != "run"
                    or executions[0].get("claim") != ("violated" if bad else "holds")
                    or any(b.get("reached") for b in executions[0].get("bounds", []))
                    or len(verifications) != 1
                    or verifications[0].get("kind") != ("fail" if bad else "pass")):
                raise RuntimeError(f"Unexpected recovery model result: {case}; {raw}")
            if case["mode"] == 0:
                expected = dict(decisions="1", pendingA="1" if case["frame"] == 0 else "0",
                                currentOwner="7", readyOwner="7", affectedBAdmitted="false",
                                unaffectedCAdmitted="false" if case["frame"] == 2 else "true",
                                retainedTerminals=str((1, 3, 0)[case["frame"]]))
                if any(values.get(key) != value for key, value in expected.items()):
                    raise RuntimeError("Wrong safe recovery outputs")
            if bad:
                batch_failures += 1
                witness = dict(case=case, model_sha256=sha(MODEL), actual=check)
                (args.artifacts / f"counterexample-{number:04d}.json").write_text(
                    json.dumps(witness, indent=2) + "\n")
        if result.returncode != (1 if batch_failures else 0):
            raise RuntimeError("Unexpected recovery CLI exit status")
        failures += batch_failures
    summary = dict(executed=len(cases), expected_unsafe=failures, unexpected=0,
                   model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)),
                   native_refinement_proved=False)
    (args.artifacts / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"PASS: {len(cases)} executed; {failures} expected unsafe; {args.artifacts}")


if __name__ == "__main__":
    main()
