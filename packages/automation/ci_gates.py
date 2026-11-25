#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Repository-owned CI gate helpers extracted out of GitHub Actions YAML.

Both local `just ci-*` recipes and `.github/workflows/ci.yml` call this module
so receipt verification, downstream qualification, and dynamic Lean proof
discovery have one authoritative implementation.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parents[2]
LEAN_LAKEFILE = REPO_ROOT / "packages" / "proofs" / "lean" / "lakefile.lean"

FORBIDDEN_TEST_MARKERS = (
    "ERROR CASE",
    "ERROR CHECK",
    "ERROR HARNESS",
    "Heap overflow",
    "Stack overflow",
)

DOWNSTREAM_SUITES: dict[str, str] = {
    "context-memory": "t/integration/lab/dependencies/yuanxu-context-memory-downstream-test.ss",
    "governance": "t/integration/lab/dependencies/yuanxu-governance-downstream-test.ss",
    "deployment": "t/yanxu/modules/services/opentofu/deployment-test.ss",
}

DOWNSTREAM_RECEIPT_MARKERS: dict[str, tuple[str, ...]] = {
    "governance": (
        "LAB-GOVERNANCE-PRODUCT-USE-OK",
        "profile=governance roots=1 selected-tests=1 cold=A/B hot=0 clean-isolation=ok",
    ),
    "deployment": (
        "LAB-DEPLOYMENT-PRODUCT-USE-OK",
        "profile=deployment roots=1 owners=4 discovered-tests=3 lab-tests=1 "
        "runtime-qualification=1 cold=A/B hot=0 clean-isolation=ok",
    ),
    "context-memory": (
        "LAB-CONTEXT-USE-OK mode=base",
        "LAB-CONTEXT-USE-OK mode=enabled",
        "LAB-CONTEXT-USE-OK mode=withdrawn",
        "LAB-CONTEXT-REFUSAL-OK owner=ai-agentic-context feature=memory",
        "LAB-CONTEXT-MEMORY-DOWNSTREAM-OK",
        "hot=0 clean-isolation=ok scopes-during-build=0",
    ),
}

LEAN_LIB_PATTERN = re.compile(
    r"^\s*lean_lib\s+(AgenticAILab(Module|Scenario)([A-Za-z0-9]+)Proof)\s+where\b",
    re.MULTILINE,
)


def camel_to_kebab(name: str) -> str:
    return re.sub(r"(?<!^)([A-Z])", r"-\1", name).lower()


def verify_focused_log_text(text: str, extra_markers: tuple[str, ...] = ()) -> None:
    required = ("MODULE-OK", "HARNESS-OK", *extra_markers)
    missing = [marker for marker in required if marker not in text]
    if missing:
        raise ValueError(f"missing required receipt markers: {', '.join(missing)}")
    present_forbidden = [marker for marker in FORBIDDEN_TEST_MARKERS if marker in text]
    if present_forbidden:
        raise ValueError(f"forbidden test error markers present: {', '.join(present_forbidden)}")
    if not re.search(r"^OK\s*$", text, re.MULTILINE):
        raise ValueError("missing final OK line")


def verify_downstream_log_text(category: str, text: str) -> None:
    markers = DOWNSTREAM_RECEIPT_MARKERS[category]
    verify_focused_log_text(text, markers)
    if category == "deployment":
        pattern = (
            r"^LAB-DEPLOYMENT-DOWNSTREAM-OK targets=[1-9][0-9]* "
            + re.escape(markers[1])
            + r"\s*$"
        )
        if not re.search(pattern, text, re.MULTILINE):
            raise ValueError("deployment downstream target receipt is missing")


def discover_lean_matrix(lakefile: Path = LEAN_LAKEFILE) -> dict[str, list[dict[str, object]]]:
    text = lakefile.read_text(encoding="utf-8")
    entries: list[dict[str, object]] = []
    for match in LEAN_LIB_PATTERN.finditer(text):
        target, kind, stem = match.group(1), match.group(2), match.group(3)
        owner = camel_to_kebab(stem)
        if kind == "Scenario":
            owner = f"{owner}-scenario"
        entries.append(
            {
                "owner": owner,
                "target": target,
                "ffi": target == "AgenticAILabModuleGovernanceProof",
            }
        )
    if not entries:
        raise ValueError(f"no Lean module/scenario targets discovered in {lakefile}")
    return {"include": entries}


def _run_and_tee(
    command: list[str],
    log_path: Path,
    *,
    env: dict[str, str] | None = None,
) -> int:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as log_file:
        process = subprocess.Popen(
            command,
            cwd=REPO_ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            log_file.write(line)
        return process.wait()


def run_qualify_downstreams(log_dir: Path) -> int:
    subprocess.run(
        ["gerbil", "env", "gerbil", "pkg", "build", "github.com/tao3k/agentic-ai-lab"],
        cwd=REPO_ROOT,
        check=True,
    )
    subprocess.run(["gerbil", "env", "just", "clean"], cwd=REPO_ROOT, check=True)

    downstream_env = dict(os.environ)
    downstream_env.setdefault("LAB_TEST_FILE_BUDGET", "300s")

    downstream_status = 0
    for category in ("context-memory", "governance", "deployment"):
        suite = DOWNSTREAM_SUITES[category]
        log_path = log_dir / f"lab-{category}-downstream.log"
        code = _run_and_tee(
            ["/usr/bin/time", "-p", "gerbil", "env", "just", "test-file", suite],
            log_path,
            env=downstream_env,
        )
        if code != 0:
            downstream_status = code

    if downstream_status != 0:
        return downstream_status

    for category in ("governance", "deployment", "context-memory"):
        log_path = log_dir / f"lab-{category}-downstream.log"
        try:
            verify_downstream_log_text(category, log_path.read_text(encoding="utf-8"))
        except ValueError as exc:
            raise SystemExit(f"{category} downstream receipt is incomplete or failed: {exc}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Repository-owned CI gate helpers.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    verify_cmd = subparsers.add_parser("verify-focused-log")
    verify_cmd.add_argument("log_path", type=Path)

    downstreams_cmd = subparsers.add_parser("qualify-downstreams")
    downstreams_cmd.add_argument(
        "--log-dir",
        type=Path,
        default=Path(os.environ.get("RUNNER_TEMP", "/tmp")),
    )

    lean_cmd = subparsers.add_parser("lean-matrix")
    lean_cmd.add_argument("--lakefile", type=Path, default=LEAN_LAKEFILE)

    args = parser.parse_args(argv)
    if args.command == "verify-focused-log":
        try:
            verify_focused_log_text(args.log_path.read_text(encoding="utf-8"))
        except ValueError as exc:
            raise SystemExit(f"focused log verification failed ({args.log_path}): {exc}")
        return 0
    if args.command == "qualify-downstreams":
        return run_qualify_downstreams(args.log_dir)
    if args.command == "lean-matrix":
        print(json.dumps(discover_lean_matrix(args.lakefile), separators=(",", ":")))
        return 0
    raise SystemExit(f"unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
