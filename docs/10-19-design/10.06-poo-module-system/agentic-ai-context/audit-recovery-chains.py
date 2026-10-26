#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Combine independently qualified recovery profiles without relabeling seeds."""

import argparse
import importlib.util
import json
from pathlib import Path


HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("recovery_gate", HERE / "run-native-query-recovery.py")
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)
gate = recovery.gate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    sources = recovery.source_cut()
    objects = gate.binaries()
    profiles = {}
    seed_digest = None
    for path in args.receipts:
        receipt = json.loads(path.read_text())
        if receipt["source_sha256"] != sources or receipt["binaries"] != objects:
            raise RuntimeError("Recovery receipt source/object cut is stale")
        if seed_digest and seed_digest != receipt["seed_receipt_sha256"]:
            raise RuntimeError("Recovery chains use different historical seed receipts")
        seed_digest = receipt["seed_receipt_sha256"]
        for name, digest in receipt["artifacts"].items():
            if gate.catalog.sha(path.parent / name) != digest:
                raise RuntimeError("Changed original recovery artifact: " + name)
        for chain in receipt["chains"]:
            profile = chain["profile"]
            if profile in profiles or len(chain["cuts"]) != 5:
                raise RuntimeError("Duplicate or incomplete recovery profile")
            db = path.parent / profile / "journal.sqlite"
            historical = []
            for number, cut in enumerate(chain["cuts"]):
                epoch = cut["after"]["epoch"]
                if epoch != chain["initial"]["epoch"] + number + 1:
                    raise RuntimeError("Recovery did not acquire a fresh writer epoch")
                if cut["kind"] != "ready":
                    continue
                actual = recovery.ready_record(db, epoch)
                if cut["stage"] == "before-commit":
                    if actual["status"] == "applied" or actual["decisions"] != 0:
                        raise RuntimeError("Failed old readiness was retroactively authorized")
                elif actual != dict(status="applied", decisions=1):
                    raise RuntimeError("Committed historical readiness was overwritten")
                historical.append(dict(epoch=epoch, boundary=cut["stage"], final_record=actual))
            final_epoch = chain["final"]["epoch"]
            if (final_epoch != chain["initial"]["epoch"] + 6
                    or recovery.ready_record(db, final_epoch) != dict(status="applied", decisions=1)):
                raise RuntimeError("Final owner has no own committed readiness")
            profiles[profile] = dict(receipt=str(path.resolve()), receipt_sha256=gate.catalog.sha(path),
                                     historical_readiness=historical, final_epoch=final_epoch)
    if set(profiles) != {"pending", "completed", "zero"}:
        raise RuntimeError("The declared three-profile recovery corpus is incomplete")
    result = dict(schema="context.query-recovery.corpus-audit.v1", profiles=profiles,
                  native_kills=15, final_native_recoveries=3,
                  seed_receipt_sha256=seed_digest, audit_sha256=gate.catalog.sha(Path(__file__)),
                  runtime_code_changed=False, exhaustive_os_scheduling=False)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: three native recovery profiles; 15 SIGKILLs; fresh current-epoch readiness")


if __name__ == "__main__":
    main()
