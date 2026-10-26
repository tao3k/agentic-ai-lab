#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Replay the native crash control with one recorded Actor profile in every process."""

import argparse
import hashlib
import importlib.util
import json
import os
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("owner", HERE / "run-native-owner-lifecycle.py")
owner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(owner)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads(args.receipt.read_text())
    if receipt["source_sha256"] != owner.sources() or receipt["binaries"] != owner.binaries():
        raise RuntimeError("Stale native crash source/object cut")
    args.artifacts.mkdir(parents=True, exist_ok=False)
    owner.RUNTIME_HEAP = receipt["heap"]
    owner.RUNTIME_MIN_HEAP = receipt.get("minimum_heap", "0")
    assignment = "gerbil_test_runtime_options=" + owner.runtime_options()
    env = os.environ.copy()
    env.pop("CONTEXT_RESOURCE_PROFILE", None)
    env.pop("ASCENT_PROCESS_TRACE", None)
    env.update(GERBIL_PATH=str(owner.ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{owner.ROOT}/.gerbil/lib:{owner.ROOT}:{owner.ROOT}/dev/.gerbil/lib")

    # The inherited SIGKILL orchestrator invokes its pre-crash command directly.
    # Wrap that handoff as well as ordinary post/counter runs; Scheme semantics,
    # cut selection, custody and the independent terminal oracle are unchanged.
    original_case = owner.migration.gate.run_case

    def matched_case(*case_args, **kwargs):
        original_command = owner.migration.gate.command
        owner.migration.gate.command = lambda *values: [
            "just", assignment, *original_command(*values)[1:]]
        return original_case(*case_args, **kwargs)

    def matched_run(command, log, environment, markers):
        # owner.run supplies the same flag itself. Avoid a duplicate Just binding.
        if command[1] == assignment:
            command = [command[0], *command[2:]]
        return owner.run(command, log, environment, markers)

    owner.migration.gate.run_case = matched_case
    owner.migration.run = matched_run
    case = owner.migration.crash(args.artifacts / "query-crash", "legacy-cut", "before-commit", env)
    counter = args.artifacts / "counter-omitted-replay"
    counter.mkdir()
    shutil.copy2(args.artifacts / "query-crash" / "crash.sqlite", counter / "journal.sqlite")
    owner.migration.gate.post(counter, case["requested_order"], case["stage"], env, mode="counter")
    logs = (args.artifacts / "query-crash" / "pre.log",
            args.artifacts / "query-crash" / "post.log", counter / "counter.log")
    for log in logs:
        text = log.read_text()
        if "150s gxi " + owner.runtime_options() not in text:
            raise RuntimeError("Wrong actual Actor runtime profile: " + str(log))
    if receipt["source_sha256"] != owner.sources() or receipt["binaries"] != owner.binaries():
        raise RuntimeError("Native crash source/object cut drifted")
    result = dict(schema="context.runtime.matched-crash.v1", receipt_sha256=sha(args.receipt),
                  runner_sha256=sha(Path(__file__)), heap=owner.RUNTIME_HEAP,
                  minimum_heap=owner.RUNTIME_MIN_HEAP, runtime_options=owner.runtime_options(),
                  current_cut_verified=True, native_case=case,
                  artifacts={str(p.relative_to(args.artifacts)): sha(p)
                             for p in sorted(args.artifacts.rglob("*")) if p.is_file()})
    (args.artifacts / "crash-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: matched Actor runtime profile in native pre-crash, recovery and omitted-replay control")


if __name__ == "__main__":
    main()
