# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import importlib
import sys

import pytest


class _BlockTursoImport:
    def find_spec(self, fullname, path=None, target=None):
        if fullname == "turso":
            raise ModuleNotFoundError("blocked optional turso test import")
        return None


def test_package_import_does_not_require_turso_driver():
    previous_modules = {
        name: module
        for name, module in sys.modules.items()
        if name == "agentic_ai_lab_runtime" or name.startswith("agentic_ai_lab_runtime.")
    }
    for name in list(previous_modules):
        sys.modules.pop(name, None)
    sys.modules.pop("turso", None)
    blocker = _BlockTursoImport()
    sys.meta_path.insert(0, blocker)
    try:
        runtime = importlib.import_module("agentic_ai_lab_runtime")
        assert runtime.START == "__start__"
        assert runtime.END == "__end__"
        with pytest.raises(runtime.RuntimeDurablePolicyError, match="pyturso"):
            runtime.TursoRuntimeGraphStore()
    finally:
        sys.meta_path.remove(blocker)
        for name in list(sys.modules):
            if name == "agentic_ai_lab_runtime" or name.startswith("agentic_ai_lab_runtime."):
                sys.modules.pop(name, None)
        sys.modules.update(previous_modules)
