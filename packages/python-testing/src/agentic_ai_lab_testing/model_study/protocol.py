# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pair typed observations with the new bounded stratified receipt."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Any

from ..ascent.live import key_from_file
from ..temporal.authority import gate_model_answer
from .fixtures import stratified_observation
from .reporting import report_json
from .runner import corpus, observations, source_head
from .paired import run, typed_observation
from .schema import CURRENT_PROTOCOL, PROTOCOLS, SCHEMA_ID, SCHEMA_VERSION


def proof_observation(case_id: str, typed: dict[str, Any],
                      receipt: dict[str, str]) -> dict[str, Any]:
    if case_id != "ascent.negation-count":
        return dict(typed)
    if receipt != {
        "status": "complete", "rows": "((1 1))",
        "proof-status": "complete", "finite-verdict": "valid",
        "proof-verdict": "valid",
    }:
        raise RuntimeError("frozen stratified receipt changed")
    return {
        **typed,
        "finite_receipt_verdict": receipt["finite-verdict"],
        "founded_proof_status": receipt["proof-status"],
        "founded_proof_verdict": receipt["proof-verdict"],
        "proof_scope": "one_founded_support_per_result_on_named_finite_snapshot",
        "intent_verified": False,
    }


def guard_answer(case_id: str, output: str, observation: dict,
                 _score: dict) -> dict:
    if case_id.startswith("temporal."):
        return gate_model_answer(output, observation)
    if case_id.startswith("ascent."):
        try:
            answer = json.loads(output)
        except json.JSONDecodeError:
            return {"status": "withheld", "reason": "invalid-model-answer"}
        if (not isinstance(answer, dict) or set(answer) != {"choice", "claim"}
                or not all(isinstance(value, str) for value in answer.values())):
            return {"status": "withheld", "reason": "invalid-model-answer"}
        if (observation.get("intent_verified") is not False
                or answer["claim"] != "bounded_candidate_only"):
            return {"status": "withheld", "reason": "candidate-claim-exceeds-evidence"}
        return {"status": "observation-only", **answer}
    raise RuntimeError("unknown frozen task")


def require_clean(root: Path) -> None:
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=root):
        raise RuntimeError(f"live study requires a committed checkout: {root}")


def require_pinned_ascent(ascent_root: Path, poo_root: Path) -> None:
    declaration = (poo_root / "gerbil.pkg").read_text(encoding="utf-8")
    pin = re.search(r'"github\.com/tao3k/gerbil-ascent@([0-9a-f]{40})"', declaration)
    if pin is None or pin.group(1) != source_head(ascent_root):
        raise RuntimeError("live ASCENT checkout differs from Agentic AI Lab dependency pin")


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
    started = time.perf_counter()
    receipt = stratified_observation(args.ascent_root, args.poo_root)
    receipt_seconds = round(time.perf_counter() - started, 3)

    def variants(case_id: str, observation: dict) -> dict[str, dict]:
        typed = typed_observation(case_id, observation)
        return {"typed": typed,
                "proof": proof_observation(case_id, typed, receipt)}

    if args.dry_run:
        report_json({"schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION,
                     "protocol": CURRENT_PROTOCOL,
                     "cases": {case["id"]: variants(case["id"], old[case["id"]])
                               for case in cases}, "receipt": receipt,
                     "native_fixture_seconds": tool_seconds,
                     "stratified_receipt_seconds": receipt_seconds})
        return 0
    if args.output is None:
        parser.error("--output is required for a live run")
    require_clean(args.ascent_root)
    require_clean(args.poo_root)
    require_pinned_ascent(args.ascent_root, args.poo_root)
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required")
    run(api_key, args.ascent_root, args.poo_root, args.output, cases, old,
        tool_seconds, variants_for_case=variants,
        arms=PROTOCOLS[CURRENT_PROTOCOL]["arms"],
        study=CURRENT_PROTOCOL, postprocess=guard_answer)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
