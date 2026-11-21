# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Default command resolution for build profile runs."""

from __future__ import annotations

import re
import shutil
from collections.abc import Sequence
from pathlib import Path


DEFAULT_BUILD_COMMAND = ("gxpkg", "build", "-g")


def build_profile_command(command_args: Sequence[str]) -> tuple[str, ...]:
    if command_args:
        return tuple(command_args)
    return resolve_gxpkg_command(DEFAULT_BUILD_COMMAND)


def resolve_gxpkg_command(command: Sequence[str]) -> tuple[str, ...]:
    command_tuple = tuple(command)
    if not command_tuple or command_tuple[0] != "gxpkg":
        return command_tuple
    launcher = shutil.which("gxpkg")
    if launcher is None:
        return command_tuple
    resolved = _shell_exec_target(Path(launcher))
    if resolved is None:
        return command_tuple
    return (str(resolved), *command_tuple[1:])


def _shell_exec_target(path: Path) -> Path | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    match = re.search(r'^\s*exec\s+"([^"]+)"\s+"\$@"\s*$', text, re.MULTILINE)
    if match is None:
        return None
    target = Path(match.group(1))
    if not target.is_file():
        return None
    return target
