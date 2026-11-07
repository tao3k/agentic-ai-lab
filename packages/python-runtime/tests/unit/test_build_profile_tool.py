# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from pathlib import Path
from typing import Sequence

from agentic_ai_lab_runtime import build_profile


def test_build_profile_parses_compile_debug_rows() -> None:
    output = """
    |agentic-ai-lab-compile-debug (phase: package-stage label: "runtime" status: skipped elapsed-micros: 42)
    |agentic-ai-lab-compile-debug (phase: package-total label: "package" status: completed elapsed-micros: 100)
    """

    rows = build_profile.parse_compile_debug_rows(output)

    assert tuple(row.label for row in rows) == ("runtime", "package")
    assert rows[-1].phase == "package-total"
    assert rows[-1].elapsed_micros == 100


def test_build_profile_receipt_reports_external_gap() -> None:
    profile = build_profile.BuildProfile(
        command=("gxpkg", "build", "-g"),
        exit_code=0,
        wall_micros=250,
        rows=(
            build_profile.CompileDebugRow(
                phase="package-total",
                label="package",
                status="completed",
                elapsed_micros=100,
            ),
        ),
    )

    receipt = build_profile.build_profile_receipt(profile)

    assert "internal-package-micros: 100" in receipt
    assert "external-gap-micros: 150" in receipt


def test_build_profile_receipt_escapes_command_strings() -> None:
    profile = build_profile.BuildProfile(
        command=("gxpkg", "build", '"quoted"'),
        exit_code=0,
        wall_micros=1,
        rows=(),
    )

    receipt = build_profile.build_profile_receipt(profile)

    assert 'command: "gxpkg build \\"quoted\\""' in receipt


def test_build_profile_gate_reports_threshold_failures() -> None:
    profile = build_profile.BuildProfile(
        command=("gxpkg", "build", "-g"),
        exit_code=0,
        wall_micros=2_000_000,
        rows=(
            build_profile.CompileDebugRow(
                phase="package-total",
                label="package",
                status="completed",
                elapsed_micros=1_500_000,
            ),
        ),
    )

    failures = build_profile.evaluate_profile_thresholds(
        profile,
        max_wall_seconds=1,
        max_package_seconds=1,
        max_external_gap_seconds=0.1,
    )
    receipt = build_profile.build_profile_gate_receipt(failures)

    assert tuple(failure.metric for failure in failures) == (
        "wall",
        "package",
        "external-gap",
    )
    assert "status: fail" in receipt
    assert "failure-count: 3" in receipt


def test_build_profile_gate_passes_when_thresholds_hold() -> None:
    profile = build_profile.BuildProfile(
        command=("gxpkg", "build", "-g"),
        exit_code=0,
        wall_micros=500_000,
        rows=(
            build_profile.CompileDebugRow(
                phase="package-total",
                label="package",
                status="completed",
                elapsed_micros=300_000,
            ),
        ),
    )

    failures = build_profile.evaluate_profile_thresholds(
        profile,
        max_wall_seconds=1,
        max_package_seconds=1,
        max_external_gap_seconds=1,
    )

    assert failures == ()
    assert "status: pass" in build_profile.build_profile_gate_receipt(failures)


def test_build_profile_main_fails_when_gate_fails(monkeypatch, tmp_path, capsys) -> None:
    def fake_build_profile_command(command: Sequence[str]) -> tuple[str, ...]:
        return ("gxpkg", "build", "-g")

    def fake_run_profile(
        command: Sequence[str],
        *,
        cwd: Path,
    ) -> build_profile.BuildProfile:
        assert tuple(command) == ("gxpkg", "build", "-g")
        assert cwd == tmp_path
        return build_profile.BuildProfile(
            command=tuple(command),
            exit_code=0,
            wall_micros=2_000_000,
            rows=(
                build_profile.CompileDebugRow(
                    phase="package-total",
                    label="package",
                    status="completed",
                    elapsed_micros=1_500_000,
                ),
            ),
        )

    monkeypatch.setattr(
        build_profile,
        "build_profile_command",
        fake_build_profile_command,
    )
    monkeypatch.setattr(build_profile, "run_profile", fake_run_profile)

    exit_code = build_profile.main(
        [
            "--cwd",
            str(tmp_path),
            "--max-package-seconds",
            "1",
        ]
    )

    output = capsys.readouterr().out
    assert exit_code == 1
    assert "agentic-ai-lab.build-profile.v1" in output
    assert "status: fail" in output


def test_build_profile_main_preserves_wrapped_command_failure(monkeypatch) -> None:
    def fake_run_profile(
        command: Sequence[str],
        *,
        cwd: Path,
    ) -> build_profile.BuildProfile:
        return build_profile.BuildProfile(
            command=tuple(command),
            exit_code=7,
            wall_micros=10,
            rows=(),
        )

    monkeypatch.setattr(build_profile, "run_profile", fake_run_profile)

    assert build_profile.main(["false"]) == 7
