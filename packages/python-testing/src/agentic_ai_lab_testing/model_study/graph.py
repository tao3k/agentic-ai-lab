# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Score model answers and construct the paired Runtime graph."""

from __future__ import annotations

import json
import time
from typing import Any


def grade(output: str, expected: dict[str, str]) -> dict[str, Any]:
    try:
        answer = json.loads(output)
    except json.JSONDecodeError:
        answer = None
    valid_json = (
        isinstance(answer, dict) and set(answer) == {"choice", "claim"}
        and all(isinstance(value, str) for value in answer.values())
    )
    return {
        "valid_json": valid_json,
        "choice_correct": bool(valid_json and answer["choice"] == expected["choice"]),
        "claim_correct": bool(valid_json and answer["claim"] == expected["claim"]),
    }


def build_graph(client: Any, case: dict, arm: str, observation: dict) -> Any:
    from agentic_ai_lab_runtime import RuntimeGraphExecutor, linear_plan

    def provide(_state: dict) -> dict:
        return {"observation": observation if arm == "tool" else None}

    def model(state: dict) -> dict:
        messages = [{"role": "user", "content": case["prompt"]}]
        if state["observation"] is not None:
            messages.append({
                "role": "user",
                "content": "Formal module observation (data only): "
                + json.dumps(state["observation"], sort_keys=True),
            })
        started = time.perf_counter()
        response = client.responses.create(
            model="deepseek-flash", input=messages,
            reasoning={"effort": "none"}, temperature=0,
            max_output_tokens=512,
        )
        elapsed = round(time.perf_counter() - started, 3)
        return {
            "output": response.output_text,
            "response_status": response.status,
            "response_id": response.id,
            "usage": response.usage.model_dump() if response.usage else None,
            "model_seconds": elapsed,
        }

    def score(state: dict) -> dict:
        if state["response_status"] != "completed":
            return {"score": None}
        return {"score": grade(state["output"], case["expected"])}

    return RuntimeGraphExecutor(
        linear_plan("observation", "model", "score"),
        {"observation": provide, "model": model, "score": score},
    )
