# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Exact file dependencies for frozen study producers; never execute imports."""

from __future__ import annotations

import ast
from importlib.resources import files
from importlib.util import resolve_name
from pathlib import Path
from collections.abc import Mapping


def _module_file(name: str, package_root: Path) -> Path | None:
    """Resolve only this source package, without loading optional providers."""
    prefix = package_root.name
    if name != prefix and not name.startswith(prefix + "."):
        return None
    path = package_root.parent.joinpath(*name.split("."))
    for candidate in (path.with_suffix(".py"), path / "__init__.py"):
        if candidate.is_file():
            return candidate.resolve()
    return None


def _source_files(
    paths: Mapping[str, Path], package_root: Path | None = None
) -> dict[str, Path]:
    """Retain declared inputs and add their statically reachable Python bytes."""
    package_root = (
        package_root or Path(str(files("agentic_ai_lab_testing")))
    ).resolve()
    # Keep each existing source label, with one entry per physical source file.
    declared = {Path(path).resolve(): name for name, path in paths.items()}
    # A declared study producer includes its CLI; imported helpers do not
    # acquire unrelated command entrypoints from transitive packages.
    for source in tuple(declared):
        command = source.parent / "__main__.py"
        if (
            source.suffix == ".py"
            and source.is_relative_to(package_root)
            and command.is_file()
        ):
            declared.setdefault(command.resolve(), str(command.resolve()))
    pending = list(declared)
    seen: set[Path] = set()
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        if path.suffix != ".py" or not path.is_relative_to(package_root):
            continue
        relative = path.relative_to(package_root)
        package = ".".join((package_root.name, *relative.parent.parts))
        dependencies: set[Path] = set()
        # Python initializes parent packages before importing their members.
        parent = path.parent
        while parent.is_relative_to(package_root):
            entry = parent / "__init__.py"
            if entry.is_file():
                dependencies.add(entry.resolve())
            if parent == package_root:
                break
            parent = parent.parent
        for node in ast.walk(ast.parse(path.read_bytes())):
            names: list[str] = []
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                base = (
                    resolve_name("." * node.level + (node.module or ""), package)
                    if node.level
                    else (node.module or "")
                )
                names = [base, *(base + "." + alias.name for alias in node.names)]
            for name in names:
                dependency = _module_file(name, package_root)
                if dependency is not None:
                    dependencies.add(dependency)
        for dependency in sorted(dependencies):
            if dependency not in declared:
                declared[dependency] = str(dependency)
            if dependency not in seen:
                pending.append(dependency)
    return {name: path for path, name in sorted(declared.items())}


def _study_module_file(name: str) -> Path:
    """Locate current study source by its canonical package identity."""
    root = Path(str(files("agentic_ai_lab_testing"))).resolve()
    source = _module_file("agentic_ai_lab_testing.assessment_studies." + name, root)
    if source is None:
        raise FileNotFoundError("study source is absent: " + name)
    return source


def _source_hashes(paths: Mapping[str, Path]) -> dict[str, str]:
    """Hash declared evidence and every reachable implementation source."""
    from hashlib import sha256

    return {
        name: sha256(path.read_bytes()).hexdigest()
        for name, path in _source_files(paths).items()
    }


def _source_label(path: Path, root: Path) -> str:
    """Keep repository labels while naming separately installed code honestly."""
    path = path.resolve()
    root = root.resolve()
    return str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
