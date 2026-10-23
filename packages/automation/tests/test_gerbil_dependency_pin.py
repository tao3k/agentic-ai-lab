# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Tests for the single-authority Gerbil dependency pin projection."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "packages" / "automation" / "gerbil_dependency_pin.py"


def pin_module():
    spec = importlib.util.spec_from_file_location("gerbil_dependency_pin", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GerbilDependencyPinTest(unittest.TestCase):
    def test_source_lock_names_do_not_include_local_toolchains(self) -> None:
        module = pin_module()
        generated = {
            "core_archive": {"repoRuleId": module.SOURCE_PACKAGE_RULE},
            "local_gerbil": {"repoRuleId": "local_toolchain_repository"},
        }
        self.assertEqual(module.locked_source_package_names(generated), {"core_archive"})

    def test_gerbil_package_is_the_direct_revision_authority(self) -> None:
        module = pin_module()
        pins = module.parse_package_pins((ROOT / "gerbil.pkg").read_text(encoding="utf-8"))
        self.assertIn("gerbil-parser", pins)
        self.assertNotIn("asp-gerbil-scheme", pins)
        owners = module.package_pin_owners(ROOT)
        self.assertEqual(owners["asp-gerbil-scheme"][0], ROOT / "dev" / "gerbil.pkg")

    def test_release_tag_projects_github_archive_prefix(self) -> None:
        module = pin_module()
        pins = module.parse_package_pins(
            '(depend: ("github.com/tao3k/asp-gerbil-scheme@v0.1.2"))'
        )
        self.assertEqual(
            pins["asp-gerbil-scheme"],
            ("github.com/tao3k/asp-gerbil-scheme", "v0.1.2"),
        )
        projection = module.expected_projection(
            "github.com/tao3k/asp-gerbil-scheme", "asp-gerbil-scheme", "v0.1.2"
        )
        self.assertEqual(projection["strip_prefix"], "asp-gerbil-scheme-0.1.2")
        self.assertEqual(
            projection["urls"],
            ["https://github.com/tao3k/asp-gerbil-scheme/archive/v0.1.2.tar.gz"],
        )

    def test_root_and_dev_cannot_both_own_the_same_pin(self) -> None:
        module = pin_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dev").mkdir()
            declaration = '(depend: ("github.com/tao3k/asp-gerbil-scheme@v0.1.2"))'
            (root / "gerbil.pkg").write_text(declaration, encoding="utf-8")
            (root / "dev" / "gerbil.pkg").write_text(declaration, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate dependency authority"):
                module.package_pin_owners(root)

    def test_repository_dependency_projection_is_closed(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "check"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("gerbil-dependency-contract: ok", completed.stdout)


if __name__ == "__main__":
    unittest.main()
