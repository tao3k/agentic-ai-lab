#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Install and verify the pinned Gerbil release artifact for CI."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import subprocess
from pathlib import Path


from gerbil_dependency_pin import declared_toolchain

ROOT = Path(__file__).resolve().parents[2]
DARWIN_REVISION = "1cfb032c7a1612637da6205f5f8a15683eba3ba0"
DARWIN_RELEASE = (
    "darwin", "aarch64", DARWIN_REVISION,
    f"https://github.com/tao3k/gerbil-bazel/releases/download/gerbil-v0.19-{DARWIN_REVISION}-darwin-aarch64-gcc16-arm64-aot-tools-single-host-unlimited-multiple-vms-patch618d76f9eb72/gerbil-v0.19-{DARWIN_REVISION}-darwin-aarch64-gcc16-arm64-aot-tools-single-host-unlimited-multiple-vms-patch618d76f9eb72.tar.gz",
    "0e18d063f888a73d9f9692d441fb3776898114e8440eada6876937d289578183",
)


def release_configuration(host: tuple[str, str]) -> tuple[str, str, str, str, str]:
    if host == ("Darwin", "arm64"):
        return DARWIN_RELEASE
    if host != ("Linux", "x86_64"):
        raise ValueError(f"unsupported Gerbil release host: {host[0]}-{host[1]}")
    sdk = declared_toolchain(ROOT)
    urls = sdk["linux_prebuilt_urls"]
    if len(urls) != 1:
        raise ValueError("native Linux SDK declaration must select one immutable release URL")
    return ("linux", "x86_64", sdk["linux_prebuilt_release_revision"],
            urls[0], sdk["linux_prebuilt_sha256"])


def _digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def _activated_environment(path: Path) -> dict[str, str]:
    # The upstream artifact owns this shell-format activation file. Only read
    # its exported environment; all install/validation flow remains Python.
    output = subprocess.check_output(
        [
            "bash", "-c",
            'set -e; source "$1" >/dev/null; export GERBIL_PREFIX GERBIL_HOME GAMBOPT; env -0',
            "bash", str(path),
        ]
    )
    return dict(item.decode().split("=", 1) for item in output.split(b"\0") if item)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("release_root", type=Path)
    args = parser.parse_args()
    host = (platform.system(), platform.machine())
    release_os, release_arch, revision, url, expected_digest = release_configuration(host)
    runner_temp = os.environ.get("RUNNER_TEMP")
    if not runner_temp:
        parser.error("RUNNER_TEMP is required")
    archive = Path(runner_temp) / url.rsplit("/", 1)[1]
    root = args.release_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["curl", "--fail", "--location", "--retry", "3", "--retry-all-errors",
         "--output", str(archive),
         url],
        check=True,
    )
    if _digest(archive) != expected_digest:
        raise SystemExit(f"Gerbil release SHA-256 mismatch: {archive}")
    subprocess.run(["tar", "-xzf", str(archive), "-C", str(root), "--strip-components=1"], check=True)

    receipt = json.loads((root / "gerbil-toolchain-release.json").read_text(encoding="utf-8"))
    if not (
        receipt.get("schema") == "gerbil-bazel.toolchain-release.v1"
        and receipt.get("upstreamRevision") == revision
        and receipt.get("platform", {}).get("os") == release_os
        and receipt.get("platform", {}).get("arch") == release_arch
    ):
        raise SystemExit("Gerbil release receipt does not match the pinned host and revision")

    env = _activated_environment(root / "activate")
    prefix = env["GERBIL_PREFIX"]
    with Path(os.environ["GITHUB_PATH"]).open("a", encoding="utf-8") as output:
        output.write(f"{prefix}/bin\n")
    with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as output:
        for key in ("GERBIL_PREFIX", "GERBIL_HOME", "GAMBOPT"):
            output.write(f"{key}={env[key]}\n")
    subprocess.run([f"{prefix}/bin/gerbil", "--version"], env=env, check=True)
    subprocess.run(
        [f"{prefix}/bin/gerbil", "interactive", "-e", '(displayln "gerbil-ready")'],
        env=env,
        check=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
