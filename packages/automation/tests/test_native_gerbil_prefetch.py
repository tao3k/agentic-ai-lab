# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""A lost advertised branch must not make a retained exact SHA unbuildable."""
from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from unittest import mock
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "gerbil_dependency_pin.py"


def module():
    spec = importlib.util.spec_from_file_location("pin", SCRIPT)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL, text=True).strip()


class NativePinPrefetchTest(unittest.TestCase):
    def test_package_manifest_selects_only_its_own_install_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "dev").mkdir()
            production = "1" * 40
            development = "2" * 40
            (root / "gerbil.pkg").write_text(
                f'(package: production depend: ("github.com/team/library@{production}"))'
            )
            manifest = root / "dev" / "gerbil.pkg"
            manifest.write_text(
                f'(package: development depend: ("github.com/team/tool@{development}"))'
            )
            api = module()
            with mock.patch.object(api, "ensure_native_commit") as prepare:
                api.prepare_native_pins(root / "production-pkg", root)
                prepare.assert_called_once_with(
                    "https://github.com/team/library.git", production,
                    (root / "production-pkg/github.com/team/library").resolve(),
                )
                prepare.reset_mock()
                api.prepare_native_pins(root / "development-pkg", root, manifest)
                prepare.assert_called_once_with(
                    "https://github.com/team/tool.git", development,
                    (root / "development-pkg/github.com/team/tool").resolve(),
                )

    def test_unadvertised_commit_is_fetched_without_changing_existing_checkout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            git(source, "init", "--quiet")
            git(source, "config", "user.name", "test")
            git(source, "config", "user.email", "test@example.invalid")
            (source / "gerbil.pkg").write_text("old pinned package")
            git(source, "add", "gerbil.pkg")
            git(source, "commit", "--quiet", "-m", "old")
            old = git(source, "rev-parse", "HEAD")
            old_branch = git(source, "branch", "--show-current")
            git(source, "checkout", "--quiet", "--orphan", "replacement")
            (source / "gerbil.pkg").write_text("replacement package")
            git(source, "add", "gerbil.pkg")
            git(source, "commit", "--quiet", "-m", "new")
            git(source, "branch", "-D", old_branch)
            git(source, "config", "uploadpack.allowAnySHA1InWant", "true")
            target = root / "cached"
            subprocess.run(["git", "clone", "--quiet", source.as_uri(), str(target)], check=True)
            self.assertNotEqual(subprocess.run(["git", "-C", str(target), "cat-file", "-e", old], stderr=subprocess.DEVNULL).returncode, 0)
            tag = target.with_name(target.name + ".tag")
            tag.write_text('"existing-owner-tag"\n')
            head = git(target, "rev-parse", "HEAD")
            (target / "gerbil.pkg").write_text("caller local edit")
            module().ensure_native_commit(source.as_uri(), old, target)
            self.assertEqual(git(target, "rev-parse", "HEAD"), head)
            self.assertEqual(tag.read_text(), '"existing-owner-tag"\n')
            self.assertEqual((target / "gerbil.pkg").read_text(), "caller local edit")
            self.assertEqual(git(target, "cat-file", "-t", old), "commit")
            fresh = root / "fresh"
            module().ensure_native_commit(source.as_uri(), old, fresh)
            self.assertEqual(git(fresh, "rev-parse", "HEAD"), old)
            self.assertEqual(fresh.with_name(fresh.name + ".tag").read_text(), f'"{old}"\n')
            self.assertEqual((fresh / "gerbil.pkg").read_text(), "old pinned package")

    def test_non_git_directory_and_non_full_revision_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            with self.assertRaises(ValueError):
                module().ensure_native_commit("unused", "a" * 40, target)
            with self.assertRaises(ValueError):
                module().ensure_native_commit("unused", "main", target / "new")
            self.assertFalse((target / "new").exists())
