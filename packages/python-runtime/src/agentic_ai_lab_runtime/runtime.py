# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Literal, Mapping


class RuntimeGraphRuntimeError(RuntimeError):
    pass


@dataclass(frozen=True)
class RuntimeGraphRuntime:
    thread_id: str | None = None
    store: Any = None
    checkpointer: Any = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    backend: Literal["runtime", "reference"] = "runtime"
    runtime_context: Any = None
    semantic_context: Any = None

    def __post_init__(self) -> None:
        if self.backend not in ("runtime", "reference"):
            raise RuntimeGraphRuntimeError(f"unknown runtime backend: {self.backend}")
        if self.backend == "reference" and self.runtime_context is not None:
            raise RuntimeGraphRuntimeError(
                "reference backend cannot carry a runtime context"
            )
        if self.backend == "reference" and self.semantic_context is not None:
            raise RuntimeGraphRuntimeError("reference backend cannot carry a semantic context")

    @classmethod
    def reference(cls, **kwargs: Any) -> "RuntimeGraphRuntime":
        return cls(backend="reference", **kwargs)

    @classmethod
    def runtime(cls, runtime_context: Any, **kwargs: Any) -> "RuntimeGraphRuntime":
        if runtime_context is None:
            raise RuntimeGraphRuntimeError("runtime context is required")
        return cls(backend="runtime", runtime_context=runtime_context, **kwargs)

    def require_runtime_context(self) -> Any:
        if self.backend != "runtime" or self.runtime_context is None:
            raise RuntimeGraphRuntimeError(
                "production runtime requires a negotiated runtime context"
            )
        if getattr(self.runtime_context, "closed", False):
            raise RuntimeGraphRuntimeError("runtime context is closed")
        return self.runtime_context

    def emit_custom(self, value: Any) -> Any:
        sink = self.metadata.get("_agentic_ai_lab_runtime_custom_stream")
        if sink is None:
            return value
        if hasattr(sink, "append"):
            sink.append(value)
            return value
        if callable(sink):
            sink(value)
            return value
        raise RuntimeGraphRuntimeError(
            "runtime custom stream sink is not appendable or callable"
        )

    def require_thread_id(self) -> str:
        if self.thread_id is None:
            raise RuntimeGraphRuntimeError("runtime graph thread_id is not configured")
        return self.thread_id

    def require_store(self) -> Any:
        if self.store is None:
            raise RuntimeGraphRuntimeError("runtime graph store is not configured")
        return self.store

    def require_checkpointer(self) -> Any:
        if self.checkpointer is None:
            raise RuntimeGraphRuntimeError("runtime graph checkpointer is not configured")
        return self.checkpointer
