# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command-line export for no-Gerbil Scheme projection artifacts."""

from __future__ import annotations

import argparse
import sys
import time
from collections.abc import Sequence
from pathlib import Path
from typing import TextIO

from ._scheme_load import preproject_load
from ._scheme_load_artifact import SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA


def main(argv: Sequence[str] | None = None, stdout: TextIO | None = None) -> int:
    parser = _argument_parser()
    args = parser.parse_args(argv)
    output = stdout if stdout is not None else sys.stdout
    if args.command == "export":
        return _export(args, output)
    parser.error(f"unsupported command: {args.command}")
    return 2


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m agentic_ai_lab_runtime.scheme_projection_artifact",
        description="Export Scheme user-interface fragments as projection artifacts.",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    export = commands.add_parser(
        "export",
        help="write a no-Gerbil projection artifact for one Scheme module",
    )
    export.add_argument("source", help="Scheme user-interface source file")
    export.add_argument(
        "--cwd",
        default=None,
        help="Agentic AI Lab workspace root used for Gerbil package resolution",
    )
    export.add_argument(
        "--output",
        default=None,
        help="artifact path; defaults to SOURCE.agentic-ai-lab-projection.sexp",
    )
    export.add_argument(
        "--force",
        action="store_true",
        help="rewrite even when a matching artifact already exists",
    )
    return parser


def _export(args: argparse.Namespace, stdout: TextIO) -> int:
    source = Path(args.source).expanduser().resolve()
    workdir = Path(args.cwd).expanduser().resolve() if args.cwd else Path.cwd()
    output_path = Path(args.output).expanduser().resolve() if args.output else None
    started = time.perf_counter_ns()
    artifact = preproject_load(
        source,
        cwd=workdir,
        output=output_path,
        force=args.force,
    )
    elapsed_us = (time.perf_counter_ns() - started) // 1000
    stdout.write(
        _receipt(source=source, workdir=workdir, artifact=artifact, elapsed_us=elapsed_us)
        + "\n"
    )
    return 0


def _receipt(
    *,
    source: Path,
    workdir: Path,
    artifact: Path,
    elapsed_us: int,
) -> str:
    return (
        "|agentic-ai-lab-scheme-projection-artifact "
        f'(schema: "{SCHEME_LOAD_PROJECTION_ARTIFACT_SCHEMA}" '
        'action: "export" '
        f'source: "{_receipt_string(str(source))}" '
        f'cwd: "{_receipt_string(str(workdir))}" '
        f'artifact: "{_receipt_string(str(artifact))}" '
        f"elapsed-us: {elapsed_us})|"
    )


def _receipt_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


if __name__ == "__main__":
    raise SystemExit(main())
