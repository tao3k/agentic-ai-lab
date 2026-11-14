#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reject obsolete runtime-C Make producers from tracked project sources."""

from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
EXCLUDED = {
    "docs/10-19-design/10.06-poo-module-system/119-agentic-control-plane-ac06-qualification-receipt.org",
    "docs/10-19-design/10.06-poo-module-system/128-bazel-runtime-c-external-build-design.org",
    "t/qualification/runtime_c/build_boundary_test.py",
}
FORBIDDEN = (
    re.compile(r"make -C bindings/runtime-c"),
    re.compile(r"bindings/runtime-c/build/libagentic_ai_lab_runtime_v0"),
    re.compile(r"subprocess\.run\(\[\"make\""),
)


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    return [Path(value.decode()) for value in result.stdout.split(b"\0") if value]


class RuntimeCBuildBoundaryTest(unittest.TestCase):
    def test_no_stale_make_producer_route(self) -> None:
        findings: list[str] = []
        for relative in tracked_files():
            if str(relative) in EXCLUDED:
                continue
            path = REPO_ROOT / relative
            if not path.is_file():
                continue
            try:
                lines = path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            for line_number, line in enumerate(lines, start=1):
                if any(pattern.search(line) for pattern in FORBIDDEN):
                    findings.append(f"{relative}:{line_number}:{line.strip()}")
        self.assertEqual(
            findings, [], "stale runtime-C Make routes remain:\n" + "\n".join(findings)
        )


if __name__ == "__main__":
    unittest.main()
