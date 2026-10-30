# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
from pathlib import Path

from agentic_ai_lab_proof.lean_declaration_closure import _source_roots


def test_source_roots_include_active_toolchain_sources(tmp_path: Path) -> None:
    lean_root = tmp_path / "proof"
    lean_root.mkdir()

    package_root = tmp_path / "dependency"
    package_lib = package_root / ".lake" / "build" / "lib" / "lean"
    package_lib.mkdir(parents=True)

    toolchain_root = tmp_path / "toolchain"
    toolchain_lib = toolchain_root / "lib" / "lean"
    toolchain_source = toolchain_root / "src" / "lean"
    toolchain_lib.mkdir(parents=True)
    toolchain_source.mkdir(parents=True)

    roots = _source_roots(
        lean_root,
        os.pathsep.join((str(package_lib), str(toolchain_lib))),
    )

    assert roots == (
        lean_root.resolve(),
        package_root.resolve(),
        toolchain_source.resolve(),
    )


def test_source_roots_ignore_binary_only_toolchain_entries(tmp_path: Path) -> None:
    lean_root = tmp_path / "proof"
    lean_root.mkdir()

    binary_only_toolchain = tmp_path / "binary-toolchain" / "lib" / "lean"
    binary_only_toolchain.mkdir(parents=True)

    assert _source_roots(lean_root, str(binary_only_toolchain)) == (
        lean_root.resolve(),
    )
