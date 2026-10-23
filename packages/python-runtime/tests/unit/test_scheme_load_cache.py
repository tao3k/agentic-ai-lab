# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import subprocess
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from agentic_ai_lab_runtime import _scheme_load as scheme_load
from agentic_ai_lab_runtime import _scheme_load_aot as scheme_aot
from agentic_ai_lab_runtime import _scheme_load_cache as scheme_cache
from agentic_ai_lab_runtime import _scheme_load_runner as scheme_runner


def _runtime_projection_fixture(root: Path) -> None:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    projection.parent.mkdir(parents=True)
    projection.write_text(";; projection fixture\n", encoding="utf-8")


def _source_fixture(root: Path) -> Path:
    source = root / "flow.ss"
    source.write_text("(user-composition cached-flow CachedProfile)\n", encoding="utf-8")
    return source


def _fake_scheme_run(calls: list[tuple[str, ...]]):
    def fake_run(args: Sequence[str], **_kwargs: Any) -> subprocess.CompletedProcess[str]:
        calls.append(tuple(args))
        return subprocess.CompletedProcess(
            args,
            0,
            stdout='((schema "yuanxu.funflow-plan-projection.v1"))\n',
            stderr="",
        )

    return fake_run


def _cache_key(root: Path, source: Path) -> tuple[object, ...]:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    return scheme_cache.scheme_load_cache_key(
        source.resolve(),
        root.resolve(),
        projection.resolve(),
    )


def test_scheme_projection_rows_reuse_warm_cache(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    calls: list[tuple[str, ...]] = []
    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: _fake_scheme_run(calls)(command.argv))

    first = scheme_load.load_projection_rows(source, cwd=tmp_path)
    second = scheme_load.load_projection_rows(source, cwd=tmp_path)

    assert first is second
    assert len(calls) == 1


def test_scheme_projection_cache_invalidates_when_source_changes(
    tmp_path, monkeypatch
) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    calls: list[tuple[str, ...]] = []
    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: _fake_scheme_run(calls)(command.argv))

    scheme_load.load_projection_rows(source, cwd=tmp_path)
    source.write_text(
        "(user-composition changed-flow ChangedProfile)\n;; changed\n",
        encoding="utf-8",
    )
    scheme_load.load_projection_rows(source, cwd=tmp_path)

    assert len(calls) == 2


def test_scheme_projection_cache_tracks_direct_profile_owner(tmp_path) -> None:
    projection = tmp_path / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    owner = tmp_path / "core" / "profile-composition" / "profile-bundle.ss"
    owner.parent.mkdir(parents=True)
    owner.write_text(";; first\n", encoding="utf-8")

    first = scheme_cache.scheme_load_cache_key(source, tmp_path, projection)
    owner.write_text(";; updated owner\n", encoding="utf-8")
    second = scheme_cache.scheme_load_cache_key(source, tmp_path, projection)

    assert first != second


def test_scheme_projection_cache_can_be_disabled(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    calls: list[tuple[str, ...]] = []
    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: _fake_scheme_run(calls)(command.argv))
    monkeypatch.setenv("AGENTIC_AI_LAB_SCHEME_LOAD_CACHE", "0")

    scheme_load.load_projection_rows(source, cwd=tmp_path)
    scheme_load.load_projection_rows(source, cwd=tmp_path)

    assert len(calls) == 2


def test_scheme_projection_prefers_direct_gerbil_runner(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    (tmp_path / ".gerbil" / "lib" / "agentic-ai-lab").mkdir(parents=True)
    source = _source_fixture(tmp_path)
    calls: list[tuple[str, ...]] = []
    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: _fake_scheme_run(calls)(command.argv))

    scheme_load.load_projection_rows(source, cwd=tmp_path, cache=False)

    assert calls[0][0] == "gxi"


def test_scheme_projection_uses_existing_aot_runner(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    artifact = scheme_aot.scheme_aot_artifact(tmp_path, _cache_key(tmp_path, source))
    artifact.binary.parent.mkdir(parents=True)
    artifact.binary.write_text("#!/bin/sh\n", encoding="utf-8")
    aot_calls: list[tuple[str, ...]] = []

    def fake_aot_run(
        args: Sequence[str],
        **_kwargs: Any,
    ) -> subprocess.CompletedProcess[str]:
        aot_calls.append(tuple(args))
        return subprocess.CompletedProcess(
            args,
            0,
            stdout='((schema "yuanxu.funflow-plan-projection.v1"))\n',
            stderr="",
        )

    monkeypatch.setattr(scheme_aot.subprocess, "run", fake_aot_run)

    rows = scheme_load.load_projection_rows(source, cwd=tmp_path)

    assert rows == (("schema", "yuanxu.funflow-plan-projection.v1"),)
    assert aot_calls == [(str(artifact.binary),)]


def test_scheme_projection_precompile_builds_aot_runner(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    compile_calls: list[tuple[str, ...]] = []

    def fake_compile_run(
        args: Sequence[str],
        **_kwargs: Any,
    ) -> subprocess.CompletedProcess[str]:
        compile_calls.append(tuple(args))
        binary = Path(args[args.index("-o") + 1])
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_text("#!/bin/sh\n", encoding="utf-8")
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

    monkeypatch.setattr(scheme_aot.subprocess, "run", fake_compile_run)

    binary = scheme_load.precompile_load(source, cwd=tmp_path)

    assert binary.exists()
    assert compile_calls
    assert "-exe" in compile_calls[0]
