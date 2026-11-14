# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Single-process Scheme load probe used by benchmark subprocess cases."""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

from .._scheme_load import load_projection_rows


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    source = Path(args.source).expanduser().resolve()
    workdir = Path(args.cwd).expanduser().resolve()
    started = time.perf_counter_ns()
    rows = load_projection_rows(
        source,
        cwd=workdir,
        cache=_flag_enabled(args.cache),
        projection_artifact=_flag_enabled(args.artifact),
        aot=_flag_enabled(args.aot),
    )
    elapsed_us = (time.perf_counter_ns() - started) // 1000
    sys.stdout.write(
        "|agentic-ai-lab-scheme-load-once "
        '(schema: "agentic-ai-lab.scheme-load-once.v1" '
        f'source: "{_receipt_string(str(source))}" '
        f'cwd: "{_receipt_string(str(workdir))}" '
        f"rows: {len(rows)} "
        f"elapsed-us: {elapsed_us})|\n"
    )
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load one Scheme user-interface fragment for benchmark sampling."
    )
    parser.add_argument("--source", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--cache", choices=("on", "off"), default="off")
    parser.add_argument("--artifact", choices=("on", "off"), default="on")
    parser.add_argument("--aot", choices=("on", "off"), default="on")
    return parser.parse_args(argv)


def _flag_enabled(value: str) -> bool:
    return value == "on"


def _receipt_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


if __name__ == "__main__":
    raise SystemExit(main())
