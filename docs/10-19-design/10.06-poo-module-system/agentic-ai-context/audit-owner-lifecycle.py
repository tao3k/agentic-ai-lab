#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Verify whole-process capacity, actual cleanup observations and durable evidence."""

import argparse
from contextlib import closing
import hashlib
import itertools
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[4]
CLOSE = "OWNER-CLOSE owner=#t timer=#t clock=#t journal=#t subscriptions=0"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value, message):
    if not value:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = json.loads(args.receipt.read_text())
    root = args.receipt.parent
    require(data["schema"] in ("context.owner-lifecycle.native.v1", "context.owner-lifecycle.native.v2") and data["no_chunking"], "Not a whole-process receipt")
    require(data["heap"] in ("1G", "2G", "3G") and data["native_watchdog_seconds"] == 150, "Resource limits changed")
    for name, digest in {**data["source_sha256"], **data["binaries"]}.items():
        require(sha(ROOT / name) == digest, "Current build drift: " + name)
    for name, digest in data["artifacts"].items():
        require(sha(root / name) == digest, "Original artifact changed: " + name)
    legal = {p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)}
    processes = []
    for cohort in data["process_cohorts"]:
        profile = cohort["profile"]
        paths = cohort["paths"]
        require(cohort["mode"] == "all" and len(paths) == 60 and {tuple(p["actual"]) for p in paths} == legal,
                "Missing whole 60-order process")
        folder = root / cohort["folder"]
        process = json.loads((folder / "process.json").read_text())
        command = process["command"]
        minimum = data.get("minimum_heap", "0")
        floor = "" if minimum == "0" else f"min-heap={minimum},"
        options = f"-:{floor}max-heap={data['heap']},debug=q"
        assignment = "gerbil_test_runtime_options=" + options
        prefix = ["just", "test-context-policy-migration"] if data['heap'] == "1G" and minimum == "0" else ["just", assignment, "test-context-policy-migration"]
        require(command[:len(prefix)] == prefix and command[-2:] == [profile, "all"],
                "A chunk/replay subset replaced the complete process")
        require(process["exit"] == 0 and process["elapsed_seconds"] < 150 and not process["trace_enabled"],
                "Whole-process budget was not met")
        pids = {row["process"].split()[0] for row in process["resources"]}
        require(len(pids) == 1, "Observed multiple native gxi processes for one 60-path invocation")
        lines = (folder / "native.log").read_text().splitlines()
        require(process['heap'] == data['heap'] and process.get("minimum_heap", "0") == minimum and all(
            options in row['process'] for row in process['resources']),
                "Observed native process heap differs from the receipt")
        require(any('150s gxi' in line and options in line for line in lines),
                "Missing actual pre-import native heap/watchdog command")
        require(lines.count(CLOSE) == 60, "Missing actual closed-handle assertions")
        require(lines[-1] == "OK" and all(m in lines for m in (
            "MODULE-OK t/context-policy-migration-test.ss", "HARNESS-OK context-policy-migration")), "Missing strict native markers")
        for index in range(60):
            image = folder / f"case-{index}.sqlite"
            with closing(sqlite3.connect(image.resolve().as_uri() + "?mode=ro", uri=True)) as db:
                require(not db.execute("SELECT 1 FROM terminals GROUP BY session,attempt HAVING count(*)>1").fetchone(),
                        "Duplicate Attempt terminal")
                require(db.execute("SELECT count(*) FROM terminals WHERE session='session-c'").fetchone() == (1,),
                        "Independent C completion disappeared")
                require(db.execute("SELECT count(*) FROM versions WHERE event='replace' AND k='policy-transition-decision:replace'").fetchone() == (1,),
                        "Lost or duplicated CAS decision")
                for payload, digest in db.execute("SELECT payload,digest FROM evidence"):
                    require(digest == "sha256:" + hashlib.sha256(payload.encode()).hexdigest(), "Original evidence changed")
        processes.append(dict(profile=profile, native_pid=next(iter(pids)), paths=60,
                              elapsed_seconds=process["elapsed_seconds"], closed_owners=60))
    if data["native_counterexamples"]:
        require({p["profile"] for p in processes} == {"canonical", "legacy-cut", "legacy-missing"}, "Missing input profile")
        text = (root / "counter-omitted-close/native.log").read_text()
        require("OWNER-COUNTER journal-open=#t retained-subscriptions=3" in text and CLOSE not in text,
                "Omitted-cleanup native counterexample was not exposed")
        text = (root / "unit/native.log").read_text()
        if data["schema"] == "context.owner-lifecycle.native.v2":
            fencing = (root / "runtime-fencing/native.log").read_text()
            require("OWNER-FENCE old-epoch=1 new-epoch=2 stale-refused=#t successor-progress=#t" in fencing,
                    "Missing actual old-owner refusal and successor progress")
            with closing(sqlite3.connect(root / "runtime-fencing/journal.sqlite")) as db:
                require(db.execute("SELECT epoch FROM owner WHERE id=1").fetchone()[0] == 2,
                        "Fencing test did not use real competing epochs")
                require({row[0] for row in db.execute("SELECT k FROM evidence")} == {"original", "successor"},
                        "Stale evidence survived or successor/original evidence disappeared")
            require("OWNER-BOOTSTRAP rollback=exact journal=closed subscriptions=0 owner=joined pending=preserved" in text,
                    "Missing actual failed-bootstrap rollback, release and join control")
            require("OWNER-KERNEL original-digest=exact missing=refused duplicate=refused forged-support=refused next-call-mutation=refused" in text,
                    "Proof kernel canonical graph regression controls missing")
            require("OWNER-PROOF retained=sealed aliases=detached current-tamper=refused foreign-owner=refused" in text,
                    "Historical credential bypasses current replay or actor ownership")
        require("OWNER-PENDING copies=2 pending-identities=1 rearmed=2 original-bytes=retained obligations=exact terminals=0 endpoints=independent" in text,
                "Pending input/endpoint ownership probe missing")
        with closing(sqlite3.connect((root / "unit/journal.sqlite").resolve().as_uri() + "?mode=ro", uri=True)) as db:
            require(db.execute("SELECT status FROM inbox WHERE id='unfinished'").fetchone() == ("pending",), "Close lost an uncommitted obligation")
            require(db.execute("SELECT payload FROM state WHERE k='value'").fetchone() == ('(list "symbol" "original")',),
                    "Close committed the unfinished replacement")
        with closing(sqlite3.connect((root / "unit/journal.sqlite.pending.sqlite").resolve().as_uri() + "?mode=ro", uri=True)) as db:
            require(db.execute("SELECT count(*) FROM terminals").fetchone() == (0,), "Cleanup fabricated endpoint termination")
    for name, digest in data["artifacts"].items():
        require(sha(root / name) == digest, "Read-only audit changed an artifact")
    args.output.write_text(json.dumps(dict(schema="context.owner-lifecycle.audit.v1", receipt_sha256=sha(args.receipt),
        auditor_sha256=sha(Path(__file__)), current_cut_verified=True, processes=processes,
        artifact_hashes_verified=len(data["artifacts"]), unbounded_capacity_proved=False), indent=2) + "\n")
    print("PASS: complete single-process cohorts, unchanged limits, native release and retained journal evidence")


if __name__ == "__main__":
    main()
