# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Deterministic output guard for temporal model observations."""

from __future__ import annotations

import json
from typing import Any


def gate_model_answer(output: str, observation: dict[str, Any]) -> dict[str, Any]:
    """Return observation-only or withheld; never mint release authority."""
    if observation.get("source") != "agentic-ai-lab.temporal-causality":
        return {"status": "withheld", "reason": "wrong-observation-source"}
    release = observation.get("release_authorized", observation.get("release-authorized?"))
    if not (release is False or release == "#f"):
        return {"status": "withheld", "reason": "invalid-release-boundary"}
    try:
        answer = json.loads(output)
    except json.JSONDecodeError:
        return {"status": "withheld", "reason": "invalid-model-answer"}
    if not (isinstance(answer, dict) and set(answer) == {"choice", "claim"}
            and all(isinstance(value, str) for value in answer.values())):
        return {"status": "withheld", "reason": "invalid-model-answer"}
    if answer["claim"] == "release_authorized":
        return {"status": "withheld", "reason": "native-denies-release"}
    if answer["claim"] == "negative_claim":
        if (observation.get("status") == "partial-temporal-classification"
                or observation.get("unknown") not in (None, "()")):
            return {"status": "withheld",
                    "reason": "open-frontier-denies-absence"}
        if observation.get("absence_proven") is not True:
            return {"status": "withheld",
                    "reason": "no-native-absence-proof"}
    return {"status": "observation-only", "choice": answer["choice"],
            "claim": answer["claim"]}


def guarded_runtime() -> Any:
    """Use the normal Runtime graph so unsafe model fields stop at one node."""
    from agentic_ai_lab_runtime import RuntimeGraphExecutor, linear_plan

    return RuntimeGraphExecutor(
        linear_plan("authority"),
        {"authority": lambda state: {
            "guard": gate_model_answer(state["model_output"], state["observation"])
        }},
    )
