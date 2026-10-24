# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the frozen paired ASCENT and temporal-causality model pilot."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any

from ..ascent.live import key_from_file

from .fixtures import observations, source_head
from .graph import build_graph, grade
from .reporting import report_json, report_record
from .schema import CORPUS_SHA256

HERE = Path(__file__).resolve().parent
CORPUS = HERE / "cases.json"


def corpus() -> list[dict[str, Any]]:
    raw = CORPUS.read_bytes()
    if hashlib.sha256(raw).hexdigest() != CORPUS_SHA256:
        raise RuntimeError("frozen model corpus hash changed")
    cases = json.loads(raw)
    if [case["id"] for case in cases] != [
        "ascent.withdrawal", "ascent.wrong-join", "ascent.negation-count",
        "temporal.closed-cut", "temporal.open-parent",
    ]:
        raise RuntimeError("frozen model task order changed")
    return cases


def run(api_key: str, ascent_root: Path, poo_root: Path, output: Path,
        cases: list[dict], evidence: dict[str, dict],
        tool_seconds: dict[str, float]) -> None:
    from openai import OpenAI

    if output.exists():
        raise FileExistsError("study output already exists")
    if output.parent.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("raw model responses must stay outside the repository")
    client = OpenAI(
        api_key=api_key, base_url="https://api.deepseek.com",
        max_retries=0, timeout=45.0,
    )
    heads = {"ascent": source_head(ascent_root), "agentic_ai_lab": source_head(poo_root)}
    attempted = 0
    for case in cases:
        for repeat, order in enumerate((("baseline", "tool"),
                                        ("tool", "baseline"),
                                        ("baseline", "tool")), 1):
            for arm in order:
                attempted += 1
                if attempted > 30:
                    raise RuntimeError("pre-registered request cap exceeded")
                observation = evidence[case["id"]]
                record: dict[str, Any] = {
                    "case": case["id"], "repeat": repeat, "arm": arm,
                    "corpus_sha256": CORPUS_SHA256, "heads": heads,
                    "observation_sha256": hashlib.sha256(
                        json.dumps(observation, sort_keys=True).encode()
                    ).hexdigest(),
                    "tool_seconds": tool_seconds[case["id"]] if arm == "tool" else 0,
                }
                try:
                    graph = build_graph(client, case, arm, observation)
                    result, _trace = graph.invoke_with_trace({})
                    record.update({
                        "response_status": result["response_status"],
                        "response_id": result["response_id"],
                        "output": result["output"],
                        "usage": result["usage"],
                        "model_seconds": result["model_seconds"],
                        "score": result["score"],
                    })
                except Exception as error:
                    record["error_type"] = type(error).__name__
                    record["score"] = None
                with output.open("a", encoding="utf-8") as file:
                    file.write(json.dumps(record, sort_keys=True) + "\n")
                report_record(case["id"], repeat, arm, record)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    cases = corpus()
    evidence, elapsed = observations(args.ascent_root, args.poo_root)
    if args.dry_run:
        report_json({"cases": [case["id"] for case in cases],
                     "observations": evidence, "tool_seconds": elapsed})
        return 0
    if args.output is None:
        parser.error("--output is required for a live run")
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required")
    run(api_key, args.ascent_root, args.poo_root, args.output,
        cases, evidence, elapsed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
