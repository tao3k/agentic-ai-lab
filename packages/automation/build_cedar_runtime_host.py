#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Build the Cedar runtime host from its Rust and Lean owners."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    profile = os.environ.get("AGENTIC_AI_LAB_CEDAR_BUILD_PROFILE", "release")
    if profile not in {"dev", "release"}:
        parser.error("AGENTIC_AI_LAB_CEDAR_BUILD_PROFILE must be dev or release")

    workspace = ROOT / "bindings/cedar-gerbil"
    proof = ROOT / "packages/proofs/lean"
    cargo_target = Path(os.environ.get("CARGO_TARGET_DIR", workspace / "target"))
    cargo_args = [
        "cargo", "build", "--locked", "--manifest-path", str(workspace / "Cargo.toml"),
        "-p", "agentic-ai-lab-cedar-authority", "--features", "aot-runtime-host", "--lib",
    ]
    if profile == "release":
        cargo_args.append("--release")
    subprocess.run(cargo_args, check=True)

    archive_profile = "release" if profile == "release" else "debug"
    archive = cargo_target / archive_profile / "libagentic_ai_lab_cedar_authority.a"
    if not archive.is_file():
        raise SystemExit(f"Cargo did not produce the declared runtime core archive: {archive}")

    env = os.environ.copy()
    env["AGENTIC_AI_LAB_CEDAR_RUNTIME_CORE_ARCHIVE"] = str(archive)
    subprocess.run(["lake", "build", "cedarRuntimeHost"], cwd=proof, env=env, check=True)

    host = proof / ".lake/build/bin/cedarRuntimeHost"
    if not host.is_file() or not os.access(host, os.X_OK):
        raise SystemExit(f"Lake did not produce the declared Runtime Host: {host}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(host, args.output)
    args.output.chmod(0o755)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
