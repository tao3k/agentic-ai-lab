#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Produce the existing wheel handoffs through native library entrypoints."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def run(command: list[str], budget: int) -> dict:
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT, timeout=budget, check=False)
        status = result.returncode
    except subprocess.TimeoutExpired:
        status = 124
    elapsed = time.monotonic() - started
    return dict(status=status, elapsedSeconds=elapsed, budgetSeconds=budget,
                withinBudget=elapsed <= budget)


def main() -> int:
    head = os.environ.get("GITHUB_SHA") or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    runtime = ROOT / ".ci/runtime-c"
    runtime.mkdir(parents=True, exist_ok=True)
    build = run(["just", "--set", "runtime_c_output", str(runtime), "build-runtime-c", "build-bundle-v1"], 90)
    if build["status"] or not build["withinBudget"]:
        write(runtime / "build-receipt.json", build)
        return build["status"] or 1
    acceptance = run(["just", "--set", "runtime_c_output", str(runtime), "test-runtime-c", "test-bundle-v1",
                      "test-runtime-c-sanitizers"], 540)
    write(runtime / "acceptance-receipt.json", acceptance)
    if acceptance["status"] or not acceptance["withinBudget"]:
        return acceptance["status"] or 1
    library = runtime / "libagentic_ai_lab_runtime_v0.so"
    symbols = subprocess.check_output(["nm", "-D", "--defined-only", str(library)], text=True)
    names = sorted(set(line.split()[-1] for line in symbols.splitlines() if line.split()))
    write(runtime / "producer-receipt.json", {
        "schema": "agentic-ai-lab.ci.runtime-c-handoff.v1",
        "producerJob": "runtime-gerbil-tests", "producerTarget": "make runtime",
        "currentHeadSha": head, "artifactPath": library.name,
        "artifactDigest": digest(library), "artifactBytes": library.stat().st_size,
        "exportedSymbolsDigest": hashlib.sha256(("\n".join(names) + "\n").encode()).hexdigest(),
        "exportedSymbolCount": len(names), "artifactAvailable": True,
        "acceptanceReceiptDigest": digest(runtime / "acceptance-receipt.json"), **build,
    })
    projection = ROOT / ".ci/python-wheel-projection"
    output = projection / "wheel_smoke.ss.agentic-ai-lab-projection.sexp"
    projection.mkdir(parents=True, exist_ok=True)
    source = ROOT / "packages/python-runtime/src/agentic_ai_lab_runtime/projections/wheel_smoke.ss"
    result = run([sys.executable, "-m", "agentic_ai_lab_runtime.scheme_projection_artifact",
                  "export", str(source), "--cwd", str(ROOT), "--output", str(output), "--force"], 120)
    write(projection / "producer-receipt.json", {
        "schema": "agentic-ai-lab.ci.scheme-projection-handoff.v1",
        "producerJob": "runtime-gerbil-tests", "compileOwner": "gerbil build",
        "currentHeadSha": head, "artifactAvailable": output.is_file(),
        "artifactDigest": digest(output) if output.is_file() else "", **result,
    })
    return result["status"] or (0 if result["withinBudget"] and output.is_file() else 1)


if __name__ == "__main__":
    raise SystemExit(main())
