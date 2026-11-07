# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Mapping, Sequence
import uuid


@dataclass(frozen=True)
class RuntimeGraphToolCall:
    name: str
    args: Mapping[str, Any] = field(default_factory=dict)
    id: str = field(default_factory=lambda: uuid.uuid4().hex)


@dataclass(frozen=True)
class RuntimeGraphMessage:
    role: str
    content: Any
    id: str | None = None
    name: str | None = None
    tool_calls: tuple[RuntimeGraphToolCall, ...] = ()
    tool_call_id: str | None = None


def human_message(content: Any, *, id: str | None = None) -> RuntimeGraphMessage:
    return RuntimeGraphMessage(role="human", content=content, id=id)


def ai_message(
    content: Any,
    *,
    id: str | None = None,
    tool_calls: Sequence[RuntimeGraphToolCall] = (),
) -> RuntimeGraphMessage:
    return RuntimeGraphMessage(
        role="ai",
        content=content,
        id=id,
        tool_calls=tuple(tool_calls),
    )


def tool_message(
    content: Any,
    *,
    tool_call_id: str,
    id: str | None = None,
    name: str | None = None,
) -> RuntimeGraphMessage:
    return RuntimeGraphMessage(
        role="tool",
        content=content,
        id=id,
        name=name,
        tool_call_id=tool_call_id,
    )


def add_messages(
    left: Sequence[RuntimeGraphMessage] | RuntimeGraphMessage | None,
    right: Sequence[RuntimeGraphMessage] | RuntimeGraphMessage | None,
) -> list[RuntimeGraphMessage]:
    merged = list(_coerce_messages(left))
    index_by_id = {
        message.id: index for index, message in enumerate(merged) if message.id is not None
    }
    for message in _coerce_messages(right):
        if message.id is not None and message.id in index_by_id:
            merged[index_by_id[message.id]] = message
        else:
            index_by_id[message.id] = len(merged) if message.id is not None else -1
            merged.append(message)
    return merged


def _coerce_messages(
    value: Sequence[RuntimeGraphMessage] | RuntimeGraphMessage | None,
) -> tuple[RuntimeGraphMessage, ...]:
    if value is None:
        return ()
    if isinstance(value, RuntimeGraphMessage):
        return (value,)
    return tuple(value)
