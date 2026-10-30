#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Regress existing source/grant controls on the qualified policy production cut."""

import argparse
import importlib.util
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("grant_gate", HERE / "run-native-grant-revocation.py")
grant = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grant)
source = grant.base
ROOT = grant.ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy-receipt", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    args = parser.parse_args()
    receipt = json.loads(args.policy_receipt.read_text())
    args.artifacts.mkdir(parents=True, exist_ok=False)
    expected = {**receipt["source_sha256"], **receipt["binaries"]}

    def check_cut():
        for name, digest in expected.items():
            if source.catalog.sha(ROOT / name) != digest:
                raise RuntimeError("Policy-qualified source/object drift: " + name)

    check_cut()
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / ".gerbil"),
               GERBIL_LOADPATH=f"{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib")
    # Gerbil processes remain serial under the repository's pre-import fence.
    grant_case = grant.run_case(args.artifacts / "grant", "before-commit", "(2 1 3 4 5)", env)
    source_case = source.run_case(args.artifacts / "source", ("withdraw", "before-commit", "(2 1 3 4 5)"), env)
    for db in args.artifacts.rglob("*.sqlite"):
        grant.recovery.stabilize_database(db)
    check_cut()
    result = dict(schema="context.policy-transition.regression.v1",
                  policy_receipt_sha256=source.catalog.sha(args.policy_receipt),
                  runner_sha256=source.catalog.sha(Path(__file__)),
                  source_sha256=receipt["source_sha256"], binaries=receipt["binaries"],
                  grant_crash_prefix=grant_case, source_crash_prefix=source_case,
                  artifacts={str(p.relative_to(args.artifacts)): source.catalog.sha(p)
                             for p in sorted(args.artifacts.rglob("*"))
                             if grant.recovery.durable_artifact(p)})
    (args.artifacts / "regression-receipt.json").write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: source and grant crash/recovery compatibility on the policy production cut")


if __name__ == "__main__":
    main()
