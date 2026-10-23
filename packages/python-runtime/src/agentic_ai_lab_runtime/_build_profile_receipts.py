# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Receipt formatting for build profile measurements and gates."""

from __future__ import annotations

from collections.abc import Sequence

from ._build_profile_model import BuildProfile, ProfileGateFailure


def build_profile_receipt(profile: BuildProfile, *, slowest_limit: int = 5) -> str:
    command = " ".join(profile.command)
    slowest = " ".join(
        (
            f"(phase: {row.phase} label: {_sexpr_string(row.label)} "
            f"status: {row.status} elapsed-micros: {row.elapsed_micros})"
        )
        for row in profile.slowest_rows[:slowest_limit]
    )
    return (
        "|agentic-ai-lab-build-profile "
        "(schema: \"agentic-ai-lab.build-profile.v1\" "
        f"command: {_sexpr_string(command)} "
        f"exit-code: {profile.exit_code} "
        f"wall-micros: {profile.wall_micros} "
        f"internal-package-micros: {profile.package_micros} "
        f"external-gap-micros: {profile.external_gap_micros} "
        f"compile-debug-rows: {len(profile.rows)} "
        f"slowest: ({slowest}))"
    )


def build_profile_gate_receipt(failures: Sequence[ProfileGateFailure]) -> str:
    status = "pass" if not failures else "fail"
    failure_rows = " ".join(
        (
            f"(metric: {failure.metric} actual-micros: {failure.actual_micros} "
            f"max-micros: {failure.max_micros})"
        )
        for failure in failures
    )
    return (
        "|agentic-ai-lab-build-profile-gate "
        "(schema: \"agentic-ai-lab.build-profile-gate.v1\" "
        f"status: {status} failure-count: {len(failures)} "
        f"failures: ({failure_rows}))"
    )


def _sexpr_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
    return f"\"{escaped}\""
