# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Native for the model study study."""

import json
import subprocess
import sys
from ._config import HARNESS, ROOT, RUNTIME
from ._sources import source_closure


def native(command, log):
    with log.open("w") as output:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
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
    markers = ("MODULE-OK", "HARNESS-OK", "\nOK\n")
    errors = (
        "ERROR CASE",
        "ERROR CHECK",
        "ERROR HARNESS",
        "ERROR MODULE",
        "Heap overflow",
        "Stack overflow",
    )
    if (
        status
        or not all(marker in text for marker in markers)
        or any(error in text for error in errors)
    ):
        raise RuntimeError(f"native gate failed with status {status}: {log}")
    return text


def probe(output):
    subprocess.run(
        ["gxi", str(ROOT / "t/harness/artifact-admission.ss"), "check"],
        cwd=ROOT,
        check=True,
    )
    output.mkdir(parents=True, exist_ok=False)
    text = native(
        HARNESS + RUNTIME + ["t/qualification/scheme-model-closure-test.ss"],
        output / "preflight.native.log",
    )
    cases = [
        json.loads(line.removeprefix("STUDY-CASE "))
        for line in text.splitlines()
        if line.startswith("STUDY-CASE ")
    ]
    if len(cases) != 24 or len({case["id"] for case in cases}) != 24:
        raise ValueError("expected 24 unique independent native truths")
    imports = sorted({name for case in cases for name in case["imports"]})
    closures = source_closure(imports, output / "source-closure.native.log")
    return cases, closures


def native_projection(raw_path, directory):
    text = native(
        HARNESS + RUNTIME + ["--study-project", str(raw_path)],
        directory / "projection.native.log",
    )
    projected = json.loads(
        next(
            line.removeprefix("NATIVE-PROJECTION ")
            for line in text.splitlines()
            if line.startswith("NATIVE-PROJECTION ")
        )
    )["prediction"]
    return projected if isinstance(projected, str) else None


def native_score(id, candidate, directory):
    directory.mkdir()
    path = directory / "candidate.sexp"
    path.write_text(candidate if candidate is not None else "")
    text = native(
        HARNESS + RUNTIME + ["--study-score", id, str(path)],
        directory / "score.native.log",
    )
    observation = json.loads(
        next(
            line.removeprefix("NATIVE-SCORE ")
            for line in text.splitlines()
            if line.startswith("NATIVE-SCORE ")
        )
    )
    return observation
