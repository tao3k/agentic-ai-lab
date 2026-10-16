# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Hermetic Bazel tool for exporting a packaged Scheme projection artifact."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import tempfile
from collections.abc import Sequence
from pathlib import Path

from _scheme_datum import parse_scheme_datum, write_scheme_datum
from packages.bazel.gerbil_environment import build_gerbil_environment


SCHEMA = "poo-flow.scheme-load-projection-artifact.v1"


def main(argv: Sequence[str] | None = None) -> int:
    args = _argument_parser().parse_args(argv)
    source = Path(args.source).resolve()
    projection = Path(args.projection_source).resolve()
    compiled_root = Path(args.compiled_root).resolve()
    dependency_root = Path(args.dependency_root_marker).resolve().parent
    project_dependency_roots = tuple(
        Path(root).resolve() for root in args.project_dependency_root
    )
    output = Path(args.output).resolve()

    rows = _load_projection_rows(
        gxi=Path(args.gxi).resolve(),
        source=source,
        projection=projection,
        compiled_root=compiled_root,
        dependency_root=dependency_root,
        project_dependency_roots=project_dependency_roots,
    )
    _write_projection_artifact(
        output=output,
        source=source,
        projection=projection,
        rows=rows,
    )
    return 0


def _write_projection_artifact(
    *,
    output: Path,
    source: Path,
    projection: Path,
    rows: tuple[object, ...],
) -> None:
    artifact = (
        ("schema", SCHEMA),
        ("source-digest", _file_digest(source)),
        ("projection-digest", _file_digest(projection)),
        ("rows", rows),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(write_scheme_datum(artifact) + "\n", encoding="utf-8")


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gxi", required=True)
    parser.add_argument("--compiled-root", required=True)
    parser.add_argument("--dependency-root-marker", required=True)
    parser.add_argument("--project-dependency-root", action="append", default=[])
    parser.add_argument("--projection-source", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    return parser


def _load_projection_rows(
    *,
    gxi: Path,
    source: Path,
    projection: Path,
    compiled_root: Path,
    dependency_root: Path,
    project_dependency_roots: tuple[Path, ...],
) -> tuple[object, ...]:
    runner_source = (
        "(import :core/profile-composition/selection-syntax\n"
        "        :poo-flow/modules/workflow/scenario/composition-syntax\n"
        "        :core/profile-composition/profile-bundle\n"
        "        :poo-flow/modules/workflow/scenario/profile-root\n"
        "        :poo-flow/modules/funflow/profile-library)\n"
        f"(include {_scheme_string(str(projection))})\n"
        "(poo-flow-runtime-load-write!\n"
        f" (begin (include {_scheme_string(str(source))})))\n"
    )
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", suffix=".ss", delete=False
    ) as runner:
        runner.write(runner_source)
        runner_path = Path(runner.name)

    env = build_gerbil_environment(
        gerbil_path=compiled_root,
        dependency_root=dependency_root,
        project_dependency_roots=project_dependency_roots,
        gxi=gxi,
    )
    try:
        result = subprocess.run(
            (str(gxi), str(runner_path)),
            cwd=Path.cwd(),
            env=env,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode:
            # Preserve the native Gerbil diagnostic at the Bazel action
            # boundary; a bare CalledProcessError hides the typed root cause.
            sys.stderr.write(result.stdout)
            sys.stderr.write(result.stderr)
            result.check_returncode()
    finally:
        runner_path.unlink(missing_ok=True)
    return tuple(parse_scheme_datum(result.stdout))


def _file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _scheme_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


if __name__ == "__main__":
    raise SystemExit(main())
