#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Audit actual crash prefixes and durable outcomes independently of the driver.

Events after the killed source command are planned suffixes, not executions.
The positional oracle below checks committed worker results without replaying
the native reducer or trusting a generic success marker alone.
"""

import argparse
import importlib.util
import json
from pathlib import Path
import re


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("source_gate", HERE / "run-native-query-durable.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
ORDER = re.compile(r"QUERY-DURABLE-ORDER owner=\(([1-5 ]+)\) arrival=\(([1-5 ]*)\)")


def order_value(text):
    return [int(value) for value in text.split()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads(args.receipt.read_text())
    out = args.receipt.parent
    if receipt["source_sha256"] != gate.sources() or receipt["binaries"] != gate.binaries():
        raise RuntimeError("Native source/object receipt is stale")
    for name, digest in receipt["artifacts"].items():
        if gate.catalog.sha(out / name) != digest:
            raise RuntimeError("Changed native evidence: " + name)

    results = []
    for case in receipt["cases"]:
        key = (case["profile"], case["stage"], case["requested_order"])
        index = gate.CASES.index(key)
        folder = out / f"case-{index:02d}"
        observed = [m for line in (folder / "pre.log").read_text().splitlines()
                    if (m := ORDER.fullmatch(line))]
        if len(observed) != 1:
            raise RuntimeError("Missing exact owner/arrival trace")
        order = order_value(observed[0][1])
        arrival = order_value(observed[0][2])
        if case["requested_order"] == "arrival":
            if order != arrival:
                raise RuntimeError("Observed-arrival path used another owner order")
        elif order != order_value(case["requested_order"].strip("()")):
            raise RuntimeError("Requested owner order was not executed")

        if case["profile"] == "zero":
            if order != [1] or arrival:
                raise RuntimeError("Zero-consumer case fabricated producers")
            expected_terminals = 0
        else:
            for sequence in (order, arrival):
                if sorted(sequence) != [1, 2, 3, 4, 5] or sequence.index(4) > sequence.index(5):
                    raise RuntimeError("Invalid independent producer trace")
            positions = {event: order.index(event) for event in order}
            completed_a = positions[2] < min(positions[1], positions[4])
            completed_b = positions[3] < positions[1]
            expected_terminals = 1 + int(completed_a) + int(completed_b)

        # C really completed before this prefix. A/B completions are durable
        # only if their events precede withdrawal (and cancellation for A).
        if (case["before"]["terminals"] != expected_terminals
                or case["after"]["terminals"] != expected_terminals):
            raise RuntimeError("Native terminal ledger violates the independent prefix oracle")
        split = order.index(1) + 1
        results.append(dict(profile=case["profile"], stage=case["stage"],
                            owner_order=order, actual_arrival=arrival,
                            executed_prefix=order[:split],
                            planned_unexecuted_suffix=order[split:],
                            expected_durable_terminals=expected_terminals))

    result = dict(schema="context.query-source.prefix-audit.v1", cases=results,
                  receipt_sha256=gate.catalog.sha(args.receipt),
                  audit_sha256=gate.catalog.sha(Path(__file__)))
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(results)} actual owner/arrival prefixes and terminal-ledger oracles")


if __name__ == "__main__":
    main()
