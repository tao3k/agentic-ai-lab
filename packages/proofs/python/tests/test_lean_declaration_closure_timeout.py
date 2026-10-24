# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path
import subprocess

import pytest

from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    export_declaration_closure,
)


def test_export_declaration_closure_has_one_build_and_export_deadline() -> None:
    observed_timeouts: list[float] = []

    def runner(
        command: list[str],
        **kwargs: object,
    ) -> subprocess.CompletedProcess[str]:
        timeout = kwargs["timeout"]
        assert isinstance(timeout, float)
        observed_timeouts.append(timeout)
        if command[:2] == ["lake", "build"]:
            return subprocess.CompletedProcess(command, 0, "", "")
        raise subprocess.TimeoutExpired(command, timeout)

    with pytest.raises(LeanClosureError) as raised:
        export_declaration_closure(
            lean_root=Path("/tmp/lean-proof"),
            root_module="AgenticAILabProof.Example",
            root_declarations=("AgenticAILabProof.Example.closed",),
            timeout_seconds=0.25,
            runner=runner,
        )

    assert raised.value.code == "lean-declaration-closure-export-timeout"
    assert "phase=lean-export" in raised.value.detail
    assert "budget_seconds=0.25" in raised.value.detail
    assert len(observed_timeouts) == 2
    assert 0 < observed_timeouts[1] <= observed_timeouts[0] <= 0.25


@pytest.mark.parametrize("timeout_seconds", [0.0, -1.0, float("inf"), float("nan")])
def test_export_declaration_closure_rejects_invalid_deadline(
    timeout_seconds: float,
) -> None:
    called = False

    def runner(
        command: list[str],
        **kwargs: object,
    ) -> subprocess.CompletedProcess[str]:
        nonlocal called
        called = True
        return subprocess.CompletedProcess(command, 0, "", "")

    with pytest.raises(LeanClosureError) as raised:
        export_declaration_closure(
            lean_root=Path("/tmp/lean-proof"),
            root_module="AgenticAILabProof.Example",
            root_declarations=("AgenticAILabProof.Example.closed",),
            timeout_seconds=timeout_seconds,
            runner=runner,
        )

    assert raised.value.code == "invalid-lean-export-timeout"
    assert called is False
