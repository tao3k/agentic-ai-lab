# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import hashlib
import json
from pathlib import Path
import subprocess
import sys

from agentic_ai_lab_proof.embodied_ai_provider_non_authority_replay import (
    build_ease005_replay_receipt,
)


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def test_ease005_replay_receipt_is_deterministic_and_self_bound() -> None:
    first = build_ease005_replay_receipt()
    second = build_ease005_replay_receipt()

    assert first == second
    payload = {key: value for key, value in first.items() if key != "traceRoot"}
    expected = hashlib.sha256(_canonical_json(payload).encode()).hexdigest()
    assert first["traceRoot"] == f"sha256:{expected}"
    implementation = (
        Path(__file__).parents[1]
        / "src/agentic_ai_lab_proof/embodied_ai_provider_non_authority.py"
    )
    implementation_digest = hashlib.sha256(implementation.read_bytes()).hexdigest()
    assert first["implementationArtifactDigest"] == (
        f"sha256:{implementation_digest}"
    )


def test_ease005_replay_retains_counterexample_and_independent_authority() -> None:
    receipt = build_ease005_replay_receipt()
    provider_cases = receipt["cases"][:3]
    independent_case = receipt["cases"][3]

    assert all(case["roleOnlyWouldAdmit"] is True for case in provider_cases)
    assert all(case["admitted"] is False for case in provider_cases)
    assert all(
        case["reasonKind"] == "ai-provider-non-authority"
        for case in provider_cases
    )
    assert independent_case["admitted"] is True
    assert independent_case["reasonKind"] == "independent-authority-admitted"


def test_module_entrypoint_replays_the_same_receipt() -> None:
    completed = subprocess.run(
        [
            sys.executable,
            "-m",
            "agentic_ai_lab_proof.embodied_ai_provider_non_authority_replay",
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    assert json.loads(completed.stdout) == build_ease005_replay_receipt()
