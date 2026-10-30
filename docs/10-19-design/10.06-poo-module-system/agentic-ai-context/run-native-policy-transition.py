#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify production Scheme policy transition, native races and crash replay."""

import argparse
from contextlib import closing
import importlib.util
import json
import os
from pathlib import Path
import re
import selectors
import signal
import sqlite3
import subprocess
import time


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("recovery_gate", HERE / "run-native-query-recovery.py")
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)
base = recovery.gate
ROOT = base.ROOT
MODULE = "t/context-policy-durable-test"
CASES = (
    ("after-receive", "(1 2 3 4 5)"),
    ("before-commit", "(2 1 3 4 5)"),
    ("after-commit", "(4 5 2 3 1)"),
    ("before-commit", "arrival"),
    ("after-commit", "arrival"),
)
TRACE = re.compile(r"POLICY-ORDER owner=\(([1-5 ]+)\) arrival=\(([1-5 ]+)\)")


def sources():
    result = recovery.source_cut()
    for name in (MODULE + ".ss", "t/harness/context-policy-durable-driver.ss",
                 str(Path(__file__).resolve().relative_to(ROOT))):
        result[name] = base.catalog.sha(ROOT / name)
    return result


def binaries():
    result = base.binaries()
    stem = ROOT / ".gerbil/lib/agentic-ai-lab" / MODULE
    files = [p for p in stem.parent.glob(stem.name + "*") if p.is_file()
             and (re.search(r"\.o[0-9]+$", p.name)
                  or p.suffix == ".ssi" or p.name.endswith(".ssxi.ss"))]
    if not any(re.search(r"\.o[0-9]+$", p.name) for p in files):
        raise RuntimeError("Missing compiled native policy test")
    result.update({str(p.relative_to(ROOT)): base.catalog.sha(p) for p in files})
    return result


def snapshot(path):
    state = base.durable.db_summary(path)
    with closing(sqlite3.connect(path)) as db:
        state["terminals"] = db.execute("SELECT count(*) FROM terminals").fetchone()[0]
        status = db.execute("SELECT status FROM inbox WHERE id='policy-replace'").fetchone()
        state["replacement_status"] = status[0] if status else None
        state["policy_writes"] = db.execute(
            "SELECT count(*) FROM versions WHERE event='policy-replace' AND k='policies'").fetchone()[0]
        state["decision_writes"] = db.execute(
            "SELECT count(*) FROM versions WHERE event='policy-replace'"
            " AND k='policy-transition-decision:policy-replace'").fetchone()[0]
    return state


def command(db, mode, order, stage):
    return ["just", "test-context-policy-durable", str(db), mode, order, stage]


def held(folder, order, stage, env):
    process = subprocess.Popen(command(folder / "journal.sqlite", "pre", order, stage),
        cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE, start_new_session=True, bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    buffer = b""
    deadline = time.monotonic() + 155
    try:
        with (folder / "pre.log").open("wb") as stream:
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
                if ("POLICY-HELD " + stage).encode() in buffer.splitlines():
                    return process
        raise RuntimeError(f"Policy owner did not reach actual crash cut: {folder}")
    except BaseException:
        base.durable.kill_owned(process)
        raise
    finally:
        selector.close()


def post(folder, order, stage, env, mode="post"):
    log = folder / (mode + ".log")
    with log.open("w") as stream:
        process = subprocess.Popen(command(folder / "journal.sqlite", mode, order, stage),
            cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=155)
        except BaseException:
            base.durable.kill_owned(process)
            raise
    text = log.read_text()
    lines = text.splitlines()
    if (process.returncode or base.catalog.query.BAD.search(text)
            or not all(line in lines for line in (
                "MODULE-OK t/context-policy-durable-test.ss", "HARNESS-OK context-policy-durable", "OK"))
            or lines[-1] != "OK"):
        raise RuntimeError(f"Native policy recovery/control failed: {log}")
    required = ("POLICY-COUNTER pending-replacement=#t cached-a=admitted" if mode == "counter" else
                "POLICY-RETRY duplicate=historical substituted=refused delayed=refused old-ticket=refused")
    if required not in lines:
        raise RuntimeError("Missing actual policy recovery/control observations")


def audit_prefix(folder, requested):
    matches = [m for line in (folder / "pre.log").read_text().splitlines()
               if (m := TRACE.fullmatch(line))]
    if len(matches) != 1:
        raise RuntimeError("Missing actual policy owner and arrival trace")
    order, arrival = ([int(x) for x in matches[0][i].split()] for i in (1, 2))
    for sequence in (order, arrival):
        if sorted(sequence) != [1, 2, 3, 4, 5] or sequence.index(4) > sequence.index(5):
            raise RuntimeError("Invalid real producer trace")
    expected_order = arrival if requested == "arrival" else [int(x) for x in requested.strip("()").split()]
    if order != expected_order:
        raise RuntimeError("Native owner did not execute the selected producer order")
    pos = {event: order.index(event) for event in order}
    expected_terminals = 1 + int(pos[2] < min(pos[1], pos[4])) + int(pos[3] < pos[1])
    split = pos[1] + 1
    return dict(owner=order, arrival=arrival, executed_prefix=order[:split],
                unexecuted_suffix=order[split:], expected_terminals=expected_terminals)


def run_case(folder, stage, order, env):
    folder.mkdir()
    process = held(folder, order, stage, env)
    base.durable.kill_owned(process)
    if process.returncode != -signal.SIGKILL:
        raise RuntimeError("Native owner did not die by SIGKILL")
    before = snapshot(folder / "journal.sqlite")
    prefix = audit_prefix(folder, order)
    committed = int(stage == "after-commit")
    if (before["policy_writes"] != committed or before["decision_writes"] != committed
            or before["replacement_status"] != ("applied" if committed else "pending")
            or before["terminals"] != prefix["expected_terminals"]):
        raise RuntimeError("Wrong durable policy/Context/terminal crash boundary")
    image = folder / "crash.sqlite"
    base.backup(folder / "journal.sqlite", image)
    recovery.stabilize_database(image)
    if snapshot(image) != before:
        raise RuntimeError("Saved policy image differs from the committed crash state")
    post(folder, order, stage, env)
    after = snapshot(folder / "journal.sqlite")
    if (after["epoch"] != before["epoch"] + 1
            or after["policy_writes"] != 1 or after["decision_writes"] != 1
            or after["replacement_status"] != "applied"
            or after["terminals"] != prefix["expected_terminals"]
            or after["terminal_digests"] != before["terminal_digests"]
            or after["originals"] != before["originals"]):
        raise RuntimeError("Policy recovery duplicated a decision, terminal, or changed original evidence")
    result = dict(stage=stage, requested_order=order, prefix=prefix,
                  signal=process.returncode, before=before, after=after,
                  crash_sha256=base.catalog.sha(image))
    (folder / "case.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS native policy crash: {stage} {order}", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--case", type=int)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    # The newly changed production files must have been compiled before a run.
    for module in ("modules/ai-agentic-context/durable-owner", MODULE):
        primary = ROOT / ".gerbil/lib/agentic-ai-lab" / (module + "~0.o1")
        if primary.stat().st_mtime_ns < (ROOT / (module + ".ss")).stat().st_mtime_ns:
            raise RuntimeError("Changed Scheme source has not been rebuilt: " + module)
    before = sources()
    objects = binaries()
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    cases = list(enumerate(CASES)) if args.case is None else [(args.case, CASES[args.case])]
    results = [run_case(args.artifacts / f"case-{i:02d}", stage, order, env)
               for i, (stage, order) in cases]
    if args.case is None:
        for label, mode in (("original-replay", "post"), ("counter-no-replay", "counter")):
            folder = args.artifacts / label
            folder.mkdir()
            base.backup(args.artifacts / "case-00/crash.sqlite", folder / "journal.sqlite")
            post(folder, CASES[0][1], CASES[0][0], env, mode=mode)
    for db in args.artifacts.rglob("*.sqlite"):
        recovery.stabilize_database(db)
    if before != sources() or objects != binaries():
        raise RuntimeError("Native policy source/object cut drifted during qualification")
    result = dict(schema="context.policy-transition.native.v1", cases=results,
                  source_sha256=before, binaries=objects,
                  original_image_replayed=args.case is None, native_counterexamples=int(args.case is None),
                  complete_declared_corpus=args.case is None,
                  artifacts={str(p.relative_to(args.artifacts)): base.catalog.sha(p)
                             for p in sorted(args.artifacts.rglob("*")) if recovery.durable_artifact(p)})
    (args.artifacts / "policy-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(results)} actual policy crash prefixes; {args.artifacts}")


if __name__ == "__main__":
    main()
