# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Bounded candidate data and a persistent Scheme experiment worker."""

from __future__ import annotations

import os
import re
import select
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ALLOWED = re.compile(r"[A-Za-z0-9_?+*<>=!()\s-]+\Z", re.ASCII)


def candidate_text(output: str) -> str | None:
    text = output.strip()
    if text.startswith("```") and text.endswith("```"):
        lines = text.splitlines()
        if len(lines) >= 3 and lines[0] in ("```", "```scheme", "```gerbil"):
            text = "\n".join(lines[1:-1]).strip()
    if not text.startswith("(candidate "):
        if not text.startswith("(candidate\n"):
            return None
    if len(text) > 16384 or not ALLOWED.fullmatch(text):
        return None
    depth = 0
    for index, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if depth < 0 or depth > 128:
            return None
        if depth == 0 and text[index + 1:].strip():
            return None
    return text if depth == 0 else None


class SchemeChecker:
    """One temporary Gerbil worker per experiment conversation."""

    def __init__(self, ascent_root: Path | None = None) -> None:
        env = os.environ.copy()
        env.pop("DEEPSEEK_API_KEY", None)
        if ascent_root is not None:
            env["GERBIL_LOADPATH"] = str(ascent_root) + (
                ":" + env["GERBIL_LOADPATH"] if env.get("GERBIL_LOADPATH") else ""
            )
        self.process = subprocess.Popen(
            ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi",
             str(HERE / "attempt.ss")],
            cwd=ascent_root or HERE, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, env=env,
        )
        self.pending = b""

    def attempt(self, candidate: str) -> dict[str, str]:
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("Scheme worker pipes are unavailable")
        self.process.stdin.write((candidate + "\n").encode("ascii"))
        self.process.stdin.flush()
        deadline = time.monotonic() + 45
        lines = []
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
                raise RuntimeError("Scheme worker exceeded 45 seconds")
            ready, _, _ = select.select([self.process.stdout], [], [], remaining)
            if not ready:
                continue
            chunk = os.read(self.process.stdout.fileno(), 4096)
            if not chunk:
                raise RuntimeError("Scheme worker exited before its receipt")
            self.pending += chunk
        fields = dict(line.split("\t", 1) for line in lines)
        required = {"status", "rows", "bound", "snapshot-digest",
                    "candidate-digest", "diagnostics", "after-status",
                    "after-rows", "after-bound", "after-snapshot-digest"}
        if set(fields) != required:
            raise RuntimeError("Scheme worker returned an incomplete receipt")
        return fields

    def close(self) -> None:
        if self.process.stdin:
            try:
                self.process.stdin.close()
            except BrokenPipeError:
                pass
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        if self.process.stdout:
            self.process.stdout.close()


def scheme_attempt(candidate: str, ascent_root: Path | None = None) -> dict[str, str]:
    checker = SchemeChecker(ascent_root)
    try:
        return checker.attempt(candidate)
    finally:
        checker.close()
