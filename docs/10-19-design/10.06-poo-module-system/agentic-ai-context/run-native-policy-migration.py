#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Run all bounded native owner schedules, live producers and legacy crash replay."""

import argparse
from contextlib import closing
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("policy_gate", HERE / "run-native-policy-transition.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
ROOT = gate.ROOT
MODULE = "t/context-policy-migration-test"
PROFILES = ("canonical", "legacy-cut", "legacy-missing")
ORDERS = [p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)]
PATH = re.compile(r"MIGRATION-PATH profile=(\S+) requested=(\([^)]*\)|[0-3]) actual=\(([^)]*)\) accepted=(#t|#f) generation=2 callback=#f")
BAD = re.compile(r"ERROR (?:CASE|CHECK|HARNESS|MODULE)|Heap overflow|Stack overflow|\*\*\* ERROR|undefined\n")


def sources():
    values = gate.sources()
    for name in (MODULE + ".ss", "t/harness/context-policy-migration-driver.ss",
                 "dev/just/build.just", "dev/just/runtime-tests.just",
                 str(Path(__file__).resolve().relative_to(ROOT))):
        values[name] = gate.base.catalog.sha(ROOT / name)
    return values


def binaries():
    values = gate.binaries()
    stem = ROOT / ".gerbil/lib/agentic-ai-lab" / MODULE
    files = [p for p in stem.parent.glob(stem.name + "*") if p.is_file()
             and (re.search(r"\.o[0-9]+$", p.name) or p.suffix == ".ssi" or p.name.endswith(".ssxi.ss"))]
    if not any(re.search(r"\.o[0-9]+$", p.name) for p in files):
        raise RuntimeError("Missing native migration fixture")
    values.update({str(p.relative_to(ROOT)): gate.base.catalog.sha(p) for p in files})
    return values


def run(command, log, env, markers):
    with log.open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=155)
        except BaseException:
            gate.base.durable.kill_owned(process)
            raise
    text = log.read_text()
    if process.returncode or BAD.search(text) or not all(x in text.splitlines() for x in markers) or text.splitlines()[-1] != "OK":
        raise RuntimeError("Native failure (original log retained): " + str(log))
    return text


def inspect_database(path):
    with closing(sqlite3.connect(path)) as db:
        if db.execute("SELECT 1 FROM terminals GROUP BY session,attempt HAVING count(*)>1").fetchone():
            raise RuntimeError("An Attempt has more than one terminal")
        if db.execute("SELECT count(*) FROM terminals WHERE session='session-c'").fetchone()[0] != 1:
            raise RuntimeError("Independent C completion disappeared")
        if db.execute("SELECT status FROM inbox WHERE id='replace'").fetchone() != ("applied",):
            raise RuntimeError("Original policy input is not applied")
        writes = db.execute("SELECT count(*) FROM versions WHERE event='replace' AND k='policy-transition-decision:replace'").fetchone()[0]
        if writes != 1:
            raise RuntimeError("Policy command did not acquire one durable decision")
        evidence = dict(db.execute("SELECT k,digest FROM evidence"))
        if not all(k in evidence for k in ("rules", "facts", "original-org", "original-ascent")):
            raise RuntimeError("Missing original evidence")
        for payload, digest in db.execute("SELECT payload,digest FROM evidence"):
            import hashlib
            if digest != "sha256:" + hashlib.sha256(payload.encode()).hexdigest():
                raise RuntimeError("Original evidence digest mismatch")
        return dict(evidence=evidence, terminals=db.execute("SELECT session,attempt,generation,digest FROM terminals ORDER BY session").fetchall(),
                    original_input=db.execute("SELECT digest FROM inbox WHERE id='replace'").fetchone()[0])


def batch(folder, profile, mode, env):
    folder.mkdir()
    text = run(["just", "test-context-policy-migration", str(folder), profile, mode], folder / "native.log", env,
               ["MIGRATION-NON-DURABLE canonical=refused legacy=refused callback=#f",
                "MODULE-OK t/context-policy-migration-test.ss", "HARNESS-OK context-policy-migration", "OK"])
    paths = [m for line in text.splitlines() if (m := PATH.fullmatch(line))]
    expected = (ORDERS if mode == "all" else ORDERS[int(mode[6:])*20:(int(mode[6:])+1)*20]
                if mode.startswith("chunk:") else list(range(4)) if mode == "live"
                else [tuple(map(int, mode.strip("()").split()))])
    if len(paths) != len(expected):
        raise RuntimeError("Missing executed native paths")
    result = []
    for index, (match, requested) in enumerate(zip(paths, expected)):
        actual = tuple(map(int, match[3].split()))
        if match[1] != profile or actual not in ORDERS:
            raise RuntimeError("Invalid actual native causal trace")
        if mode != "live" and actual != requested:
            raise RuntimeError("Controlled owner did not execute the selected schedule")
        if profile == "legacy-missing" and match[4] != "#f":
            raise RuntimeError("Missing historical cut was guessed")
        db = folder / f"case-{index}.sqlite"
        gate.recovery.stabilize_database(db)
        result.append(dict(requested=requested, actual=actual, accepted=match[4] == "#t", state=inspect_database(db)))
    # Every real timer produces two copies and exactly one duplicate disposition.
    phases = re.findall(r"^MIGRATION-TIMER phase=(\S+)", text, flags=re.M)
    if phases.count("received") != 2 * len(paths) or phases.count("duplicate") != len(paths) or phases.count("applied") + phases.count("stale") != len(paths):
        raise RuntimeError("Real delayed/duplicate timer coverage is incomplete")
    print(f"PASS: {profile} {mode}: {len(paths)} actual native paths", flush=True)
    return dict(profile=profile, mode=mode, folder=folder.name, paths=result)


def crash(folder, profile, stage, env):
    # The older crash orchestrator supplies actual SIGKILL, saved-image custody
    # and an independent terminal prefix oracle. Only its Just entrypoint differs.
    gate.command = lambda db, mode, order, cut: ["just", "test-context-policy-migration-crash", str(db), mode, order, cut, profile]

    def post(folder, order, stage, env, mode="post"):
        markers = ["MODULE-OK t/context-policy-durable-test.ss", "HARNESS-OK context-policy-durable", "OK"]
        text = run(gate.command(folder / "journal.sqlite", mode, order, stage), folder / (mode + ".log"), env, markers)
        if mode == "post" and f"POLICY-MIGRATION profile={profile} accepted={'#f' if profile == 'legacy-missing' else '#t'}" not in text:
            raise RuntimeError("Wrong recovered legacy policy decision")
        if mode == "counter" and "POLICY-COUNTER pending-replacement=#t cached-a=admitted" not in text:
            raise RuntimeError("Missing actual omitted-replay counterexample")
    gate.post = post
    order = {"after-receive": "(1 2 3 4 5)", "before-commit": "(2 1 3 4 5)",
             "after-commit": "(4 5 2 3 1)"}[stage]
    result = gate.run_case(folder, stage, order, env)
    if profile == "legacy-missing":
        with closing(sqlite3.connect(folder / "journal.sqlite")) as db:
            payload = db.execute("SELECT payload FROM state WHERE k='policy-transition-decision:policy-replace'").fetchone()[0]
            if "missing-expected-cut" not in payload:
                raise RuntimeError("Legacy refusal did not retain the missing-cut reason")
    return dict(profile=profile, **result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--replay", type=Path, help="Replay a retained one-path witness")
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    for module in ("modules/ai-agentic-context/durable-owner", "modules/temporal-causality/runtime/policy-clock", MODULE,
                   "t/context-durable-owner", "t/context-policy-durable-test"):
        if (ROOT / ".gerbil/lib/agentic-ai-lab" / (module + "~0.o1")).stat().st_mtime_ns < (ROOT / (module + ".ss")).stat().st_mtime_ns:
            raise RuntimeError("Changed native source was not rebuilt: " + module)
    before, objects = sources(), binaries()
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"), GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    batches, crashes = [], []
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness["source_sha256"] != before:
            raise RuntimeError("Stale native witness")
        order = "(" + " ".join(map(str, witness["order"])) + ")"
        batches.append(batch(args.artifacts / "replay", witness["profile"], order, env))
    else:
        for profile in PROFILES:
            if args.smoke:
                batches.append(batch(args.artifacts / (profile + "-smoke"), profile, "(2 3 4 5 1)", env))
            else:
                for chunk in range(3):
                    batches.append(batch(args.artifacts / f"{profile}-controlled-{chunk}", profile, f"chunk:{chunk}", env))
            if not args.smoke:
                batches.append(batch(args.artifacts / (profile + "-live"), profile, "live", env))
        if not args.smoke:
            for profile in ("legacy-cut", "legacy-missing"):
                for stage in ("after-receive", "before-commit", "after-commit"):
                    crashes.append(crash(args.artifacts / f"crash-{profile}-{stage}", profile, stage, env))
            for label, mode in (("original-replay", "post"), ("counter-no-replay", "counter")):
                folder = args.artifacts / label
                folder.mkdir()
                gate.base.backup(args.artifacts / "crash-legacy-cut-after-receive/crash.sqlite", folder / "journal.sqlite")
                # Reset the declared profile after the missing-cut crash cohort.
                gate.command = lambda db, m, o, s: ["just", "test-context-policy-migration-crash", str(db), m, o, s, "legacy-cut"]
                markers = ["MODULE-OK t/context-policy-durable-test.ss", "HARNESS-OK context-policy-durable", "OK"]
                text = run(gate.command(folder / "journal.sqlite", mode, "(1 2 3 4 5)", "after-receive"), folder / (mode + ".log"), env, markers)
                required = "POLICY-COUNTER pending-replacement=#t cached-a=admitted" if mode == "counter" else "POLICY-MIGRATION profile=legacy-cut accepted=#t reason=accepted"
                if required not in text:
                    raise RuntimeError("Original image positive/negative replay is missing")
    for db in args.artifacts.rglob("*.sqlite"):
        gate.recovery.stabilize_database(db)
    if before != sources() or objects != binaries():
        raise RuntimeError("Migration source/object cut drifted")
    for number, item in enumerate(batches):
        for index, path in enumerate(item["paths"]):
            (args.artifacts / f"witness-{number}-{index}.json").write_text(json.dumps(dict(
                profile=item["profile"], order=path["actual"], source_sha256=before), indent=2) + "\n")
    result = dict(schema="context.policy-migration.native.v1", source_sha256=before, binaries=objects,
                  exhaustive_declared_controlled_orders=not args.smoke and not args.replay,
                  os_schedules_exhaustive=False, batches=batches, crash_prefixes=crashes,
                  original_image_positive=not args.smoke and not args.replay,
                  native_counterexamples=int(not args.smoke and not args.replay),
                  artifacts={str(p.relative_to(args.artifacts)): gate.base.catalog.sha(p)
                             for p in sorted(args.artifacts.rglob("*")) if gate.recovery.durable_artifact(p)})
    (args.artifacts / "migration-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {sum(len(x['paths']) for x in batches)} native paths, {len(crashes)} crash prefixes")


if __name__ == "__main__":
    main()
