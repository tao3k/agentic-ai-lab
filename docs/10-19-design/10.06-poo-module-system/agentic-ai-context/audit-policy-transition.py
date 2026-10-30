#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Audit saved native policy evidence without launching or mutating an owner."""

import argparse
from contextlib import closing
import hashlib
import json
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[4]
BAD = re.compile(r"ERROR (?:CASE|CHECK|HARNESS|MODULE)|Heap overflow|Stack overflow|\*\*\* ERROR")
TRACE = re.compile(r"POLICY-ORDER owner=\(([1-5 ]+)\) arrival=\(([1-5 ]+)\)")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value, message):
    if not value:
        raise RuntimeError(message)


def rows(path):
    # Read-only mode prevents audit from silently creating a missing database.
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
        return dict(
            inbox=db.execute("SELECT payload,digest,status FROM inbox WHERE id='policy-replace'").fetchone(),
            writes=db.execute("SELECT k,count(*) FROM versions WHERE event='policy-replace' GROUP BY k").fetchall(),
            terminals=db.execute("SELECT session,attempt,generation,digest FROM terminals ORDER BY session,attempt,generation").fetchall())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads(args.receipt.read_text())
    root = args.receipt.parent
    require(receipt["schema"] == "context.policy-transition.native.v1", "Wrong native receipt schema")
    require(receipt["complete_declared_corpus"] and len(receipt["cases"]) == 5,
            "The declared five-prefix corpus was not executed")
    require(receipt["original_image_replayed"] and receipt["native_counterexamples"] == 1,
            "Missing original-image positive or native negative control")
    for name, digest in {**receipt["source_sha256"], **receipt["binaries"]}.items():
        require(sha(ROOT / name) == digest, "Current source/object drift: " + name)
    for name, digest in receipt["artifacts"].items():
        require(sha(root / name) == digest, "Evidence artifact changed: " + name)
    for log in root.rglob("*.log"):
        require(not BAD.search(log.read_text()), "Native error marker: " + str(log))
    require("POLICY-COUNTER pending-replacement=#t cached-a=admitted" in
            (root / "counter-no-replay/counter.log").read_text().splitlines(),
            "Missing actual unsafe restoration observation")
    for label in ("original-replay", "counter-no-replay"):
        mode = "counter" if label == "counter-no-replay" else "post"
        lines = (root / label / (mode + ".log")).read_text().splitlines()
        require(all(marker in lines for marker in (
                    "MODULE-OK t/context-policy-durable-test.ss", "HARNESS-OK context-policy-durable", "OK"))
                and lines[-1] == "OK", "Missing original-image native harness markers")
    results = []
    for index, case in enumerate(receipt["cases"]):
        folder = root / f"case-{index:02d}"
        matches = [m for line in (folder / "pre.log").read_text().splitlines()
                   if (m := TRACE.fullmatch(line))]
        require(len(matches) == 1, "Missing actual producer trace")
        order, arrival = ([int(x) for x in matches[0][i].split()] for i in (1, 2))
        require(all(sorted(seq) == [1, 2, 3, 4, 5] and seq.index(4) < seq.index(5)
                    for seq in (order, arrival)), "Invalid causal producer trace")
        pos = {event: order.index(event) for event in order}
        expected = 1 + int(pos[2] < min(pos[1], pos[4])) + int(pos[3] < pos[1])
        before, after = rows(folder / "crash.sqlite"), rows(folder / "journal.sqlite")
        require(len(before["terminals"]) == expected and before["terminals"] == after["terminals"],
                "Terminal count/original terminal digests changed")
        require(before["inbox"][:2] == after["inbox"][:2] and after["inbox"][2] == "applied",
                "Original input bytes changed or were not applied")
        committed = case["stage"] == "after-commit"
        require(before["inbox"][2] == ("applied" if committed else "pending"), "Wrong crash image cut")
        for key in ("policies", "policy-revisions", "context", "policy-transition-decision:policy-replace"):
            require(dict(after["writes"]).get(key) == 1, "Decision did not commit exactly once: " + key)
            require(dict(before["writes"]).get(key, 0) == int(committed), "Partial crash commit: " + key)
        require(case["before"]["originals"] == case["after"]["originals"], "Raw original evidence changed")
        require(case["after"]["epoch"] == case["before"]["epoch"] + 1 and case["signal"] == -9,
                "Recovery did not use a new owner after SIGKILL")
        results.append(dict(case=index, actual_owner=order, actual_arrival=arrival,
                            expected_terminals=expected, terminal_digests_retained=True,
                            original_input_retained=True, atomic_once=True))
    # Reopening SQLite must not invalidate the original stable artifact inventory.
    for name, digest in receipt["artifacts"].items():
        require(sha(root / name) == digest, "Audit changed a stable artifact: " + name)
    args.output.write_text(json.dumps(dict(
        schema="context.policy-transition.audit.v1", receipt_sha256=sha(args.receipt),
        auditor_sha256=sha(Path(__file__)), current_cut_verified=True, cases=results,
        artifact_hashes_verified=len(receipt["artifacts"]), exhaustive_concurrency=False), indent=2) + "\n")
    print("PASS: current native cut, immutable evidence, atomic policy decisions and terminal oracle")


if __name__ == "__main__":
    main()
