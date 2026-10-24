# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import json

from agentic_ai_lab_proof.embodied_ai_constrained_effect_replay import canonical_receipt


def test_replay_receipt_is_deterministic() -> None:
    first = json.dumps(canonical_receipt(), sort_keys=True, separators=(",", ":"))
    second = json.dumps(canonical_receipt(), sort_keys=True, separators=(",", ":"))
    assert first == second


def test_replay_receipt_captures_negative_and_positive_cases() -> None:
    receipt = canonical_receipt()
    cases = receipt["cases"]
    assert isinstance(cases, list)
    assert sum(bool(case["admitted"]) for case in cases) == 1
    assert len(cases) == 7
    assert all(bool(case["authorizationOnlyWouldAdmit"]) for case in cases)
    assert str(receipt["traceRoot"]).startswith("sha256:")
