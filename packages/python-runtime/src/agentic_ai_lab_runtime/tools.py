# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Mapping

from .messages import RuntimeGraphMessage, RuntimeGraphToolCall, tool_message


class RuntimeGraphToolError(RuntimeError):
    pass


@dataclass(frozen=True)
class RuntimeGraphTool:
    name: str
    invoke: Callable[[Mapping[str, Any]], Any]

    @classmethod
    def from_callable(
        cls,
        name: str,
        function: Callable[..., Any],
    ) -> RuntimeGraphTool:
        return cls(name=name, invoke=lambda args: function(**dict(args)))


@dataclass(frozen=True)
class RuntimeGraphToolNode:
    tools: Mapping[str, RuntimeGraphTool]
    messages_key: str = "messages"

    @classmethod
    def from_callables(
        cls,
        tools: Mapping[str, Callable[..., Any]],
        *,
        messages_key: str = "messages",
    ) -> RuntimeGraphToolNode:
        return cls(
            {
                name: RuntimeGraphTool.from_callable(name, function)
                for name, function in tools.items()
            },
            messages_key=messages_key,
        )

    def __call__(self, state: Mapping[str, Any]) -> dict[str, list[RuntimeGraphMessage]]:
        messages = tuple(state.get(self.messages_key, ()))
        if not messages:
            raise RuntimeGraphToolError("runtime graph tool node requires messages")
        calls = tuple(messages[-1].tool_calls)
        outputs = [self._invoke_tool(call) for call in calls]
        return {self.messages_key: outputs}

    def _invoke_tool(self, call: RuntimeGraphToolCall) -> RuntimeGraphMessage:
        try:
            tool = self.tools[call.name]
        except KeyError as exc:
            raise RuntimeGraphToolError(f"missing runtime graph tool: {call.name}") from exc
        return tool_message(
            tool.invoke(call.args),
            tool_call_id=call.id,
            name=call.name,
        )
