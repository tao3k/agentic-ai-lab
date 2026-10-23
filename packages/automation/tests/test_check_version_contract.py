# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Tests for the Agentic AI Lab release version contract."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "packages" / "automation" / "check_version_contract.py"


def version_contract_module():
    spec = importlib.util.spec_from_file_location("check_version_contract", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VersionContractTest(unittest.TestCase):
    def test_root_version_is_canonical_semver(self) -> None:
        contract = version_contract_module()
        self.assertEqual(contract.release_version(ROOT), ("0.1.0", (0, 1, 0)))

    def test_repository_version_contract_is_closed(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("version-contract: ok (0.1.0)", completed.stdout)


if __name__ == "__main__":
    unittest.main()
