# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Runtime launcher for a Bazel-declared Gerbil project environment."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from collections.abc import Sequence
from pathlib import Path

from packages.bazel.gerbil_environment import build_gerbil_environment


RUNTIME_SCHEMA = "agentic-ai-lab.gerbil-project-environment-runtime.v1"


def main(argv: Sequence[str] | None = None) -> int:
    args = _argument_parser().parse_args(argv)
    command = tuple(args.command)
    if command[:1] == ("--",):
        command = command[1:]
    if not command:
        raise SystemExit("a command is required after --")

    project_root = Path(args.project_root).resolve()
    gerbil_path = project_root / ".gerbil"
    dependency_root = Path(args.dependency_root_marker).resolve().parent
    project_dependency_roots = tuple(
        Path(root).resolve() for root in args.project_dependency_root
    )
    gxi = Path(args.gxi).resolve()
    native_scheme_env = Path(args.native_scheme_env).resolve()
    workspace = Path(args.workspace).resolve()
    working_directory = (workspace / args.working_directory).resolve()
    declaration_receipt = Path(args.declaration_receipt).resolve()
    project_receipt = Path(args.project_receipt).resolve()

    environment = build_gerbil_environment(
        gerbil_path=gerbil_path,
        dependency_root=dependency_root,
        project_dependency_roots=project_dependency_roots,
        gxi=gxi,
    )
    runtime_receipt = {
        "schema": RUNTIME_SCHEMA,
        "declarationReceipt": str(declaration_receipt),
        "projectReceipt": str(project_receipt),
        "gerbilPath": environment["GERBIL_PATH"],
        "gerbilLoadPath": environment["GERBIL_LOADPATH"],
        "gxi": str(gxi),
        "workingDirectory": str(working_directory),
    }
    environment.update(
        {
            "AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT": str(declaration_receipt),
            "AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT_JSON": json.dumps(
                runtime_receipt,
                separators=(",", ":"),
                sort_keys=True,
            ),
            "AGENTIC_AI_LAB_GERBIL_PROJECT_RECEIPT": str(project_receipt),
        }
    )
    native_command = (
        str(native_scheme_env),
        "env",
        *(f"{name}={environment[name]}" for name in _forwarded_environment_names()),
        *command,
    )
    completed = subprocess.run(
        native_command,
        cwd=working_directory,
        env=dict(os.environ),
        check=False,
    )
    return completed.returncode if completed.returncode >= 0 else 128 - completed.returncode


def _forwarded_environment_names() -> tuple[str, ...]:
    return (
        "GERBIL_PATH",
        "GERBIL_LOADPATH",
        "PATH",
        "AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT",
        "AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT_JSON",
        "AGENTIC_AI_LAB_GERBIL_PROJECT_RECEIPT",
    )


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gxi", required=True)
    parser.add_argument("--native-scheme-env", required=True)
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--project-receipt", required=True)
    parser.add_argument("--dependency-root-marker", required=True)
    parser.add_argument("--project-dependency-root", action="append", default=[])
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--working-directory", default="")
    parser.add_argument("--declaration-receipt", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    return parser


if __name__ == "__main__":
    raise SystemExit(main())
