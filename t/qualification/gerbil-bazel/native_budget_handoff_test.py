#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Exercise the actual generated exports without substituting a compiler."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import unittest

from shared_gerbil_capability_test import resolve_runfile

WRAPPERS: list[Path] = []


def exported_environment(path: Path, caller: dict[str, str], repetitions: int = 1) -> dict[str, str]:
    # Stop before tool invocation. This tests repository-generated policy,
    # not a copied environment builder or an alternate Gerbil Harness.
    source = path.read_text(encoding="utf-8")
    exports, marker, _ = source.partition("export GERBIL_NATIVE_ABI=")
    if not marker:
        raise AssertionError(f"native environment boundary is missing: {path}")
    result = subprocess.run(
        ["/bin/bash", "-c", exports * repetitions + "\n/usr/bin/env -0"],
        env={"PATH": os.defpath, **caller},
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return dict(row.decode().split("=", 1) for row in result.stdout.split(b"\0") if row)


class NativeBudgetHandoffTest(unittest.TestCase):
    def test_unset_budgets_keep_configured_defaults(self) -> None:
        for path in WRAPPERS:
            with self.subTest(wrapper=path.name):
                actual = exported_environment(path, {})
                self.assertGreater(int(actual["GERBIL_BUILD_CORES"]), 0)
                self.assertIn("~~lib=" + actual["GERBIL_HOME"] + "/lib", actual["GAMBOPT"])

    def test_child_budget_survives_while_native_identity_stays_pinned(self) -> None:
        for path in WRAPPERS:
            with self.subTest(wrapper=path.name):
                baseline = exported_environment(path, {})
                actual = exported_environment(path, {
                    "GERBIL_BUILD_CORES": "2",
                    "GAMBOPT": "max-heap=16M,debug=q,~~=/foreign,~~lib=/foreign/lib",
                    "GERBIL_HOME": "/foreign",
                    "GERBIL_GSC": "/foreign/gsc",
                })
                self.assertEqual(actual["GERBIL_BUILD_CORES"], "2")
                options = actual["GAMBOPT"].split(",")
                self.assertEqual([x for x in options if x.startswith("max-heap=")], ["max-heap=16M"])
                self.assertIn("debug=q", options)
                aliases = dict(x.split("=", 1) for x in options if x.startswith("~~"))
                self.assertEqual(aliases["~~"], baseline["GERBIL_HOME"])
                self.assertEqual(aliases["~~lib"], baseline["GERBIL_HOME"] + "/lib")
                self.assertEqual(actual["GERBIL_HOME"], baseline["GERBIL_HOME"])
                self.assertEqual(actual["GERBIL_GSC"], baseline["GERBIL_GSC"])

    def test_nested_wrappers_preserve_the_same_budget_without_mapping_growth(self) -> None:
        caller = {"GERBIL_BUILD_CORES": "1", "GAMBOPT": "max-heap=32M,debug=q"}
        for path in WRAPPERS:
            with self.subTest(wrapper=path.name):
                first = exported_environment(path, caller)
                repeated = exported_environment(path, caller, repetitions=3)
                self.assertEqual(repeated["GERBIL_BUILD_CORES"], "1")
                self.assertEqual(repeated["GAMBOPT"], first["GAMBOPT"])

    def test_explicit_empty_runtime_options_keep_only_native_mappings(self) -> None:
        for path in WRAPPERS:
            with self.subTest(wrapper=path.name):
                actual = exported_environment(path, {"GAMBOPT": ""})
                self.assertTrue(actual["GAMBOPT"].startswith("~~="))
                self.assertNotIn("max-heap=", actual["GAMBOPT"])


if __name__ == "__main__":
    WRAPPERS = [resolve_runfile(key) for key in sys.argv[1:]]
    if not WRAPPERS:
        raise SystemExit("native wrapper runfiles are required")
    unittest.main(argv=[sys.argv[0]])
