# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""List, select, run, and report module case coverage."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

from .catalog import build_catalog
from .model import CaseContext


def module_roots(entries: list[str]) -> dict[str, Path]:
    roots: dict[str, Path] = {}
    for entry in entries:
        module, separator, raw_path = entry.partition("=")
        if not separator or not module or not raw_path or module in roots:
            raise ValueError("--module-root requires unique NAME=PATH entries")
        path = Path(raw_path).resolve()
        if not path.is_dir():
            raise ValueError("module root does not exist: " + module)
        roots[module] = path
    return roots


def parser() -> argparse.ArgumentParser:
    command = argparse.ArgumentParser(description=__doc__)
    command.add_argument("action", choices=("list", "run", "coverage"))
    command.add_argument("--repo-root", type=Path, default=Path.cwd())
    command.add_argument("--case")
    command.add_argument("--module")
    command.add_argument("--part")
    command.add_argument("--composition", choices=("single", "cross"))
    command.add_argument("--mode", choices=("unit", "native", "live"))
    command.add_argument("--module-root", action="append", default=[], metavar="NAME=PATH")
    command.add_argument("--receipt", type=Path,
                         help="write a structured result for the selected cases")
    return command


def source_state(repository_root: Path) -> tuple[str | None, bool | None]:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=repository_root, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
    )
    if result.returncode != 0:
        return None, None
    status = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=normal"],
        cwd=repository_root, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, check=False,
    )
    return result.stdout.strip(), bool(status.stdout) if status.returncode == 0 else None


def main(argv: list[str] | None = None) -> int:
    command = parser()
    args = command.parse_args(argv)
    repository_root = args.repo_root.resolve()
    catalog = build_catalog()
    if args.action == "coverage":
        if not (repository_root / "modules").is_dir():
            command.error("--repo-root must contain modules/")
        for module, cases in catalog.module_coverage(repository_root):
            sys.stdout.write(module + "\t" + str(len(cases)) + "\t"
                             + ",".join(cases) + "\n")
        return 0

    selected = catalog.select(identity=args.case, module=args.module, part=args.part,
                              composition=args.composition, mode=args.mode)
    if args.action == "list":
        for case in selected:
            targets = ",".join(target.module + ":" + target.part
                               for target in case.spec.targets)
            sys.stdout.write(case.spec.identity + "\t" + case.spec.mode
                             + "\t" + case.spec.composition + "\t" + targets + "\n")
        return 0
    if not selected:
        command.error("no cases match the selection")
    runtime_source = repository_root / "packages/python-runtime/src"
    if runtime_source.is_dir() and str(runtime_source) not in sys.path:
        sys.path.insert(0, str(runtime_source))
    try:
        context = CaseContext(repository_root, module_roots(args.module_root))
    except ValueError as error:
        command.error(str(error))
    failed = False
    results: list[dict[str, object]] = []
    for case in selected:
        if case.spec.mode == "live":
            command.error("interactive live cases use their dedicated CLI")
        started = time.perf_counter()
        try:
            evidence = case.check(context)
        except Exception as error:
            failed = True
            sys.stdout.write(case.spec.identity + "\tFAIL\t"
                             + type(error).__name__ + ": " + str(error) + "\n")
            results.append({"identity": case.spec.identity, "status": "FAIL",
                            "duration_ms": round((time.perf_counter() - started) * 1000),
                            "error_type": type(error).__name__, "error": str(error)})
        else:
            elapsed = round(time.perf_counter() - started, 3)
            sys.stdout.write(case.spec.identity + "\tPASS\t"
                             + str(elapsed) + "s\n")
            results.append({"identity": case.spec.identity, "status": "PASS",
                            "duration_ms": round((time.perf_counter() - started) * 1000),
                            "evidence": dict(evidence.details) if evidence else {}})
        sys.stdout.flush()
    if args.receipt:
        receipt = args.receipt.resolve()
        receipt.parent.mkdir(parents=True, exist_ok=True)
        revision, dirty = source_state(repository_root)
        document = {"schema": "agentic-ai-lab.testing-cases.v1",
                    "source_revision": revision, "working_tree_dirty": dirty,
                    "results": results}
        temporary = receipt.with_name(receipt.name + ".tmp")
        temporary.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
        temporary.replace(receipt)
    return 1 if failed else 0
