#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify complete 60-path single processes under the unchanged native fence."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import threading
import time

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("migration", HERE / "run-native-policy-migration.py")
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)
ROOT = migration.ROOT
PRODUCTION = (
    "modules/temporal-causality/runtime/private/scheduling-kernel",
    "modules/temporal-causality/runtime/scheduling",
    "modules/temporal-causality/runtime/owner-ingress",
    "modules/temporal-causality/runtime/change-feed",
    "modules/workflow/scenario/configuration/module-composition",
    "modules/workflow/scenario/configuration/module-activation",
    "modules/temporal-causality/truth-maintenance/support/policy-host",
    "modules/temporal-causality/evaluator/fact",
    "modules/temporal-causality/evaluator/private/rule-kernel",
    "modules/temporal-causality/evaluator/rule",
    "modules/temporal-causality/evaluator/private/binding-kernel",
    "modules/temporal-causality/evaluator/binding",
    "modules/temporal-causality/evaluator/derivation",
    "modules/ai-agentic-context/funs-projection",
    "modules/temporal-causality/evaluator/proof-host",
    "modules/ai-agentic-context/use-host", "modules/ai-agentic-context/query-provider",
    "modules/ai-agentic-context/session-host", "modules/temporal-causality/runtime/durable-journal",
    "modules/ai-agentic-context/durable-owner", "modules/temporal-causality/runtime/policy-clock",
)
RUNTIME_HEAP = "1G"
RUNTIME_MIN_HEAP = "0"
CLOSE = "OWNER-CLOSE owner=#t timer=#t clock=#t journal=#t subscriptions=0"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    values = migration.sources()
    for name in (*[p + ".ss" for p in PRODUCTION], "t/context-owner-lifecycle-test.ss", "t/ai-agentic-context-core-test.ss",
                 "core/observability/testing-script.ss",
                 "core/module-system/building/artifacts.ss", "t/context-runtime-fencing-test.ss",
                 "t/harness/context-runtime-fencing-driver.ss",
                 "t/context-hybrid-owner-test.ss", "t/harness/context-hybrid-owner-driver.ss",
                 str((HERE / "25-bootstrap-lifecycle.sysml").relative_to(ROOT)),
                 str((HERE / "run-bootstrap-lifecycle-model.py").relative_to(ROOT)),
                 "t/harness/context-owner-lifecycle-driver.ss", "t/context-runtime-cost-test.ss",
                 "t/harness/context-runtime-cost-driver.ss", "t/context-actor-cost-test.ss",
                 "t/harness/context-actor-cost-driver.ss",
                 str((HERE / "24-runtime-credential.sysml").relative_to(ROOT)),
                 str((HERE / "run-runtime-credential-model.py").relative_to(ROOT)),
                 str((HERE / "audit-owner-lifecycle.py").relative_to(ROOT)),
                 str((HERE / "run-native-context-cost.py").relative_to(ROOT)), str(Path(__file__).resolve().relative_to(ROOT))):
        values[name] = sha(ROOT / name)
    return values


def binaries():
    values = migration.binaries()
    for name in (*PRODUCTION, "t/context-owner-lifecycle-test", "t/context-runtime-cost-test", "t/context-actor-cost-test", "t/context-runtime-fencing-test", "t/context-hybrid-owner-test"):
        stem = ROOT / ".gerbil/lib/agentic-ai-lab" / name
        for p in stem.parent.glob(stem.name + "*"):
            if p.is_file() and (re.search(r"\.o[0-9]+$", p.name) or p.suffix == ".ssi" or p.name.endswith(".ssxi.ss")):
                values[str(p.relative_to(ROOT))] = sha(p)
    return values


def monitor(group, folder, done, samples):
    while not done.wait(5):
        rows = subprocess.check_output(["ps", "-axo", "pid,pgid,rss,time,args"], text=True).splitlines()
        matching = [r for r in rows if len(r.split()) >= 5 and r.split()[1] == str(group) and "bin/gxi " in r]
        if matching:
            pid = matching[0].split()[0]
            result = subprocess.run(["lsof", "-nP", "-p", pid, "-Fftn"], capture_output=True, text=True)
            records = result.stdout.splitlines()
            samples.append(dict(elapsed=time.monotonic(), process=matching[0],
                                numeric_fds=sum(bool(re.match(r"^f\d+", x)) for x in records),
                                sqlite_files=sorted({x[1:] for x in records if x.startswith("n") and ".sqlite" in x})))
            (folder / "resources.json").write_text(json.dumps(samples, indent=2) + "\n")


def runtime_options():
    minimum = "" if RUNTIME_MIN_HEAP == "0" else f"min-heap={RUNTIME_MIN_HEAP},"
    return f"-:{minimum}max-heap={RUNTIME_HEAP},debug=q"


def run(command, log, env, markers):
    # This supervisor never extends the Just recipe's 150s native watchdog.
    if command[0] != "just":
        raise RuntimeError("Native tests require the pre-import Just runtime fence")
    if RUNTIME_HEAP != "1G" or RUNTIME_MIN_HEAP != "0":
        command = [command[0], "gerbil_test_runtime_options=" + runtime_options(), *command[1:]]
    start = time.monotonic()
    done, samples = threading.Event(), []
    failure = None
    with log.open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        observer = threading.Thread(target=monitor, args=(process.pid, log.parent, done, samples), daemon=True)
        observer.start()
        try:
            process.wait(timeout=155)
        except BaseException as error:
            failure = error
            migration.gate.base.durable.kill_owned(process)
        finally:
            finished = time.monotonic()
            done.set()
            observer.join(timeout=3)
    elapsed = finished - start
    text = log.read_text()
    lines = text.splitlines()
    # Persist failed runs as well as passes; a missing final receipt is never
    # interpreted as qualification, and the original timeout remains replayable.
    (log.parent / "process.json").write_text(json.dumps(dict(command=command, exit=process.returncode,
        elapsed_seconds=elapsed, observed_pid=process.pid, heap=RUNTIME_HEAP, minimum_heap=RUNTIME_MIN_HEAP, runtime_options=runtime_options(), native_watchdog_seconds=150,
        supervisor_failure=None if failure is None else repr(failure),
        trace_enabled=False, resources=samples), indent=2) + "\n")
    if failure is not None:
        raise failure
    if process.returncode or migration.BAD.search(text) or not all(x in lines for x in markers) or lines[-1] != "OK":
        raise RuntimeError("Native resource gate failed; evidence retained: " + str(log))
    if "RESOURCE-PHASE" in text or "RUNTIME-COST" in text:
        raise RuntimeError("Diagnostic native tracing cannot qualify capacity")
    return text


def main():
    global RUNTIME_HEAP, RUNTIME_MIN_HEAP
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--replay", type=Path, help="Repeat a whole qualified 60-path process, never a chunk")
    parser.add_argument("--heap", choices=("1G", "2G", "3G"), help="Explicit pre-import runtime budget; default 2G")
    parser.add_argument("--min-heap", choices=("0", "512M", "1G", "1536M"),
                        help="Working-heap floor within the same maximum; default 1G for 2G/3G")
    args = parser.parse_args()
    RUNTIME_HEAP = args.heap or "2G"
    RUNTIME_MIN_HEAP = args.min_heap or ("0" if RUNTIME_HEAP == "1G" else "1G")
    args.artifacts.mkdir(parents=True, exist_ok=False)
    for module in (*PRODUCTION, "t/context-policy-migration-test", "t/context-owner-lifecycle-test"):
        if (ROOT / ".gerbil/lib/agentic-ai-lab" / (module + "~0.o1")).stat().st_mtime_ns < (ROOT / (module + ".ss")).stat().st_mtime_ns:
            raise RuntimeError("Changed Scheme not rebuilt: " + module)
    before, objects = sources(), binaries()
    (args.artifacts / "start-cut.json").write_text(json.dumps(dict(
        source_sha256=before, binaries=objects), indent=2) + "\n")
    profiles = ("legacy-cut", "canonical", "legacy-missing")
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["source_sha256"] != before or witness["binaries"] != objects:
            raise RuntimeError("Stale whole-process replay")
        replay_heap = witness.get("heap", "1G")
        if args.heap is not None and args.heap != replay_heap:
            raise RuntimeError("Replay cannot change the recorded runtime heap")
        RUNTIME_HEAP = replay_heap
        replay_minimum = witness.get("minimum_heap", "0")
        if args.min_heap is not None and args.min_heap != replay_minimum:
            raise RuntimeError("Replay cannot change the recorded working-heap floor")
        RUNTIME_MIN_HEAP = replay_minimum
        profiles = witness.get("profiles") or [witness["profile"]]
    sizes = {"0": 0, "512M": 512, "1G": 1024, "1536M": 1536, "2G": 2048, "3G": 3072}
    if sizes[RUNTIME_MIN_HEAP] > sizes[RUNTIME_HEAP]:
        raise RuntimeError("Working heap exceeds the selected maximum")
    env = os.environ.copy()
    env.pop("CONTEXT_RESOURCE_PROFILE", None)
    env.pop("ASCENT_PROCESS_TRACE", None)
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"), GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    migration.run = run
    # Seal the complete queue token before execution, including failed runs.
    (args.artifacts / "whole-replay.json").write_text(json.dumps(dict(
        profiles=list(profiles), heap=RUNTIME_HEAP, minimum_heap=RUNTIME_MIN_HEAP, source_sha256=before, binaries=objects), indent=2) + "\n")
    results = []
    for profile in profiles:
        folder = args.artifacts / profile
        (args.artifacts / f"replay-{profile}.json").write_text(json.dumps(dict(
            profile=profile, heap=RUNTIME_HEAP, minimum_heap=RUNTIME_MIN_HEAP, source_sha256=before, binaries=objects), indent=2) + "\n")
        # ALL is a single Just invocation with one gxi process and 60 owners.
        results.append(migration.batch(folder, profile, "all", env))
        text = (folder / "native.log").read_text()
        if text.splitlines().count(CLOSE) != 60:
            raise RuntimeError("Missing actual cleanup of all 60 owners")
    if not args.replay:
        counter = args.artifacts / "counter-omitted-close"
        counter.mkdir()
        text = run(["just", "test-context-policy-migration", str(counter), "legacy-cut", "counter"],
                   counter / "native.log", env,
                   ["MODULE-OK t/context-policy-migration-test.ss", "HARNESS-OK context-policy-migration", "OK"])
        if "OWNER-COUNTER journal-open=#t retained-subscriptions=3" not in text or CLOSE in text:
            raise RuntimeError("The native omitted-cleanup counterexample was not exposed")
        unit = args.artifacts / "unit"
        unit.mkdir()
        run(["just", "test-context-owner-lifecycle", str(unit / "journal.sqlite")], unit / "native.log", env,
            ["MODULE-OK t/context-owner-lifecycle-test.ss", "HARNESS-OK context-owner-lifecycle", "OK"])
        fencing = args.artifacts / "runtime-fencing"
        fencing.mkdir()
        run(["just", "test-context-runtime-fencing", str(fencing / "journal.sqlite")],
            fencing / "native.log", env,
            ["MODULE-OK t/context-runtime-fencing-test.ss", "HARNESS-OK context-runtime-fencing", "OK",
             "OWNER-FENCE old-epoch=1 new-epoch=2 stale-refused=#t successor-progress=#t"])
        hybrid = args.artifacts / "hybrid-pressure"
        hybrid.mkdir()
        run(["just", "test-context-hybrid-owner", str(hybrid / "journal")], hybrid / "native.log", env,
            ["MODULE-OK t/context-hybrid-owner-test.ss", "HARNESS-OK context-hybrid-owner", "OK",
             "HYBRID-STOP saturated-control=retained timer-retry=interruptible owner=joined"])
        # Query Provider subscribers are a fourth source kind beyond the raw
        # authority fixture. Regress their disposal together with a real crash.
        migration.crash(args.artifacts / "query-crash", "legacy-cut", "before-commit", env)
    for db in args.artifacts.rglob("*.sqlite"):
        migration.gate.recovery.stabilize_database(db)
    if before != sources() or objects != binaries():
        raise RuntimeError("Owner lifecycle source/object cut drifted")
    result = dict(schema="context.owner-lifecycle.native.v2", source_sha256=before, binaries=objects,
                  complete_single_process_paths=60, process_cohorts=results,
                  process_count=len(profiles), no_chunking=True, heap=RUNTIME_HEAP, minimum_heap=RUNTIME_MIN_HEAP,
                  runtime_options=runtime_options(), runtime_backend="gambit-owner-bounded-ingress-coalesced-wake", native_watchdog_seconds=150,
                  native_counterexamples=int(not args.replay),
                  artifacts={str(p.relative_to(args.artifacts)): sha(p) for p in sorted(args.artifacts.rglob("*"))
                             if migration.gate.recovery.durable_artifact(p)})
    (args.artifacts / "owner-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(profiles)} unpartitioned native processes, 60 paths each; all owned resources released")


if __name__ == "__main__":
    main()
