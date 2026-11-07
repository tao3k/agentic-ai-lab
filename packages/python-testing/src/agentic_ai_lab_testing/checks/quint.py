# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pinned Quint finite proofs, with real-output watchdog and negative controls."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable

from ..model import CaseContext, CaseEvidence
from .quint_cases import GROUPS, QuintCase


IDLE_LIMIT_SECONDS = 5
CASE_LIMIT_SECONDS = 45
STATE_COUNT = re.compile(rb"([\d,]+) states generated, ([\d,]+) distinct states.*?([\d,]+) states left on queue")



def _terminate(child: subprocess.Popen[bytes]) -> None:
    if child.poll() is not None:
        return
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        child.wait(timeout=1)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()


def _run_quint(command: list[str], cwd: Path,
               progress: Callable[[bytes], None] | None = None) -> tuple[int, bytes, int]:
    """Collect actual Quint/backend bytes, with a strict idle and per-case deadline."""
    child = subprocess.Popen(
        command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        start_new_session=True, bufsize=0,
    )
    assert child.stdout is not None
    started = last_output = time.monotonic()
    output = bytearray()
    pending = bytearray()
    visible = (b"Parsing file", b"Starting...",
               b"Finished computing initial states", b"Model checking completed",
               b"Error: Invariant", b"Finished in")
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(child.stdout, selectors.EVENT_READ)
            while selector.get_map() or child.poll() is None:
                for key, _ in selector.select(timeout=0.1):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    last_output = time.monotonic()
                    output.extend(chunk)
                    pending.extend(chunk)
                    while b"\n" in pending:
                        line, _, remainder = pending.partition(b"\n")
                        pending = bytearray(remainder)
                        visible_line = (any(token in line for token in visible)
                                        or b" states generated, " in line)
                        if progress is not None and (visible_line or line.startswith((b"[", b"PASS", b"# APALACHE"))):
                            progress(line + b"\n")
                now = time.monotonic()
                if now - last_output > IDLE_LIMIT_SECONDS:
                    raise TimeoutError("process produced no bytes for five seconds")
                if now - started > CASE_LIMIT_SECONDS:
                    raise TimeoutError("Quint exceeded the 45-second case limit")
        return child.wait(), bytes(output), round((time.monotonic() - started) * 1000)
    finally:
        _terminate(child)
        child.stdout.close()


def check_quint(context: CaseContext, case: QuintCase,
                progress: Callable[[bytes], None] | None = None,
                server_endpoint: str | None = None) -> CaseEvidence:
    models = context.repository_root / case.source_directory
    quint = context.repository_root / "packages/proofs/quint/node_modules/.bin/quint"
    version = subprocess.run([str(quint), "--version"], capture_output=True,
                             text=True, check=True, timeout=5).stdout.strip()
    if version != "0.33.0":
        raise AssertionError(f"expected Quint 0.33.0, got {version!r}")
    source = models / f"{case.model}.qnt"
    # Include imported modules: an instance hash alone does not bind its semantics.
    sources = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
               for p in sorted(models.glob("*.qnt"))}
    with tempfile.TemporaryDirectory(prefix="poo-quint-") as directory:
        work = Path(directory)
        for p in models.glob("*.qnt"):
            (work / p.name).write_bytes(p.read_bytes())
        config = work / "backend.json"
        config.write_text('{"workers":"1","maxHeap":"-Xmx1G"}\n')
        command = [str(quint), "verify", str(work / source.name), "--main", case.model,
                   "--backend", "tlc", "--apalache-version", "0.62.1",
                   "--invariant", case.invariant, "--tlc-config", str(config),
                   "--verbosity", "3"]
        if server_endpoint is not None:
            command += ["--server-endpoint", server_endpoint]
        if case.temporal:
            command += ["--temporal", case.temporal]
        if progress is not None:
            progress(f"QUINT-CHECK {case.model} {case.invariant}\n".encode())
        status, output, duration_ms = _run_quint(command, work, progress)
    if sources != {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(models.glob("*.qnt"))}:
        raise AssertionError("Quint sources changed during verification")
    counts = STATE_COUNT.search(output)
    if case.negative:
        accepted = (status == 1 and b"Error: Invariant q_inv is violated." in output
                    and b"[violation] Found an issue" in output
                    and b"error: found a counterexample" in output)
    else:
        accepted = (status == 0 and b"[ok] No violation found" in output
                    and counts is not None and counts[3].replace(b",", b"") == b"0"
                    and (not case.temporal or b"Finished checking temporal properties" in output))
    if not accepted or counts is None:
        raise AssertionError(f"{case.model}/{case.invariant}: unexpected Quint result {status}; "
                             + output.decode(errors="replace")[-2400:])
    if progress is not None:
        progress(f"QUINT-OK {case.model} states={counts[2].decode()} negative={case.negative}\n".encode())
    return CaseEvidence({"model": case.model, "invariant": case.invariant,
                         "negative": case.negative, "temporal": case.temporal,
                         "quint_version": version, "backend": "tlc", "server_endpoint": server_endpoint, "apalache_version": "0.62.1",
                         "sources_sha256": sources, "exit": status,
                         "generated_states": int(counts[1].replace(b",", b"")),
                         "distinct_states": int(counts[2].replace(b",", b"")),
                         "duration_ms": duration_ms, "idle_limit_seconds": 5,
                         "case_limit_seconds": 45,
                         "stdout_sha256": hashlib.sha256(output).hexdigest()})


def _scheme(value: object) -> str:
    if value is None: return "#f"
    if isinstance(value, bool): return "#t" if value else "#f"
    if isinstance(value, str):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(value, dict):
        return "(" + " ".join("(" + str(k).replace("_", "-") + " . " + _scheme(v) + ")"
                              for k, v in value.items()) + ")"
    if isinstance(value, list): return "(" + " ".join(map(_scheme, value)) + ")"
    return str(value)


def _load_backend(root: Path):
    # Core also runs standalone; locate its tool through the explicit repository.
    spec = importlib.util.spec_from_file_location(
        "_agentic_ai_lab_quint_backend", root / "core/dev/proofs/quint/backend.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", choices=["all", *GROUPS], default="all")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    if args.receipt:
        args.receipt.unlink(missing_ok=True)
    root = Path(__file__).resolve().parents[5]
    # The proof runner only uses repository_root from the harness context.
    from types import SimpleNamespace
    context = SimpleNamespace(repository_root=root)
    cases = [c for g, items in GROUPS.items() if args.group in ("all", g) for c in items]
    def progress(data: bytes) -> None:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()

    backend = _load_backend(root)
    from . import quint_cases
    bound = [Path(__file__), Path(quint_cases.__file__), Path(backend.__file__),
             root / "packages/proofs/quint/package-lock.json"]
    directories = sorted({c.source_directory for c in cases})
    def source_cut():
        current = set(bound)
        for directory in directories:
            current.update((root / directory).glob("*.qnt"))
        return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(current)}
    sources = source_cut()
    with backend.backend_session(progress, root / "packages/proofs/quint/node_modules/.bin/quint") as endpoint:
        results = [dict(check_quint(context, c, progress, endpoint).details) for c in cases]
    if sources != source_cut():
        raise AssertionError("bound Quint sources or checkers changed during qualification")
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(_scheme({"schema": "agentic-ai-lab.quint-proof.v1", "sources_sha256": sources, "cases": results}) + "\n")
    progress(f"QUINT-QUALIFICATION-OK {len(results)} cases\n".encode())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
