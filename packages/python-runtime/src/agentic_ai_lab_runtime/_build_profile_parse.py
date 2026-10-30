# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Compile debug row parsing for build profile receipts."""

from __future__ import annotations

import re

from ._build_profile_model import CompileDebugRow


DEBUG_LINE_PREFIX = "|agentic-ai-lab-compile-debug "


def parse_compile_debug_rows(output: str) -> tuple[CompileDebugRow, ...]:
    rows: list[CompileDebugRow] = []
    for line in output.splitlines():
        row = _parse_compile_debug_line(line.lstrip())
        if row is not None:
            rows.append(row)
    return tuple(rows)


def _parse_compile_debug_line(line: str) -> CompileDebugRow | None:
    if not line.startswith(DEBUG_LINE_PREFIX):
        return None
    phase = _field(line, "phase")
    label = _field(line, "label")
    status = _field(line, "status")
    elapsed = _field(line, "elapsed-micros")
    if phase is None or label is None or status is None or elapsed is None:
        return None
    try:
        elapsed_micros = int(elapsed)
    except ValueError:
        return None
    return CompileDebugRow(
        phase=phase,
        label=label,
        status=status,
        elapsed_micros=elapsed_micros,
    )


def _field(debug_body: str, name: str) -> str | None:
    quoted = re.search(rf"{re.escape(name)}:\s+\"([^\"]*)\"", debug_body)
    if quoted:
        return quoted.group(1)
    bare = re.search(rf"{re.escape(name)}:\s+([^\s)]+)", debug_body)
    if bare:
        return bare.group(1)
    return None
