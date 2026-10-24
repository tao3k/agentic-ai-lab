# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Private implementation for C ABI-backed runtime graph programs."""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from typing import Any, Mapping

from ._program_resolution import resolve_actions, resolve_reducers
from .checkpoints import RuntimeGraphCheckpoint
from .event_stream import RuntimeGraphStreamProjection, normalize_stream_modes
from .materialization import RuntimeGraphBindings, describe_runtime_graph_plan
from .receipts import RuntimeReceipt, parse_runtime_receipt
from .runtime import RuntimeGraphRuntime
from .runtime_graph import (
    RuntimeGraphError,
    RuntimeGraphEvent,
    RuntimeGraphExecutor,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
)

RUNTIME_GRAPH_PLAN_STATE_KEY = "_agentic_ai_lab_runtime_graph_plan"


async def _call_checkpoint_method(
    checkpointer,
    async_name: str,
    sync_name: str,
    *args,
    **kwargs,
):
    method = getattr(checkpointer, async_name, None)
    if method is not None:
        return await method(*args, **kwargs)
    from ._anyio_runtime import run_blocking

    return await run_blocking(getattr(checkpointer, sync_name), *args, **kwargs)


@dataclass(frozen=True)
class RuntimeGraphRegistries:
    actions: Mapping[str, Any] = field(default_factory=dict)
    routers: Mapping[str, Any] = field(default_factory=dict)
    reducers: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class RuntimeGraphExecution:
    state: dict[str, Any]
    trace: tuple[str, ...]
    validation_receipt: bytes
    events: tuple[RuntimeGraphEvent, ...] = ()

    @property
    def validation(self) -> RuntimeReceipt:
        return parse_runtime_receipt(self.validation_receipt)

    @property
    def plan_digest(self) -> str | None:
        return self.validation.plan_digest


class RuntimeGraphProgram:
    """Python production graph program with explicit Scheme admission.

    The installed runtime-v0 control lane does not execute graph semantics.
    Native execution requires Scheme topology admission and a real control session.
    """

    def __init__(
        self,
        *,
        plan: RuntimeGraphPlan,
        graph_bindings: RuntimeGraphBindings | None = None,
        registries: RuntimeGraphRegistries | None = None,
        runtime: RuntimeGraphRuntime | None = None,
    ) -> None:
        self.plan = plan
        self.graph_bindings = graph_bindings or RuntimeGraphBindings()
        self.registries = registries or RuntimeGraphRegistries()
        self.runtime = runtime or RuntimeGraphRuntime()

    @classmethod
    def reference(cls, **kwargs: Any) -> "RuntimeGraphProgram":
        runtime = kwargs.pop("runtime", None)
        if runtime is None:
            runtime = RuntimeGraphRuntime.reference()
        elif runtime.backend != "reference":
            raise RuntimeGraphError("reference program requires a reference runtime")
        return cls(runtime=runtime, **kwargs)

    def describe(self) -> bytes:
        return describe_runtime_graph_plan(self.plan, self.graph_bindings)

    def describe_receipt(self) -> RuntimeReceipt:
        return parse_runtime_receipt(self.describe())

    def invoke(self, initial_state: Mapping[str, Any]) -> dict[str, Any]:
        return self.invoke_with_trace(initial_state).state

    async def ainvoke(self, initial_state: Mapping[str, Any]) -> dict[str, Any]:
        return (await self.ainvoke_with_trace(initial_state)).state

    async def abatch(
        self,
        inputs: Sequence[Mapping[str, Any]],
        *,
        max_concurrency: int | None = None,
    ) -> list[dict[str, Any]]:
        from ._anyio_runtime import map_ordered_async, run_blocking

        values = list(inputs)
        if not values:
            return await map_ordered_async(
                self.ainvoke, values, max_concurrency=max_concurrency
            )

        validation_receipt, plan_digest = await run_blocking(self._validated_plan)
        executor = self._executor()

        async def invoke_prepared(
            initial_state: Mapping[str, Any],
        ) -> dict[str, Any]:
            execution = await self._ainvoke_prepared(
                initial_state,
                validation_receipt=validation_receipt,
                plan_digest=plan_digest,
                executor=executor,
            )
            return execution.state

        return await map_ordered_async(
            invoke_prepared, values, max_concurrency=max_concurrency
        )

    async def ainvoke_with_trace(
        self, initial_state: Mapping[str, Any], *, trace_key: str | None = None
    ) -> RuntimeGraphExecution:
        from ._anyio_runtime import run_blocking

        validation_receipt, plan_digest = await run_blocking(self._validated_plan)
        executor = self._executor()
        return await self._ainvoke_prepared(
            initial_state,
            validation_receipt=validation_receipt,
            plan_digest=plan_digest,
            executor=executor,
            trace_key=trace_key,
        )

    async def _ainvoke_prepared(
        self,
        initial_state: Mapping[str, Any],
        *,
        validation_receipt: bytes,
        plan_digest: str | None,
        executor: RuntimeGraphExecutor,
        trace_key: str | None = None,
    ) -> RuntimeGraphExecution:
        try:
            state, trace, events = await executor._ainvoke_owned_with_events(
                self._internal_state(initial_state), trace_key=trace_key
            )
        except RuntimeGraphInterrupted as exc:
            raise self._public_interrupted(exc, validation_receipt, plan_digest) from exc
        return self._execution(state, trace, validation_receipt, events)

    def stream(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_mode: object = "values",
        trace_key: str | None = None,
    ):
        validation_receipt, plan_digest = self._validated_plan()
        executor = self._executor()
        state = self._internal_state(initial_state)
        try:
            for chunk in executor.stream(state, stream_mode=stream_mode, trace_key=trace_key):
                yield self._public_chunk(chunk)
        except RuntimeGraphInterrupted as exc:
            raise self._public_interrupted(exc, validation_receipt, plan_digest) from exc

    async def astream(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_mode: object = "values",
        trace_key: str | None = None,
    ):
        from ._anyio_runtime import run_blocking

        validation_receipt, plan_digest = await run_blocking(self._validated_plan)
        executor = self._executor()
        try:
            async for chunk in executor.astream(
                self._internal_state(initial_state),
                stream_mode=stream_mode,
                trace_key=trace_key,
            ):
                yield self._public_chunk(chunk)
        except RuntimeGraphInterrupted as exc:
            raise self._public_interrupted(exc, validation_receipt, plan_digest) from exc

    def stream_projection(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_modes: object = None,
        trace_key: str | None = None,
    ) -> RuntimeGraphStreamProjection:
        modes = normalize_stream_modes(stream_modes)
        return RuntimeGraphStreamProjection.from_chunks(
            self.stream(initial_state, stream_mode=modes, trace_key=trace_key)
        )

    def invoke_with_trace(
        self, initial_state: Mapping[str, Any], *, trace_key: str | None = None
    ) -> RuntimeGraphExecution:
        validation_receipt, plan_digest = self._validated_plan()
        try:
            state, trace, events = self._executor().invoke_with_events(
                self._internal_state(initial_state), trace_key=trace_key
            )
        except RuntimeGraphInterrupted as exc:
            raise self._public_interrupted(exc, validation_receipt, plan_digest) from exc
        return self._execution(state, trace, validation_receipt, events)

    def invoke_thread(self, thread_id: str, initial_state: dict[str, Any], checkpointer, *, trace_key: str | None = None) -> RuntimeGraphExecution:
        try:
            execution = self.invoke_with_trace(initial_state, trace_key=trace_key)
        except RuntimeGraphInterrupted as exc:
            checkpointer.save_interrupted(thread_id, exc)
            raise
        checkpointer.save(_checkpoint_from_execution(thread_id, execution))
        return execution

    async def ainvoke_thread(
        self,
        thread_id: str,
        initial_state: dict[str, Any],
        checkpointer,
        *,
        trace_key: str | None = None,
    ) -> RuntimeGraphExecution:
        try:
            execution = await self.ainvoke_with_trace(initial_state, trace_key=trace_key)
        except RuntimeGraphInterrupted as exc:
            await _call_checkpoint_method(
                checkpointer, "asave_interrupted", "save_interrupted", thread_id, exc
            )
            raise
        await _call_checkpoint_method(
            checkpointer,
            "asave",
            "save",
            _checkpoint_from_execution(thread_id, execution),
        )
        return execution

    def resume_thread(
        self,
        thread_id: str,
        resume_result: object,
        checkpointer,
        *,
        trace_key: str | None = None,
        clear: bool = True,
    ) -> RuntimeGraphExecution:
        execution = self.resume_interrupted(
            checkpointer.load_interrupted(thread_id),
            resume_result,
            trace_key=trace_key,
        )
        if clear:
            checkpointer.clear(thread_id)
        return execution

    async def aresume_thread(
        self,
        thread_id: str,
        resume_result: object,
        checkpointer,
        *,
        trace_key: str | None = None,
        clear: bool = True,
    ) -> RuntimeGraphExecution:
        interrupted = await _call_checkpoint_method(
            checkpointer, "aload_interrupted", "load_interrupted", thread_id
        )
        execution = await self.aresume_interrupted(
            interrupted, resume_result, trace_key=trace_key
        )
        if clear:
            await _call_checkpoint_method(checkpointer, "aclear", "clear", thread_id)
        return execution

    def get_state(self, thread_id: str, checkpointer) -> Any:
        return checkpointer.inspect(thread_id)

    async def aget_state(self, thread_id: str, checkpointer) -> Any:
        return await _call_checkpoint_method(
            checkpointer,
            "ainspect",
            "inspect",
            thread_id,
        )

    def get_state_history(self, thread_id: str, checkpointer) -> tuple[Any, ...]:
        return tuple(checkpointer.history(thread_id))

    async def aget_state_history(self, thread_id: str, checkpointer) -> tuple[Any, ...]:
        return tuple(
            await _call_checkpoint_method(
                checkpointer,
                "ahistory",
                "history",
                thread_id,
            )
        )

    def get_state_at(self, thread_id: str, checkpoint_id: str, checkpointer) -> Any:
        return checkpointer.load_at(thread_id, checkpoint_id)

    async def aget_state_at(
        self,
        thread_id: str,
        checkpoint_id: str,
        checkpointer,
    ) -> Any:
        return await _call_checkpoint_method(
            checkpointer,
            "aload_at",
            "load_at",
            thread_id,
            checkpoint_id,
        )

    def update_state(
        self,
        thread_id: str,
        values: Mapping[str, Any],
        checkpointer,
        *,
        replace: bool = False,
    ) -> Any:
        return checkpointer.update_state(thread_id, values, replace=replace)

    async def aupdate_state(
        self,
        thread_id: str,
        values: Mapping[str, Any],
        checkpointer,
        *,
        replace: bool = False,
    ) -> Any:
        return await _call_checkpoint_method(
            checkpointer,
            "aupdate_state",
            "update_state",
            thread_id,
            values,
            replace=replace,
        )

    def resume_interrupted(
        self,
        interrupted: RuntimeGraphInterrupted,
        resume_result: object = None,
        *,
        trace_key: str | None = None,
    ) -> RuntimeGraphExecution:
        validation_receipt, plan_digest = self._validated_plan()
        if interrupted.plan_digest and interrupted.plan_digest != plan_digest:
            raise RuntimeGraphError("runtime graph plan digest mismatch before resume")
        resumed = RuntimeGraphInterrupted(
            interrupted.interrupt,
            node=interrupted.node,
            step=interrupted.step,
            state=self._internal_state(interrupted.state),
            trace=interrupted.trace,
            pending=interrupted.pending,
            events=interrupted.events,
            validation_receipt=validation_receipt,
            plan_digest=plan_digest,
        )
        state, trace, events = self._executor().resume_interrupted(
            resumed, resume_result, trace_key=trace_key
        )
        return self._execution(state, trace, validation_receipt, events)

    def _validated_plan(self) -> tuple[bytes, str | None]:
        if self.runtime.backend == "native":
            self.runtime.require_native_context()
            from .semantic_runtime import SemanticRuntime
            semantic = self.runtime.semantic_context
            if not isinstance(semantic, SemanticRuntime):
                raise RuntimeGraphError(
                    "native graph execution is unavailable: runtime-v0 negotiates "
                    "the control lane but does not execute Scheme graph semantics; "
                    "a qualified SemanticRuntime is required"
                )
            from ._native.session import NativeRuntimeSession
            if not isinstance(self.runtime.native_context, NativeRuntimeSession):
                raise RuntimeGraphError("native execution requires an actual runtime-v0 session")
            receipt = semantic.admit_graph(self.plan, self.graph_bindings)
            return receipt, parse_runtime_receipt(receipt).plan_digest
        receipt = self.describe()
        return receipt, parse_runtime_receipt(receipt).plan_digest

    async def aresume_interrupted(
        self,
        interrupted: RuntimeGraphInterrupted,
        resume_result: object = None,
        *,
        trace_key: str | None = None,
    ) -> RuntimeGraphExecution:
        from ._anyio_runtime import run_blocking

        validation_receipt, plan_digest = await run_blocking(self._validated_plan)
        if interrupted.plan_digest is not None and interrupted.plan_digest != plan_digest:
            raise RuntimeGraphError("runtime graph plan digest mismatch before resume")
        restored = RuntimeGraphInterrupted(
            interrupted.interrupt,
            node=interrupted.node,
            step=interrupted.step,
            state=self._internal_state(interrupted.state),
            trace=interrupted.trace,
            pending=interrupted.pending,
            events=interrupted.events,
            validation_receipt=validation_receipt,
            plan_digest=plan_digest,
        )
        state, trace, events = await self._executor().aresume_interrupted(
            restored, resume_result, trace_key=trace_key
        )
        return self._execution(state, trace, validation_receipt, events)

    def _executor(self) -> RuntimeGraphExecutor:
        return RuntimeGraphExecutor(
            self.plan,
            resolve_actions(self.plan, self.graph_bindings, self.registries),
            routers=dict(self.registries.routers),
            runtime=self.runtime,
            reducers=resolve_reducers(self.graph_bindings, self.registries),
            semantic_graph=(self.runtime.semantic_context.bind_graph(self.plan, self.graph_bindings)
                            if self.runtime.backend == 'native' else None),
        )

    def _internal_state(self, state: Mapping[str, Any]) -> dict[str, Any]:
        internal_state = dict(state)
        internal_state[RUNTIME_GRAPH_PLAN_STATE_KEY] = self.plan
        return internal_state

    def _execution(
        self,
        state: Mapping[str, Any],
        trace: list[str],
        validation_receipt: bytes,
        events: list[RuntimeGraphEvent],
    ) -> RuntimeGraphExecution:
        return RuntimeGraphExecution(
            self._public_state(state),
            tuple(trace),
            validation_receipt,
            tuple(events),
        )

    def _public_interrupted(
        self,
        exc: RuntimeGraphInterrupted,
        validation_receipt: bytes,
        plan_digest: str | None,
    ) -> RuntimeGraphInterrupted:
        return RuntimeGraphInterrupted(
            exc.interrupt,
            node=exc.node,
            step=exc.step,
            state=self._public_state(exc.state),
            trace=exc.trace,
            pending=exc.pending,
            events=exc.events,
            validation_receipt=validation_receipt,
            plan_digest=plan_digest,
        )

    def _public_chunk(self, chunk):
        if isinstance(chunk, tuple) and len(chunk) == 2:
            mode, value = chunk
            if mode == "values":
                return mode, self._public_state(value)
            if mode == "checkpoints" and hasattr(value, "state"):
                return mode, replace(value, state=self._public_state(value.state))
            if isinstance(value, RuntimeGraphEvent):
                return mode, self._public_event(value)
            return chunk
        if isinstance(chunk, RuntimeGraphEvent):
            return self._public_event(chunk)
        if hasattr(chunk, "checkpoint_id") and hasattr(chunk, "state"):
            return replace(chunk, state=self._public_state(chunk.state))
        return self._public_state(chunk) if isinstance(chunk, Mapping) else chunk

    def _public_event(self, event: RuntimeGraphEvent) -> RuntimeGraphEvent:
        detail = dict(event.detail)
        if "state" in detail:
            detail["state"] = self._public_state(detail["state"])
        return RuntimeGraphEvent(event.kind, event.node, event.step, detail)

    def _public_state(self, state: Mapping[str, Any]) -> dict[str, Any]:
        public_state = dict(state)
        public_state.pop(RUNTIME_GRAPH_PLAN_STATE_KEY, None)
        return public_state


def _checkpoint_from_execution(
    thread_id: str,
    execution: RuntimeGraphExecution,
) -> RuntimeGraphCheckpoint:
    step = max((event.step for event in execution.events), default=len(execution.trace))
    return RuntimeGraphCheckpoint(
        checkpoint_id="",
        thread_id=thread_id,
        interrupt=None,
        node=execution.trace[-1] if execution.trace else "",
        step=step,
        state=dict(execution.state),
        trace=execution.trace,
        pending=(),
        events=execution.events,
        validation_receipt=execution.validation_receipt,
        plan_digest=execution.plan_digest,
    )
