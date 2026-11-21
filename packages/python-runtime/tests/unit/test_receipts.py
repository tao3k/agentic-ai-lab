# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime import parse_runtime_receipt


def test_parse_runtime_receipt_fields() -> None:
    receipt = parse_runtime_receipt(
        b"agentic-ai-lab-receipt.v1\n"
        b"kind=runtime-graph-validation\n"
        b"nodes=2\n"
        b"plan-digest=0123456789abcdef\n"
    )

    assert receipt.version == "agentic-ai-lab-receipt.v1"
    assert receipt.kind == "runtime-graph-validation"
    assert receipt.integer("nodes") == 2
    assert receipt.plan_digest == "0123456789abcdef"


def test_parse_runtime_receipt_rejects_unknown_version() -> None:
    with pytest.raises(ValueError, match="unsupported version"):
        parse_runtime_receipt(b"agentic-ai-lab-receipt.v0\nkind=x\n")


def test_parse_runtime_receipt_rejects_invalid_field() -> None:
    with pytest.raises(ValueError, match="invalid field"):
        parse_runtime_receipt(b"agentic-ai-lab-receipt.v1\nkind\n")


def test_runtime_receipt_requires_fields() -> None:
    receipt = parse_runtime_receipt(b"agentic-ai-lab-receipt.v1\nkind=x\n")

    with pytest.raises(ValueError, match="missing runtime receipt field"):
        receipt.require("missing")


def test_runtime_receipt_integer_requires_integer_value() -> None:
    receipt = parse_runtime_receipt(b"agentic-ai-lab-receipt.v1\nkind=x\nnodes=abc\n")

    with pytest.raises(ValueError, match="not an integer"):
        receipt.integer("nodes")
