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

    def test_development_runtime_shares_exact_parent_poo_and_refuses_shadow(self) -> None:
        module = pin_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shared = root / "production/pkg"
            source = shared / "github.com/tao3k/gerbil-poo"
            source.mkdir(parents=True)
            subprocess.run(["git", "init", "--quiet", str(source)], check=True)
            (source / "gerbil.pkg").write_text("(package: clan/poo)\n")
            subprocess.run(["git", "-C", str(source), "add", "gerbil.pkg"], check=True)
            subprocess.run(["git", "-C", str(source), "-c", "user.name=Native pin test",
                            "-c", "user.email=native-pin@example.invalid", "commit", "--quiet",
                            "-m", "Fixture"], check=True)
            revision = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
            (root / "gerbil.pkg").write_text(f'(depend: ("github.com/tao3k/gerbil-poo@{revision}"))')
            version = subprocess.check_output(["git", "-C", str(source), "describe", "--tags", "--always"], text=True).strip()
            source.with_name(source.name + ".manifest").write_text(f'(("github.com/tao3k/gerbil-poo" . "{version}"))')
            source.with_name(source.name + ".tag").write_text(f'"{revision}"')
            destination = root / "development/pkg"
            module.share_native_poo(destination, shared, root)
            module.share_native_poo(destination, shared, root)
            for suffix in ("", ".manifest", ".tag"):
                alias = destination / ("github.com/tao3k/gerbil-poo" + suffix)
                self.assertTrue(alias.is_symlink())
                self.assertEqual(alias.resolve(), source.with_name(source.name + suffix).resolve())
            manifest = destination / "github.com/tao3k/gerbil-poo.manifest"
            manifest.unlink()
            manifest.write_text("older manifest")
            with self.assertRaisesRegex(ValueError, "cache conflicts"):
                module.share_native_poo(destination, shared, root)
            self.assertEqual(manifest.read_text(), "older manifest")
            (root / "gerbil.pkg").write_text('(depend: ("github.com/tao3k/gerbil-poo@' + "0" * 40 + '"))')
            with self.assertRaisesRegex(ValueError, "head differs"):
                module.share_native_poo(root / "new/pkg", shared, root)
            self.assertFalse((root / "new").exists())

    def test_development_preparation_uses_its_own_declaration(self) -> None:
        from unittest.mock import patch
        module = pin_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dev").mkdir()
            (root / "dev/gerbil.pkg").write_text('(depend: ("github.com/tao3k/asp-gerbil-scheme@' + "1" * 40 + '"))')
            with patch.object(module, "ensure_native_commit") as prepare, patch.object(module, "share_native_poo") as share:
                module.prepare_native_pins(root / "store", root, owner="development")
            self.assertEqual(prepare.call_args.args[0], "https://github.com/tao3k/asp-gerbil-scheme.git")
            self.assertEqual(prepare.call_args.args[1], "1" * 40)
            share.assert_called_once()

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
