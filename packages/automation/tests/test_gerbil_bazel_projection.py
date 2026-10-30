# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Bazel source and lock projection checks; Gerbil owns package behavior."""

from __future__ import annotations

import importlib.util
import json
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


class GerbilBazelProjectionTest(unittest.TestCase):
    def test_source_lock_names_do_not_include_local_toolchains(self) -> None:
        module = pin_module()
        generated = {
            "core_archive": {"repoRuleId": module.SOURCE_PACKAGE_RULE},
            "local_gerbil": {"repoRuleId": "local_toolchain_repository"},
        }
        self.assertEqual(module.locked_source_package_names(generated), {"core_archive"})

    def test_core_pin_cannot_drift_from_bazel_while_product_pins_match(self) -> None:
        module = pin_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ("gerbil.pkg", "dev/gerbil.pkg", "core/gerbil.pkg",
                             "MODULE.bazel", "MODULE.bazel.lock",
                             "gerbil-dependencies.MODULE.bazel"):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / relative).read_bytes())
            manifest = root / "core" / "gerbil.pkg"
            pins = module.parse_package_pins(manifest.read_text())
            repository, revision = pins["gerbil-poo"]
            manifest.write_text(manifest.read_text().replace(revision, "0" * 40))
            errors = module.collect_errors(root)
            self.assertTrue(any("gerbil_poo_sources.revision" in error for error in errors),
                            errors)
            # The checker must never silently rewrite the owning manifest.
            self.assertIn(repository + "@" + "0" * 40, manifest.read_text())

    def test_lock_sync_updates_code_identity_without_copying_host_toolchain(self) -> None:
        from unittest.mock import patch
        module = pin_module()
        native_key = "os:osx,arch:aarch64"
        target_key = "os:linux,arch:amd64"
        source = {"repoRuleId": module.SOURCE_PACKAGE_RULE,
                  "attributes": {"revision": "current"}}
        native = {"bzlTransitiveDigest": "current-code", "usagesDigest": "current-usage",
                  "generatedRepoSpecs": {"orgize_sources": source,
                                        "local_gerbil": {"platform": "darwin"}}}
        target = {"bzlTransitiveDigest": "old-code", "usagesDigest": "old-usage",
                  "generatedRepoSpecs": {"orgize_sources": source,
                                        "local_gerbil": {"platform": "linux"}}}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "MODULE.bazel.lock"
            lock.write_text(json.dumps({"moduleExtensions": {
                module.EXTENSION_ID: {native_key: native, target_key: target}}}))
            (root / "gerbil-dependencies.MODULE.bazel").write_text("")
            with patch.object(module, "host_lock_key", return_value=native_key), \
                 patch.object(module, "toolchain_lock_errors", return_value=[]), \
                 patch.object(module, "direct_source_repositories",
                              return_value={"orgize": "orgize_sources"}):
                module.sync_lock(root)
            actual = json.loads(lock.read_text())["moduleExtensions"][module.EXTENSION_ID]
            self.assertEqual(actual[target_key]["bzlTransitiveDigest"], "current-code")
            self.assertEqual(actual[target_key]["usagesDigest"], "current-usage")
            self.assertEqual(actual[target_key]["generatedRepoSpecs"]["orgize_sources"], source)
            self.assertEqual(actual[target_key]["generatedRepoSpecs"]["local_gerbil"],
                             {"platform": "linux"})

    def test_shared_digest_cannot_bless_a_stale_linux_sdk(self) -> None:
        module = pin_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "MODULE.bazel").write_text(
                'GERBIL_LINUX_REVISION = "current-sdk"\n'
                'gerbil.auto(name="local_gerbil", expected_version_prefixes=["Current"], '
                'linux_prebuilt_release_revision=GERBIL_LINUX_REVISION)\n')
            native = {"generatedRepoSpecs": {"local_gerbil": {"attributes": {
                "expected_version_prefixes": ["Current"]}}}}
            linux = {"generatedRepoSpecs": {"local_gerbil": {"attributes": {
                "expected_version_prefixes": ["Current"], "release_revision": "current-sdk"}}}}
            extension = {"os:osx,arch:aarch64": native, "os:linux,arch:amd64": linux}
            self.assertEqual(module.toolchain_lock_errors(extension, root), [])
            # Model the real failure: equal digests and current host SDK, but a
            # foreign platform still points to a different native ABI release.
            for entry in extension.values():
                entry.update(bzlTransitiveDigest="same-code", usagesDigest="same-usage")
            linux["generatedRepoSpecs"]["local_gerbil"]["attributes"]["release_revision"] = "old-sdk"
            self.assertIn("os:linux,arch:amd64: SDK local_gerbil.release_revision is stale",
                          module.toolchain_lock_errors(extension, root))
            lock = root / "MODULE.bazel.lock"
            lock.write_text(json.dumps({"moduleExtensions": {module.EXTENSION_ID: extension}}))
            before = lock.read_bytes()
            with self.assertRaisesRegex(ValueError, "native lock refresh"):
                module.sync_lock(root)
            self.assertEqual(lock.read_bytes(), before)

    def test_native_refresh_preserves_foreign_platform_evaluation(self) -> None:
        from unittest.mock import patch
        module = pin_module()
        linux, darwin = "os:linux,arch:amd64", "os:osx,arch:aarch64"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "MODULE.bazel.lock"
            foreign = {"generatedRepoSpecs": {"local_gerbil": {"platform": "darwin"}}}
            lock.write_text(json.dumps({"moduleExtensions": {module.EXTENSION_ID: {
                linux: {"stale": True}, darwin: foreign}}}))
            with patch.object(module, "host_lock_key", return_value=linux):
                module.refresh_native_lock(root)
            self.assertEqual(json.loads(lock.read_text())["moduleExtensions"][module.EXTENSION_ID],
                             {darwin: foreign})

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
