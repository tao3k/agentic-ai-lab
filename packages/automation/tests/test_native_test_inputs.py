# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""The locked fixture transport must retain canonical producer paths."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "native_test_inputs.py"
spec = importlib.util.spec_from_file_location("native_test_inputs", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NativeTestInputsTest(unittest.TestCase):
    def test_source_aliases_resolve_to_the_same_fixture_producer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "artifact"
            for name in ("families/aws", "awsOnly", "awsNull", "parent", "child", "binary"):
                (artifact / name).mkdir(parents=True)
            (artifact / "families/aws/schema.json").write_text("{}")
            (artifact / "binary/provider").write_bytes(b"recorded bytes")
            tools = '{"shell":"/store/bash","system":"fixture","nixpkgs":"/nix/store/fixture-package-set"}'
            (artifact / "tools").write_text(tools + "\n")
            alias = root / "inputs"
            alias.symlink_to(artifact, target_is_directory=True)
            env = module.fixture_environment(alias)
            self.assertEqual(env["AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS"], str(artifact.resolve()))
            self.assertEqual(env["AGENTIC_AI_LAB_OPENTOFU_ARTIFACT"], env["AGENTIC_AI_LAB_OPENTOFU_FLAKE_ARTIFACT"])
            self.assertEqual(env["AGENTIC_AI_LAB_OPENTOFU_TEST_AWS_ONLY_ARTIFACT"], str((artifact / "awsOnly").resolve()))
            self.assertNotEqual(env["AGENTIC_AI_LAB_OPENTOFU_TEST_AWS_ONLY_ARTIFACT"], env["AGENTIC_AI_LAB_OPENTOFU_ARTIFACT"])
            self.assertEqual(env["AGENTIC_AI_LAB_OPENTOFU_TEST_REBUILT"], str((artifact / "awsNull").resolve()))
            self.assertNotEqual(env["AGENTIC_AI_LAB_OPENTOFU_TEST_REBUILT"], env["AGENTIC_AI_LAB_OPENTOFU_TEST_AWS_ONLY_ARTIFACT"])
            self.assertEqual(Path(env["YUANXU_AWS_BINARY"]).read_bytes(), b"recorded bytes")
            self.assertEqual(Path(env["YUANXU_JSON_SCHEMA_AWS_EXPORT"]).read_text(), "{}")
            self.assertEqual(env["AGENTIC_AI_LAB_NIX_TEST_TOOLS"], tools)
            self.assertEqual(env["NIX_PATH"], "nixpkgs=/nix/store/fixture-package-set")

    def test_incomplete_inputs_refuse_before_any_native_command(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                module.fixture_environment(Path(directory))


if __name__ == "__main__":
    unittest.main()
