# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Exercise the real content cache with a controlled Lake process boundary."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess

import pytest

from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    export_declaration_closure,
)


@pytest.fixture
def cache_harness(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    root = tmp_path / ".lake/build/lib/lean/Root.olean"
    exporter = tmp_path / ".lake/build/bin/agenticAiLabDeclarationClosure"
    for artifact in (root, exporter):
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.write_bytes(b"generation-one")
    payload = {
        "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
        "lean_version": "4.31.0",
        "root_module": "Root",
        "root_declarations": ["Root.x"],
        "base_imports": ["Init"],
        "proof_base_imports": [],
        "proof_base_interface": [],
        "owner_modules": ["Root"],
        "declarations": [
            {
                "name": "Root.x",
                "kind": "theorem",
                "owner_module": "Root",
                "local_dependencies": [],
            }
        ],
    }
    calls = []
    control = {"build_ok": True, "output": json.dumps(payload)}

    def runner(command, **kwargs):
        calls.append(command[:2])
        if command[:2] == ["lake", "build"]:
            return subprocess.CompletedProcess(command, 0 if control["build_ok"] else 1, "", "")
        return subprocess.CompletedProcess(command, 0, control["output"], "")

    monkeypatch.setattr(subprocess, "run", runner)

    def export():
        return export_declaration_closure(
            lean_root=tmp_path,
            root_module="Root",
            root_declarations=("Root.x",),
            runner=runner,
        )

    return export, control, calls, root, exporter, payload


def test_cache_hit_still_requires_successful_lake_admission(cache_harness):
    export, control, calls, *_ = cache_harness
    first = export()
    assert export() == first
    assert calls == [["lake", "build"], ["lake", "env"], ["lake", "build"]]
    control["build_ok"] = False
    with pytest.raises(LeanClosureError, match="lake-build-failed"):
        export()
    assert calls[-1] == ["lake", "build"]


@pytest.mark.parametrize("artifact_index", [3, 4], ids=["root-olean", "exporter"])
def test_content_change_invalidates_cache_with_unchanged_size_and_mtime(
    cache_harness, artifact_index
):
    export, _, calls, *_ = cache_harness
    export()
    artifact = cache_harness[artifact_index]
    before = artifact.stat()
    artifact.write_bytes(b"generation-two")
    os.utime(artifact, ns=(before.st_atime_ns, before.st_mtime_ns))
    assert artifact.stat().st_size == before.st_size
    export()
    assert calls.count(["lake", "env"]) == 2


@pytest.mark.parametrize("fault", ["malformed", "root", "base", "proof-base"])
def test_invalid_export_is_never_published_to_cache(cache_harness, fault):
    export, control, calls, _, _, payload = cache_harness
    if fault == "malformed":
        control["output"] = "{"
    else:
        field, value = {
            "root": ("root_declarations", ["Root.other"]),
            "base": ("base_imports", ["Init", "Other"]),
            "proof-base": ("proof_base_imports", ["Cedar.Spec"]),
        }[fault]
        control["output"] = json.dumps({**payload, field: value})
    with pytest.raises(LeanClosureError):
        export()
    control["output"] = json.dumps(payload)
    assert export().root_declarations == ("Root.x",)
    assert calls.count(["lake", "env"]) == 2
