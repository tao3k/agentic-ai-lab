# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Unit tests for repository-owned CI gate helpers."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

AUTOMATION_DIR = Path(__file__).resolve().parents[1]
if str(AUTOMATION_DIR) not in sys.path:
    sys.path.insert(0, str(AUTOMATION_DIR))

import ci_gates  # noqa: E402


class CiGatesTests(unittest.TestCase):
    def test_verify_focused_log_accepts_complete_receipt(self) -> None:
        log = "MODULE-OK t/foo-test.ss\nHARNESS-OK\nOK\n"
        ci_gates.verify_focused_log_text(log)

    def test_verify_focused_log_rejects_forbidden_marker(self) -> None:
        log = "MODULE-OK t/foo-test.ss\nERROR CHECK failure\nHARNESS-OK\nOK\n"
        with self.assertRaises(ValueError):
            ci_gates.verify_focused_log_text(log)

    def test_verify_focused_log_rejects_missing_final_ok(self) -> None:
        log = "MODULE-OK t/foo-test.ss\nHARNESS-OK\n"
        with self.assertRaises(ValueError):
            ci_gates.verify_focused_log_text(log)

    def test_verify_downstream_deployment_checks_target_count_line(self) -> None:
        marker = ci_gates.DOWNSTREAM_RECEIPT_MARKERS["deployment"][1]
        valid = (
            "MODULE-OK t/yanxu/modules/services/opentofu/deployment-test.ss\n"
            "LAB-DEPLOYMENT-PRODUCT-USE-OK\n"
            f"LAB-DEPLOYMENT-DOWNSTREAM-OK targets=12 {marker}\n"
            "HARNESS-OK\n"
            "OK\n"
        )
        ci_gates.verify_downstream_log_text("deployment", valid)

        missing_count = (
            "MODULE-OK t/yanxu/modules/services/opentofu/deployment-test.ss\n"
            "LAB-DEPLOYMENT-PRODUCT-USE-OK\n"
            f"{marker}\n"
            "HARNESS-OK\n"
            "OK\n"
        )
        with self.assertRaises(ValueError):
            ci_gates.verify_downstream_log_text("deployment", missing_count)

    def test_discover_lean_matrix_reads_real_lakefile(self) -> None:
        matrix = ci_gates.discover_lean_matrix()
        entries = matrix["include"]
        targets = [entry["target"] for entry in entries]
        self.assertIn("AgenticAILabModuleGovernanceProof", targets)
        self.assertIn("AgenticAILabScenarioHealthcareProof", targets)
        self.assertIn("AgenticAILabModuleMemoryCoreProof", targets)
        governance = next(e for e in entries if e["target"] == "AgenticAILabModuleGovernanceProof")
        self.assertEqual(governance["owner"], "governance")
        self.assertTrue(governance["ffi"])
        healthcare = next(e for e in entries if e["target"] == "AgenticAILabScenarioHealthcareProof")
        self.assertEqual(healthcare["owner"], "healthcare-scenario")
        self.assertFalse(healthcare["ffi"])


if __name__ == "__main__":
    unittest.main()
