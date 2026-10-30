# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Thin multi-framework benchmark CLI."""

import argparse
import sys
from pathlib import Path

from .registry import all_cases, select_cases
from .report import render_json, render_org, render_text
from .runner import run_cases


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=2000)
    parser.add_argument("--warmup", type=int, default=200)
    parser.add_argument("--framework", action="append", default=[])
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--progress", action="store_true")
    parser.add_argument("--keep-gc", action="store_true")
    parser.add_argument("--format", choices=("text", "json", "org"), default="text")
    parser.add_argument("--report-org", type=Path)
    parser.add_argument("--fail-on-gap", action="store_true")
    args = parser.parse_args(argv)
    if args.list:
        for case in all_cases():
            sys.stdout.write(f"{case.family}\t{case.name}\n")
        return 0
    if args.iterations <= 0 or args.warmup < 0:
        parser.error("iterations must be positive and warmup non-negative")
    try:
        cases = select_cases(args.framework, args.case)
    except ValueError as exc:
        parser.error(str(exc))
    report = run_cases(
        cases, iterations=args.iterations, warmup=args.warmup,
        keep_gc=args.keep_gc, progress=args.progress,
    )
    org = render_org(report)
    if args.report_org:
        args.report_org.write_text(org + "\n", encoding="utf-8")
    sys.stdout.write(
        {"text": render_text, "json": render_json, "org": render_org}[
            args.format
        ](report) + "\n"
    )
    return 1 if args.fail_on_gap and report.failures else 0
