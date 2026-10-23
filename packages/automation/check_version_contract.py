#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Validate every first-party release projection against root VERSION."""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEMVER = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def release_version(root: Path = ROOT) -> tuple[str, tuple[int, int, int]]:
    value = (root / "VERSION").read_text(encoding="utf-8").strip()
    match = SEMVER.fullmatch(value)
    if match is None:
        raise ValueError("VERSION must contain one canonical semantic version")
    return value, tuple(int(part) for part in match.groups())


def nested(payload: object, *keys: str) -> object:
    value = payload
    for key in keys:
        if not isinstance(value, dict) or key not in value:
            raise KeyError(".".join(keys))
        value = value[key]
    return value


def expect(errors: list[str], label: str, actual: object, expected: object) -> None:
    if actual != expected:
        errors.append(f"{label}: expected {expected!r}, found {actual!r}")


def regex_value(path: Path, pattern: str, label: str) -> str:
    match = re.search(pattern, path.read_text(encoding="utf-8"), re.MULTILINE | re.DOTALL)
    if match is None:
        raise ValueError(f"{label}: version declaration is absent")
    return match.group(1)


def collect_errors(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    try:
        version, (major, minor, _patch) = release_version(root)
    except (OSError, ValueError) as error:
        return [str(error)]

    try:
        module_version = regex_value(
            root / "MODULE.bazel",
            r'module\(\s*name\s*=\s*"agentic_ai_lab"\s*,\s*version\s*=\s*"([^"]+)"',
            "MODULE.bazel",
        )
        expect(errors, "MODULE.bazel agentic_ai_lab version", module_version, version)

        toml_versions = (
            ("bindings/cedar-gerbil/Cargo.toml", ("workspace", "package", "version")),
            ("bindings/rust-ir/Cargo.toml", ("package", "version")),
            ("packages/proofs/python/pyproject.toml", ("project", "version")),
            ("packages/python-runtime/pyproject.toml", ("project", "version")),
        )
        for relative, keys in toml_versions:
            payload = tomllib.loads((root / relative).read_text(encoding="utf-8"))
            expect(errors, relative, nested(payload, *keys), version)

        for relative in (
            "bindings/runtime-ts/package.json",
            "bindings/runtime-wasm/package.json",
        ):
            payload = json.loads((root / relative).read_text(encoding="utf-8"))
            expect(errors, relative, nested(payload, "version"), version)

        lock_path = root / "bindings/runtime-ts/package-lock.json"
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
        expect(errors, "bindings/runtime-ts/package-lock.json", nested(lock, "version"), version)
        expect(
            errors,
            "bindings/runtime-ts/package-lock.json root package",
            nested(lock, "packages", "", "version"),
            version,
        )

        pkgconfig_version = regex_value(
            root / "bindings/runtime-c/pkgconfig/agentic-ai-lab-runtime-v0.pc",
            r"^Version:\s*(\S+)$",
            "runtime-v0 pkg-config",
        )
        expect(errors, "runtime-v0 pkg-config", pkgconfig_version, version)

        scheme_path = root / "modules/workflow/contracts/runtime-v0-abi-schema.ss"
        scheme_major = int(regex_value(scheme_path, r"\(abi-major\s+([0-9]+)\)", "Scheme ABI major"))
        scheme_minor = int(regex_value(scheme_path, r"\(abi-minor\s+([0-9]+)\)", "Scheme ABI minor"))
        expect(errors, "Scheme ABI major", scheme_major, major)
        expect(errors, "Scheme ABI minor", scheme_minor, minor)

        python_path = root / "packages/python-runtime/src/agentic_ai_lab_runtime/_protocol_person_abi_schema.py"
        python_major = int(regex_value(python_path, r"^ABI_MAJOR\s*=\s*([0-9]+)$", "Python ABI major"))
        python_minor = int(regex_value(python_path, r"^ABI_MINOR\s*=\s*([0-9]+)$", "Python ABI minor"))
        expect(errors, "Python ABI major", python_major, major)
        expect(errors, "Python ABI minor", python_minor, minor)

        header_path = root / "bindings/runtime-c/include/agentic_ai_lab/runtime_v0_contract.h"
        header_major = int(regex_value(header_path, r"^#define AGENTIC_AI_LAB_RUNTIME_V0_ABI_MAJOR ([0-9]+)u$", "C ABI major"))
        header_minor = int(regex_value(header_path, r"^#define AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR ([0-9]+)u$", "C ABI minor"))
        expect(errors, "C ABI major", header_major, major)
        expect(errors, "C ABI minor", header_minor, minor)

        for relative in (
            "bindings/runtime-c/tests/vectors/runtime_v0_contract.txt",
            "t/fixtures/runtime-language-abi/promotion-request-v1.vector",
        ):
            path = root / relative
            vector_major = int(regex_value(path, r"^abi-major=([0-9]+)$", f"{relative} ABI major"))
            vector_minor = int(regex_value(path, r"^abi-minor=([0-9]+)$", f"{relative} ABI minor"))
            expect(errors, f"{relative} ABI major", vector_major, major)
            expect(errors, f"{relative} ABI minor", vector_minor, minor)
    except (KeyError, OSError, ValueError, tomllib.TOMLDecodeError, json.JSONDecodeError) as error:
        errors.append(str(error))
    return errors


def main() -> int:
    errors = collect_errors()
    if errors:
        for error in errors:
            sys.stderr.write(f"version-contract: {error}\n")
        return 1
    version, _ = release_version()
    sys.stdout.write(f"version-contract: ok ({version})\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
