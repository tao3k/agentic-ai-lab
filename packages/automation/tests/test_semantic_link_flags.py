# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Portable SDK dependencies resolve through the current native host provider."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[3] / "bindings/runtime-c/tools/build-semantic.py"
spec = importlib.util.spec_from_file_location("semantic_build", SCRIPT)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SemanticLinkFlagsTest(unittest.TestCase):
    def test_darwin_adds_current_provider_without_dropping_sdk_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "lib/libgerbil.ldd").write_text(
                "(-L/absent/producer/openssl/lib -lcrypto -lssl -lz -lsqlite3 -lm)"
            )
            with patch.object(builder.subprocess, "check_output", return_value="-L/current/openssl/lib\n") as probe:
                flags = builder.native_link_flags(root, "Darwin")
            probe.assert_called_once_with(["pkg-config", "--libs-only-L", "openssl"], text=True)
            self.assertEqual(flags[0], "-L/current/openssl/lib")
            self.assertEqual(flags[1:], ["-L/absent/producer/openssl/lib", "-lcrypto", "-lssl", "-lz", "-lsqlite3", "-lm"])

    def test_linux_preserves_sdk_flags_without_host_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "lib/libgerbil.ldd").write_text("(-ldl -lm -lcrypto)")
            with patch.object(builder.subprocess, "check_output") as probe:
                self.assertEqual(builder.native_link_flags(root, "Linux"), ["-ldl", "-lm", "-lcrypto"])
            probe.assert_not_called()

    def test_missing_host_provider_is_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "lib/libgerbil.ldd").write_text("(-lcrypto)")
            with patch.object(builder.subprocess, "check_output", side_effect=subprocess.CalledProcessError(1, "pkg-config")):
                with self.assertRaises(subprocess.CalledProcessError):
                    builder.native_link_flags(root, "Darwin")
