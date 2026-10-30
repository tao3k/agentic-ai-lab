# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command-line AOT warmup for Scheme user-interface loading."""

from __future__ import annotations

import argparse
import sys
import time
from collections.abc import Sequence
from pathlib import Path
from typing import TextIO

from ._scheme_load import precompile_load
from ._scheme_load_aot import scheme_aot_artifact
from ._scheme_load_cache import scheme_load_cache_key
from ._scheme_load_runner import runtime_projection_source


SCHEME_LOAD_AOT_RECEIPT_SCHEMA = "agentic-ai-lab.scheme-load-aot.v1"


def main(argv: Sequence[str] | None = None, stdout: TextIO | None = None) -> int:
    parser = _argument_parser()
    args = parser.parse_args(argv)
    output = stdout if stdout is not None else sys.stdout
    if args.command == "precompile":
        return _precompile(args, output)
    parser.error(f"unsupported command: {args.command}")
    return 2


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m agentic_ai_lab_runtime.scheme_load_aot",
        description="Precompile Scheme user-interface fragments into Gerbil AOT runners.",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    precompile = commands.add_parser(
        "precompile",
        help="compile a Scheme load projection runner for one user module",
    )
    precompile.add_argument("source", help="Scheme user-interface source file")
    precompile.add_argument(
        "--cwd",
        default=None,
        help="Agentic AI Lab workspace root used for Gerbil package resolution",
    )
    precompile.add_argument(
        "--force",
        action="store_true",
        help="rebuild even when the fingerprint-matched runner already exists",
    )
    return parser


def _precompile(args: argparse.Namespace, stdout: TextIO) -> int:
    source = Path(args.source).expanduser().resolve()
    workdir = Path(args.cwd).expanduser().resolve() if args.cwd else Path.cwd()
    projection = runtime_projection_source(workdir)
    cache_key = scheme_load_cache_key(source, workdir, projection)
    artifact = scheme_aot_artifact(workdir, cache_key)
    should_rebuild = bool(args.force or not artifact.binary.exists())

    started = time.perf_counter_ns()
    binary = precompile_load(source, cwd=workdir, force=args.force)
    elapsed_us = (time.perf_counter_ns() - started) // 1000

    stdout.write(
        _receipt(
            source=source,
            workdir=workdir,
            binary=binary,
            rebuilt=should_rebuild,
            elapsed_us=elapsed_us,
        )
        + "\n"
    )
    return 0


def _receipt(
    *,
    source: Path,
    workdir: Path,
    binary: Path,
    rebuilt: bool,
    elapsed_us: int,
) -> str:
    return (
        "|agentic-ai-lab-scheme-load-aot "
        f'(schema: "{SCHEME_LOAD_AOT_RECEIPT_SCHEMA}" '
        'action: "precompile" '
        f'source: "{_receipt_string(str(source))}" '
        f'cwd: "{_receipt_string(str(workdir))}" '
        f'binary: "{_receipt_string(str(binary))}" '
        f"rebuilt?: {_scheme_bool(rebuilt)} "
        f"elapsed-us: {elapsed_us})|"
    )


def _receipt_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _scheme_bool(value: bool) -> str:
    if value:
        return "#t"
    return "#f"


if __name__ == "__main__":
    raise SystemExit(main())
