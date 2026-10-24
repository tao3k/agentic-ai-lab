# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Build profile receipt generation for the Agentic AI Lab package."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from collections.abc import Iterable, Sequence
from pathlib import Path

from ._build_profile_command import build_profile_command
from ._build_profile_diagnostics import (
    LauncherDiagnostic,
    build_profile_launcher_diagnostic_receipt,
    default_launcher_diagnostic_command,
    run_launcher_diagnostic,
)
from ._build_profile_gates import evaluate_profile_thresholds
from ._build_profile_model import BuildProfile, CompileDebugRow, ProfileGateFailure
from ._build_profile_parse import parse_compile_debug_rows
from ._build_profile_receipts import build_profile_gate_receipt, build_profile_receipt


def run_profile(command: Sequence[str], *, cwd: Path) -> BuildProfile:
    started = time.perf_counter_ns()
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
    )
    finished = time.perf_counter_ns()
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return BuildProfile(
        command=tuple(command),
        exit_code=result.returncode,
        wall_micros=(finished - started) // 1000,
        rows=parse_compile_debug_rows(result.stdout + result.stderr),
    )


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Profile gxpkg build wall time against Agentic AI Lab debug rows.",
    )
    parser.add_argument(
        "--cwd",
        type=Path,
        default=Path.cwd(),
        help="Workspace directory to run the build command in.",
    )
    parser.add_argument(
        "--max-wall-seconds",
        type=float,
        default=None,
        help="Fail when total wall time exceeds this threshold.",
    )
    parser.add_argument(
        "--max-package-seconds",
        type=float,
        default=None,
        help="Fail when internal package compile time exceeds this threshold.",
    )
    parser.add_argument(
        "--max-external-gap-seconds",
        type=float,
        default=None,
        help="Fail when wall time outside package compile exceeds this threshold.",
    )
    parser.add_argument(
        "--diagnose-launcher",
        action="store_true",
        help=(
            "Also time the build command launcher baseline. External-gap gate "
            "failures enable this diagnostic automatically."
        ),
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Build command. Defaults to: gxpkg build -g",
    )
    return parser.parse_args(None if argv is None else tuple(argv))


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    command = build_profile_command(args.command)
    profile = run_profile(command, cwd=args.cwd)
    sys.stdout.write(build_profile_receipt(profile) + "\n")
    failures = evaluate_profile_thresholds(
        profile,
        max_wall_seconds=args.max_wall_seconds,
        max_package_seconds=args.max_package_seconds,
        max_external_gap_seconds=args.max_external_gap_seconds,
    )
    sys.stdout.write(build_profile_gate_receipt(failures) + "\n")
    if args.diagnose_launcher or _has_external_gap_failure(failures):
        diagnostic = run_launcher_diagnostic(
            default_launcher_diagnostic_command(command),
            cwd=args.cwd,
        )
        sys.stdout.write(
            build_profile_launcher_diagnostic_receipt(profile, diagnostic) + "\n",
        )
    if profile.exit_code == 0 and failures:
        return 1
    return profile.exit_code


def _has_external_gap_failure(failures: Sequence[ProfileGateFailure]) -> bool:
    return any(failure.metric == "external-gap" for failure in failures)


if __name__ == "__main__":
    raise SystemExit(main())
