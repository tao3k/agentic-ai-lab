# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run a registered paired model study with fixed observations."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Callable

from ..ascent.live import key_from_file
from .runner import build_graph, corpus, observations, source_head, CORPUS_SHA256
from .reporting import report_json, report_record
from .schema import PROTOCOLS, SCHEMA_ID, SCHEMA_VERSION


def typed_observation(case_id: str, old: dict[str, Any]) -> dict[str, Any]:
    typed = dict(old)
    if case_id.startswith("ascent."):
        typed["evidence_scope"] = "candidate_on_named_finite_snapshot"
        typed["intent_verified"] = False
    elif case_id.startswith("temporal."):
        if typed.pop("release-authorized?") != "#f":
            raise RuntimeError("native release field changed from frozen fixture")
        typed["release_authorized"] = False
        typed["causation_proven"] = False
        typed["evidence_scope"] = "temporal_classification_only"
        if case_id == "temporal.open-parent":
            typed["absence_proven"] = False
    else:
        raise RuntimeError("unknown frozen task")
    return typed


def run(api_key: str, ascent_root: Path, poo_root: Path, output: Path,
        cases: list[dict], old: dict[str, dict], tool_seconds: dict[str, float],
        *, variants_for_case: Callable[[str, dict], dict[str, dict]] | None = None,
        arms: tuple[str, str] = PROTOCOLS["typed"]["arms"],
        study: str = "typed",
        postprocess: Callable[[str, str, dict, dict], dict] | None = None) -> None:
    from openai import OpenAI

    if study not in PROTOCOLS or arms != PROTOCOLS[study]["arms"]:
        raise ValueError("model study protocol is not registered in schema")

    if output.exists():
        raise FileExistsError(f"{study} study output already exists")
    if output.parent.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("raw model responses must stay outside the repository")
    client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com",
                    max_retries=0, timeout=45.0)
    heads = {"ascent": source_head(ascent_root), "agentic_ai_lab": source_head(poo_root)}
    attempted = 0
    for case in cases:
        case_id = case["id"]
        variants = (variants_for_case(case_id, old[case_id])
                    if variants_for_case else
                    {"old": old[case_id],
                     "typed": typed_observation(case_id, old[case_id])})
        if set(variants) != set(arms):
            raise RuntimeError(f"{study} observation arms are incomplete")
        for repeat, order in enumerate((arms, arms[::-1], arms), 1):
            for arm in order:
                attempted += 1
                if attempted > 30:
                    raise RuntimeError(f"pre-registered {study} request cap exceeded")
                observation = variants[arm]
                record: dict[str, Any] = {
                    "case": case_id, "repeat": repeat, "arm": arm,
                    "schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION,
                    "protocol": study,
                    "protocol_revision": PROTOCOLS[study]["revision"],
                    "corpus_sha256": CORPUS_SHA256, "heads": heads,
                    "observation_sha256": hashlib.sha256(
                        json.dumps(observation, sort_keys=True).encode()
                    ).hexdigest(),
                    "tool_seconds": tool_seconds[case_id],
                }
                try:
                    graph = build_graph(client, case, "tool", observation)
                    result, _trace = graph.invoke_with_trace({})
                    record.update({
                        "response_status": result["response_status"],
                        "response_id": result["response_id"],
                        "output": result["output"],
                        "usage": result["usage"],
                        "model_seconds": result["model_seconds"],
                        "score": result["score"],
                    })
                    if postprocess:
                        record["guard"] = postprocess(
                            case_id, result["output"], observation, result["score"]
                        )
                except Exception as error:
                    record["error_type"] = type(error).__name__
                    record["score"] = None
                with output.open("a", encoding="utf-8") as file:
                    file.write(json.dumps(record, sort_keys=True) + "\n")
                report_record(case_id, repeat, arm, record)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    cases = corpus()
    old, tool_seconds = observations(args.ascent_root, args.poo_root)
    typed = {case["id"]: typed_observation(case["id"], old[case["id"]])
             for case in cases}
    if args.dry_run:
        report_json({"old": old, "typed": typed})
        return 0
    if args.output is None:
        parser.error("--output is required for a live run")
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required")
    run(api_key, args.ascent_root, args.poo_root, args.output,
        cases, old, tool_seconds)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
