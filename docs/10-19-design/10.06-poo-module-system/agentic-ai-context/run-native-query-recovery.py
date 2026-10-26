#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Crash repeatedly inside real pending-source recovery and owner readiness.

Historical seed images are immutable inputs, not current-build qualifications.
The final native cut is captured independently. Every Gerbil process is serial
and launched through the existing heap-fenced Just entrypoint.
"""

import argparse
import gc
import importlib.util
import json
import os
from pathlib import Path
import selectors
import signal
import sqlite3
import subprocess
import time


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("source_gate", HERE / "run-native-query-durable.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
ROOT = gate.ROOT
CUTS = (
    ("source", "before-commit"),
    ("source", "before-commit"),
    ("source", "after-commit"),
    ("ready", "before-commit"),
    ("ready", "after-commit"),
)
SEEDS = ((0, "pending", 1), (3, "completed", 3), (5, "zero", 0))


def source_cut():
    result = gate.sources()
    result[str(Path(__file__).resolve().relative_to(ROOT))] = gate.catalog.sha(Path(__file__))
    return result


def validate_seed(receipt_path):
    receipt = json.loads(receipt_path.read_text())
    # Only the crash-hook driver changed. Check all producer/runtime sources
    # and native artifacts against the seed's recorded cut before using it.
    excluded_source = "t/context-query-durable-test.ss"
    excluded_native = ".gerbil/lib/agentic-ai-lab/t/context-query-durable-test"
    for name, digest in receipt["source_sha256"].items():
        if name != excluded_source and gate.catalog.sha(ROOT / name) != digest:
            raise RuntimeError("Seed/runtime source drift: " + name)
    for name, digest in receipt["binaries"].items():
        if not name.startswith(excluded_native) and gate.catalog.sha(ROOT / name) != digest:
            raise RuntimeError("Seed/runtime native drift: " + name)
    for index, label, terminal_count in SEEDS:
        key = f"case-{index:02d}/crash.sqlite"
        if gate.catalog.sha(receipt_path.parent / key) != receipt["artifacts"][key]:
            raise RuntimeError("Original seed image changed: " + key)
        state = gate.snapshot(receipt_path.parent / key)
        if (state["source_status"] != "pending" or state["source_catalog_writes"] != 0
                or state["terminals"] != terminal_count):
            raise RuntimeError("Wrong historical recovery seed: " + label)
    return receipt


def hold_recovery(db, folder, kind, stage, profile, env):
    process = subprocess.Popen(
        gate.command(db, "recovery-cut", kind, stage, profile), cwd=ROOT, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
        start_new_session=True, bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    marker = f"QUERY-RECOVERY-HELD {kind} {stage}".encode()
    buffer = b""
    deadline = time.monotonic() + 155
    try:
        with (folder / "held.log").open("wb") as stream:
            while time.monotonic() < deadline:
                if not selector.select(1):
                    if process.poll() is not None:
                        break
                    continue
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    break
                stream.write(chunk)
                stream.flush()
                buffer += chunk
                if marker in buffer.splitlines():
                    if gate.catalog.query.BAD.search(buffer.decode()):
                        raise RuntimeError("Native failure before recovery cut")
                    return process
        raise RuntimeError(f"Recovery did not reach its actual cut: {folder}")
    except BaseException:
        gate.durable.kill_owned(process)
        raise
    finally:
        selector.close()


def ready_record(db, epoch):
    connection = sqlite3.connect(db)
    try:
        identity = f"owner-recovery:{epoch}"
        status = connection.execute("SELECT status FROM inbox WHERE id=?", (identity,)).fetchone()
        decisions = connection.execute("SELECT count(*) FROM log WHERE id=? AND epoch=?",
                                       (identity, epoch)).fetchone()[0]
        return dict(status=status[0] if status else None, decisions=decisions)
    finally:
        connection.close()


def stabilize_database(path):
    """Retain committed logical state in a self-contained WAL-mode main file.

    The legacy inspection helpers use connection context managers, which do
    not close SQLite connections. Release those owned read handles before
    checkpointing; never hash transient shared-memory/WAL coordination files.
    """
    gc.collect()
    connection = sqlite3.connect(path)
    try:
        checkpoint = connection.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        if checkpoint[0] != 0:
            raise RuntimeError("Recovery image still has an active reader/writer")
    finally:
        connection.close()
    wal = Path(str(path) + "-wal")
    if wal.exists() and wal.stat().st_size:
        raise RuntimeError("Recovery image has uncheckpointed committed bytes")


def durable_artifact(path):
    return path.is_file() and not path.name.endswith(("-wal", "-shm"))


def run_chain(out, original, label, terminal_count, env):
    folder = out / label
    folder.mkdir()
    db = folder / "journal.sqlite"
    gate.backup(original, db)
    initial = gate.snapshot(db)
    if initial != gate.snapshot(original):
        raise RuntimeError("Chain does not start from the original saved image")
    profile = "zero" if label == "zero" else "withdraw"
    rows = []
    for number, (kind, stage) in enumerate(CUTS):
        step = folder / f"crash-{number:02d}"
        step.mkdir()
        before = gate.snapshot(db)
        process = hold_recovery(db, step, kind, stage, profile, env)
        gate.durable.kill_owned(process)
        if process.returncode != -signal.SIGKILL:
            raise RuntimeError("Recovery owner did not die by SIGKILL")
        after = gate.snapshot(db)
        applied = int(number >= 2)
        if (after["epoch"] != before["epoch"] + 1
                or after["source_catalog_writes"] != applied
                or after["source_status"] != ("applied" if applied else "pending")
                or after["terminal_digests"] != initial["terminal_digests"]
                or after["originals"] != initial["originals"]
                or after["terminals"] != terminal_count):
            raise RuntimeError("Repeated recovery changed source progress, evidence or terminals")
        readiness = ready_record(db, after["epoch"])
        if kind == "ready":
            expected = dict(status="applied", decisions=1) if stage == "after-commit" else dict(status="pending", decisions=0)
            if readiness != expected:
                raise RuntimeError("Wrong current-epoch readiness crash boundary")
        elif readiness != dict(status=None, decisions=0):
            raise RuntimeError("Source recovery announced readiness before its cut")
        image = step / "crash.sqlite"
        gate.backup(db, image)
        if gate.snapshot(image) != after:
            raise RuntimeError("Intermediate recovery image changed")
        stabilize_database(image)
        if gate.snapshot(image) != after:
            raise RuntimeError("Checkpointing changed the committed recovery state")
        rows.append(dict(kind=kind, stage=stage, signal=process.returncode,
                         before=before, after=after, readiness=readiness,
                         crash_sha256=gate.catalog.sha(image)))
        print(f"PASS repeated recovery: {label} {number + 1}/5 {kind} {stage}", flush=True)

    # This is a sixth new owner. It must commit its own readiness, then the
    # existing post gate verifies current support, retries and stale-input fences.
    gate.post(folder, "(1 2 3 4 5)", "after-receive", profile, env)
    final = gate.snapshot(db)
    if (final["epoch"] != initial["epoch"] + 6
            or final["source_catalog_writes"] != 1
            or final["terminal_digests"] != initial["terminal_digests"]
            or final["originals"] != initial["originals"]
            or ready_record(db, final["epoch"]) != dict(status="applied", decisions=1)):
        raise RuntimeError("Final owner trusted stale readiness or changed retained state")
    stabilize_database(db)
    result = dict(profile=label, initial=initial, cuts=rows, final=final)
    (folder / "chain.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed-receipt", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--profile", choices=("pending", "completed", "zero"))
    args = parser.parse_args()
    seed = validate_seed(args.seed_receipt)
    args.artifacts.mkdir(parents=True, exist_ok=False)
    before = source_cut()
    objects = gate.binaries()
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    results = []
    for index, label, terminals in SEEDS:
        if args.profile and label != args.profile:
            continue
        original = args.seed_receipt.parent / f"case-{index:02d}/crash.sqlite"
        results.append(run_chain(args.artifacts, original, label, terminals, env))
    if before != source_cut() or objects != gate.binaries():
        raise RuntimeError("Source or native artifact drift during repeated recovery")
    # Native processes are gone. Make each retained main file self-contained
    # before hashing, and exclude runtime coordination files from the receipt.
    for database in args.artifacts.rglob("*.sqlite"):
        stabilize_database(database)
    result = dict(schema="context.query-repeated-recovery.native.v1",
                  seed_receipt_sha256=gate.catalog.sha(args.seed_receipt),
                  seed_schema=seed["schema"], source_sha256=before, binaries=objects,
                  chains=results, native_kills=5 * len(results),
                  complete_declared_corpus=args.profile is None,
                  artifacts={str(p.relative_to(args.artifacts)): gate.catalog.sha(p)
                             for p in sorted(args.artifacts.rglob("*")) if durable_artifact(p)})
    (args.artifacts / "recovery-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(results)} native recovery chains; {5 * len(results)} real recovery kills")


if __name__ == "__main__":
    main()
