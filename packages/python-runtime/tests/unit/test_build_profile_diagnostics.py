# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tests for build profile launcher diagnostics."""

from __future__ import annotations

from agentic_ai_lab_runtime import build_profile


def test_build_profile_launcher_diagnostic_receipt_reports_baseline_share() -> None:
    profile = build_profile.BuildProfile(
        command=("gxpkg", "build", "-g"),
        exit_code=0,
        wall_micros=10_000_000,
        rows=(
            build_profile.CompileDebugRow(
                phase="package-total",
                label="agentic-ai-lab",
                status="ok",
                elapsed_micros=1_000_000,
            ),
        ),
    )
    diagnostic = build_profile.LauncherDiagnostic(
        command=("gxpkg", "--help"),
        exit_code=0,
        wall_micros=6_000_000,
    )

    receipt = build_profile.build_profile_launcher_diagnostic_receipt(
        profile,
        diagnostic,
    )

    assert "agentic-ai-lab.build-profile-launcher-diagnostic.v1" in receipt
    assert 'profile-command: "gxpkg build -g"' in receipt
    assert 'command: "gxpkg --help"' in receipt
    assert "external-gap-micros: 9000000" in receipt
    assert "external-gap-share-permille: 667" in receipt


def test_build_profile_main_diagnoses_external_gap_failure(
    monkeypatch,
    tmp_path,
    capsys,
) -> None:
    observed_commands: list[tuple[str, ...]] = []

    def fake_build_profile_command(command: tuple[str, ...]) -> tuple[str, ...]:
        return ("gxpkg", "build", "-g")

    def fake_run_profile(
        command: tuple[str, ...],
        *,
        cwd: object,
    ) -> build_profile.BuildProfile:
        return build_profile.BuildProfile(
            command=tuple(command),
            exit_code=0,
            wall_micros=10_000_000,
            rows=(
                build_profile.CompileDebugRow(
                    phase="package-total",
                    label="agentic-ai-lab",
                    status="ok",
                    elapsed_micros=1_000_000,
                ),
            ),
        )

    def fake_run_launcher_diagnostic(
        command: tuple[str, ...],
        *,
        cwd: object,
    ) -> build_profile.LauncherDiagnostic:
        observed_commands.append(tuple(command))
        return build_profile.LauncherDiagnostic(
            command=tuple(command),
            exit_code=0,
            wall_micros=6_000_000,
        )

    monkeypatch.setattr(
        build_profile,
        "build_profile_command",
        fake_build_profile_command,
    )
    monkeypatch.setattr(build_profile, "run_profile", fake_run_profile)
    monkeypatch.setattr(
        build_profile,
        "run_launcher_diagnostic",
        fake_run_launcher_diagnostic,
    )

    exit_code = build_profile.main(
        [
            "--cwd",
            str(tmp_path),
            "--max-external-gap-seconds",
            "1",
        ],
    )

    captured = capsys.readouterr()
    assert exit_code == 1
    assert observed_commands == [("gxpkg", "--help")]
    assert "agentic-ai-lab.build-profile-launcher-diagnostic.v1" in captured.out


def test_build_profile_main_diagnoses_on_request_without_gate_failure(
    monkeypatch,
    tmp_path,
    capsys,
) -> None:
    observed_commands: list[tuple[str, ...]] = []

    def fake_run_profile(
        command: tuple[str, ...],
        *,
        cwd: object,
    ) -> build_profile.BuildProfile:
        return build_profile.BuildProfile(
            command=tuple(command),
            exit_code=0,
            wall_micros=1_000_000,
            rows=(
                build_profile.CompileDebugRow(
                    phase="package-total",
                    label="agentic-ai-lab",
                    status="ok",
                    elapsed_micros=900_000,
                ),
            ),
        )

    def fake_run_launcher_diagnostic(
        command: tuple[str, ...],
        *,
        cwd: object,
    ) -> build_profile.LauncherDiagnostic:
        observed_commands.append(tuple(command))
        return build_profile.LauncherDiagnostic(
            command=tuple(command),
            exit_code=1,
            wall_micros=100_000,
        )

    monkeypatch.setattr(build_profile, "run_profile", fake_run_profile)
    monkeypatch.setattr(
        build_profile,
        "run_launcher_diagnostic",
        fake_run_launcher_diagnostic,
    )

    exit_code = build_profile.main(
        [
            "--cwd",
            str(tmp_path),
            "--diagnose-launcher",
            "custom-gxpkg",
            "build",
            "-g",
        ],
    )

    captured = capsys.readouterr()
    assert exit_code == 0
    assert observed_commands == [("custom-gxpkg", "--help")]
    assert "agentic-ai-lab.build-profile-launcher-diagnostic.v1" in captured.out
