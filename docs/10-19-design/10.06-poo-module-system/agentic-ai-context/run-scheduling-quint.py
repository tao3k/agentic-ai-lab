#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Check bounded scheduling and project real ITF traces for native replay."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "core/dev/proofs/quint"))
from backend import backend_session
from native import QuintCLI

COUNTS = re.compile(rb"([\d,]+) states generated, ([\d,]+) distinct states.*?([\d,]+) states left on queue")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    out = args.artifacts.resolve()
    out.mkdir(parents=True, exist_ok=False)
    quint = shutil.which("quint")
    if subprocess.check_output([quint, "--version"], text=True).strip() != "0.33.0":
        raise RuntimeError("Expected pinned Quint 0.33.0")
    sources = {str(p.relative_to(ROOT)): sha(p) for p in HERE.glob("27-*.qnt")}
    sources[str(Path(__file__).relative_to(ROOT))] = sha(Path(__file__))
    for name in ("backend.py", "native.py", "native-cli.cjs"):
        p = ROOT / "core/dev/proofs/quint" / name
        sources[str(p.relative_to(ROOT))] = sha(p)
    for relative in ("modules/temporal-causality/runtime/scheduling.ss",
                     "modules/temporal-causality/runtime/private/scheduling-kernel.ss",
                     "t/context-scheduling-test.ss", "t/harness/context-scheduling-driver.ss",
                     "dev/just/build.just", "dev/just/runtime-tests.just",
                     "build.ss",
                     str((HERE / "27-bounded-scheduling.sysml").relative_to(ROOT)),
                     str((HERE / "run-scheduling-sysml.py").relative_to(ROOT))):
        sources[relative] = sha(ROOT / relative)
    (out / "source-cut.json").write_text(json.dumps(sources, indent=2) + "\n")
    config = out / "backend.json"
    config.write_text('{"workers":"1","maxHeap":"-Xmx1G"}\n')
    results = []
    backend_clock = [0.0]
    def progress(chunk):
        backend_clock[0] = time.monotonic()
        with (out / "backend.log").open("ab") as log:
            log.write(chunk)
        print(chunk.decode(errors="replace"), end="", flush=True)
    # Core's owned backend preserves its existing 45s/5s real-output fences.
    os.chdir(out)
    with backend_session(progress, quint) as endpoint:
        with QuintCLI(quint, "verify", str(out)) as verifier:
            for bug in ("none", "capacity", "priority", "close", "burst"):
                model = HERE / f"27-scheduling-{bug}.qnt"
                main_module = f"BoundedScheduling_{bug}"
                command = [quint, "typecheck", str(model)]
                typed = subprocess.run(command, capture_output=True, timeout=15)
                (out / f"{bug}-typecheck.log").write_bytes(typed.stdout + typed.stderr)
                if typed.returncode:
                    raise RuntimeError("Quint typecheck failed: " + bug)
                print("QUINT-CHECK " + bug, flush=True)
                request = dict(input=str(model), main=main_module, backend="tlc",
                               apalacheVersion="0.62.1", invariant="safety", invariants=[],
                               init="init", step="step", maxSteps=10, randomTransitions=False,
                               tlcConfig=str(config), verbosity=3, serverEndpoint=endpoint)
                (out / f"{bug}-request.json").write_text(json.dumps(request, indent=2) + "\n")
                status, output = verifier.request(request, wall=45, idle=5, emit=True,
                                                  backend_progress=lambda: backend_clock[0])
                log = out / f"{bug}-verify.log"
                log.write_bytes(output)
                counts = COUNTS.search(output)
                negative = bug != "none"
                accepted = (status == 1 and b"Error: Invariant q_inv is violated." in output
                            and b"error: found a counterexample" in output) if negative else (
                            status == 0 and b"[ok] No violation found" in output
                            and counts is not None and counts[3].replace(b",", b"") == b"0")
                if not accepted:
                    raise RuntimeError("Unexpected verifier result: " + bug)
                results.append(dict(mode=bug, expected_counterexample=negative, exit=status,
                                    generated_states=int(counts[1].replace(b",", b"")) if counts else None,
                                    distinct_states=int(counts[2].replace(b",", b"")) if counts else None,
                                    log_sha256=sha(log)))
    replays = []
    native_cases = []
    for bug in ("none", "capacity", "priority", "close", "burst"):
        replay = out / ("replay-" + bug)
        replay.mkdir()
        command = [quint, "test", str(HERE / f"27-scheduling-{bug}.qnt"),
                   "--main", f"BoundedScheduling_{bug}", "--seed", "20261026",
                   "--max-samples", "1", "--out-itf", str(replay / "trace_{test}_{seq}.itf.json")]
        result = subprocess.run(command, capture_output=True, timeout=30)
        (replay / "native.log").write_bytes(result.stdout + result.stderr)
        traces = sorted(replay.glob("*.itf.json"))
        if result.returncode or len(traces) != 5:
            raise RuntimeError("Missing deterministic QNT replay: " + bug)
        for trace in traces:
            itf = json.loads(trace.read_text())
            state_key = next(key for key in itf["vars"] if key.endswith("::s"))
            op_key = next(key for key in itf["vars"] if key.endswith("::op"))
            rows = []
            for state in itf["states"][1:]:
                scalar = lambda value: int(value["#bigint"])
                projected = [scalar(state[state_key][field]) for field in ("d", "c", "b", "burst", "p")]
                rows.append([scalar(state[op_key]), projected])
            unsafe = any(state[state_key]["bad"] or
                         int(state[state_key]["d"]["#bigint"]) + (int(state[state_key]["b"]["#bigint"]) == 1) > 2 or
                         (int(state[state_key]["p"]["#bigint"]) == 2 and
                          any(int(state[state_key][field]["#bigint"]) != 0 for field in ("d", "c", "b")))
                         for state in itf["states"])
            native_cases.append(dict(mode=bug, unsafe=unsafe, trace=str(trace), events=rows))
        replays.append(dict(mode=bug, command=command,
                            traces={trace.name: sha(trace) for trace in traces}))
    (out / "native-cases.json").write_text(json.dumps(native_cases, indent=2) + "\n")
    def sexpr(value):
        if isinstance(value, list):
            return "(" + " ".join(sexpr(item) for item in value) + ")"
        return str(value)
    (out / "native-cases.scm").write_text(
        "(" + "\n".join("(" + case["mode"] + (" #t " if case["unsafe"] else " #f ") + sexpr(case["events"]) + ")"
                          for case in native_cases) + ")\n")
    if any(sha(ROOT / name) != digest for name, digest in sources.items()):
        raise RuntimeError("QNT source/backend drift")
    (out / "summary.json").write_text(json.dumps(dict(
        schema="context.scheduling.quint.v1", source_sha256=sources, results=results, replays=replays,
        bounded_finite_model=True, distributed_runtime_implemented=False,
        native_refinement_proved=False), indent=2) + "\n")
    print("PASS: finite scheduling safety plus four deliberate broken-contract counterexamples")


if __name__ == "__main__":
    main()
