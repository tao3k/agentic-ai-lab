#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify catalog-only native replay through real SQLite and fresh processes.

Build explicitly with just build-test t/context-query-catalog-test.ss first. This gate
does not rebuild or qualify automatic durable-owner source command recovery.
"""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location("query_gate", HERE / "run-native-query.py")
query = importlib.util.module_from_spec(spec)
spec.loader.exec_module(query)
MODULE = "t/context-query-catalog-test"
INPUTS = [
    "modules/ai-agentic-context/query-provider.ss",
    "modules/ai-agentic-context/org-contract/elements.ss",
    "modules/ai-agentic-context/session-host.ss",
    "modules/temporal-causality/runtime/durable-journal.ss",
    MODULE + ".ss", "t/harness/context-query-catalog-driver.ss",
    "t/context-query-provider-test.ss",
    "modules/ai-agentic-context/org-contract/templates/evidence-source.org",
    "dev/just/build.just", "dev/just/runtime-tests.just",
    "build.ss",
    str(Path(__file__).resolve().relative_to(ROOT)),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    return {name: sha(ROOT / name) for name in INPUTS}


def binaries():
    # Reuse the existing broad dependency/object inventory. Record every suffix
    # that Gerbil could load, including the new focused driver module.
    values = query.binaries()
    stem = ROOT / ".gerbil/lib/agentic-ai-lab" / MODULE
    files = [p for p in stem.parent.glob(stem.name + "*") if p.is_file()
             and (re.search(r"\.o[0-9]+$", p.name)
                  or p.suffix == ".ssi" or p.name.endswith(".ssxi.ss"))]
    if not any(re.search(r"\.o[0-9]+$", p.name) for p in files):
        raise RuntimeError("Missing compiled catalog test")
    values.update({str(p.relative_to(ROOT)): sha(p) for p in files})
    return values


def execute(out, db, mode, label):
    log = out / (label + ".log")
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    with log.open("w") as stream:
        result = subprocess.run(
            ["just", "test-context-query-catalog", str(db), mode], cwd=ROOT,
            env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=130)
    text = log.read_text()
    lines = text.splitlines()
    if (result.returncode or query.BAD.search(text)
            or "MODULE-OK t/context-query-catalog-test.ss" not in lines
            or "HARNESS-OK context-query-catalog" not in lines
            or not lines or lines[-1] != "OK"):
        raise RuntimeError(f"Native catalog failure: {log}")
    required = {
        "prepare": "CATALOG-PREPARED source-generation=1 queries=0 sessions=0 epoch=1",
        "replay": "CATALOG-REPLAY original-bytes=#t empty-root=#t native-proof=#t"
                  " same-query-different-head-refused=#t old-current=#f fresh-current=#t",
        "verify": "CATALOG-VERIFIED source-generation=3 original-queries=2"
                  " old-current=#f fresh-current=#t stale-root-refused=#t",
    }
    if required[mode] not in lines:
        raise RuntimeError(f"Missing native catalog observations: {log}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
    out = args.artifacts or Path(tempfile.mkdtemp(prefix="query-catalog-", dir="/private/tmp"))
    out.mkdir(parents=True, exist_ok=args.artifacts is None)
    before = sources()
    objects = binaries()
    db = out / "catalog.sqlite"
    execute(out, db, "prepare", "prepare")
    original = out / "original-unqueried.sqlite"
    shutil.copyfile(db, original)
    execute(out, db, "replay", "replay")
    execute(out, db, "verify", "verify")

    # Restart the original zero-observation database again, not a newly built
    # fixture. Compare its input bytes before changing this independent copy.
    replay_db = out / "replayed-original.sqlite"
    shutil.copyfile(original, replay_db)
    if sha(replay_db) != sha(original):
        raise RuntimeError("Original database replay input changed")
    execute(out, replay_db, "replay", "original-replay")
    execute(out, replay_db, "verify", "original-verify")
    if before != sources() or objects != binaries():
        raise RuntimeError("Catalog source or native object cut changed during qualification")
    receipt = dict(
        schema="context.query-catalog.native-replay.v1", native_processes=5,
        zero_consumers=True, zero_observations_at_source_admission=True,
        original_database_replayed=True, source_sha256=before, binaries=objects,
        automatic_durable_owner_integration=False,
        artifacts={str(p.relative_to(out)): sha(p) for p in sorted(out.iterdir()) if p.is_file()})
    (out / "catalog-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS: 5 native processes; zero-consumer root and original DB replay; {out}")


if __name__ == "__main__":
    main()
