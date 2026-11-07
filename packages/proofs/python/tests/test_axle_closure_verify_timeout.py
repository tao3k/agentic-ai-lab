# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import asyncio

import pytest

from agentic_ai_lab_proof import axle_closure_verify
from agentic_ai_lab_proof.lean_declaration_closure import LeanClosureError


def test_complete_axle_closure_operation_has_a_hard_deadline(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def never_returns(**_kwargs: object) -> object:
        await asyncio.sleep(60)
        return object()

    monkeypatch.setattr(
        axle_closure_verify,
        "build_exact_axle_closure",
        never_returns,
    )

    with pytest.raises(LeanClosureError) as raised:
        asyncio.run(
            axle_closure_verify._build_exact_axle_closure_with_deadline(
                closure=object(),  # type: ignore[arg-type]
                sources=(),
                environment="lean",
                operation_timeout_seconds=0.01,
                base_timeout_seconds=0.0,
            )
        )

    assert raised.value.code == "axle-operation-deadline-exceeded"
    assert "0.01-second deadline" in raised.value.detail
