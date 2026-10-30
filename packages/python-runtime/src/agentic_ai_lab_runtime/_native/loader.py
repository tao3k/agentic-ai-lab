# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Locate and negotiate a bundled or explicitly overridden runtime-v0 library."""

from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import sys

from .errors import NativeRuntimeLoadError

RUNTIME_LIBRARY_ENV = "AGENTIC_AI_LAB_RUNTIME_V0_LIBRARY"
BUNDLE_SCHEMA = b"agentic-ai-lab.organization-bundle.draft.3"


@dataclass(frozen=True)
class NativeRuntimeHealth:
    library_path: Path
    abi_major: int
    abi_minor: int
    capabilities: int
    max_payload_bytes: int


def _bundled_library_name() -> str:
    if sys.platform == "darwin":
        return "libagentic_ai_lab_runtime_v0.dylib"
    if sys.platform == "win32":
        return "agentic_ai_lab_runtime_v0.dll"
    return "libagentic_ai_lab_runtime_v0.so"


def native_library_path() -> Path:
    override = os.environ.get(RUNTIME_LIBRARY_ENV)
    if override:
        return Path(override).expanduser().resolve()
    return Path(__file__).parent / "lib" / _bundled_library_name()


def probe_native_runtime(
    *, library_path: str | os.PathLike[str] | None = None
) -> NativeRuntimeHealth:
    try:
        from ._runtime_v0_cffi import ffi, lib
    except ImportError as exc:
        raise NativeRuntimeLoadError("out-of-line CFFI extension is unavailable") from exc
    path = Path(library_path).resolve() if library_path is not None else native_library_path()
    if not path.is_file():
        raise NativeRuntimeLoadError(f"native runtime library is absent: {path}")
    schema = ffi.new("uint8_t[]", BUNDLE_SCHEMA)
    identity_bytes = b"agentic-ai-lab-python-runtime"
    identity = ffi.new("uint8_t[]", identity_bytes)
    health = ffi.new("agentic_ai_lab_python_runtime_v0_health *")
    ok = lib.agentic_ai_lab_python_runtime_v0_probe(
        os.fsencode(path),
        schema,
        len(BUNDLE_SCHEMA),
        identity,
        len(identity_bytes),
        health,
    )
    if not ok:
        message = ffi.string(health.error).decode("utf-8", "replace")
        raise NativeRuntimeLoadError(message, status=int(health.status))
    return NativeRuntimeHealth(
        library_path=path,
        abi_major=int(health.abi_major),
        abi_minor=int(health.abi_minor),
        capabilities=int(health.capabilities),
        max_payload_bytes=int(health.max_payload_bytes),
    )
