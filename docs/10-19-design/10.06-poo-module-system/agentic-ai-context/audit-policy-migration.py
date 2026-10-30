#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Read-only audit of the complete bounded migration corpus and original inputs."""

import argparse
from contextlib import closing
import hashlib
import itertools
import json
from pathlib import Path
import re
import sqlite3

ROOT = Path(__file__).resolve().parents[4]
FIELD = re.compile(r'\(list "([^"]+)" \(list "(scalar|symbol)" ("(?:\\.|[^"\\])*"|#t|#f|-?\d+)\)\)')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scalars(payload):
    # The decision's inert wire projection contains scalar/symbol fields only.
    # This reads exact journal fields; it does not evaluate Scheme expressions.
    return {key: (value == "#t" if value in ("#t", "#f") else json.loads(value))
            for key, kind, value in FIELD.findall(payload)}


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
    require(data["schema"] == "context.policy-migration.native.v1" and data["exhaustive_declared_controlled_orders"],
            "Missing complete declared native corpus")
    for name, digest in {**data["source_sha256"], **data["binaries"]}.items():
        require(sha(ROOT / name) == digest, "Current source/object drift: " + name)
    for name, digest in data["artifacts"].items():
        require(sha(root / name) == digest, "Original artifact changed: " + name)
    legal = {p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)}
    counts = {}
    for profile in ("canonical", "legacy-cut", "legacy-missing"):
        controlled = [b for b in data["batches"] if b["profile"] == profile and b["mode"].startswith("chunk:")]
        live = next(b for b in data["batches"] if b["profile"] == profile and b["mode"] == "live")
        require(len(controlled) == 3 and {b["mode"] for b in controlled} == {"chunk:0", "chunk:1", "chunk:2"},
                "Missing fixed-size native chunk")
        paths = [p for b in controlled for p in b["paths"]]
        require(len(paths) == 60 and {tuple(p["actual"]) for p in paths} == legal,
                "Missing or duplicate controlled schedules: " + profile)
        require(len(live["paths"]) == 4, "Missing independently scheduled producer paths")
        accepted = 0
        for cohort in [*controlled, live]:
            folder = root / cohort["folder"]
            for index, path in enumerate(cohort["paths"]):
                require(tuple(path["actual"]) in legal, "Illegal actual causal order")
                db_path = folder / f"case-{index}.sqlite"
                with closing(sqlite3.connect(db_path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
                    payload = db.execute("SELECT payload FROM state WHERE k='policy-transition-decision:replace'").fetchone()[0]
                    decision = scalars(payload)
                    require(decision["kind"] == "context.policy-transition-decision.v1", "Wrong decision kind")
                    expected = profile != "legacy-missing" and decision["previous-generation"] == 1 and decision["previous-digest"] == decision["expected-digest"]
                    require(decision["accepted?"] == path["accepted"] == expected, "Actual journal violated original-cut CAS")
                    if cohort["mode"].startswith("chunk:"):
                        pos = {event: path["actual"].index(event) for event in range(1, 6)}
                        positional = profile != "legacy-missing" and pos[2] < min(pos[1], pos[3])
                        require(expected == positional, "Native CAS disagrees with queued-clock positional oracle")
                        require(db.execute("SELECT count(*) FROM terminals WHERE session='session'").fetchone() == (0,),
                                "An expired native result acquired a terminal")
                    if profile == "legacy-missing":
                        require(decision["reason"] == "missing-expected-cut" and decision["expected-generation"] is False,
                                "A missing historical expectation was inferred")
                    require(not db.execute("SELECT 1 FROM terminals GROUP BY session,attempt HAVING count(*)>1").fetchone(),
                            "Duplicate terminal across generations")
                    require(db.execute("SELECT status FROM inbox WHERE id='replace'").fetchone() == ("applied",),
                            "Legacy input remained pending")
                    require(db.execute("SELECT count(*) FROM versions WHERE event='replace' AND k='policy-transition-decision:replace'").fetchone() == (1,),
                            "Repeated or missing policy decision")
                    require(db.execute("SELECT count(*) FROM terminals WHERE session='session-c'").fetchone() == (1,),
                            "Independent C lacks its actual terminal")
                    accepted += int(expected)
        require((accepted == 0) if profile == "legacy-missing" else (0 < accepted < 64), "Vacuous CAS cohort")
        counts[profile] = dict(controlled=60, live=4, accepted=accepted, refused=64-accepted)
    require(len(data["crash_prefixes"]) == 6 and data["native_counterexamples"] == 1 and data["original_image_positive"],
            "Missing crash/replay controls")
    require({(c["profile"], c["stage"]) for c in data["crash_prefixes"]} ==
            {(p, s) for p in ("legacy-cut", "legacy-missing") for s in ("after-receive", "before-commit", "after-commit")},
            "Crash control matrix is incomplete")
    for item in data["crash_prefixes"]:
        require(item["signal"] == -9 and item["after"]["epoch"] == item["before"]["epoch"] + 1,
                "Crash recovery did not use a new owner")
        require(item["before"]["terminal_digests"] == item["after"]["terminal_digests"]
                and item["before"]["originals"] == item["after"]["originals"], "Crash changed original evidence")
        require(item["after"]["decision_writes"] == 1 and item["after"]["replacement_status"] == "applied",
                "Original legacy decision did not settle exactly once")
        image = root / f"crash-{item['profile']}-{item['stage']}" / "journal.sqlite"
        with closing(sqlite3.connect(image.resolve().as_uri() + "?mode=ro", uri=True)) as db:
            require(not db.execute("SELECT 1 FROM inbox WHERE id LIKE 'authority-recovery:%'").fetchone(),
                    "Legacy recovery invented a second authority input")
            payload = db.execute("SELECT payload FROM state WHERE k='policy-transition-decision:policy-replace'").fetchone()[0]
            decision = scalars(payload)
            require(decision["accepted?"] == (item["profile"] == "legacy-cut"), "Wrong crash migration outcome")
            if item["profile"] == "legacy-missing":
                require(decision["reason"] == "missing-expected-cut", "Missing-cut history was silently upgraded")
    for name, digest in data["artifacts"].items():
        require(sha(root / name) == digest, "Audit altered an original artifact")
    args.output.write_text(json.dumps(dict(schema="context.policy-migration.audit.v1",
        receipt_sha256=sha(args.receipt), auditor_sha256=sha(Path(__file__)), cohorts=counts,
        current_cut_verified=True, artifact_hashes_verified=len(data["artifacts"]),
        all_os_interleavings_proved=False), indent=2) + "\n")
    print("PASS: 180 controlled + 12 live paths, native CAS decisions, immutable crash evidence")


if __name__ == "__main__":
    main()
