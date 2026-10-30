# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Request for the movie study study."""

import json
from ._config import MAX_INPUT_BYTES, MAX_OUTPUT_TOKENS
from ._sources import digest


def request_for(source, case, arm):
    # Explicit declared family reuse. No automatic NL intent equivalence claim.
    public = {k: case[k] for k in ("template", "left", "right", "blocked")}
    if arm == "baseline":
        context = {"finiteSource": source, "question": public}
        instruction = "Using only the supplied finite P161 cast facts, answer the question. Return only a JSON array of actor QIDs; no prose. Missing claims mean absent only in this finite extract."
    elif arm == "scheme-contract":
        # Intent compilation does not require actor enumeration. The engine
        # retains the actual facts; this hash binds identity, not correctness.
        context = {
            "question": public,
            "sourceIdentity": digest(
                json.dumps(source, ensure_ascii=False, sort_keys=True).encode()
            ),
            "executor": {
                "castColumns": ["Film", "Actor"],
                "bindings": {"left": "Film", "right": "Film", "blocked": "Actor"},
                "operators": ["union", "intersection", "branch-scoped exclusion"],
            },
        }
        instruction = (
            "Compile the declared question template, not its answer. Return only a JSON object with exactly two fields: "
            '"combine": "any" (OR) or "all" (AND), and "exclude_scope": "none", "left", or "both". '
            "The scheme engine will substitute movie/actor bindings and preserve typed evidence before projection. No prose."
        )
    else:
        raise ValueError("unknown movie study arm")
    task = json.dumps(context, ensure_ascii=False, sort_keys=True)
    request = {
        "model": "deepseek-flash",
        "input": [{"role": "user", "content": instruction + "\n" + task}],
        "reasoning": {"effort": "high"},
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "stream": True,
        "store": False,
    }
    if len(json.dumps(request, ensure_ascii=False).encode()) > MAX_INPUT_BYTES:
        raise ValueError("movie request exceeds frozen input bound")
    return request


def continuation_plan(preview, output, frozen_root):
    """Bind preserved producers and the exact paid prefix before resuming."""
    plan = json.loads((preview / "plan.json").read_text())
    for path, expected in plan["producerHashes"].items():
        if digest((frozen_root / path).read_bytes()) != expected:
            raise ValueError("frozen producer mismatch: " + path)
    for item in plan["order"]:
        data = (preview / item["request"]).read_bytes()
        request = json.loads(data)
        if digest(data) != item["sha256"] or len(data) > MAX_INPUT_BYTES:
            raise ValueError("frozen request mismatch")
        if (
            request["model"] != "deepseek-flash"
            or request["max_output_tokens"] != plan["maxOutputTokens"]
        ):
            raise ValueError("frozen request budget mismatch")
    if (
        plan["purpose"] != "mechanism-regression"
        or plan["capabilityEvaluationEligible"]
        or len(plan["order"]) != 9
        or plan["retries"] != 0
        or plan["conservativeScheduledUpperUsd"] > 1
    ):
        raise ValueError("unexpected pilot budget or scope")
    records = [
        json.loads(line) for line in (output / "calls.jsonl").read_text().splitlines()
    ]
    if not 0 < len(records) < 9:
        raise ValueError("expected an unfinished paid prefix")
    for index, record in enumerate(records):
        if any(
            record[key] != plan["order"][index][key] for key in ("id", "arm", "sha256")
        ):
            raise ValueError("paid prefix does not match frozen order")
    return plan, records
