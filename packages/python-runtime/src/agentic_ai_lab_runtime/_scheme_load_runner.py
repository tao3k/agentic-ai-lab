# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Subprocess runner ownership for Scheme runtime projection loading."""

from __future__ import annotations

import json
import os
import selectors
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import NamedTuple

from ._scheme_datum import SchemeRows, parse_scheme_datum


def run_scheme_projection(
    module_path: Path,
    workdir: Path,
    projection_path: Path,
) -> SchemeRows:
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", suffix=".ss", delete=False
    ) as runner:
        runner.write(runner_source(module_path, projection_path))
        runner_path = Path(runner.name)
    try:
        result = _run_scheme_loader(module_path, workdir, runner_path)
    finally:
        runner_path.unlink(missing_ok=True)
    return parse_scheme_datum(result.stdout)


def runner_source(module_path: Path, projection_path: Path) -> str:
    source_path = scheme_string(str(module_path))
    projection_source_path = scheme_string(str(projection_path))
    return (
        "(for-each (lambda (module)\n"
        " (display (string-append \"IMPORT \" (symbol->string module) \"\\n\") (current-error-port))\n"
        " (force-output (current-error-port))\n"
        " (eval `(import ,module))\n"
        " (display (string-append \"MODULE-OK \" (symbol->string module) \"\\n\") (current-error-port))\n"
        " (force-output (current-error-port)))\n"
        " '(" + " ".join(":" + name for name in _runtime_authoring_imports()) + "))\n"
        f"(eval '(include {projection_source_path}))\n"
        "(eval '(agentic-ai-lab-runtime-load-write!\n"
        f" (let () (include {source_path}))))\n"
    )


def _runtime_authoring_imports():
    manifest = Path(__file__).parent / 'projections' / 'runtime_load_imports.json'
    return json.loads(manifest.read_text())['modules']


def aot_runner_source(module_path: Path, projection_path: Path) -> str:
    source_path = scheme_string(str(module_path))
    projection_source_path = scheme_string(str(projection_path))
    return (
        "(import :yuanxu/profile-composition/selection-syntax\n"
        "        :agentic-ai-lab/modules/workflow/scenario/composition-syntax\n"
        "        :yuanxu/profile-composition/profile-bundle\n"
        "        :agentic-ai-lab/modules/workflow/scenario/profile-root\n"
        "        :agentic-ai-lab/modules/workflow/profiles/funflow-library)\n"
        f"(include {projection_source_path})\n"
        "(export main)\n"
        "(def (main . args)\n"
        "  (agentic-ai-lab-runtime-load-write!\n"
        f"   (let () (include {source_path}))))\n"
    )


def runtime_projection_source(workdir: Path) -> Path:
    candidate = find_runtime_projection_source(workdir)
    if candidate is not None:
        return candidate
    relative_path = Path("modules/workflow/scenario/runtime-funflow.ss")
    raise FileNotFoundError(f"cannot find Scheme runtime load projection: {relative_path}")


def find_runtime_projection_source(workdir: Path) -> Path | None:
    relative_path = Path("modules/workflow/scenario/runtime-funflow.ss")
    candidates = (
        workdir / relative_path,
        Path(__file__).resolve().parents[4] / relative_path,
    )
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def scheme_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


class _SchemeLoaderCommand(NamedTuple):
    argv: tuple[str, ...]
    env: dict[str, str] | None


def _run_scheme_loader(
    module_path: Path,
    workdir: Path,
    runner_path: Path,
) -> subprocess.CompletedProcess[str]:
    failures: list[str] = []
    for command in _scheme_loader_commands(workdir, runner_path):
        try:
            return _run_with_native_progress(command, workdir)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "").strip()
            failures.append(f"{' '.join(command.argv[:3])}: {detail}")
    raise RuntimeError(
        f"Scheme load failed for {module_path}: {'; '.join(failures)}"
    )


_SCHEME_LOAD_TOTAL_SECONDS = 90.0


def _run_with_native_progress(command, workdir):
    """Preserve the data stdout and forward real native diagnostics immediately."""
    process = subprocess.Popen(command.argv, cwd=workdir, env=command.env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    deadline = time.monotonic() + _SCHEME_LOAD_TOTAL_SECONDS
    output = {process.stdout: bytearray(), process.stderr: bytearray()}
    try:
        with selectors.DefaultSelector() as selector:
            for stream in output:
                selector.register(stream, selectors.EVENT_READ)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise RuntimeError('Scheme projection exceeded its total time limit')
                events = selector.select(timeout=min(5, remaining))
                if not events and time.monotonic() >= deadline:
                    raise RuntimeError('Scheme projection exceeded its total time limit')
                if not events:
                    raise RuntimeError('Scheme projection emitted no real output for five seconds')
                for key, _ in events:
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    output[key.fileobj].extend(chunk)
                    if key.fileobj is process.stderr:
                        sys.stderr.write(chunk.decode('utf-8', 'replace')); sys.stderr.flush()
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('Scheme projection exceeded its total time limit')
        status = process.wait(timeout=min(5, remaining))
        stdout = output[process.stdout].decode('utf-8')
        stderr = output[process.stderr].decode('utf-8', 'replace')
        if status:
            raise subprocess.CalledProcessError(status, command.argv, stdout, stderr)
        return subprocess.CompletedProcess(command.argv, status, stdout, stderr)
    finally:
        if process.poll() is None:
            process.kill(); process.wait()
        process.stdout.close(); process.stderr.close()


def _scheme_loader_commands(
    workdir: Path,
    runner_path: Path,
) -> tuple[_SchemeLoaderCommand, ...]:
    direct_env = _direct_scheme_loader_env(workdir)
    fallback = _SchemeLoaderCommand(
        ("gxpkg", "env", "gxi", "-:max-heap=1G,debug=q", str(runner_path)),
        None,
    )
    if direct_env is None:
        return (fallback,)
    direct = _SchemeLoaderCommand(("gxi", "-:max-heap=1G,debug=q", str(runner_path)), direct_env)
    return (direct, fallback)


def _direct_scheme_loader_env(workdir: Path) -> dict[str, str] | None:
    inherited_gerbil_path = os.environ.get("GERBIL_PATH")
    inherited_candidate = (
        Path(inherited_gerbil_path) if inherited_gerbil_path else None
    )
    workspace_candidate = workdir / ".gerbil"
    gerbil_path = next(
        (
            candidate
            for candidate in (inherited_candidate, workspace_candidate)
            if candidate is not None
            and (candidate / "lib" / "agentic-ai-lab").exists()
        ),
        None,
    )
    if gerbil_path is None:
        return None
    env = dict(os.environ)
    env["GERBIL_PATH"] = str(gerbil_path)
    if gerbil_path == workspace_candidate:
        env["PATH"] = os.pathsep.join(
            (str(gerbil_path / "bin"), env.get("PATH", ""))
        )
    return env


__all__ = [
    "aot_runner_source",
    "find_runtime_projection_source",
    "run_scheme_projection",
    "runtime_projection_source",
    "runner_source",
    "scheme_string",
]
