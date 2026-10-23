# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import subprocess
from collections.abc import Sequence
from pathlib import Path
from typing import Any

from agentic_ai_lab_runtime import _scheme_load as scheme_load
from agentic_ai_lab_runtime import _scheme_load_artifact as scheme_artifact
from agentic_ai_lab_runtime import _scheme_load_runner as scheme_runner
from agentic_ai_lab_runtime import scheme_projection_artifact


def _runtime_projection_fixture(root: Path) -> Path:
    projection = root / "modules" / "workflow" / "scenario" / "runtime-funflow.ss"
    projection.parent.mkdir(parents=True)
    projection.write_text(";; projection fixture\n", encoding="utf-8")
    return projection


def _source_fixture(root: Path) -> Path:
    source = root / "flow.ss"
    source.write_text("(user-composition artifact-flow ArtifactProfile)\n", encoding="utf-8")
    return source


def _projection_rows(name: str) -> tuple[tuple[str, str], tuple[str, str]]:
    return (
        ("schema", "yuanxu.funflow-plan-projection.v1"),
        ("name", name),
    )


def test_scheme_projection_loads_adjacent_artifact_without_subprocess(
    tmp_path,
    monkeypatch,
) -> None:
    scheme_load.clear_load_cache()
    projection = _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    rows = _projection_rows("artifact")
    scheme_artifact.write_projection_artifact(
        scheme_artifact.adjacent_projection_artifact(source),
        module_path=source,
        projection_path=projection,
        rows=rows,
    )

    def fail_subprocess(*_args: object, **_kwargs: object) -> None:
        raise AssertionError("artifact load should not start Gerbil")

    monkeypatch.setattr(scheme_runner, "_run_with_native_progress", fail_subprocess)

    loaded = scheme_load.load_projection_rows(source, cwd=tmp_path, cache=False)

    assert loaded == rows


def test_scheme_projection_loads_adjacent_artifact_without_projection_source(
    tmp_path,
    monkeypatch,
) -> None:
    scheme_load.clear_load_cache()
    projection = _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    rows = _projection_rows("artifact-only")
    scheme_artifact.write_projection_artifact(
        scheme_artifact.adjacent_projection_artifact(source),
        module_path=source,
        projection_path=projection,
        rows=rows,
    )
    projection.unlink()

    def fail_subprocess(*_args: object, **_kwargs: object) -> None:
        raise AssertionError("standalone artifact load should not start Gerbil")

    monkeypatch.setattr(scheme_load, "find_runtime_projection_source", lambda _cwd: None)
    monkeypatch.setattr(scheme_runner, "_run_with_native_progress", fail_subprocess)

    loaded = scheme_load.load_projection_rows(source, cwd=tmp_path, cache=False)

    assert loaded == rows


def test_scheme_projection_ignores_stale_artifact_and_falls_back(
    tmp_path,
    monkeypatch,
) -> None:
    scheme_load.clear_load_cache()
    projection = _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)
    scheme_artifact.write_projection_artifact(
        scheme_artifact.adjacent_projection_artifact(source),
        module_path=source,
        projection_path=projection,
        rows=_projection_rows("stale"),
    )
    source.write_text(
        "(user-composition changed-artifact-flow ChangedArtifactProfile)\n",
        encoding="utf-8",
    )
    calls: list[tuple[str, ...]] = []

    def fake_run(
        args: Sequence[str],
        **_kwargs: Any,
    ) -> subprocess.CompletedProcess[str]:
        calls.append(tuple(args))
        return subprocess.CompletedProcess(
            args,
            0,
            stdout=(
                '(("schema" "yuanxu.funflow-plan-projection.v1") '
                '("name" "fresh"))\n'
            ),
            stderr="",
        )

    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: fake_run(command.argv))

    loaded = scheme_load.load_projection_rows(source, cwd=tmp_path, cache=False)

    assert ("name", "fresh") in loaded
    assert len(calls) == 1


def test_preproject_load_writes_projection_artifact(tmp_path, monkeypatch) -> None:
    scheme_load.clear_load_cache()
    _runtime_projection_fixture(tmp_path)
    source = _source_fixture(tmp_path)

    def fake_run(
        args: Sequence[str],
        **_kwargs: Any,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            args,
            0,
            stdout=(
                '(("schema" "yuanxu.funflow-plan-projection.v1") '
                '("name" "built"))\n'
            ),
            stderr="",
        )

    monkeypatch.setattr(scheme_runner, "_run_with_native_progress",
                        lambda command, workdir: fake_run(command.argv))

    artifact = scheme_load.preproject_load(source, cwd=tmp_path)
    loaded = scheme_load.load_projection_rows(source, cwd=tmp_path, cache=False)

    assert artifact == scheme_artifact.adjacent_projection_artifact(source)
    assert artifact.exists()
    assert ("name", "built") in loaded


def test_scheme_projection_artifact_command_emits_receipt(
    tmp_path,
    monkeypatch,
    capsys,
) -> None:
    source = _source_fixture(tmp_path)
    artifact = tmp_path / "projection.sexp"

    def fake_preproject_load(
        path: str | Path,
        *,
        cwd: str | Path | None = None,
        output: str | Path | None = None,
        force: bool = False,
    ) -> Path:
        assert Path(path).resolve() == source.resolve()
        assert Path(cwd).resolve() == tmp_path.resolve()
        assert Path(output).resolve() == artifact.resolve()
        assert force is True
        return artifact

    monkeypatch.setattr(
        scheme_projection_artifact,
        "preproject_load",
        fake_preproject_load,
    )

    exit_code = scheme_projection_artifact.main(
        [
            "export",
            str(source),
            "--cwd",
            str(tmp_path),
            "--output",
            str(artifact),
            "--force",
        ]
    )

    output = capsys.readouterr().out
    assert exit_code == 0
    assert 'schema: "agentic-ai-lab.scheme-load-projection-artifact.v1"' in output
    assert 'action: "export"' in output
    assert f'artifact: "{artifact.resolve()}"' in output
