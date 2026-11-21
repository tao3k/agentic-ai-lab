#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run a Gerbil command with the package-local load path."""

from __future__ import annotations

import argparse
import os
import platform
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _darwin_environment(env: dict[str, str]) -> None:
    developer_dir = env.get("DEVELOPER_DIR", "")
    sdkroot = env.get("SDKROOT", "")
    refresh_developer = not developer_dir or developer_dir.startswith("/nix/store/") or not Path(developer_dir).is_dir()
    if refresh_developer:
        clean = {key: value for key, value in env.items() if key not in {"DEVELOPER_DIR", "SDKROOT"}}
        developer_dir = subprocess.check_output(
            ["/usr/bin/xcode-select", "--print-path"], env=clean, text=True
        ).strip()
    if refresh_developer or not sdkroot or sdkroot.startswith("/nix/store/") or not Path(sdkroot).is_dir():
        clean = {key: value for key, value in env.items() if key != "SDKROOT"}
        clean["DEVELOPER_DIR"] = developer_dir
        sdkroot = subprocess.check_output(
            ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"],
            env=clean,
            text=True,
        ).strip()
    env["DEVELOPER_DIR"] = developer_dir
    env["SDKROOT"] = sdkroot


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-first", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command:
        parser.error("a Gerbil command is required")

    env = os.environ.copy()
    system = platform.system()
    if system == "Darwin":
        _darwin_environment(env)
    elif system != "Linux":
        parser.error(f"unsupported Gerbil host system: {system}")

    source_root = ROOT.parent
    build_library = ROOT / ".gerbil/lib"
    local_paths = [str(source_root), str(build_library)] if args.source_first else [str(build_library), str(source_root)]
    if env.get("GERBIL_LOADPATH"):
        local_paths.append(env["GERBIL_LOADPATH"])
    overrides = [f"GERBIL_LOADPATH={os.pathsep.join(local_paths)}"]
    if system == "Darwin":
        overrides.extend(
            [f"DEVELOPER_DIR={env['DEVELOPER_DIR']}", f"SDKROOT={env['SDKROOT']}"]
        )
    return subprocess.call(["gxpkg", "env", "env", *overrides, *args.command], env=env)


if __name__ == "__main__":
    raise SystemExit(main())
