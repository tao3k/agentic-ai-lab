#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Kill real Query owners at durable cuts, recover and retain original images.

Native processes run serially through the Just heap fence. These selected
process-death paths complement the section-16 model, not all OS schedules.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import selectors
import signal
import sqlite3
import subprocess
import tempfile
import time


HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


catalog = load("query_catalog", HERE / "run-native-query-catalog.py")
durable = load("old_durable", HERE / "run-native-durable.py")
ROOT = catalog.ROOT
EXTRA_MODULES = (
    "modules/ai-agentic-context/durable-owner",
    "modules/temporal-causality/runtime/monotonic-clock",
    "modules/temporal-causality/runtime/policy-clock",
    "t/context-durable-owner",
    "t/context-query-durable-test",
)
INPUTS = tuple(dict.fromkeys([
    *catalog.INPUTS, *catalog.query.INPUTS,
    *(name + ".ss" for name in EXTRA_MODULES),
    "t/harness/context-query-durable-driver.ss",
    str((HERE / "run-native-durable.py").relative_to(ROOT)),
    str((HERE / "run-native-clock.py").relative_to(ROOT)),
    str((HERE / "run-native-authority.py").relative_to(ROOT)),
    str(Path(__file__).resolve().relative_to(ROOT)),
]))
CASES = [
    ("withdraw", "after-receive", "(1 2 3 4 5)"),
    ("withdraw", "before-commit", "(2 1 3 4 5)"),
    ("withdraw", "after-commit", "(4 5 2 3 1)"),
    ("withdraw", "before-commit", "arrival"),
    ("replace", "after-commit", "arrival"),
    ("zero", "after-receive", "(1)"),
    ("zero", "before-commit", "(1)"),
    ("zero", "after-commit", "(1)"),
]


def sources():
    return {name: catalog.sha(ROOT / name) for name in INPUTS}


def binaries():
    result = catalog.binaries()
    for name in EXTRA_MODULES:
        stem = ROOT / ".gerbil/lib/agentic-ai-lab" / name
        files = [p for p in stem.parent.glob(stem.name + "*") if p.is_file()
                 and (re.search(r"\.o[0-9]+$", p.name)
                      or p.suffix == ".ssi" or p.name.endswith(".ssxi.ss"))]
        if not any(re.search(r"\.o[0-9]+$", p.name) for p in files):
            raise RuntimeError("Missing native module: " + name)
        result.update({str(p.relative_to(ROOT)): catalog.sha(p) for p in files})
    return result


def command(db, mode, order, stage, profile):
    return ["just", "test-context-query-durable", str(db), mode, order, stage, profile]


def held(folder, order, stage, profile, env):
    process = subprocess.Popen(
        command(folder / "journal.sqlite", "pre", order, stage, profile),
        cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE, start_new_session=True, bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + 155
    buffer = b""
    log = folder / "pre.log"
    try:
        with log.open("wb") as stream:
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
                if ("QUERY-DURABLE-HELD " + stage).encode() in buffer.splitlines():
                    return process
        raise RuntimeError(f"Owner did not reach the real crash cut: {log}")
    except BaseException:
        durable.kill_owned(process)
        raise
    finally:
        selector.close()


def snapshot(path):
    # Reuse the original native durable storage/digest checks, then inspect the
    # exact source transaction separately from opaque read/check transactions.
    result = durable.db_summary(path)
    with sqlite3.connect(path) as db:
        result["terminals"] = db.execute("SELECT count(*) FROM terminals").fetchone()[0]
        result["source_status"] = db.execute(
            "SELECT status FROM inbox WHERE id='source-change'").fetchone()[0]
        result["source_catalog_writes"] = db.execute(
            "SELECT count(*) FROM versions WHERE event='source-change' AND k='query-catalog'").fetchone()[0]
    return result


def post(folder, order, stage, profile, env, mode="post"):
    log = folder / (mode + ".log")
    with log.open("w") as stream:
        process = subprocess.Popen(
            command(folder / "journal.sqlite", mode, order, stage, profile),
            cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
            start_new_session=True)
        try:
            process.wait(timeout=155)
        except BaseException:
            durable.kill_owned(process)
            raise
    lines = log.read_text().splitlines()
    if (process.returncode or catalog.query.BAD.search(log.read_text())
            or not all(value in lines for value in (
                "MODULE-OK t/context-query-durable-test.ss",
                "HARNESS-OK context-query-durable", "OK"))
            or lines[-1] != "OK"):
        raise RuntimeError(f"Restart/control failed: {log}")
    if mode == "post":
        required = [
            "QUERY-DURABLE-RECOVER generation=2 affected-fenced=#t unaffected-preserved=#t zero="
            + ("#t" if profile == "zero" else "#f"),
            "QUERY-DURABLE-RETRY duplicate=historical substituted=refused delayed=refused generation=3",
        ]
        if not all(line in lines for line in required):
            raise RuntimeError(f"Missing native recovery evidence: {log}")
    else:
        if "QUERY-DURABLE-COUNTER omitted-source-replay cached-a=admitted pending-source=#t" not in lines:
            raise RuntimeError("Missing native unsafe control")
    return log


def backup(source, target):
    with sqlite3.connect(source) as src, sqlite3.connect(target) as dst:
        src.backup(dst)


def run_case(folder, case, env):
    profile, stage, order = case
    folder.mkdir()
    process = held(folder, order, stage, profile, env)
    durable.kill_owned(process)
    if process.returncode != -signal.SIGKILL:
        raise RuntimeError("Owner did not die by SIGKILL")
    before = snapshot(folder / "journal.sqlite")
    expected = int(stage == "after-commit")
    if (before["source_catalog_writes"] != expected
            or before["source_status"] != ("applied" if expected else "pending")):
        raise RuntimeError("Wrong source transaction crash boundary")
    backup(folder / "journal.sqlite", folder / "crash.sqlite")
    if snapshot(folder / "crash.sqlite") != before:
        raise RuntimeError("Saved crash image changed the committed input")
    post(folder, order, stage, profile, env)
    after = snapshot(folder / "journal.sqlite")
    if (after["epoch"] != before["epoch"] + 1
            or after["source_status"] != "applied" or after["source_catalog_writes"] != 1
            or after["terminal_digests"] != before["terminal_digests"]
            or after["originals"] != before["originals"]):
        raise RuntimeError("Recovery changed evidence/terminals or reapplied a source command")
    result = dict(profile=profile, stage=stage, requested_order=order,
                  signal=process.returncode, before=before, after=after,
                  crash_sha256=catalog.sha(folder / "crash.sqlite"))
    (folder / "case.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS native crash: {profile} {stage} {order}", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--case", type=int)
    args = parser.parse_args()
    out = args.artifacts or Path(tempfile.mkdtemp(prefix="query-source-owner-", dir="/private/tmp"))
    out.mkdir(parents=True, exist_ok=args.artifacts is None)
    before = sources()
    objects = binaries()
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    cases = list(enumerate(CASES)) if args.case is None else [(args.case, CASES[args.case])]
    results = [run_case(out / f"case-{index:02d}", case, env) for index, case in cases]
    if args.case is None:
        original = out / "case-00/crash.sqlite"
        # Positive and unsafe recovery start from the same original crash image.
        for label, mode in (("original-replay", "post"), ("counter-no-replay", "counter")):
            folder = out / label
            folder.mkdir()
            backup(original, folder / "journal.sqlite")
            if snapshot(folder / "journal.sqlite") != snapshot(original):
                raise RuntimeError("Replay input differs from original saved crash")
            profile, stage, order = CASES[0]
            post(folder, order, stage, profile, env, mode=mode)
    if before != sources() or objects != binaries():
        raise RuntimeError("Native source/object cut changed during source-command qualification")
    receipt = dict(schema="context.query-durable-source.native.v1", cases=results,
                   source_sha256=before, binaries=objects,
                   full_corpus=args.case is None, native_counterexamples=int(args.case is None),
                   original_crash_replay=args.case is None,
                   artifacts={str(p.relative_to(out)): catalog.sha(p)
                              for p in sorted(out.rglob("*")) if p.is_file()})
    (out / "query-durable-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS: {len(results)} native crash paths; {out}")


if __name__ == "__main__":
    main()
