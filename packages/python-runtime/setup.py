# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Build the out-of-line CFFI extension and bundle the qualified C runtime."""

from __future__ import annotations

import os
from pathlib import Path
import platform
import shutil

from setuptools_rust import Binding, RustExtension
from setuptools import setup
from setuptools.command.build_py import build_py

RUNTIME_LIBRARY_ENV = "AGENTIC_AI_LAB_RUNTIME_V0_LIBRARY"


def _runtime_library() -> Path:
    configured = os.environ.get(RUNTIME_LIBRARY_ENV)
    if not configured:
        raise RuntimeError(
            f"{RUNTIME_LIBRARY_ENV} must name the Bazel-built runtime-v0 "
            "shared library"
        )
    library = Path(configured).expanduser().resolve()
    if not library.is_file():
        raise RuntimeError(f"Bazel runtime-v0 shared library is absent: {library}")
    return library


class BuildPyWithRuntime(build_py):
    def run(self) -> None:
        super().run()
        system = platform.system()
        library_name = {
            "Darwin": "libagentic_ai_lab_runtime_v0.dylib",
            "Windows": "agentic_ai_lab_runtime_v0.dll",
        }.get(system, "libagentic_ai_lab_runtime_v0.so")
        source = _runtime_library()
        target = Path(self.build_lib) / "agentic_ai_lab_runtime" / "_native" / "lib"
        target.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target / library_name)
        semantic = os.environ.get("AGENTIC_AI_LAB_SEMANTIC_LIBRARY")
        if semantic:
            semantic_source = Path(semantic).resolve()
            semantic_name = "libagentic_ai_lab_semantic.dylib" if system == "Darwin" else "libagentic_ai_lab_semantic.so"
            shutil.copy2(semantic_source, target / semantic_name)
            shutil.copy2(Path(str(semantic_source) + ".ss"), target / (semantic_name + ".ss"))


setup(
    rust_extensions=[RustExtension("agentic_ai_lab_runtime._reasoning",
        path="../../modules/evidence-assessment/native/Cargo.toml",
        binding=Binding.PyO3, features=["python", "extension-module"])],
    cffi_modules=["src/agentic_ai_lab_runtime/_native/_build.py:ffibuilder",
                  "src/agentic_ai_lab_runtime/_native/_semantic_build.py:ffibuilder",
                  "src/agentic_ai_lab_runtime/_native/_temporal_store_build.py:ffibuilder"],
    cmdclass={"build_py": BuildPyWithRuntime},
)
