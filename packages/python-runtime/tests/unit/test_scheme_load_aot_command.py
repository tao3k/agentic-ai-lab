# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

from agentic_ai_lab_runtime import scheme_load_aot
from agentic_ai_lab_runtime import _scheme_load_aot as scheme_aot
from agentic_ai_lab_runtime import _scheme_load_cache as scheme_cache


def _runtime_projection_fixture(root: Path) -> None:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    projection.parent.mkdir(parents=True)
    projection.write_text(";; projection fixture\n", encoding="utf-8")


def _source_fixture(root: Path) -> Path:
    source = root / "flow.ss"
    source.write_text("(user-composition command-flow CommandProfile)\n", encoding="utf-8")
    return source


def _aot_artifact_binary(root: Path, source: Path) -> Path:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    cache_key = scheme_cache.scheme_load_cache_key(
        source.resolve(),
        root.resolve(),
        projection.resolve(),
    )
    return scheme_aot.scheme_aot_artifact(root.resolve(), cache_key).binary


def test_scheme_load_aot_precompile_command_emits_receipt(
    tmp_path, monkeypatch, capsys
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    expected_binary = _aot_artifact_binary(tmp_path, source)

    def fake_precompile_load(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        force: bool = False,
    ) -> Path:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        assert force is False
        return expected_binary

    monkeypatch.setattr(scheme_load_aot, "precompile_load", fake_precompile_load)

    exit_code = scheme_load_aot.main(
        ["precompile", str(source), "--cwd", str(tmp_path)]
    )

    captured = capsys.readouterr()
    assert exit_code == 0
    assert 'schema: "agentic-ai-lab.scheme-load-aot.v1"' in captured.out
    assert 'action: "precompile"' in captured.out
    assert f'binary: "{expected_binary}"' in captured.out
    assert "rebuilt?: #t" in captured.out
    assert "elapsed-us:" in captured.out


def test_scheme_load_aot_precompile_command_marks_cached_binary(
    tmp_path, monkeypatch, capsys
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    expected_binary = _aot_artifact_binary(tmp_path, source)
    expected_binary.parent.mkdir(parents=True)
    expected_binary.write_text("#!/bin/sh\n", encoding="utf-8")

    def fake_precompile_load(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        force: bool = False,
    ) -> Path:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        assert force is False
        return expected_binary

    monkeypatch.setattr(scheme_load_aot, "precompile_load", fake_precompile_load)

    exit_code = scheme_load_aot.main(
        ["precompile", str(source), "--cwd", str(tmp_path)]
    )

    captured = capsys.readouterr()
    assert exit_code == 0
    assert "rebuilt?: #f" in captured.out


def test_scheme_load_aot_precompile_command_passes_force(
    tmp_path, monkeypatch, capsys
) -> None:
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    expected_binary = _aot_artifact_binary(tmp_path, source)
    expected_binary.parent.mkdir(parents=True)
    expected_binary.write_text("#!/bin/sh\n", encoding="utf-8")
    force_values: list[bool] = []

    def fake_precompile_load(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        force: bool = False,
    ) -> Path:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        force_values.append(force)
        return expected_binary

    monkeypatch.setattr(scheme_load_aot, "precompile_load", fake_precompile_load)

    exit_code = scheme_load_aot.main(
        ["precompile", str(source), "--cwd", str(tmp_path), "--force"]
    )

    captured = capsys.readouterr()
    assert exit_code == 0
    assert force_values == [True]
    assert "rebuilt?: #t" in captured.out
