# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Transport for the candidate model study."""

import json
import os
import selectors
import subprocess
import time
from ._artifacts import save
from ._config import CANONICAL, PREPARED, ROOT, RUNTIME
from ._judge import reachable


def environment():
    env = os.environ.copy()
    env["GERBIL_PATH"] = str(CANONICAL.parent if CANONICAL.exists() else RUNTIME)
    env["GERBIL_LOADPATH"] = (
        f"{CANONICAL}:{PREPARED}"
        if CANONICAL.exists()
        else f"{RUNTIME / 'lib'}:{PREPARED}"
    )
    for name in (
        "CC",
        "CFLAGS",
        "CPPFLAGS",
        "LDFLAGS",
        "NIX_CFLAGS_COMPILE",
        "NIX_LDFLAGS",
        "CPATH",
        "SDKROOT",
    ):
        env.pop(name, None)
    return env


class Consumer:
    def __init__(self, run, dynamic=False):
        self.trace = []
        self.run = run
        self.dynamic = dynamic
        self.shutdown = None
        self._stdout_buffer = bytearray()
        run.mkdir(parents=True, exist_ok=True)
        self.err = (run / "native-stderr.log").open("a")
        command = self._start_process(run, dynamic)
        self._await_readiness(run, dynamic, command)

    def _start_process(self, run, dynamic):
        """Open the selected native transport and retain spawn failure evidence."""
        command = (
            [
                "/opt/homebrew/bin/gxi",
                "-e",
                "(import :gerbil-ascent/t/research/candidate-interaction)",
                "-e",
                "(main)",
            ]
            if dynamic
            else [str(RUNTIME / "bin/candidate-interaction"), "-:max-heap=1G,debug=q"]
        )
        if dynamic == "module":
            command = [
                str(RUNTIME / "bin/candidate-interaction"),
                "-:max-heap=1G,debug=q",
                "--dynamic-evidence",
            ]
        try:
            self.p = subprocess.Popen(
                command,
                env=environment(),
                cwd=ROOT,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=self.err,
                bufsize=0,
            )
        except OSError as error:
            self.err.close()
            save(
                run / "native-readiness-failure.json",
                {
                    "phase": "spawn",
                    "command": command,
                    "dynamic": dynamic,
                    "error": str(error),
                },
            )
            raise
        return command

    def _await_readiness(self, run, dynamic, command):
        """Admit the transport only after its bounded readiness handshake."""
        began = time.monotonic()
        load_deadline = 60 if dynamic else 20
        try:
            if self.receive(load_deadline) != {"ready": True}:
                raise ValueError("native readiness mismatch")
            self.trace.append(
                {
                    "request": {"op": "module_load"},
                    "answer": {"ready": True},
                    "seconds": time.monotonic() - began,
                }
            )
            save(
                run / "native-readiness.json",
                {
                    "ready": True,
                    "command": command,
                    "dynamic": dynamic,
                    "deadline": load_deadline,
                    "seconds": time.monotonic() - began,
                },
            )
        except Exception as error:
            save(
                run / "native-readiness-failure.json",
                {
                    "error": str(error),
                    "seconds": time.monotonic() - began,
                    "deadline": load_deadline,
                    "command": command,
                    "dynamic": dynamic,
                    "exit": self.p.poll(),
                    "pendingBytes": len(self._stdout_buffer),
                },
            )
            self.close()
            raise

    def receive(self, deadline=20):
        expires = time.monotonic() + deadline
        with selectors.DefaultSelector() as selector:
            selector.register(self.p.stdout, selectors.EVENT_READ)
            while b"\n" not in self._stdout_buffer:
                remaining = expires - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    if self._stdout_buffer:
                        (self.run / "native-partial-output.bin").write_bytes(
                            self._stdout_buffer
                        )
                    raise TimeoutError(f"native {deadline}-second deadline")
                chunk = os.read(self.p.stdout.fileno(), 65536)
                if not chunk:
                    if self._stdout_buffer:
                        (self.run / "native-partial-output.bin").write_bytes(
                            self._stdout_buffer
                        )
                    raise RuntimeError(
                        f"native exit before complete response (exit={self.p.poll()})"
                    )
                self._stdout_buffer.extend(chunk)
        line, _, rest = self._stdout_buffer.partition(b"\n")
        self._stdout_buffer = bytearray(rest)
        try:
            return json.loads(line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            with (self.run / "native-invalid-output.log").open("ab") as log:
                log.write(line + b"\n")
            raise

    def call(self, **request):
        began = time.monotonic()
        event = {"request": request}
        self.trace.append(event)
        save(self.run / "native.json", self.trace)
        try:
            self.p.stdin.write((json.dumps(request) + "\n").encode())
            self.p.stdin.flush()
            answer = self.receive()
            event["answer"] = answer
        except Exception as error:
            event["failure"] = str(error)
            raise
        finally:
            event["seconds"] = time.monotonic() - began
            save(self.run / "native.json", self.trace)
        if isinstance(answer, dict) and "error" in answer:
            raise ValueError(answer["error"])
        return answer

    def close(self):
        if self.shutdown is not None:
            return self.shutdown
        began = time.monotonic()
        fallback = []
        error = None
        if self.p.poll() is None:
            # main already treats stdin EOF as completion. SIGTERM does not
            # reliably wake the dynamic runtime's blocking read-line.
            try:
                self.p.stdin.close()
            except (BrokenPipeError, OSError) as failure:
                error = str(failure)
            try:
                self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                fallback.append("terminate")
                self.p.terminate()
                try:
                    self.p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    fallback.append("kill")
                    self.p.kill()
                    self.p.wait(timeout=5)
        if not self.p.stdin.closed:
            self.p.stdin.close()
        self.p.stdout.close()
        self.err.close()
        self.shutdown = {
            "protocol": "stdin EOF",
            "dynamic": self.dynamic,
            "clean": self.p.returncode == 0 and not fallback and error is None,
            "exit": self.p.returncode,
            "fallback": fallback,
            "error": error,
            "seconds": time.monotonic() - began,
            "graceSeconds": 5,
        }
        save(self.run / "native-shutdown.json", self.shutdown)
        return self.shutdown


class AtomicJudge:
    def call(self, **request):
        if request["op"] == "init":
            self.edges = request["edges"]
            self.needs = request["needs"]
            self.options = request["options"]
            return {}
        fragment = next(
            o["fragment"] for o in self.options if o["id"] == request["selection"][0]
        )
        n = next(n for n in self.needs if n[0] == fragment)
        return {
            "valid": reachable(self.edges, n[1], n[2])
            and reachable(self.edges, n[3], n[4])
        }


class EpisodeConsumer:
    def __init__(self, native):
        self.native = native

    def call(self, **request):
        return self.native.call(
            op="reuse-episode", atom=request["atom"], premises=request["premises"]
        )
