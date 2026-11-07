# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tests for build-profile command resolution."""

from __future__ import annotations

from agentic_ai_lab_runtime import _build_profile_command as command_profile


def test_build_profile_command_preserves_explicit_command() -> None:
    command = command_profile.build_profile_command(("custom", "build"))

    assert command == ("custom", "build")


def test_build_profile_command_resolves_gxpkg_shell_exec_wrapper(
    monkeypatch,
    tmp_path,
) -> None:
    real_gxpkg = tmp_path / "real-gxpkg"
    wrapper = tmp_path / "gxpkg"
    real_gxpkg.write_text("#!/bin/sh\n", encoding="utf-8")
    wrapper.write_text(
        "#!/bin/sh\n"
        "export GERBIL_HOME=/tmp/gerbil\n"
        f"exec \"{real_gxpkg}\" \"$@\"\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(command_profile.shutil, "which", lambda name: str(wrapper))

    command = command_profile.build_profile_command(())

    assert command == (str(real_gxpkg), "build", "-g")


def test_build_profile_command_keeps_default_when_wrapper_target_is_missing(
    monkeypatch,
    tmp_path,
) -> None:
    wrapper = tmp_path / "gxpkg"
    wrapper.write_text(
        "#!/bin/sh\n"
        f"exec \"{tmp_path / 'missing-gxpkg'}\" \"$@\"\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(command_profile.shutil, "which", lambda name: str(wrapper))

    command = command_profile.build_profile_command(())

    assert command == ("gxpkg", "build", "-g")
