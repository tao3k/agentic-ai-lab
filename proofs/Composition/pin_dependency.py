#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Fetch the exact LeanPoo dependency even after its topic branch is deleted."""

import argparse
import re
import subprocess
import tomllib
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    project = parser.parse_args().project.resolve()
    config = tomllib.loads((project / "lakefile.toml").read_text())
    dependencies = [item for item in config["require"] if item["name"] == "LeanPoo"]
    if len(dependencies) != 1:
        raise SystemExit("expected exactly one pinned LeanPoo dependency")
    dependency = dependencies[0]
    revision = dependency["rev"]
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise SystemExit("LeanPoo requires a full immutable commit SHA")
    repository = project / ".lake/packages/LeanPoo"
    repository.mkdir(parents=True, exist_ok=True)

    def git(*args: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(repository), *args], text=True
        ).strip()

    if not (repository / ".git").exists():
        if any(repository.iterdir()):
            raise SystemExit("refusing to initialize a nonempty dependency directory")
        git("init", "--quiet")
        git("remote", "add", "origin", dependency["git"])
    if git("remote", "get-url", "origin") != dependency["git"]:
        raise SystemExit("LeanPoo origin differs from the declared dependency")
    if git("status", "--porcelain", "--untracked-files=no"):
        raise SystemExit("refusing to replace modified LeanPoo dependency sources")
    cached = subprocess.run(
        ["git", "-C", str(repository), "cat-file", "-e", f"{revision}^{{commit}}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if not cached:
        git("fetch", "--depth=1", "origin", revision)
        if git("rev-parse", "FETCH_HEAD") != revision:
            raise SystemExit("fetched dependency does not match the declared SHA")
    git("checkout", "--detach", revision)
    if git("rev-parse", "HEAD") != revision:
        raise SystemExit("checked-out dependency does not match the declared SHA")
    print(f"LeanPoo exact dependency verified: {revision}", flush=True)


if __name__ == "__main__":
    main()
