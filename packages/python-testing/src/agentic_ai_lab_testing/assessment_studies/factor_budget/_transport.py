# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Transport for the factor budget study."""

import json, os, selectors, subprocess, time
from ._config import BASE, SNAP


class SchemeEngine:
    def __init__(self):
        env = os.environ.copy()
        env["GERBIL_PATH"] = str(SNAP / ".gerbil")
        env["GERBIL_LOADPATH"] = str(SNAP / ".gerbil/lib")
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
        self.err = (BASE / "native-stderr.log").open("a")
        self.p = subprocess.Popen(
            [str(SNAP / ".gerbil/bin/factor-budget"), "-:max-heap=1G,debug=q"],
            cwd=SNAP,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.err,
            text=True,
            bufsize=1,
        )

    def call(self, **kw):
        began = time.monotonic()
        self.p.stdin.write(json.dumps(kw) + "\n")
        self.p.stdin.flush()
        s = selectors.DefaultSelector()
        s.register(self.p.stdout, selectors.EVENT_READ)
        if not s.select(20):
            self.close()
            raise TimeoutError("native reply deadline")
        s.close()
        line = self.p.stdout.readline()
        if not line:
            raise RuntimeError("native exited; see native-stderr.log")
        r = json.loads(line)
        if "error" in r:
            raise RuntimeError(r["error"])
        return (r, time.monotonic() - began)

    def close(self):
        if self.p.poll() is None:
            self.p.terminate()
            try:
                self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait(timeout=5)
        self.err.close()
