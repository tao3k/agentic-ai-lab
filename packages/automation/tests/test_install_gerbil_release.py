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

    def test_linux_installer_keeps_the_verified_release_pin(self) -> None:
        os_name, architecture, revision, url, digest = installer.release_configuration(("Linux", "x86_64"))
        self.assertEqual((os_name, architecture), ("linux", "x86_64"))
        self.assertEqual(revision, "2591dcd9b7c6d2c4e9dd8611a17c5b1a5d82bbdb")
        self.assertEqual(digest, "3b345b1af68dfbbc0e73bae64941e4c8910d0ca192d81432ce699c5af385b565")
        tag = f"gerbil-v0.19-{revision}-linux-x86_64-portable-full-single-host-unlimited-patcha379bb244bfa"
        self.assertEqual(url, f"https://github.com/tao3k/gerbil-bazel/releases/download/{tag}/{tag}.tar.gz")

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
