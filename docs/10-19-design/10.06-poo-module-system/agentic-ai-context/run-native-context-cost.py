#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Measure steady events at the same cut as a complete cold-process receipt."""

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("owner", HERE / "run-native-owner-lifecycle.py")
owner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(owner)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cold-receipt", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    cold = json.loads(args.cold_receipt.read_text())
    sources, binaries = owner.sources(), owner.binaries()
    if cold["source_sha256"] != sources or cold["binaries"] != binaries:
        raise RuntimeError("Steady events cannot substitute for a different cold source/object cut")
    if not (cold["no_chunking"] and cold["complete_single_process_paths"] == 60
            and len(cold["process_cohorts"]) == 3):
        raise RuntimeError("Both acceptance dimensions require all three complete cold queues")
    owner.RUNTIME_HEAP = cold["heap"]
    owner.RUNTIME_MIN_HEAP = cold["minimum_heap"]
    args.artifacts.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.pop("ASCENT_PROCESS_TRACE", None)
    env.pop("CONTEXT_RESOURCE_PROFILE", None)
    env.update(GERBIL_PATH=str(owner.ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{owner.ROOT}/.gerbil/lib:{owner.ROOT}:{owner.ROOT}/dev/.gerbil/lib")
    # The existing supervisor preserves the process command, native flags,
    # original transcript and failures. Scheme owns every measured operation.
    log = args.artifacts / "native.log"
    text = owner.run(["just", "test-context-actor-cost", str(args.artifacts)], log, env,
                     ["MODULE-OK t/context-actor-cost-test.ss", "HARNESS-OK context-actor-cost", "OK",
                      "ACTOR-ORG-CONTROLS source=refused parser=refused query=refused edited=refused authority=refused",
                      "ACTOR-PARALLEL owners=8 producers=8 events=480 closed=8"])
    phases = {}
    for line in text.splitlines():
        if not line.startswith("ACTOR-COST "):
            continue
        fields = dict(token.split("=", 1) for token in line.split()[1:])
        name = fields.pop("phase")
        if name in phases:
            raise RuntimeError("Duplicate cost phase")
        values = {key: float(value) for key, value in fields.items()}
        if any(not math.isfinite(value) or value < 0 for value in values.values()):
            raise RuntimeError("Invalid native counter; do not publish inferred performance")
        phases[name] = values
    for name in ("context-current-memory", "context-current-durable", "org-current-replay", "journal-transaction"):
        if phases.get(name, {}).get("count") != 60:
            raise RuntimeError("Missing complete steady-event phase: " + name)
    if sources != owner.sources() or binaries != owner.binaries():
        raise RuntimeError("Source/object cut drifted during steady measurement")
    receipt = dict(schema="context.runtime.dual-cost.v1", source_sha256=sources, binaries=binaries,
                   cold_receipt=str(args.cold_receipt.resolve()), cold_sha256=owner.sha(args.cold_receipt),
                   heap=cold["heap"], minimum_heap=cold["minimum_heap"], native_watchdog_seconds=150,
                   cold_processes=cold["process_cohorts"], steady_phases=phases,
                   performance_target_status="measured-not-an-optimized-throughput-claim",
                   artifacts={p.name: owner.sha(p) for p in (log, args.artifacts / "process.json")})
    (args.artifacts / "cost-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("PASS: cold reconstruction and steady events measured separately at one source/object cut")


if __name__ == "__main__":
    main()
