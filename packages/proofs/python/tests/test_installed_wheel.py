# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).parents[4]
PACKAGE_ROOT = Path(__file__).parents[1]
VECTOR = REPO_ROOT / "packages/proofs/vectors/proof_case_vector_v1_positive.hex"
CONSUMER = Path(__file__).with_name("installed_wheel_consumer.py")
BENCHMARK = PACKAGE_ROOT / "benchmarks/proof_case_cffi_benchmark.py"


def test_installed_wheel_consumes_public_c_abi(tmp_path: Path) -> None:
    if sys.platform == "win32":
        pytest.skip("runtime-C installed wheel gate currently targets POSIX hosts")
    dist = tmp_path / "dist"
    subprocess.run(
        ["uv", "build", "--wheel", "--out-dir", str(dist)],
        cwd=PACKAGE_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    wheel = next(dist.glob("agentic_ai_lab_proof-*.whl"))

    environment = tmp_path / "venv"
    subprocess.run(
        ["uv", "venv", "--python", sys.executable, str(environment)],
        check=True,
        capture_output=True,
        text=True,
    )
    python = environment / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    subprocess.run(
        ["uv", "pip", "install", "--python", str(python), str(wheel)],
        check=True,
        capture_output=True,
        text=True,
    )

    library = tmp_path / (
        "agentic_ai_lab_proof.dll"
        if sys.platform == "win32"
        else "libagentic_ai_lab_proof.dylib"
        if sys.platform == "darwin"
        else "libagentic_ai_lab_proof.so"
    )
    link_mode = "-dynamiclib" if sys.platform == "darwin" else "-shared"
    subprocess.run(
        [
            "cc",
            "-std=c11",
            "-O2",
            "-fPIC",
            link_mode,
            "-I",
            str(REPO_ROOT / "bindings/runtime-c/include"),
            str(REPO_ROOT / "bindings/runtime-c/src/proof_case_v1.c"),
            "-o",
            str(library),
        ],
        check=True,
    )

    consumer_env = os.environ.copy()
    consumer_env.pop("PYTHONPATH", None)
    completed = subprocess.run(
        [
            str(python),
            str(CONSUMER),
            "--library",
            str(library),
            "--vector",
            str(VECTOR),
            "--forbid-root",
            str(REPO_ROOT),
        ],
        cwd=tmp_path,
        env=consumer_env,
        check=True,
        capture_output=True,
        text=True,
    )

    assert "installed-wheel-consumer: version=0.1.0 size=424" in completed.stdout
    assert "digest=41c5ef60ac9296a28e045f7e26d975cf46a34cab69f56dc7ab4d7091fe1ff557" in (
        completed.stdout
    )
    assert "site-packages" in completed.stdout

    benchmark = subprocess.run(
        [
            str(python),
            str(BENCHMARK),
            "--library",
            str(library),
            "--vector",
            str(VECTOR),
            "--iterations",
            "2",
            "--max-batch",
            "8",
        ],
        cwd=tmp_path,
        env=consumer_env,
        check=True,
        capture_output=True,
        text=True,
    )
    assert "path=installed-wheel-caller-owned" in benchmark.stdout
    assert "crossings-per-item-steady=3" in benchmark.stdout
    assert "layout-measurements=1" in benchmark.stdout
    assert "caller-output-allocations-per-item=0" in benchmark.stdout
