# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed build profile rows and threshold failure records."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CompileDebugRow:
    phase: str
    label: str
    status: str
    elapsed_micros: int


@dataclass(frozen=True)
class BuildProfile:
    command: tuple[str, ...]
    exit_code: int
    wall_micros: int
    rows: tuple[CompileDebugRow, ...]

    @property
    def package_micros(self) -> int:
        package_rows = tuple(row for row in self.rows if row.phase == "package-total")
        if not package_rows:
            return 0
        return package_rows[-1].elapsed_micros

    @property
    def external_gap_micros(self) -> int:
        return max(0, self.wall_micros - self.package_micros)

    @property
    def slowest_rows(self) -> tuple[CompileDebugRow, ...]:
        return tuple(sorted(self.rows, key=lambda row: row.elapsed_micros, reverse=True))


@dataclass(frozen=True)
class ProfileGateFailure:
    metric: str
    actual_micros: int
    max_micros: int
