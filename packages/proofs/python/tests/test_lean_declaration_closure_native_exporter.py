# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import json
import subprocess
from pathlib import Path

from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanDeclarationClosureRequest,
    export_declaration_closure,
    export_declaration_closures,
)


def test_export_uses_native_lake_executable(tmp_path: Path) -> None:
    calls: list[list[str]] = []
    phases: list[dict[str, object]] = []

    def runner(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
        calls.append(list(command))
        if command[:2] == ["lake", "build"]:
            return subprocess.CompletedProcess(command, 0, "", "")
        declaration = {
            "name": "Root.x",
            "kind": "theorem",
            "owner_module": "Root",
            "local_dependencies": [],
            "source_range": {
                "start_line": 1,
                "start_column": 0,
                "start_char_utf16": 0,
                "end_line": 1,
                "end_column": 1,
                "end_char_utf16": 1,
            },
        }
        payload = {
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
            "lean_version": "4.31.0",
            "root_module": "Root",
            "root_declarations": ["Root.x"],
            "base_imports": ["Init"],
            "proof_base_imports": [],
            "owner_modules": ["Root"],
            "declarations": [declaration],
            "proof_base_interface": [],
        }
        native_phase = json.dumps(
            {
                "elapsed_ms": 3,
                "phase": "environment-import",
                "schema_id": "agentic-ai-lab.lean-export-phase.v1",
                "state": "completed",
            }
        )
        return subprocess.CompletedProcess(
            command,
            0,
            json.dumps(payload),
            native_phase,
        )

    export_declaration_closure(
        lean_root=tmp_path,
        root_module="Root",
        root_declarations=("Root.x",),
        timeout_seconds=5,
        runner=runner,
        phase_observer=phases.append,
    )

    assert calls[0] == [
        "lake",
        "build",
        "Root",
        "agenticAiLabDeclarationClosure",
    ]
    assert calls[1][:3] == [
        "lake",
        "env",
        ".lake/build/bin/agenticAiLabDeclarationClosure",
    ]
    assert [phase["phase"] for phase in phases] == [
        "lake-build",
        "lean-export",
        "environment-import",
        "closure-parse",
    ]


def test_batch_export_reuses_one_lake_build_generation(
    tmp_path: Path,
) -> None:
    calls: list[list[str]] = []
    phases: list[dict[str, object]] = []

    def payload(
        root_module: str,
        root_declaration: str,
    ) -> dict[str, object]:
        return {
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
            "lean_version": "4.31.0",
            "root_module": root_module,
            "root_declarations": [root_declaration],
            "base_imports": ["Init"],
            "proof_base_imports": [],
            "owner_modules": [root_module],
            "declarations": [
                {
                    "name": root_declaration,
                    "kind": "theorem",
                    "owner_module": root_module,
                    "local_dependencies": [],
                    "source_range": {
                        "start_line": 1,
                        "start_column": 0,
                        "start_char_utf16": 0,
                        "end_line": 1,
                        "end_column": 1,
                        "end_char_utf16": 1,
                    },
                }
            ],
            "proof_base_interface": [],
        }

    def runner(
        command: list[str],
        **_kwargs: object,
    ) -> subprocess.CompletedProcess[str]:
        calls.append(list(command))
        if command[:2] == ["lake", "build"]:
            return subprocess.CompletedProcess(command, 0, "", "")
        batch_payload: list[dict[str, object]] = []
        for index, argument in enumerate(command):
            if argument == "--batch-root":
                batch_payload.append(payload(command[index + 1], command[index + 2]))
        return subprocess.CompletedProcess(
            command,
            0,
            json.dumps(batch_payload),
            "",
        )

    closures = export_declaration_closures(
        lean_root=tmp_path,
        requests=(
            LeanDeclarationClosureRequest("Root.One", ("Root.One.x",)),
            LeanDeclarationClosureRequest("Root.Two", ("Root.Two.y",)),
        ),
        timeout_seconds=5,
        runner=runner,
        phase_observer=phases.append,
    )

    assert calls[0] == [
        "lake",
        "build",
        "Root.One",
        "Root.Two",
        "agenticAiLabDeclarationClosure",
    ]
    assert len([call for call in calls if call[:2] == ["lake", "build"]]) == 1
    assert tuple(closure.root_module for closure in closures) == (
        "Root.One",
        "Root.Two",
    )
    assert phases[0]["phase"] == "generation-lake-build"
    assert phases[1]["phase"] == "generation-lean-export"
    assert len(calls) == 2
