# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import json
from pathlib import Path
import subprocess

import pytest

from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    LeanDeclarationClosure,
    export_declaration_closure,
    resolve_owner_sources,
)


def closure_payload() -> dict[str, object]:
    return {
        "base_imports": ["Init"],
        "proof_base_imports": [],
        "proof_base_interface": [],
        "declarations": [
            {
                "kind": "structure",
                "local_dependencies": [],
                "name": "Example.Claims",
                "owner_module": "Example.Core",
            },
            {
                "kind": "theorem",
                "local_dependencies": ["Example.Claims"],
                "name": "Example.safe",
                "owner_module": "Example.Root",
            },
        ],
        "lean_version": "4.31.0",
        "owner_modules": ["Example.Core", "Example.Root"],
        "root_declarations": ["Example.safe"],
        "root_module": "Example.Root",
        "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
    }


def completed(
    args: object,
    *,
    returncode: int = 0,
    stdout: str = "",
    stderr: str = "",
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=args,
        returncode=returncode,
        stdout=stdout,
        stderr=stderr,
    )


def test_closure_digest_is_deterministic() -> None:
    first = LeanDeclarationClosure.from_mapping(closure_payload())
    second = LeanDeclarationClosure.from_json(
        json.dumps(closure_payload(), indent=2)
    )

    assert first.closure_digest == second.closure_digest
    assert first.owner_modules_in_dependency_order() == (
        "Example.Core",
        "Example.Root",
    )


def test_non_topological_closure_fails_closed() -> None:
    payload = closure_payload()
    declarations = payload["declarations"]
    assert isinstance(declarations, list)
    declarations.reverse()

    with pytest.raises(
        LeanClosureError,
        match="non-topological-declaration",
    ):
        LeanDeclarationClosure.from_mapping(payload)


def test_root_outside_closure_fails_closed() -> None:
    payload = closure_payload()
    payload["root_declarations"] = ["Example.missing"]

    with pytest.raises(LeanClosureError, match="root-outside-closure"):
        LeanDeclarationClosure.from_mapping(payload)


def test_exporter_builds_root_before_running_lean(tmp_path: Path) -> None:
    calls: list[list[str]] = []

    def runner(
        command: list[str],
        **_: object,
    ) -> subprocess.CompletedProcess[str]:
        calls.append(command)
        if command[:2] == ["lake", "build"]:
            return completed(command)
        return completed(command, stdout=json.dumps(closure_payload()))

    closure = export_declaration_closure(
        lean_root=tmp_path,
        root_module="Example.Root",
        root_declarations=("Example.safe",),
        runner=runner,
    )

    assert closure.root_declarations == ("Example.safe",)
    assert calls == [
        [
            "lake",
            "build",
            "Example.Root",
            "agenticAiLabDeclarationClosure",
        ],
        [
            "lake",
            "env",
            ".lake/build/bin/agenticAiLabDeclarationClosure",
            "--root-module",
            "Example.Root",
            "--root-declaration",
            "Example.safe",
        ],
    ]


def test_lake_build_failure_is_actionable(tmp_path: Path) -> None:
    def runner(
        command: list[str],
        **_: object,
    ) -> subprocess.CompletedProcess[str]:
        return completed(command, returncode=1, stderr="unknown module")

    with pytest.raises(LeanClosureError, match="lake-build-failed"):
        export_declaration_closure(
            lean_root=tmp_path,
            root_module="Example.Missing",
            root_declarations=("Example.missing",),
            runner=runner,
        )


def test_owner_sources_follow_lake_path_and_are_hashed(
    tmp_path: Path,
) -> None:
    lean_root = tmp_path / "lean"
    dependency_root = tmp_path / "dependency"
    core = lean_root / "Example" / "Core.lean"
    root = dependency_root / "Example" / "Root.lean"
    core.parent.mkdir(parents=True)
    root.parent.mkdir(parents=True)
    core.write_text("structure Example.Claims where\n")
    root.write_text("theorem Example.safe : True := by trivial\n")
    lean_path = (
        f"{lean_root / '.lake/build/lib/lean'}:"
        f"{dependency_root / '.lake/build/lib/lean'}"
    )

    def runner(
        command: list[str],
        **_: object,
    ) -> subprocess.CompletedProcess[str]:
        return completed(command, stdout=lean_path)

    sources = resolve_owner_sources(
        closure=LeanDeclarationClosure.from_mapping(closure_payload()),
        lean_root=lean_root,
        runner=runner,
    )

    assert [source.module for source in sources] == [
        "Example.Core",
        "Example.Root",
    ]
    assert sources[0].owner_path == "Example/Core.lean"
    assert sources[0].source_digest.startswith("sha256:")
    assert sources[1].owner_path.startswith("Example.Root:")


def test_ambiguous_owner_source_fails_closed(tmp_path: Path) -> None:
    first = tmp_path / "first"
    second = tmp_path / "second"
    for root in (first, second):
        source = root / "Example" / "Core.lean"
        source.parent.mkdir(parents=True)
        source.write_text("structure Example.Claims where\n")
    lean_path = (
        f"{first / '.lake/build/lib/lean'}:"
        f"{second / '.lake/build/lib/lean'}"
    )

    def runner(
        command: list[str],
        **_: object,
    ) -> subprocess.CompletedProcess[str]:
        return completed(command, stdout=lean_path)

    with pytest.raises(
        LeanClosureError,
        match="owner-source-resolution-failed",
    ):
        resolve_owner_sources(
            closure=LeanDeclarationClosure.from_mapping(closure_payload()),
            lean_root=tmp_path / "lean",
            runner=runner,
        )
