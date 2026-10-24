#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Transport an existing locked Nix fixture into an unchanged native launcher.

This neither discovers tests nor admits their results. Just owns preparation;
the existing Core/ASP worker retains its heap, watchdog and result protocol.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path


def fixture_environment(inputs: Path) -> dict[str, str]:
    root = inputs.resolve(strict=True)
    families = (root / "families").resolve(strict=True)
    return {
        "AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS": str(root),
        "AGENTIC_AI_LAB_OPENTOFU_ARTIFACT": str(families),
        "AGENTIC_AI_LAB_OPENTOFU_FLAKE_ARTIFACT": str(families),
        "AGENTIC_AI_LAB_OPENTOFU_TEST_AWS_ONLY_ARTIFACT": str((root / "awsOnly").resolve(strict=True)),
        "AGENTIC_AI_LAB_OPENTOFU_TEST_REBUILT": str((root / "awsNull").resolve(strict=True)),
        "YUANXU_JSON_SCHEMA_AWS_EXPORT": str((families / "aws/schema.json").resolve(strict=True)),
        "AGENTIC_AI_LAB_OPENTOFU_TEST_PARENT_ARTIFACT": str((root / "parent").resolve(strict=True)),
        "AGENTIC_AI_LAB_OPENTOFU_TEST_CHILD_ARTIFACT": str((root / "child").resolve(strict=True)),
        "YUANXU_AWS_BINARY": str((root / "binary/provider").resolve(strict=True)),
        "AGENTIC_AI_LAB_NIX_TEST_TOOLS": (root / "tools").read_text().strip(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a heap-fenced native command is required")
    environment = os.environ.copy()
    environment.update(fixture_environment(args.inputs))
    os.execvpe(command[0], command, environment)


if __name__ == "__main__":
    main()
