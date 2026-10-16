# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import contextlib
import hashlib
import io
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from _scheme_datum import parse_scheme_datum, write_scheme_datum
from packages.bazel import scheme_projection_artifact_tool as projection_tool


class SchemeProjectionArtifactToolTest(unittest.TestCase):
    def test_native_failure_preserves_the_gerbil_diagnostic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            source = root / "flow.ss"
            projection = root / "runtime-load-projection.ss"
            compiled_root = root / "compiled"
            dependency_root = root / "dependencies"
            fake_gxi = root / "gxi"

            source.write_text("(use-composition smoke)\n", encoding="utf-8")
            projection.write_text(";; projection\n", encoding="utf-8")
            (compiled_root / "lib").mkdir(parents=True)
            dependency_root.mkdir()
            fake_gxi.write_text(
                "#!/bin/sh\n"
                "printf '%s\\n' 'native projection diagnostic'\n"
                "exit 70\n",
                encoding="utf-8",
            )
            fake_gxi.chmod(0o755)
            diagnostic = io.StringIO()

            with contextlib.redirect_stderr(diagnostic):
                with self.assertRaises(subprocess.CalledProcessError):
                    projection_tool._load_projection_rows(
                        gxi=fake_gxi,
                        source=source,
                        projection=projection,
                        compiled_root=compiled_root,
                        dependency_root=dependency_root,
                        project_dependency_roots=(),
                    )

            self.assertIn("native projection diagnostic", diagnostic.getvalue())

    def test_main_writes_packaged_digest_envelope(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            source = root / "flow.ss"
            projection = root / "runtime-load-projection.ss"
            compiled_root = root / "compiled"
            dependency_marker = root / "dependencies" / ".root"
            project_dependency_root = root / "package"
            loadpath_capture = root / "loadpath.txt"
            runner_capture = root / "runner.ss"
            output = root / "flow.ss.poo-flow-projection.sexp"
            fake_gxi = root / "gxi"

            source.write_text("(use-composition smoke)\n", encoding="utf-8")
            projection.write_text(";; projection\n", encoding="utf-8")
            (compiled_root / "lib" / "poo-flow").mkdir(parents=True)
            dependency_marker.parent.mkdir(parents=True)
            dependency_marker.write_text("dependencies\n", encoding="utf-8")
            (project_dependency_root / ".gerbil" / "lib").mkdir(parents=True)
            fake_gxi.write_text(
                "#!/bin/sh\n"
                f"printf '%s' \"$GERBIL_LOADPATH\" >'{loadpath_capture}'\n"
                f"cat \"$1\" >'{runner_capture}'\n"
                "printf '%s\\n' '((\"schema\" \"projection.v1\") "
                "(\"name\" \"smoke\"))'\n",
                encoding="utf-8",
            )
            fake_gxi.chmod(0o755)

            status = projection_tool.main(
                [
                    "--gxi",
                    str(fake_gxi),
                    "--compiled-root",
                    str(compiled_root),
                    "--dependency-root-marker",
                    str(dependency_marker),
                    "--project-dependency-root",
                    str(project_dependency_root),
                    "--projection-source",
                    str(projection),
                    "--source",
                    str(source),
                    "--output",
                    str(output),
                ]
            )

            artifact = dict(parse_scheme_datum(output.read_text(encoding="utf-8")))
            expected = (
                ("schema", projection_tool.SCHEMA),
                ("source-digest", _digest(source)),
                ("projection-digest", _digest(projection)),
                (
                    "rows",
                    (("schema", "projection.v1"), ("name", "smoke")),
                ),
            )
            self.assertEqual(status, 0)
            self.assertEqual(
                loadpath_capture.read_text(encoding="utf-8"),
                os.pathsep.join(
                    (
                        str((compiled_root / "lib").resolve()),
                        str((project_dependency_root / ".gerbil" / "lib").resolve()),
                        str(dependency_marker.parent.resolve()),
                    )
                ),
            )
            self.assertEqual(
                output.read_text(encoding="utf-8"),
                write_scheme_datum(expected) + "\n",
            )
            self.assertEqual(artifact["schema"], projection_tool.SCHEMA)
            self.assertEqual(artifact["source-digest"], _digest(source))
            self.assertEqual(artifact["projection-digest"], _digest(projection))
            self.assertEqual(
                artifact["rows"],
                (("schema", "projection.v1"), ("name", "smoke")),
            )
            runner_source = runner_capture.read_text(encoding="utf-8")
            self.assertIn(
                ":core/profile-composition/selection-syntax",
                runner_source,
            )
            self.assertIn(
                ":core/profile-composition/profile-bundle",
                runner_source,
            )
            self.assertIn(
                ":poo-flow/modules/workflow/scenario/profile-root",
                runner_source,
            )
            self.assertIn(
                ":poo-flow/modules/funflow/profile-library",
                runner_source,
            )
            self.assertNotIn(
                ":poo-flow/src/user-interface/init-syntax",
                runner_source,
            )


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()
