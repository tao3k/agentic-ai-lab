# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Sources for the model study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import shutil
from ._config import HARNESS, ROOT, RUNTIME
from .._source_files import _source_files


def digest(data):
    return hashlib.sha256(data).hexdigest()


def producer_hashes(paths=None):
    from .. import supervision

    if paths is None:
        paths = {
            "packages/python-testing/src/" + __name__.replace(".", "/") + ".py": Path(
                __file__
            ),
            str(_study_module_file("supervision")): Path(supervision.__file__),
            "t/model/response-projection.ss": ROOT / "t/model/response-projection.ss",
            "t/model/source-closure.ss": ROOT / "t/model/source-closure.ss",
        }
    elif not isinstance(paths, dict):
        paths = {str(path): Path(path) for path in paths}
    return {
        name: digest(path.read_bytes()) for name, path in _source_files(paths).items()
    }


def module_path(name):
    if name.startswith("gerbil-ascent/"):
        return ROOT / (name.split("/", 1)[1] + ".ss")
    if name in ("yuanxu/types.ssi", "yuanxu/types.scm", "yuanxu/types~0.scm"):
        return ROOT / ".data/dependencies/prefix/lib" / name
    raise ValueError("unrecognized source binding")


def source_environment():
    env = os.environ.copy()
    existing = env.get("GERBIL_LOADPATH", "")
    # Native executables do not inherit gxi's standard-library initialization.
    # Locate the installed SDK through the actual launcher, never a guessed ABI.
    launcher = shutil.which("gxi")
    if launcher is None:
        raise ValueError("installed Gerbil launcher is unavailable")
    sdk = Path(launcher).resolve().parent.parent
    if not (sdk / "lib/gerbil/core.ssi").is_file():
        raise ValueError("installed Gerbil standard-library interface is unavailable")
    env["GERBIL_HOME"] = str(sdk)
    env["GERBIL_LOADPATH"] = (
        str(ROOT / ".cache/ascent/compiled-library/lib")
        + (":" + existing if existing else "")
        + ":"
        + str(sdk / "lib")
    )
    return env


def source_closure(imports, log):
    command = HARNESS + RUNTIME + ["--source-closure", *imports]
    with log.open("w") as output:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            env=source_environment(),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        for line in process.stdout:
            output.write(line)
            output.flush()
            sys.stdout.write(line)
            sys.stdout.flush()
        status = process.wait()
    text = log.read_text()
    if status or not all(
        marker in text for marker in ("MODULE-OK", "HARNESS-OK", "\nOK\n")
    ):
        raise RuntimeError("compiler source closure failed")
    records = [
        json.loads(line.removeprefix("SOURCE-CLOSURE "))
        for line in text.splitlines()
        if line.startswith("SOURCE-CLOSURE ")
    ]
    if {record["root"] for record in records} != set(imports):
        raise ValueError("compiler omitted an import root")
    return {record["root"]: record["modules"] for record in records}
