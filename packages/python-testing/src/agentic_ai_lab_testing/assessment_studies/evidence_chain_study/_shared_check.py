# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared check for the evidence chain study study."""

import hashlib, json
from pathlib import Path
from .. import inference_reuse_study as s


def shared_check(directory, _output=None):
    plan = json.loads((directory / "plan.json").read_text())
    assert (
        hashlib.sha256((directory / "plan.json").read_bytes()).hexdigest()
        == (directory / "plan.sha256").read_text().strip()
    )
    assert (
        hashlib.sha256((directory / plan["library"]).read_bytes()).hexdigest()
        == plan["librarySha256"]
    )
    assert (
        hashlib.sha256((directory / "qualification.json").read_bytes()).hexdigest()
        == plan["qualificationSha256"]
    )
    for name, h in plan["inputs"].items():
        path = Path(name)
        assert (
            not path.is_absolute()
            and ".." not in path.parts
            and ".cache" not in path.parts
        )
        assert (
            (directory / "inputs" / path)
            .resolve()
            .is_relative_to((directory / "inputs").resolve())
        )
        assert (s.ROOT / path).resolve().is_relative_to(s.ROOT.resolve())
        assert (
            hashlib.sha256((directory / "inputs" / path).read_bytes()).hexdigest() == h
        ), "snapshot drift " + name
        assert hashlib.sha256((s.ROOT / path).read_bytes()).hexdigest() == h, (
            "loaded checkout drift " + name
        )
    from ..interface_tests import qualification_inputs

    runtime = json.loads((directory / "pyo3-runtime-receipt.json").read_text())
    assert qualification_inputs([]) == runtime, (
        "loaded PyO3 runtime or syntax resources drift"
    )
    return plan


def shared_committed_check(directory, output):
    import subprocess

    plan = shared_check(directory)
    blocked = []
    for name, h in plan["inputs"].items():
        p = subprocess.run(
            ["git", "show", "HEAD:" + name],
            cwd=s.ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        if p.returncode or hashlib.sha256(p.stdout).hexdigest() != h:
            blocked.append(name)
    output.mkdir(parents=True, exist_ok=True)
    result = {
        "portableSnapshotInputsVerified": True,
        "committedInputsVerified": not blocked,
        "blocked": blocked,
        "networkReproductionVerified": False,
        "portableWheelQualified": False,
    }
    (output / "committed-input-check.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    if blocked:
        raise SystemExit(2)
    return result
