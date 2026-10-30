# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from packages.bazel import gerbil_project_environment_tool as environment_tool


class GerbilProjectEnvironmentToolTest(unittest.TestCase):
    def test_writable_runtime_preserves_producer_and_cleans_after_command_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            producer = root / "producer"
            workspace = root / "workspace"
            library = producer / ".gerbil" / "lib"
            library.mkdir(parents=True)
            # A library-only producer has no bin directory. Qualification must
            # still be able to publish executables in its own writable prefix.
            marker = library / "source.marker"
            marker.write_text("compiled-source")
            workspace.mkdir()
            wrapper = root / "native-env"
            wrapper.write_text('#!/bin/sh\nexec "$@"\n')
            wrapper.chmod(0o755)
            capture = root / "capture.json"
            command = root / "command"
            command.write_text(
                '#!/usr/bin/env python3\n'
                'import json, os\nfrom pathlib import Path\n'
                'runtime = Path(os.environ["GERBIL_PATH"])\n'
                '(runtime / "lib" / "scratch").write_text("mutable")\n'
                'libraries = os.environ["GERBIL_LOADPATH"].split(os.pathsep)\n'
                'assert (Path(libraries[1]) / "source.marker").read_text() == "compiled-source"\n'
                '(runtime / "bin").mkdir(exist_ok=True)\n'
                '(runtime / "bin" / "qualification-tool").write_text("owned")\n'
                'Path(os.environ["CAPTURE"]).write_text(json.dumps(str(runtime)))\n'
                'raise SystemExit(int(os.environ["COMMAND_STATUS"]))\n'
            )
            command.chmod(0o755)
            arguments = [
                "--gxi", str(root / "gxi"), "--native-scheme-env", str(wrapper),
                "--project-root", str(producer), "--project-receipt", str(root / "receipt"),
                "--dependency-root-marker", str(root / "dependency" / ".root"),
                "--workspace", str(workspace), "--declaration-receipt", str(root / "declaration"),
                "--runtime-directory", ".runtimes", "--", str(command),
            ]
            for status in (0, 7):
                with self.subTest(status=status), patch.dict(
                    os.environ, {"CAPTURE": str(capture), "COMMAND_STATUS": str(status)}
                ):
                    self.assertEqual(environment_tool.main(arguments), status)
                    self.assertFalse(Path(json.loads(capture.read_text())).exists())
                    self.assertEqual(marker.read_text(), "compiled-source")
                    self.assertFalse((library / "scratch").exists())
                    self.assertFalse((producer / ".gerbil" / "bin").exists())

    def test_main_launches_command_with_declared_project_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            project_root = root / "project"
            gerbil_path = project_root / ".gerbil"
            dependency_project = root / "dependency-project"
            dependency_marker = root / "toolchain-libraries" / ".root"
            workspace = root / "workspace"
            working_directory = workspace / "packages" / "python-runtime"
            gxi = root / "toolchain" / "bin" / "gxi"
            native_scheme_env = root / "native-scheme-env"
            capture = root / "environment.json"
            capture_command = root / "capture-environment"
            declaration_receipt = root / "environment.receipt.json"
            project_receipt = root / "project.receipt.json"

            (gerbil_path / "lib" / "agentic-ai-lab").mkdir(parents=True)
            (dependency_project / ".gerbil" / "lib").mkdir(parents=True)
            dependency_marker.parent.mkdir(parents=True)
            dependency_marker.write_text("libraries\n", encoding="utf-8")
            working_directory.mkdir(parents=True)
            gxi.parent.mkdir(parents=True)
            gxi.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            gxi.chmod(0o755)
            native_scheme_env.write_text("#!/bin/sh\nexec \"$@\"\n", encoding="utf-8")
            native_scheme_env.chmod(0o755)
            declaration_receipt.write_text('{"schema":"declaration.v1"}\n')
            project_receipt.write_text('{"schema":"project.v1"}\n')
            capture_command.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os\n"
                "from pathlib import Path\n"
                "Path(os.environ['CAPTURE']).write_text(json.dumps({\n"
                "  'gerbil_path': os.environ['GERBIL_PATH'],\n"
                "  'gerbil_loadpath': os.environ['GERBIL_LOADPATH'],\n"
                "  'path': os.environ['PATH'],\n"
                "  'declaration': os.environ['AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT'],\n"
                "  'project': os.environ['AGENTIC_AI_LAB_GERBIL_PROJECT_RECEIPT'],\n"
                "  'runtime': os.environ['AGENTIC_AI_LAB_GERBIL_ENV_RECEIPT_JSON'],\n"
                "  'cwd': os.getcwd(),\n"
                "}))\n",
                encoding="utf-8",
            )
            capture_command.chmod(0o755)

            with patch.dict(os.environ, {"CAPTURE": str(capture)}):
                status = environment_tool.main(
                    [
                        "--gxi",
                        str(gxi),
                        "--native-scheme-env",
                        str(native_scheme_env),
                        "--project-root",
                        str(project_root),
                        "--project-receipt",
                        str(project_receipt),
                        "--dependency-root-marker",
                        str(dependency_marker),
                        "--project-dependency-root",
                        str(dependency_project),
                        "--workspace",
                        str(workspace),
                        "--working-directory",
                        "packages/python-runtime",
                        "--declaration-receipt",
                        str(declaration_receipt),
                        "--",
                        str(capture_command),
                    ]
                )

            evidence = json.loads(capture.read_text(encoding="utf-8"))
            runtime_receipt = json.loads(evidence["runtime"])
            self.assertEqual(status, 0)
            self.assertEqual(evidence["gerbil_path"], str(gerbil_path.resolve()))
            self.assertEqual(
                evidence["gerbil_loadpath"],
                os.pathsep.join(
                    (
                        str((gerbil_path / "lib").resolve()),
                        str((dependency_project / ".gerbil" / "lib").resolve()),
                        str(dependency_marker.parent.resolve()),
                    )
                ),
            )
            self.assertEqual(
                evidence["path"].split(os.pathsep)[0],
                str(gxi.resolve().parent),
            )
            self.assertEqual(evidence["declaration"], str(declaration_receipt.resolve()))
            self.assertEqual(evidence["project"], str(project_receipt.resolve()))
            self.assertEqual(evidence["cwd"], str(working_directory.resolve()))
            self.assertEqual(runtime_receipt["schema"], environment_tool.RUNTIME_SCHEMA)
            self.assertEqual(runtime_receipt["gxi"], str(gxi.resolve()))


if __name__ == "__main__":
    unittest.main()
