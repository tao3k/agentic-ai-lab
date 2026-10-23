# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import ast
import inspect
from pathlib import Path

import agentic_ai_lab_runtime as runtime


RUNTIME_DOMAIN_EXPORTS = {
    "RuntimeDurableAdapter",
    "RuntimeDurableEnvelopeManifest",
    "RuntimeDurablePolicyError",
    "RuntimeDurablePolicyManifest",
    "RuntimeGraphBuilder",
    "RuntimeGraphProgram",
    "coerce_runtime_durable_envelope_manifest",
    "coerce_runtime_durable_policy_manifest",
}


DURABLE_ADAPTER_METHODS = {
    "turso",
    "turso_from_envelope",
    "receipt",
    "has",
    "ahas",
    "inspect",
    "ainspect",
    "history",
    "ahistory",
    "load_at",
    "aload_at",
    "update_state",
    "aupdate_state",
    "clear",
    "aclear",
    "invoke_thread",
    "ainvoke_thread",
    "resume_thread",
    "aresume_thread",
}


def _python_sources(root: Path) -> list[Path]:
    return sorted(
        path
        for owner in (root / "src", root / "tests")
        for path in owner.rglob("*.py")
    )


def _ctypes_imports(path: Path) -> list[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    violations: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            violations.extend(
                alias.name for alias in node.names if alias.name.split(".", 1)[0] == "ctypes"
            )
        elif isinstance(node, ast.ImportFrom) and node.module:
            if node.module.split(".", 1)[0] == "ctypes":
                violations.append(node.module)
        elif isinstance(node, ast.Call) and node.args:
            first = node.args[0]
            if not isinstance(first, ast.Constant) or not isinstance(first.value, str):
                continue
            dynamic_import = (
                isinstance(node.func, ast.Name) and node.func.id == "__import__"
            ) or (
                isinstance(node.func, ast.Attribute)
                and node.func.attr == "import_module"
            )
            if dynamic_import and first.value.split(".", 1)[0] == "ctypes":
                violations.append(first.value)
    return violations


def test_runtime_domain_public_exports_are_declared() -> None:
    exported = set(runtime.__all__)

    assert RUNTIME_DOMAIN_EXPORTS <= exported
    for name in RUNTIME_DOMAIN_EXPORTS:
        assert hasattr(runtime, name)


def test_retired_graph_abi_exports_are_absent() -> None:
    exported = set(runtime.__all__)

    assert "AgenticAILabRuntimeBinding" not in exported
    assert "AgenticAILabRuntimeCffiBinding" not in exported
    assert "materialize_runtime_graph_plan" not in exported


def test_production_runtime_has_no_ctypes_owner() -> None:
    package_root = Path(__file__).resolve().parents[2]
    violations = {
        str(path.relative_to(package_root)): imports
        for path in _python_sources(package_root)
        if (imports := _ctypes_imports(path))
    }

    assert violations == {}
    assert "ctypes" not in (package_root / "README.org").read_text(
        encoding="utf-8"
    ).lower()


def test_durable_adapter_runtime_facade_is_public() -> None:
    adapter = runtime.RuntimeDurableAdapter

    for method in DURABLE_ADAPTER_METHODS:
        assert callable(getattr(adapter, method))


def test_durable_adapter_thread_facade_accepts_program_argument() -> None:
    invoke_signature = inspect.signature(runtime.RuntimeDurableAdapter.invoke_thread)
    resume_signature = inspect.signature(runtime.RuntimeDurableAdapter.resume_thread)

    assert tuple(invoke_signature.parameters)[:3] == ("self", "program", "thread_id")
    assert tuple(resume_signature.parameters)[:3] == ("self", "program", "thread_id")
