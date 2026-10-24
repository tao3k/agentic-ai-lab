#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from external_module import (
    ExternalModuleConfig,
    ExternalModuleError,
    _export_tracked_tree,
    run_external_module,
)

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]


class ExternalModuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="external-module-unit-")
        root = Path(self.temporary.name)
        self.log = root / "bazel-args.jsonl"
        self.fake_bazel = root / "fake_bazel.py"
        self.fake_bazel.write_text(
            """import json, os, sys
with open(os.environ['AGENTIC_AI_LAB_EXTERNAL_BAZEL_ARGS_LOG'], 'a', encoding='utf-8') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
raise SystemExit(1 if any('bazel-no-root-override' in arg for arg in sys.argv[1:]) else 0)
""",
            encoding="utf-8",
        )
        self.environment = patch.dict(
            os.environ,
            {"AGENTIC_AI_LAB_EXTERNAL_BAZEL_ARGS_LOG": str(self.log)},
        )
        self.environment.start()

    def tearDown(self) -> None:
        self.environment.stop()
        self.temporary.cleanup()

    def invocations(self) -> list[list[str]]:
        return [
            json.loads(line)
            for line in self.log.read_text(encoding="utf-8").splitlines()
        ]

    def config(
        self, mode: str, output_base: Path | None = None
    ) -> ExternalModuleConfig:
        return ExternalModuleConfig(
            (sys.executable, str(self.fake_bazel)), mode, output_base
        )

    def test_relative_output_base_fails_before_bazel(self) -> None:
        with self.assertRaisesRegex(ExternalModuleError, "must be an absolute path"):
            run_external_module(
                REPO_ROOT, self.config("analysis", Path("relative/path"))
            )
        self.assertFalse(self.log.exists())

    def test_export_contains_pinned_core_subtree_sources(self) -> None:
        exported = Path(self.temporary.name) / "exported"
        exported.mkdir()
        _export_tracked_tree(REPO_ROOT, exported)
        self.assertEqual(
            (exported / "core" / "gerbil.pkg").read_bytes(),
            (REPO_ROOT / "core" / "gerbil.pkg").read_bytes(),
        )
        self.assertTrue((exported / "core" / "build.ss").is_file())

    def test_default_output_root_and_analysis_build(self) -> None:
        receipt = run_external_module(REPO_ROOT, self.config("analysis"))
        invocations = self.invocations()
        self.assertEqual(len(invocations), 3)
        self.assertTrue(invocations[0][0].startswith("--output_user_root="))
        self.assertIn("bazel-no-root-override", invocations[0][0])
        self.assertEqual(invocations[1][1], "query")
        self.assertEqual(invocations[2][1:4], ["build", "--jobs=2", "--nobuild"])
        self.assertFalse(receipt["compiled"])

    def test_stable_output_base_and_full_build(self) -> None:
        output_base = Path(self.temporary.name) / "stable output base"
        receipt = run_external_module(REPO_ROOT, self.config("full", output_base))
        invocations = self.invocations()
        self.assertEqual(len(invocations), 3)
        self.assertTrue(invocations[1][0].startswith("--output_base="))
        self.assertEqual(invocations[2][1:3], ["build", "--jobs=2"])
        self.assertNotIn("--nobuild", invocations[2])
        self.assertTrue(output_base.is_dir())
        self.assertTrue(receipt["compiled"])


if __name__ == "__main__":
    unittest.main()
