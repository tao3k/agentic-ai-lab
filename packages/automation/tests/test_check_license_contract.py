# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Tests for the Agentic AI Lab publication license contract."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "packages" / "automation" / "check_license_contract.py"


def license_contract_module():
    spec = importlib.util.spec_from_file_location("check_license_contract", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LicenseContractTest(unittest.TestCase):
    def test_source_release_rejects_raw_and_compressed_execution_logs(self) -> None:
        contract = license_contract_module()
        errors: list[str] = []
        contract.validate_source_artifacts(tuple(ROOT / name for name in
            ["run.log", "run.log.gz", "run.log.zst", "qualification.ss", "catalog.ss"]), errors)
        self.assertEqual(len(errors), 3)
        self.assertTrue(all("local or CI artifact" in error for error in errors))

    def test_gitlink_contributor_repository_is_excluded(self) -> None:
        contract = license_contract_module()

        self.assertIn("packages/lambda-episteme", contract.submodule_paths())
        self.assertIn("packages/lambda-aitia", contract.submodule_paths())
        self.assertNotIn(
            ROOT / "packages/lambda-episteme/pyproject.toml",
            contract.project_files(),
        )

    def test_repository_license_contract_is_closed(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("license-contract: ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
