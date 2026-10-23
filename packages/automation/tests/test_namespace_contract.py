# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Current API names migrate; recorded evidence must retain its identity."""
import importlib.util
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "namespace_contract", Path(__file__).resolve().parents[1] / "check_namespace_contract.py")
contract = importlib.util.module_from_spec(SPEC)
with patch.object(sys, "path", [str(Path(__file__).resolve().parents[1]), *sys.path]):
    SPEC.loader.exec_module(contract)


class NamespaceContractTests(unittest.TestCase):
    def check_source(self, relative, contents):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
            with patch.object(contract, "ROOT", root):
                return contract.issues(path)

    def test_new_package_and_independent_core_are_accepted(self):
        self.assertEqual(self.check_source("config.ss", "(import :agentic-ai-lab/init :yuanxu/types)"), [])

    def test_old_import_and_source_path_are_refused(self):
        old = "poo" + "-flow"
        self.assertEqual(len(self.check_source(old + "/init.ss", "(import :" + old + "/init)")), 2)

    def test_lean_mangled_old_package_is_refused(self):
        old = "initialize_poo" + "_x2dflow_x2dproof_Module"
        self.assertTrue(self.check_source("host.c", old))

    def test_obsolete_core_import_is_refused(self):
        old = ":" + "core/types"
        self.assertTrue(self.check_source("config.ss", "(import " + old + ")"))

    def test_compiler_projection_refuses_obsolete_module_identity(self):
        self.assertTrue(self.check_source("runtime_load_imports.json",
            '{"roots": [], "modules": ["core/types"]}'))

    def test_core_source_path_is_not_a_module_namespace(self):
        self.assertEqual(self.check_source("README.org", "[[file:core/types.ss]]"), [])
        self.assertEqual(self.check_source("BUILD.bazel", '"//:core/gerbil.pkg"'), [])

    def test_recorded_evidence_keeps_original_identity(self):
        old = "POO" + "_FLOW"
        self.assertEqual(self.check_source("t/evidence/original.json", '{"name":"' + old + '"}'), [])
        self.assertEqual(self.check_source("benchmarks/original.receipt", old), [])
        self.assertEqual(self.check_source("t/qualification/semantic-abi/2026-10-04-run/report.json", old), [])

    def test_existing_pr_ref_is_not_a_public_namespace(self):
        self.assertEqual(self.check_source("README.org", "research/ascent-" + "poo" + "-flow"), [])

    def test_proof_pin_refuses_a_different_core_revision(self):
        revision = "a" * 40
        url = "https://github.com/tao3k/gebril-yuanxu.git"
        declaration = f'require YuanxuProof from git "{url}" @ "{revision}"'
        manifest = {"packages": [{"name": "YuanxuProof", "type": "git", "url": url,
                                   "rev": revision, "subDir": "dev/proofs/lean"}]}
        self.assertEqual(contract.proof_pin_issues(revision, declaration, manifest), [])
        self.assertTrue(contract.proof_pin_issues("b" * 40, declaration, manifest))
        manifest["packages"][0]["rev"] = "c" * 40
        self.assertTrue(contract.proof_pin_issues(revision, declaration, manifest))


if __name__ == "__main__":
    unittest.main()
