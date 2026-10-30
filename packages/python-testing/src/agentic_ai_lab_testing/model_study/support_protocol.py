# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Freeze prompts, native reference and call budget before model execution."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from .protocol import require_clean, require_pinned_ascent
from .runner import source_head
from .support_native import observe, parse_observation

SETTINGS = {"model": "deepseek-flash", "temperature": 0,
            "reasoning": {"effort": "none"}, "max_output_tokens": 1024}
TRANSPORT = {"base_url": "https://api.deepseek.com", "timeout": 45, "max_retries": 0}
SOURCES = ("candidate/program.ss", "program/scheme-checked.ss")
TASK = """Write one inert (candidate ...) program using the supplied ASCENT implementation.
Sources are edge/2, blocked/2, weight/2 and root/1. Define recursive positive
path/2, allowed/2 as path minus blocked pairs, weighted/2 as (origin, doubled
weight) for allowed destinations with an even weight, and summary/2 as the
sum of distinct weighted values per root. Query summary with its two variables.
Use limits 16 64 128. Do not add source facts or run Scheme procedures.
Initial source: edge=((0 1) (1 2) (0 2)), blocked=(),
weight=((0 2) (1 4) (2 6)), root=((0)). The program must also work after
source withdrawal and replacement; those source states are held out.
Return exactly one candidate datum, with no Markdown or explanation.
"""
SELF_REVIEW = "Review your candidate against the task and supplied implementation. Return the final candidate datum only."
NATIVE_REVIEW = "Review your candidate using this initial-source native observation. It checks execution and bounded evidence, not task intent. Return the final candidate datum only.\n{observation}"


def initial_prompt(root: Path) -> str:
    return "\n\n".join(f";;; ASCENT source: {name}\n" + (root / name).read_text()
                         for name in SOURCES) + "\n\nTask:\n" + TASK


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def metadata(ascent: Path, poo: Path, files: dict[str, bytes]) -> dict:
    return {"protocol": "support-candidate-paired-v1", "ascent_head": source_head(ascent),
            "poo_head": source_head(poo), "settings": SETTINGS, "transport": TRANSPORT, "max_calls": 4,
            "arms": ["self", "native"], "calls_per_arm": 2,
            "files": {name: digest(raw) for name, raw in files.items()}}


def preview(directory: Path, ascent: Path, poo: Path, gerbil_path: Path) -> dict:
    require_clean(ascent)
    require_clean(poo)
    require_pinned_ascent(ascent, poo)
    if (directory.exists() or directory.resolve().is_relative_to(poo.resolve())
            or directory.resolve().is_relative_to(ascent.resolve())):
        raise ValueError("preview requires a new external directory")
    reference = observe(ascent, gerbil_path)
    records = parse_observation(reference)
    if ([row["rows"] for row in records[:4]] != ["((0 20))", "((0 20))", "((0 8))", "((0 12))"]
            or any(row["status"] != "complete" or row["finite"] != "valid"
                   or row["founded"] != "valid" or row["policy"] != "task-shape"
                   for row in records[:4])
            or records[-1]["finite"] != "invalid" or records[-1]["founded"] != "invalid"):
        raise RuntimeError("qualified support reference changed")
    files = {"initial.txt": initial_prompt(ascent).encode(),
             "self_review.txt": SELF_REVIEW.encode(), "native_review.txt": NATIVE_REVIEW.encode(),
             "reference.tsv": reference.encode()}
    manifest = metadata(ascent, poo, files)
    directory.mkdir(parents=True)
    for name, raw in files.items():
        (directory / name).write_bytes(raw)
    (directory / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    return manifest


def validate(directory: Path, ascent: Path, poo: Path) -> dict[str, str]:
    require_clean(ascent)
    require_clean(poo)
    require_pinned_ascent(ascent, poo)
    names = ("initial.txt", "self_review.txt", "native_review.txt", "reference.tsv")
    files = {name: (directory / name).read_bytes() for name in names}
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest != metadata(ascent, poo, files):
        raise RuntimeError("preview bytes, heads or protocol settings changed")
    if (files["initial.txt"] != initial_prompt(ascent).encode()
            or files["self_review.txt"] != SELF_REVIEW.encode()
            or files["native_review.txt"] != NATIVE_REVIEW.encode()):
        raise RuntimeError("preview prompt differs from committed protocol")
    parse_observation(files["reference.tsv"].decode())
    return {name: raw.decode() for name, raw in files.items()}
