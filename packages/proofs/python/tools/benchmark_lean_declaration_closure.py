# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from statistics import median
import time
from typing import Mapping

from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    LeanDeclarationClosureRequest,
    export_declaration_closures,
)


SCHEMA_ID = "agentic-ai-lab.lean-declaration-closure-performance.v1"
REQUESTS = (
    LeanDeclarationClosureRequest(
        root_module="AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore",
        root_declarations=(
            "AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationLifecycleCore.SourceBoundEffectCompletionRecoveryCedarAuthorizationEvidence.Admitted",
        ),
        proof_base_imports=("Cedar.Spec",),
    ),
    LeanDeclarationClosureRequest(
        root_module="AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore",
        root_declarations=(
            "AgenticAILabProof.Enterprise.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridgeCore.SourceBoundEffectCompletionRecoveryCedarAuthorizationSubjectBridge.lifecycleAdmitted",
        ),
        proof_base_imports=("Cedar.Spec",),
    ),
)


def _sample(
    lean_root: Path,
    timeout_seconds: float,
) -> dict[str, object]:
    phases: list[Mapping[str, object]] = []
    started = time.monotonic()
    try:
        closures = export_declaration_closures(
            lean_root=lean_root,
            requests=REQUESTS,
            timeout_seconds=timeout_seconds,
            phase_observer=phases.append,
        )
    except LeanClosureError as error:
        return {
            "cache_state": "unavailable",
            "closure_digests": [],
            "elapsed_ms": round((time.monotonic() - started) * 1000),
            "error": {"code": error.code, "detail": error.detail},
            "phases": phases,
            "status": "failed",
        }
    elapsed_ms = round((time.monotonic() - started) * 1000)
    cache_states = tuple(
        phase.get("cache_state") for phase in phases if phase.get("phase") == "closure-cache-read"
    )
    state = (
        "warm"
        if cache_states and all(value == "hit" for value in cache_states)
        else "cold-or-mixed"
    )
    return {
        "status": "completed",
        "cache_state": state,
        "closure_digests": [closure.closure_digest for closure in closures],
        "elapsed_ms": elapsed_ms,
        "phases": phases,
    }


def _summary(samples: list[dict[str, object]]) -> dict[str, object]:
    warm_elapsed = [
        sample["elapsed_ms"]
        for sample in samples
        if sample["cache_state"] == "warm" and isinstance(sample["elapsed_ms"], int)
    ]
    sorted_warm_elapsed = sorted(warm_elapsed)
    warm_p95_ms = (
        sorted_warm_elapsed[max(0, math.ceil(0.95 * len(sorted_warm_elapsed)) - 1)]
        if sorted_warm_elapsed
        else None
    )
    return {
        "failed_sample_count": sum(sample.get("status") == "failed" for sample in samples),
        "sample_count": len(samples),
        "warm_max_ms": max(warm_elapsed) if warm_elapsed else None,
        "warm_p50_ms": round(median(warm_elapsed)) if warm_elapsed else None,
        "warm_p95_ms": warm_p95_ms,
        "warm_sample_count": len(warm_elapsed),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lean-root", type=Path, default=Path("../lean"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    args = parser.parse_args()
    if args.runs <= 0:
        parser.error("--runs must be positive")
    if not math.isfinite(args.timeout_seconds) or args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive and finite")
    samples = []
    for _ in range(args.runs):
        sample = _sample(args.lean_root, args.timeout_seconds)
        samples.append(sample)
        if sample["status"] == "failed":
            break
    failed = any(sample["status"] == "failed" for sample in samples)
    receipt = {
        "requested_sample_count": args.runs,
        "timeout_seconds": args.timeout_seconds,
        "status": "failed" if failed else "completed",
        "requests": [
            {
                "root_declarations": list(request.root_declarations),
                "root_module": request.root_module,
            }
            for request in REQUESTS
        ],
        "samples": samples,
        "schema_id": SCHEMA_ID,
        "summary": _summary(samples),
    }
    output = (
        json.dumps(
            receipt,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    if args.output is None:
        print(output, end="")
    else:
        args.output.write_text(output)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
