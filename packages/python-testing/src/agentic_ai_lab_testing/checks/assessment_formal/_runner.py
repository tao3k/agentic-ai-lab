# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Runner for the assessment formal study."""

from __future__ import annotations

from agentic_ai_lab_testing.model_study.reporting import report_text
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time
import uuid
from ._capacity import capacity
from ._config import ROOT, SECONDS
from ._models import Configuration, configuration
from ._obligations import obligations, validate_output


class Runner:
    def __init__(self) -> None:
        self.started = time.monotonic()
        self.deadline = self.started + SECONDS
        supplied = os.environ.get("ASCENT_FORMAL_RUN_DIR")
        self.output = (
            Path(supplied)
            if supplied
            else ROOT / ".cache/ascent/formal" / uuid.uuid4().hex
        )
        self.output.mkdir(parents=True, exist_ok=False)
        self.environment = dict(
            os.environ,
            QUINT_HOME=str(Path(os.environ.get("QUINT_HOME", Path.home() / ".quint"))),
            OUT_DIR=str(ROOT / ".cache/ascent/quint-output"),
        )
        for name in ("no_proxy", "NO_PROXY"):
            self.environment[name] = "127.0.0.1,localhost" + (
                "," + os.environ[name] if os.environ.get(name) else ""
            )
        self.quint = ROOT / "packages/proofs/quint/node_modules/.bin/quint"
        self.jar = (
            Path(self.environment["QUINT_HOME"])
            / "apalache-dist-0.62.1/apalache/lib/apalache.jar"
        )
        self.server: subprocess.Popen | None = None

    def run(self, argv: list[str], label: str, cwd: Path = ROOT) -> tuple[int, str]:
        path = self.output / f"{label}.out"
        guarded = bool(argv and Path(argv[0]).name == "lake")
        if guarded:
            adapter = [
                sys.executable,
                str(ROOT / "workbench/src/ascent_workbench/lean_guard.py"),
            ]
            if argv[1:] == ["-v", "build", "AscentProof", "AscentProofTests"]:
                argv = [*adapter, "build"]
            elif argv[1:4] == ["env", "lean", "--run"] and (
                len(argv) == 6
                or (len(argv) > 6 and argv[4:6] == ["ExecutionPolicy.lean", "batch"])
            ):
                argv = [*adapter, "render", *argv[4:]]
            else:
                raise ValueError(
                    "unsupported Lean invocation; use the source-owned Guard adapter"
                )
        errors = self.output / f"{label}.stderr.out"
        with path.open("w") as log, errors.open("w") as diagnostics:
            child = subprocess.Popen(
                argv,
                cwd=cwd,
                env=self.environment,
                stdout=log,
                stderr=diagnostics if guarded else subprocess.STDOUT,
                start_new_session=True,
            )
            try:
                code = child.wait(timeout=max(0, self.deadline - time.monotonic()))
            except BaseException:
                if child.poll() is None:
                    # The LeanPoo adapter owns a nested compiler group. Give its
                    # finally cleanup a chance to reap that group before killing
                    # the adapter itself, as in LeanPoo's phase supervisor.
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                raise
        return code, path.read_text() + (errors.read_text() if code and guarded else "")

    def start_compiler(self) -> int:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        self.server_log = (self.output / "compiler.out").open("w")
        self.server = subprocess.Popen(
            [
                "java",
                "-Xmx1G",
                "-Xss32m",
                "-XX:+UseParallelGC",
                f"-Djava.io.tmpdir={self.output}",
                "-jar",
                str(self.jar),
                "server",
                f"--port={port}",
            ],
            cwd=ROOT,
            env=self.environment,
            stdout=self.server_log,
            stderr=subprocess.STDOUT,
        )
        ready_deadline = min(self.deadline, time.monotonic() + 30)
        while self.server.poll() is None and time.monotonic() < ready_deadline:
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                    return port
            except OSError:
                time.sleep(0.1)
        raise RuntimeError(
            "Quint compiler did not start: "
            + (self.output / "compiler.out").read_text()
        )

    def close_compiler(self) -> None:
        if self.server is not None:
            if self.server.poll() is None:
                self.server.terminate()
            try:
                self.server.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.server.kill()
                self.server.wait()
            self.server_log.close()
            self.server = None

    def _compile_model(self, base, temporal, port):
        """Compile one model and reject an unqualified compiler response."""
        invariants = (
            *base.invariants,
            *((base.constraint,) if base.constraint else ()),
        )
        argv = [
            str(self.quint),
            "compile",
            f"packages/proofs/quint/{base.model}.qnt",
            "--main",
            base.main,
            "--target",
            "tlaplus",
            "--init",
            "init",
            "--step",
            "step",
            "--invariant",
            ",".join(invariants),
            "--apalache-version",
            "0.62.1",
            "--server-endpoint",
            f"127.0.0.1:{port}",
            "--verbosity",
            "0",
        ]
        if temporal:
            argv += ["--temporal", ",".join(temporal)]
        code, output = self.run(argv, f"compile-{base.model}")
        if code or f"MODULE {base.main} " not in output:
            raise RuntimeError(f"Quint compilation failed {base.model}: {output}")
        return output

    def compile(self, configurations: list[Configuration]) -> None:
        cache = ROOT / ".cache/ascent/quint-compiled"
        cache.mkdir(parents=True, exist_ok=True)
        # Imported helpers are compilation inputs too. No model-check results
        # are cached; even a compilation hit must execute every obligation.
        inputs = [
            (str(p.relative_to(ROOT)), hashlib.sha256(p.read_bytes()).hexdigest())
            for p in sorted((ROOT / "packages/proofs/quint").glob("*.qnt"))
        ]
        inputs += [
            (
                "package-lock",
                hashlib.sha256(
                    (ROOT / "packages/proofs/quint/package-lock.json").read_bytes()
                ).hexdigest(),
            ),
            ("backend", hashlib.sha256(self.jar.read_bytes()).hexdigest()),
        ]
        port = None
        try:
            for base in configurations:
                temporal = (
                    ("ReaderCompletion", "RoundCompletion", "spec", "roundSpec")
                    if base.model == "ReaderLifetime"
                    else base.properties
                )
                fingerprint = hashlib.sha256(
                    json.dumps(
                        (inputs, base.main, base.invariants, temporal, base.constraint)
                    ).encode()
                ).hexdigest()
                identity, artifact = (
                    cache / f"{base.model}.identity",
                    cache / f"{base.model}.tla",
                )
                target = self.output / f"{base.main}.tla"
                hit = False
                if identity.exists() and artifact.exists():
                    fields = identity.read_text().split()
                    hit = fields == [
                        fingerprint,
                        hashlib.sha256(artifact.read_bytes()).hexdigest(),
                    ]
                if hit:
                    target.write_bytes(artifact.read_bytes())
                else:
                    if port is None:
                        port = self.start_compiler()
                    output = self._compile_model(base, temporal, port)
                    artifact.write_text(output)
                    identity.write_text(
                        f"{fingerprint} {hashlib.sha256(artifact.read_bytes()).hexdigest()}\n"
                    )
                    target.write_text(output)
                target.write_text(
                    re.sub(
                        r'"(?:\\.|[^"\\])*"|:=',
                        lambda match: "=" if match[0] == ":=" else match[0],
                        target.read_text(),
                    )
                )
                report_text(
                    f"QUINT-COMPILE-OK {base.model} cache={int(hit)}", flush=True
                )
        finally:
            self.close_compiler()

    def check(self, base: Configuration) -> int:
        count = 0
        for obligation in obligations(base):
            label = f"{base.model}-{obligation.name}"
            config = self.output / f"{label}.cfg"
            config.write_text(obligation.configuration.text())
            code, output = self.run(
                [
                    "java",
                    "-Xmx1G",
                    "-XX:+UseParallelGC",
                    f"-Djava.io.tmpdir={self.output}",
                    "-cp",
                    str(self.jar),
                    "tlc2.TLC",
                    "-workers",
                    "1",
                    "-config",
                    str(config),
                    "-metadir",
                    str(self.output / label),
                    str(self.output / f"{base.main}.tla"),
                ],
                label,
            )
            validate_output(obligation, code, output)
            marker = "QUINT-CHECK-OK" if code == 0 else "COUNTEREXAMPLE-OK"
            report_text(
                f"{marker} {label} {obligation.property} exit={code}", flush=True
            )
            count += 1
        return count

    def quint_checks(self, models: tuple[str, ...]) -> dict[str, int]:
        configurations = [configuration(model, self.environment) for model in models]
        self.compile(configurations)
        workers = min(capacity(), len(configurations))
        report_text(
            f"QUINT-CAPACITY workers={workers} models={len(configurations)}", flush=True
        )
        results = {}
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {
                pool.submit(self.check, base): base.model for base in configurations
            }
            for future in as_completed(futures):
                results[futures[future]] = future.result()
        report_text("ALL-QUINT-CHECK-OK", flush=True)
        return results
