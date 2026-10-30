# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Own the native Gerbil repair worker and independent Scheme scorers."""

from __future__ import annotations

import os
import select
import subprocess
import time
from pathlib import Path

SCHEME_SOURCE_DIR = Path(__file__).resolve().parent / "scheme_source"


def scheme_env(ascent_root: Path, gerbil_path: Path) -> dict[str, str]:
    env = os.environ.copy()
    env.pop("DEEPSEEK_API_KEY", None)
    env["GERBIL_PATH"] = str(gerbil_path)
    env["GERBIL_LOADPATH"] = str(ascent_root)
    return env


def score(receipt_path: Path, poo_root: Path, ascent_root: Path,
          gerbil_path: Path) -> str:
    result = subprocess.run(
        ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi",
         str(SCHEME_SOURCE_DIR / "repair_score.ss"), str(receipt_path)],
        cwd=poo_root, env=scheme_env(ascent_root, gerbil_path),
        capture_output=True, text=True, timeout=90, check=True,
    )
    scores = [line for line in result.stdout.splitlines()
              if line.startswith("(score ")]
    if len(scores) != 1:
        raise RuntimeError("native scorer returned no unique score")
    return scores[0]


def control_score(expected: Path, answer: Path, poo_root: Path,
                  ascent_root: Path, gerbil_path: Path) -> str:
    result = subprocess.run(
        ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi",
         str(SCHEME_SOURCE_DIR / "score.ss"), str(expected), str(answer)],
        cwd=poo_root, env=scheme_env(ascent_root, gerbil_path),
        capture_output=True, text=True, timeout=90, check=True,
    )
    scores = [line for line in result.stdout.splitlines()
              if line.startswith("(score ")]
    if len(scores) != 1:
        raise RuntimeError("control scorer returned no unique score")
    return scores[0]


class NativeTool:
    def __init__(self, poo_root: Path, ascent_root: Path,
                 gerbil_path: Path) -> None:
        self.process = subprocess.Popen(
            ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi",
             str(SCHEME_SOURCE_DIR / "repair_attempt.ss")],
            cwd=poo_root, env=scheme_env(ascent_root, gerbil_path),
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        self.pending = b""
        self.last_native_ns: int | None = None

    def attempt(self, candidate: str) -> str:
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("native tool pipes unavailable")
        self.process.stdin.write((candidate + "\n").encode("ascii"))
        self.process.stdin.flush()
        deadline = time.monotonic() + 90
        lines: list[str] = []
        while True:
            if b"\n" in self.pending:
                raw, self.pending = self.pending.split(b"\n", 1)
                line = raw.decode("utf-8")
                if line == "END":
                    break
                lines.append(line)
                continue
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                self.process.kill()
                raise TimeoutError("native tool exceeded 90 seconds")
            readable, _, _ = select.select([self.process.stdout], [], [], remaining)
            if not readable:
                continue
            chunk = os.read(self.process.stdout.fileno(), 4096)
            if not chunk:
                raise RuntimeError("native tool exited without a receipt")
            self.pending += chunk
        receipts = [line for line in lines if line.startswith("(receipt ")]
        timings = [line for line in lines if line.startswith("TIMING ")]
        if len(receipts) != 1 or len(timings) != 1:
            raise RuntimeError("native tool returned no unique receipt")
        self.last_native_ns = int(timings[0].split()[1])
        return receipts[0] + "\n"

    def close(self) -> None:
        if self.process.stdin is not None:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        if self.process.stdout is not None:
            self.process.stdout.close()
