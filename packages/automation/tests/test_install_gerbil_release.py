# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""The Python installer can read the upstream toolchain activation contract."""

from __future__ import annotations

import importlib.util
import tempfile
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "install_gerbil_release.py"
sys.path.insert(0, str(SCRIPT.parent))
SPEC = importlib.util.spec_from_file_location("install_gerbil_release", SCRIPT)
assert SPEC and SPEC.loader
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallGerbilReleaseTest(unittest.TestCase):
    def test_shared_qualification_action_uses_the_same_installer(self) -> None:
        # Avoid a second hand-maintained release selection in the Nix action.
        root = SCRIPT.parents[2]
        action = (root / ".github/actions/setup-gerbil/action.yml").read_text()
        self.assertIn("python3 packages/automation/install_gerbil_release.py", action)
        self.assertNotIn("revision=", action)
        self.assertNotIn("sha256=", action)
        self.assertNotIn("2591dcd", action)

    def test_linux_installer_consumes_the_canonical_native_sdk_declaration(self) -> None:
        sdk = installer.declared_toolchain(installer.ROOT)
        os_name, architecture, revision, url, digest = installer.release_configuration(("Linux", "x86_64"))
        self.assertEqual((os_name, architecture), ("linux", "x86_64"))
        self.assertEqual(revision, sdk["linux_prebuilt_release_revision"])
        self.assertEqual(digest, sdk["linux_prebuilt_sha256"])
        self.assertEqual(sdk["linux_prebuilt_urls"], [url])

    def test_activation_reads_nonexported_upstream_values(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            activation = Path(temporary) / "activate"
            activation.write_text(
                "GERBIL_PREFIX=/tmp/gerbil-prefix\n"
                "GERBIL_HOME=/tmp/gerbil-home\n"
                "GAMBOPT=p1\n",
                encoding="utf-8",
            )
            environment = installer._activated_environment(activation)

        self.assertEqual(environment["GERBIL_PREFIX"], "/tmp/gerbil-prefix")
        self.assertEqual(environment["GERBIL_HOME"], "/tmp/gerbil-home")
        self.assertEqual(environment["GAMBOPT"], "p1")


if __name__ == "__main__":
    unittest.main()
