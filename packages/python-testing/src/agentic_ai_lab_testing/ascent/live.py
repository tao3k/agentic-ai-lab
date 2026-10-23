# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Interactive DeepSeek access to the Scheme-native reasoning candidate check."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from .candidate import SchemeChecker, candidate_text, scheme_attempt


def terminal_write(value: str) -> None:
    """Emit one bounded experiment message through the terminal surface."""
    sys.stdout.write(value)
    sys.stdout.flush()


def key_from_file(path: Path) -> str:
    """Load one credential without evaluating the env file or printing it."""
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"(?:export\s+)?DEEPSEEK_API_KEY\s*=\s*(.+)", line)
        if match:
            value = match.group(1).strip().strip("\"'")
            if value:
                return value
    raise ValueError("DEEPSEEK_API_KEY is absent from the selected env file")


def build_graph(client: Any, model: str, checker=scheme_attempt) -> Any:
    """The downstream adapter owns model and Scheme nodes, not graph semantics."""
    from agentic_ai_lab_runtime import RuntimeGraphExecutor, linear_plan

    def model_turn(state: dict) -> dict:
        started = time.perf_counter()
        events = client.responses.create(
            model=model, input=state["messages"], max_output_tokens=4096,
            reasoning={"effort": "none"}, stream=True,
        )
        terminal_write("model> ")
        chunks: list[str] = []
        response = None
        first_token_seconds = None
        for event in events:
            if event.type == "response.output_text.delta":
                if first_token_seconds is None:
                    first_token_seconds = round(time.perf_counter() - started, 3)
                chunks.append(event.delta)
                terminal_write(event.delta)
            elif event.type in ("response.completed", "response.incomplete",
                                "response.failed"):
                response = event.response
        terminal_write("\n")
        if response is None:
            raise RuntimeError("DeepSeek stream ended without a final response")
        if response.status != "completed":
            reason = getattr(response.incomplete_details, "reason", None)
            raise RuntimeError(f"DeepSeek response status: {response.status} ({reason})")
        return {"output": "".join(chunks), "response_id": response.id,
                "usage": response.usage.model_dump() if response.usage else None,
                "model_seconds": round(time.perf_counter() - started, 3),
                "first_token_seconds": first_token_seconds}

    def check_candidate(state: dict) -> dict:
        started = time.perf_counter()
        candidate = candidate_text(state["output"])
        if candidate is None:
            return {"receipt": None, "scheme_seconds": 0.0}
        return {"receipt": checker(candidate),
                "scheme_seconds": round(time.perf_counter() - started, 3)}

    return RuntimeGraphExecutor(
        linear_plan("model", "candidate"),
        {"model": model_turn, "candidate": check_candidate},
    )


def converse(api_key: str, model: str, transcript: Path | None,
             ascent_root: Path | None) -> None:
    from openai import OpenAI  # optional live-model dependency

    client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com",
                    max_retries=0, timeout=90.0)
    checker = SchemeChecker(ascent_root)
    graph = build_graph(client, model, checker.attempt)
    messages: list[dict[str, str]] = []
    terminal_write("DeepSeek interactive session. No initial prompt or instructions are sent.\n")
    terminal_write("Type /quit to end. Scheme sample source: edge/2 = {(0,1), (1,2)};\n")
    terminal_write("a second snapshot withdraws (1,2). Exact candidate data is checked locally.\n")
    while True:
        try:
            user = input("you> ")
        except EOFError:
            break
        if user == "/quit":
            break
        if not user.strip():
            continue
        messages.append({"role": "user", "content": user})
        try:
            result, trace = graph.invoke_with_trace({"messages": list(messages)})
        except Exception as error:
            messages.pop()
            terminal_write("turn failed> " + type(error).__name__ + "\n")
            continue
        raw = result["output"]
        event: dict = {"user": user, "model": raw,
                       "response_id": result["response_id"],
                       "usage": result["usage"], "runtime_trace": trace,
                       "model_seconds": result["model_seconds"],
                       "first_token_seconds": result["first_token_seconds"],
                       "scheme_seconds": result["scheme_seconds"]}
        messages.append({"role": "assistant", "content": raw})
        terminal_write("timing> first token " + str(result["first_token_seconds"])
                       + " s; model " + str(result["model_seconds"])
                       + " s; Scheme " + str(result["scheme_seconds"]) + " s\n")
        if result["receipt"] is not None:
            terminal_write("Scheme receipt> "
                           + json.dumps(result["receipt"], ensure_ascii=False)
                           + "\n")
            event["receipt"] = result["receipt"]
        if transcript is not None:
            with transcript.open("a", encoding="utf-8") as file:
                file.write(json.dumps(event, ensure_ascii=False) + "\n")
    checker.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="deepseek-flash")
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--transcript", type=Path,
                        help="optional local JSONL transcript path")
    parser.add_argument("--ascent-root", type=Path,
                        help="local Gerbil package checkout if not installed by gxpkg")
    args = parser.parse_args()
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required")
    converse(api_key, args.model, args.transcript, args.ascent_root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
