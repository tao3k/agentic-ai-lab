# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Transport for the evidence interaction study."""

import json
import os
import selectors
import subprocess
import time
from ._artifacts import canonical, save
from ._config import KERNEL, ROOT, RUNTIME


class EvidenceEngine:
    def __init__(self, run, judge=False):
        self.trace = []
        self.run = run
        self.judge = judge
        env = os.environ.copy()
        env["GERBIL_PATH"] = str(RUNTIME)
        env["GERBIL_LOADPATH"] = ":".join(
            map(
                str,
                [
                    RUNTIME / "lib",
                    ROOT / ".cache/ascent/evidence-store/lib",
                    KERNEL / ".gerbil/lib",
                ],
            )
        )
        env["LIBRARY_PATH"] = (
            subprocess.check_output(
                ["brew", "--prefix", "openssl@3"], text=True
            ).strip()
            + "/lib"
        )
        for k in (
            "CC",
            "CFLAGS",
            "CPPFLAGS",
            "LDFLAGS",
            "CPATH",
            "C_INCLUDE_PATH",
            "CPLUS_INCLUDE_PATH",
            "NIX_CFLAGS_COMPILE",
            "NIX_LDFLAGS",
            "DEVELOPER_DIR",
            "SDKROOT",
        ):
            env.pop(k, None)
        binary = (
            KERNEL / ".gerbil/bin/crosspath-search"
            if judge
            else RUNTIME / "bin/evidence-search"
        )
        self.err = (
            run / ("judge-stderr.log" if judge else "scenario-stderr.log")
        ).open("a")
        self.p = subprocess.Popen(
            [str(binary), "-:max-heap=1G,debug=q"],
            env=env,
            cwd=ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.err,
            text=True,
            bufsize=1,
        )
        if not judge:
            began = time.monotonic()
            with selectors.DefaultSelector() as selector:
                selector.register(self.p.stdout, selectors.EVENT_READ)
                if not selector.select(20):
                    save(
                        run / "consumer-readiness-failure.json",
                        {
                            "status": "timeout",
                            "deadlineSeconds": 20,
                            "seconds": time.monotonic() - began,
                        },
                    )
                    self.close()
                    raise TimeoutError("consumer module-load readiness deadline")
            if json.loads(self.p.stdout.readline()) != {"ready": True}:
                self.close()
                raise ValueError("unexpected consumer readiness response")
            self.trace.append(
                {
                    "request": {"op": "module_load"},
                    "answer": {"ready": True},
                    "seconds": time.monotonic() - began,
                }
            )

    def call(self, **request):
        began = time.monotonic()
        self.p.stdin.write(canonical(request) + "\n")
        self.p.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(self.p.stdout, selectors.EVENT_READ)
            if not selector.select(20):
                raise TimeoutError("native RPC deadline")
        line = self.p.stdout.readline()
        if not line:
            raise RuntimeError("native process exited")
        answer = json.loads(line)
        self.trace.append(
            {"request": request, "answer": answer, "seconds": time.monotonic() - began}
        )
        if "error" in answer:
            raise ValueError(answer["error"])
        return answer

    def close(self):
        if self.p.poll() is None:
            self.p.terminate()
            try:
                self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait(timeout=5)
        self.err.close()

    def __enter__(self):
        return self

    def __exit__(self, kind, failure, _):
        if failure is not None:
            save(
                self.run
                / f"native-failure-{'judge' if self.judge else 'consumer'}-{time.time_ns()}.json",
                {"failure": str(failure), "trace": self.trace},
            )
        self.close()
