# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
from pathlib import Path

from agentic_ai_lab_runtime._scheme_load_runner import (
    _direct_scheme_loader_env,
    _scheme_loader_commands,
)


def test_direct_loader_consumes_declared_bazel_environment(
    tmp_path: Path,
    monkeypatch,
) -> None:
    gerbil_path = tmp_path / "compiled-project" / ".gerbil"
    (gerbil_path / "lib" / "agentic-ai-lab").mkdir(parents=True)
    loadpath = os.pathsep.join(
        (
            str(gerbil_path / "lib"),
            str(tmp_path / "dependency" / ".gerbil" / "lib"),
            str(tmp_path / "toolchain-libraries"),
        )
    )
    inherited_path = os.environ.get("PATH", "")
    monkeypatch.setenv("GERBIL_PATH", str(gerbil_path))
    monkeypatch.setenv("GERBIL_LOADPATH", loadpath)
    monkeypatch.setenv("PATH", inherited_path)

    environment = _direct_scheme_loader_env(tmp_path / "source-workspace")

    assert environment is not None
    assert environment["GERBIL_PATH"] == str(gerbil_path)
    assert environment["GERBIL_LOADPATH"] == loadpath
    assert environment["PATH"] == inherited_path


def test_declared_bazel_environment_selects_direct_gxi_first(
    tmp_path: Path,
    monkeypatch,
) -> None:
    gerbil_path = tmp_path / "compiled-project" / ".gerbil"
    (gerbil_path / "lib" / "agentic-ai-lab").mkdir(parents=True)
    monkeypatch.setenv("GERBIL_PATH", str(gerbil_path))
    monkeypatch.setenv("GERBIL_LOADPATH", str(gerbil_path / "lib"))
    runner = tmp_path / "runner.ss"

    commands = _scheme_loader_commands(tmp_path / "source-workspace", runner)

    assert commands[0].argv == ("gxi", "-:max-heap=1G,debug=q", str(runner))
    assert commands[0].env is not None
    assert commands[0].env["GERBIL_PATH"] == str(gerbil_path)
    assert commands[1].argv == ("gxpkg", "env", "gxi", "-:max-heap=1G,debug=q", str(runner))
    assert commands[1].env is None


def test_native_progress_keeps_datum_and_diagnostics_separate(tmp_path, capsys):
    import sys
    from agentic_ai_lab_runtime._scheme_load_runner import (
        _SchemeLoaderCommand, _run_with_native_progress,
    )

    command = _SchemeLoaderCommand(
        (sys.executable, '-c',
         "import sys; print('MODULE-OK test', file=sys.stderr); print('(datum)')"),
        None,
    )
    result = _run_with_native_progress(command, tmp_path)
    assert result.stdout == '(datum)\n'
    assert result.stderr == 'MODULE-OK test\n'
    assert capsys.readouterr().err == result.stderr


def test_total_deadline_stops_child_even_with_continuous_output(tmp_path, monkeypatch):
    import sys
    import pytest
    import agentic_ai_lab_runtime._scheme_load_runner as runner

    monkeypatch.setattr(runner, '_SCHEME_LOAD_TOTAL_SECONDS', 0.2)
    command = runner._SchemeLoaderCommand(
        (sys.executable, '-u', '-c',
         "import time\nwhile True:\n print('datum'); time.sleep(0.01)"),
        None,
    )
    with pytest.raises(RuntimeError, match='total time limit'):
        runner._run_with_native_progress(command, tmp_path)
