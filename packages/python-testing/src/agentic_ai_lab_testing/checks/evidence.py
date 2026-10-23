# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Agentic AI Lab evidence-assessment case through its heap-fenced Scheme gate."""

from __future__ import annotations

import os
import subprocess

from ..model import CaseContext


def evidence_assessment(context: CaseContext) -> None:
    env = os.environ.copy()
    env.setdefault("GERBIL_PATH", str(context.repository_root / ".gerbil"))
    roots = [str(path) for name, path in context.module_roots.items()
             if name in ("gerbil-ascent", "gerbil-parser")]
    env["GERBIL_LOADPATH"] = ":".join(
        roots + ([env["GERBIL_LOADPATH"]] if env.get("GERBIL_LOADPATH") else []))
    result = subprocess.run(
        ["just", "test-file", "t/evidence-assessment-core-test.ss"],
        cwd=context.repository_root, env=env, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=150,
        check=False,
    )
    output = result.stdout
    required = ("MODULE-OK t/evidence-assessment-core-test.ss", "HARNESS-OK", "\nOK\n")
    errors = ("ERROR CASE", "ERROR CHECK", "ERROR HARNESS", "Heap overflow", "Stack overflow")
    if result.returncode or any(token not in output for token in required):
        raise AssertionError("evidence-assessment Scheme case did not complete")
    if any(token in output for token in errors):
        raise AssertionError("evidence-assessment Scheme case contains an error marker")
