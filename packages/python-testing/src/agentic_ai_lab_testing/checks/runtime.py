# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Python Runtime graph checks with an in-memory model transport."""

from __future__ import annotations

import contextlib
import io
from types import SimpleNamespace

from ..ascent.live import build_graph
from ..model import CaseContext


def fake_client(text: str, calls: list[dict]) -> SimpleNamespace:
    def create(**kwargs: object) -> list[SimpleNamespace]:
        calls.append(kwargs)
        response = SimpleNamespace(status="completed", id="test-response",
                                   usage=None, incomplete_details=None)
        return [SimpleNamespace(type="response.output_text.delta", delta=text),
                SimpleNamespace(type="response.completed", response=response)]

    return SimpleNamespace(responses=SimpleNamespace(create=create))


def graph_transport(_context: CaseContext) -> None:
    calls: list[dict] = []
    graph = build_graph(fake_client("Hello", calls), "deepseek-flash")
    messages = [{"role": "user", "content": "hello"}]
    with contextlib.redirect_stdout(io.StringIO()):
        state, trace = graph.invoke_with_trace({"messages": messages})
    if trace != ["model", "candidate"] or state["output"] != "Hello":
        raise AssertionError("Runtime graph did not execute both nodes")
    if state["receipt"] is not None or calls[0]["input"] != messages:
        raise AssertionError("noncandidate output changed the model input")
    if "instructions" in calls[0] or not calls[0]["stream"]:
        raise AssertionError("model transport injected instructions or lost streaming")
