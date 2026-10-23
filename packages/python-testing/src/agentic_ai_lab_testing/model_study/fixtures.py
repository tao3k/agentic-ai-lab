# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Read and validate native observations for the frozen model corpus."""

from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path
from typing import Any

from ..ascent.candidate import SchemeChecker

HERE = Path(__file__).resolve().parent

GOOD_PATH = (
    "(candidate (relation path 2) "
    "(rule (path ?x ?y) (edge ?x ?y)) "
    "(rule (path ?x ?z) (path ?x ?y) (edge ?y ?z)) "
    "(query path ?x ?y) (limits 16 64 64))"
)
WRONG_PATH = (
    "(candidate (relation path 2) "
    "(rule (path ?x ?y) (edge ?x ?y)) "
    "(rule (path ?x ?z) (edge ?x ?y) (path ?x ?z)) "
    "(query path ?x ?y) (limits 16 64 64))"
)


def source_head(root: Path) -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True,
    ).strip()


def native_script(script: Path, root: Path, load_roots: list[Path]) -> dict[str, str]:
    env = os.environ.copy()
    env.pop("DEEPSEEK_API_KEY", None)
    env["GERBIL_LOADPATH"] = ":".join(
        [*(str(path) for path in load_roots), env.get("GERBIL_LOADPATH", "")]
    ).rstrip(":")
    result = subprocess.run(
        ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi", str(script)],
        cwd=root, env=env, capture_output=True, text=True, timeout=60,
        check=True,
    )
    lines = [line for line in result.stdout.splitlines() if "\t" in line]
    fields = dict(line.split("\t", 1) for line in lines)
    if len(fields) != len(lines):
        raise RuntimeError("native fixture emitted duplicate labels")
    return fields


def observations(ascent_root: Path | None, poo_root: Path) -> tuple[dict[str, dict], dict[str, float]]:
    started = time.perf_counter()
    checker = SchemeChecker(ascent_root)
    try:
        good = checker.attempt(GOOD_PATH)
        wrong = checker.attempt(WRONG_PATH)
    finally:
        checker.close()
    ascent_seconds = round(time.perf_counter() - started, 3)
    if not (good["status"] == good["after-status"] == "complete"
            and "(0 2)" in good["rows"] and "(0 2)" not in good["after-rows"]
            and wrong["status"] == "complete"
            and "(0 2)" not in wrong["rows"]):
        raise RuntimeError("ASCENT path observations disagree with frozen answer")

    started = time.perf_counter()
    finite = native_script(
        HERE.parent / "ascent" / "finite_attempt.ss",
        ascent_root or poo_root,
        [ascent_root] if ascent_root is not None else [poo_root],
    )
    finite_seconds = round(time.perf_counter() - started, 3)
    if finite != {
        "status": "complete", "rows": "((1 1))",
        "finite-status": "complete", "verdict": "valid",
    }:
        raise RuntimeError("ASCENT finite evidence disagrees with frozen answer")

    started = time.perf_counter()
    temporal = native_script(
        HERE.parent / "temporal" / "attempt.ss", poo_root,
        [poo_root],
    )
    temporal_seconds = round(time.perf_counter() - started, 3)
    expected_temporal = {
        "closed.status": "bounded-temporal-classification",
        "closed.past": '("prescription" "administration")',
        "closed.current": '("observation")',
        "closed.future": '("scheduled-dose")',
        "closed.counterfactual": '("corrected-prescription")',
        "closed.unknown": "()",
        "closed.release-authorized?": "#f",
        "open.status": "partial-temporal-classification",
        "open.unknown": '("missing-administration")',
        "open.release-authorized?": "#f",
    }
    if temporal != expected_temporal:
        raise RuntimeError("temporal module disagrees with frozen answer")

    data = {
        "ascent.withdrawal": {
            "source": "gerbil-ascent", "G1_status": good["status"],
            "G1_path_rows": good["rows"],
            "G2_status": good["after-status"],
            "G2_path_rows": good["after-rows"],
        },
        "ascent.wrong-join": {
            "source": "gerbil-ascent", "proposed_status": wrong["status"],
            "proposed_path_rows": wrong["rows"],
            "repaired_status": good["status"],
            "repaired_path_rows": good["rows"],
        },
        "ascent.negation-count": {"source": "gerbil-ascent", **finite},
        "temporal.closed-cut": {
            "source": "agentic-ai-lab.temporal-causality",
            **{key.removeprefix("closed."): value for key, value in temporal.items()
               if key.startswith("closed.")},
        },
        "temporal.open-parent": {
            "source": "agentic-ai-lab.temporal-causality",
            **{key.removeprefix("open."): value for key, value in temporal.items()
               if key.startswith("open.")},
        },
    }
    elapsed = {
        "ascent.withdrawal": ascent_seconds,
        "ascent.wrong-join": ascent_seconds,
        "ascent.negation-count": finite_seconds,
        "temporal.closed-cut": temporal_seconds,
        "temporal.open-parent": temporal_seconds,
    }
    return data, elapsed


def stratified_observation(ascent_root: Path | None, poo_root: Path) -> dict[str, str]:
    """Check the new receipt on the same frozen negation/count input."""
    result = native_script(
        HERE.parent / "ascent" / "stratified_attempt.ss",
        ascent_root or poo_root,
        [ascent_root] if ascent_root is not None else [poo_root],
    )
    expected = {
        "status": "complete", "rows": "((1 1))",
        "proof-status": "complete", "finite-verdict": "valid",
        "proof-verdict": "valid",
    }
    if result != expected:
        raise RuntimeError("ASCENT receipt disagrees with frozen Rust/finite result")
    return result
