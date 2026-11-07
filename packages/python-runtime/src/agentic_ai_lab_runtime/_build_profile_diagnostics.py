# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Launcher baseline diagnostics for build profile receipts."""

from __future__ import annotations

import subprocess
import time
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


class _BuildProfileLike(Protocol):
    command: tuple[str, ...]

    @property
    def external_gap_micros(self) -> int: ...


@dataclass(frozen=True)
class LauncherDiagnostic:
    command: tuple[str, ...]
    exit_code: int | None
    wall_micros: int
    error: str | None = None


def build_profile_launcher_diagnostic_receipt(
    profile: _BuildProfileLike,
    diagnostic: LauncherDiagnostic,
) -> str:
    profile_command = " ".join(profile.command)
    command = " ".join(diagnostic.command)
    exit_code = "none" if diagnostic.exit_code is None else str(diagnostic.exit_code)
    error = diagnostic.error or ""
    return (
        "|agentic-ai-lab-build-profile-launcher-diagnostic "
        "(schema: \"agentic-ai-lab.build-profile-launcher-diagnostic.v1\" "
        f"profile-command: {_sexpr_string(profile_command)} "
        f"command: {_sexpr_string(command)} "
        f"exit-code: {exit_code} "
        f"wall-micros: {diagnostic.wall_micros} "
        f"external-gap-micros: {profile.external_gap_micros} "
        "external-gap-share-permille: "
        f"{_permille(diagnostic.wall_micros, profile.external_gap_micros)} "
        f"error: {_sexpr_string(error)})"
    )


def run_launcher_diagnostic(command: Sequence[str], *, cwd: Path) -> LauncherDiagnostic:
    started = time.perf_counter_ns()
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            capture_output=True,
        )
    except OSError as exc:
        finished = time.perf_counter_ns()
        return LauncherDiagnostic(
            command=tuple(command),
            exit_code=None,
            wall_micros=(finished - started) // 1000,
            error=f"{type(exc).__name__}: {exc}",
        )
    finished = time.perf_counter_ns()
    return LauncherDiagnostic(
        command=tuple(command),
        exit_code=result.returncode,
        wall_micros=(finished - started) // 1000,
    )


def default_launcher_diagnostic_command(command: Sequence[str]) -> tuple[str, ...]:
    if not command:
        return ("gxpkg", "--help")
    return (command[0], "--help")


def _permille(numerator: int, denominator: int) -> int:
    if denominator <= 0:
        return 0
    return round(numerator * 1000 / denominator)


def _sexpr_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
    return f"\"{escaped}\""
