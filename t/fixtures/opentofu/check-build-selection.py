#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Check real derivation dependencies; store cache hits are not evidence."""
import argparse
import json
import subprocess
from pathlib import Path


def closure(drv):
    return set(subprocess.check_output(
        ["nix-store", "--query", "--requisites", drv], text=True).splitlines())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selected-drv", required=True)
    parser.add_argument("--selected-out", required=True)
    parser.add_argument("--all-drv", required=True)
    parser.add_argument("--catalog", required=True)
    args = parser.parse_args()
    catalog = json.loads(Path(args.catalog).read_text())
    selected = closure(args.selected_drv)
    complete = closure(args.all_drv)
    aws = closure(catalog["aws"]["drv"])
    assert catalog["aws"]["drv"] in selected
    assert set(Path(args.selected_out).iterdir()) == {Path(args.selected_out) / "aws"}
    assert (Path(args.selected_out) / "aws").resolve() == Path(catalog["aws"]["out"])
    excluded = {}
    for name in ("awscc", "null"):
        drv = catalog[name]["drv"]
        assert drv in complete, f"positive control missing {name}"
        assert drv not in selected, f"unselected Schema dependency {name}"
        unique = closure(drv) - aws
        assert unique and unique.isdisjoint(selected), f"unselected build dependencies {name}"
        excluded[name] = {"schema_drv": drv, "excluded_dependency_paths": len(unique)}
    print(json.dumps({
        "selected_drv": args.selected_drv, "selected_out": args.selected_out,
        "all_drv": args.all_drv, "providers": ["aws"],
        "excluded": excluded, "derivation_closure_verified": True,
        "cache_hit_used_as_evidence": False,
    }, indent=2))


if __name__ == "__main__":
    main()
