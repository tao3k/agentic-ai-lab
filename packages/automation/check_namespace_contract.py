#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Reject obsolete product identities in maintained sources and source paths.

Recorded execution evidence keeps its original bytes and identities. It cannot
qualify a renamed build; current consumers must be rebuilt and tested separately.
"""
from __future__ import annotations

import re
import json
import sys
from pathlib import Path

from check_license_contract import ROOT, project_files, git_output

OBSOLETE = re.compile(r"poo[-_ ]?flow", re.IGNORECASE)
EVIDENCE_SUFFIXES = {".log", ".receipt", ".snapshot", ".gz"}
SOURCE_SUFFIXES = {
    ".ss", ".scm", ".pkg", ".py", ".rs", ".c", ".cc", ".h", ".pc",
    ".toml", ".bzl", ".bazel", ".nix", ".just", ".yml", ".yaml", ".lean",
    ".qnt", ".mjs", ".ts", ".json", ".lock", ".md", ".org", ".txt",
}


def evidence(path: Path) -> bool:
    dated_qualification = path.parts[:2] == ("t", "qualification") and any(
        re.match(r"20\d\d-\d\d-\d\d(?:-|$)", part) for part in path.parts[2:])
    return path.suffix in EVIDENCE_SUFFIXES or "evidence" in path.parts or dated_qualification


def issues(path: Path) -> list[str]:
    relative = path.relative_to(ROOT)
    if evidence(relative):
        return []
    failures = []
    if OBSOLETE.search(str(relative)):
        failures.append(f"{relative}: obsolete source path")
    if path.suffix not in SOURCE_SUFFIXES and path.name not in {"Justfile", "Dockerfile"}:
        return failures
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return failures
    for number, line in enumerate(text.splitlines(), 1):
        # An existing PR's Git ref is immutable identity, not an import/export.
        line = line.replace("research/ascent-" + "poo" + "-flow", "existing-pr-ref")
        if OBSOLETE.search(line):
            failures.append(f"{relative}:{number}: obsolete product identity")
    return failures


def main() -> int:
    files = set(project_files())
    failures = [issue for path in sorted(files) for issue in issues(path)]
    core_revision = git_output("ls-files", "--stage", "core").split()[1]
    failures.extend(proof_pin_issues(
        core_revision,
        (ROOT / "packages/proofs/lean/lakefile.lean").read_text(),
        json.loads((ROOT / "packages/proofs/lean/lake-manifest.json").read_text())))
    for failure in failures:
        print(f"namespace-contract: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(f"namespace-contract: ok ({len(files)} files; original evidence excluded)")
    return 0


def proof_pin_issues(revision: str, declaration: str, manifest: dict) -> list[str]:
    source = re.search(r'require YuanxuProof from git\s+"([^"]+)"\s+@ "([0-9a-f]{40})"', declaration)
    packages = [p for p in manifest["packages"] if p["name"] == "YuanxuProof"]
    expected_url = "https://github.com/tao3k/gebril-yuanxu.git"
    if not source or source.groups() != (expected_url, revision):
        return ["Yuanxu proof declaration must match the Core gitlink"]
    if len(packages) != 1 or any(packages[0].get(k) != v for k, v in {
        "type": "git", "url": expected_url, "rev": revision, "subDir": "dev/proofs/lean"
    }.items()):
        return ["Yuanxu proof lock must match the published Core revision"]
    return []


if __name__ == "__main__":
    raise SystemExit(main())
