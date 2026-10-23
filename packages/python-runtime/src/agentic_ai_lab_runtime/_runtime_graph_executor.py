# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import inspect
from collections.abc import Mapping, Sequence
from typing import Any, Iterator

from ._anyio_runtime import map_ordered_async
from ._runtime_graph_context import GraphRunContext, record_trace
from ._runtime_graph_factory import bind_runtime_action, linear_plan
from ._runtime_graph_state import (
    NormalizedActionResult,
    check_endpoint,
    index_conditional_edges,
    index_edges,
    merge_state,
    normalize_action_result,
    with_branch_update,
)
from ._runtime_graph_stream import StreamPublisher, validated_stream_modes
from ._runtime_graph_types import (
    END,
    RuntimeAction,
    RuntimeActionResult,
    RuntimeGraphError,
    RuntimeGraphEvent,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    RuntimeGraphSend,
    RuntimeReducer,
    RuntimeRouter,
    RuntimeState,
)
from .event_stream import RuntimeGraphStreamProjection, normalize_stream_modes
from .runtime import RuntimeGraphRuntime


class RuntimeGraphExecutor:
    def __init__(
        self,
        plan: RuntimeGraphPlan,
        actions: Mapping[str, RuntimeAction],
        *,
        routers: Mapping[str, RuntimeRouter] | None = None,
        reducers: Mapping[str, RuntimeReducer] | None = None,
        runtime: RuntimeGraphRuntime | None = None,
        semantic_graph=None,
    ) -> None:
        self.plan = plan
        self.runtime = runtime or RuntimeGraphRuntime.reference()
        self._semantic_graph = semantic_graph
        if self.runtime.backend == 'native':
            from .semantic_runtime import _SemanticGraphBinding
            from ._native.session import NativeRuntimeSession
            if not isinstance(self.runtime.require_native_context(), NativeRuntimeSession):
                raise RuntimeGraphError('native scheduler requires an actual control session')
            if not isinstance(semantic_graph, _SemanticGraphBinding):
                raise RuntimeGraphError('native scheduler requires a Scheme graph binding')
        self.actions = {
            node: bind_runtime_action(action, self.runtime)
            for node, action in actions.items()
        }
        self.routers = dict(routers or {})
        self.reducers = dict(reducers or {})
        self._edges = index_edges(plan.edges)
        if semantic_graph is not None:
            self._edges = semantic_graph.static_successors
        self._conditional_edges = index_conditional_edges(plan.conditional_edges)
        self._validate_plan()
        self._validate_actions()

    def invoke(self, initial_state: Mapping[str, Any]) -> RuntimeState:
        return self.invoke_with_trace(initial_state)[0]

    async def ainvoke(self, initial_state: Mapping[str, Any]) -> RuntimeState:
        return (await self.ainvoke_with_trace(initial_state))[0]

    async def abatch(
        self,
        inputs: Sequence[Mapping[str, Any]],
        *,
        max_concurrency: int | None = None,
    ) -> list[RuntimeState]:
        return await map_ordered_async(
            self.ainvoke, inputs, max_concurrency=max_concurrency
        )

    def invoke_with_trace(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str]]:
        state, trace, _events = self.invoke_with_events(
            initial_state, trace_key=trace_key
        )
        return state, trace

    def invoke_with_events(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        context = GraphRunContext.from_initial(self, initial_state)
        return self._run_context(context, trace_key=trace_key)

    async def ainvoke_with_trace(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str]]:
        state, trace, _events = await self.ainvoke_with_events(
            initial_state, trace_key=trace_key
        )
        return state, trace

    async def ainvoke_with_events(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        context = GraphRunContext.from_initial(self, initial_state)
        return await self._arun_context(context, trace_key=trace_key)

    async def _ainvoke_owned_with_events(
        self,
        initial_state: RuntimeState,
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        """Consume a fresh state through the single-use ownership path.

        The caller transfers ownership and must not observe or reuse
        ``initial_state`` after this call. Public callers must use
        ``ainvoke_with_events`` so their input remains defensively isolated.
        """
        context = GraphRunContext.from_owned(self, initial_state)
        return await self._arun_context(context, trace_key=trace_key)

    def resume_interrupted(
        self,
        interrupted: RuntimeGraphInterrupted,
        resume_result: RuntimeActionResult = None,
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        context = GraphRunContext.from_interrupted(interrupted)
        record_trace(context.state, trace_key, context.trace)
        outcome = normalize_action_result(resume_result)
        for _event in self._finish_node(context, interrupted.node, outcome, event_kind="resume"):
            pass
        return self._run_context(context, trace_key=trace_key)

    async def aresume_interrupted(
        self,
        interrupted: RuntimeGraphInterrupted,
        resume_result: RuntimeActionResult = None,
        *,
        trace_key: str | None = None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        context = GraphRunContext.from_interrupted(interrupted)
        record_trace(context.state, trace_key, context.trace)
        if inspect.isawaitable(resume_result):
            resume_result = await resume_result
        outcome = normalize_action_result(resume_result)
        await self._afinish_node(context, interrupted.node, outcome, event_kind="resume")
        return await self._arun_context(context, trace_key=trace_key)

    def stream(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_mode: str | Sequence[str] = "values",
        trace_key: str | None = None,
    ) -> Iterator[Any]:
        modes = validated_stream_modes(stream_mode)
        multi_mode = not isinstance(stream_mode, str)
        context = GraphRunContext.from_initial(self, initial_state)
        publisher = StreamPublisher(self, modes, multi_mode, context)
        yield from self._stream_context(context, publisher, trace_key=trace_key)

    def stream_events(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> Iterator[RuntimeGraphEvent]:
        context = GraphRunContext.from_initial(self, initial_state)
        yield from self._stream_events_context(context, trace_key=trace_key)

    async def astream(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_mode: str | Sequence[str] = "values",
        trace_key: str | None = None,
    ):
        modes = validated_stream_modes(stream_mode)
        multi_mode = not isinstance(stream_mode, str)
        context = GraphRunContext.from_initial(self, initial_state)
        publisher = StreamPublisher(self, modes, multi_mode, context)
        async for chunk in self._astream_context(
            context, publisher, trace_key=trace_key
        ):
            yield chunk

    async def astream_events(
        self,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ):
        context = GraphRunContext.from_initial(self, initial_state)
        for event in await self._arun_events_context(context, trace_key=trace_key):
            yield event

    def stream_projection(
        self,
        initial_state: Mapping[str, Any],
        *,
        stream_modes: str | Sequence[str] | None = None,
        trace_key: str | None = None,
    ) -> RuntimeGraphStreamProjection:
        modes = normalize_stream_modes(stream_modes)
        return RuntimeGraphStreamProjection.from_chunks(
            self.stream(initial_state, stream_mode=modes, trace_key=trace_key)
        )

    def _run_context(
        self,
        context: "GraphRunContext",
        *,
        trace_key: str | None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        for _event in self._stream_events_context(context, trace_key=trace_key):
            pass
        return context.state, context.trace, context.events

    async def _arun_context(
        self,
        context: "GraphRunContext",
        *,
        trace_key: str | None,
    ) -> tuple[RuntimeState, list[str], list[RuntimeGraphEvent]]:
        await self._arun_events_context(context, trace_key=trace_key)
        return context.state, context.trace, context.events

    async def _arun_events_context(
        self,
        context: "GraphRunContext",
        *,
        trace_key: str | None,
    ) -> list[RuntimeGraphEvent]:
        context.publish("start", None, 0, {"pending": tuple(context.pending)})
        while context.pending:
            await self._aexecute_next_event_step(context, trace_key=trace_key)
        record_trace(context.state, trace_key, context.trace)
        context.publish(
            "complete",
            None,
            context.step,
            {"state": dict(context.state), "trace": tuple(context.trace)},
        )
        return context.events

    def _stream_events_context(
        self,
        context: "GraphRunContext",
        *,
        trace_key: str | None,
    ) -> Iterator[RuntimeGraphEvent]:
        yield context.publish("start", None, 0, {"pending": tuple(context.pending)})
        while context.pending:
            event = self._execute_next_event_step(context, trace_key=trace_key)
            yield from event
        record_trace(context.state, trace_key, context.trace)
        yield context.publish(
            "complete",
            None,
            context.step,
            {"state": dict(context.state), "trace": tuple(context.trace)},
        )

    def _stream_context(
        self,
        context: "GraphRunContext",
        publisher: "StreamPublisher",
        *,
        trace_key: str | None,
    ) -> Iterator[Any]:
        yield from publisher.events(context.publish("start", None, 0, {"pending": tuple(context.pending)}))
        while context.pending:
            yield from self._execute_next_stream_step(
                context, publisher, trace_key=trace_key
            )
        record_trace(context.state, trace_key, context.trace)
        complete = context.publish(
            "complete",
            None,
            context.step,
            {"state": dict(context.state), "trace": tuple(context.trace)},
        )
        yield from publisher.events(complete)

    async def _astream_context(
        self,
        context: "GraphRunContext",
        publisher: "StreamPublisher",
        *,
        trace_key: str | None,
    ):
        for chunk in publisher.events(
            context.publish("start", None, 0, {"pending": tuple(context.pending)})
        ):
            yield chunk
        while context.pending:
            for chunk in await self._aexecute_next_stream_step(
                context, publisher, trace_key=trace_key
            ):
                yield chunk
        record_trace(context.state, trace_key, context.trace)
        complete = context.publish(
            "complete",
            None,
            context.step,
            {"state": dict(context.state), "trace": tuple(context.trace)},
        )
        for chunk in publisher.events(complete):
            yield chunk

    def _execute_next_event_step(
        self, context: "GraphRunContext", *, trace_key: str | None
    ) -> Iterator[RuntimeGraphEvent]:
        node, branch_update = context.next_node()
        if node == END:
            return
        outcome = self._start_and_run_node(
            context, node, branch_update, trace_key=trace_key
        )
        for event in self._finish_node(context, node, outcome, event_kind="node-end"):
            yield event

    async def _aexecute_next_event_step(
        self, context: "GraphRunContext", *, trace_key: str | None
    ) -> None:
        node, branch_update = context.next_node()
        if node == END:
            return
        outcome = await self._astart_and_run_node(
            context, node, branch_update, trace_key=trace_key
        )
        await self._afinish_node(context, node, outcome, event_kind="node-end")

    def _execute_next_stream_step(
        self,
        context: "GraphRunContext",
        publisher: "StreamPublisher",
        *,
        trace_key: str | None,
    ) -> Iterator[Any]:
        node, branch_update = context.next_node()
        if node == END:
            return
        yield from publisher.tasks(node, context.step + 1, "start")
        start_len = len(publisher.custom_values)
        outcome = self._start_and_run_node(
            context, node, branch_update, trace_key=trace_key
        )
        yield from publisher.events(context.events[-1])
        for event in self._finish_node(context, node, outcome, event_kind="node-end"):
            yield from publisher.events(event)
        yield from publisher.tasks(node, context.step, "finish")
        yield from publisher.node_outputs(node, context, outcome.update, start_len)

    async def _aexecute_next_stream_step(
        self,
        context: "GraphRunContext",
        publisher: "StreamPublisher",
        *,
        trace_key: str | None,
    ) -> list[Any]:
        chunks: list[Any] = []
        node, branch_update = context.next_node()
        if node == END:
            return chunks
        chunks.extend(publisher.tasks(node, context.step + 1, "start"))
        start_len = len(publisher.custom_values)
        outcome = await self._astart_and_run_node(
            context, node, branch_update, trace_key=trace_key
        )
        chunks.extend(publisher.events(context.events[-1]))
        event = await self._afinish_node(
            context, node, outcome, event_kind="node-end"
        )
        chunks.extend(publisher.events(event))
        chunks.extend(publisher.tasks(node, context.step, "finish"))
        chunks.extend(publisher.node_outputs(node, context, outcome.update, start_len))
        return chunks

    def _start_and_run_node(
        self,
        context: "GraphRunContext",
        node: str,
        branch_update: Mapping[str, Any] | None,
        *,
        trace_key: str | None,
    ) -> NormalizedActionResult:
        context.advance_step(self.plan.step_limit)
        context.trace.append(node)
        record_trace(context.state, trace_key, context.trace)
        action_state = with_branch_update(context.state, branch_update)
        context.publish(
            "node-start",
            node,
            context.step,
            {
                "branch-update-keys": tuple((branch_update or {}).keys()),
                "trace": tuple(context.trace),
            },
        )
        outcome = normalize_action_result(self.actions[node](dict(action_state)))
        if outcome.interrupt is not None:
            self._raise_interrupted(context, node, outcome.interrupt)
        return outcome

    async def _astart_and_run_node(
        self,
        context: "GraphRunContext",
        node: str,
        branch_update: Mapping[str, Any] | None,
        *,
        trace_key: str | None,
    ) -> NormalizedActionResult:
        context.advance_step(self.plan.step_limit)
        context.trace.append(node)
        record_trace(context.state, trace_key, context.trace)
        action_state = with_branch_update(context.state, branch_update)
        context.publish(
            "node-start",
            node,
            context.step,
            {
                "branch-update-keys": tuple((branch_update or {}).keys()),
                "trace": tuple(context.trace),
            },
        )
        result = self.actions[node](action_state)
        if inspect.isawaitable(result):
            result = await result
        outcome = normalize_action_result(result)
        if outcome.interrupt is not None:
            self._raise_interrupted(context, node, outcome.interrupt)
        return outcome

    def _finish_node(
        self,
        context: "GraphRunContext",
        node: str,
        outcome: NormalizedActionResult,
        *,
        event_kind: str,
    ) -> Iterator[RuntimeGraphEvent]:
        if outcome.update is not None:
            context.state = merge_state(context.state, outcome.update, self.reducers)
        context.pending.extend(self._next_targets(node, context.state, outcome))
        yield context.publish(
            event_kind,
            node,
            context.step,
            {
                "command-controls-flow": outcome.controls_flow,
                "goto": outcome.goto,
                "send-targets": tuple(send.target for send in outcome.sends),
                "update-keys": tuple((outcome.update or {}).keys()),
            },
        )

    async def _afinish_node(
        self,
        context: "GraphRunContext",
        node: str,
        outcome: NormalizedActionResult,
        *,
        event_kind: str,
    ) -> RuntimeGraphEvent:
        if outcome.update is not None:
            context.state = merge_state(context.state, outcome.update, self.reducers)
        context.pending.extend(await self._anext_targets(node, context.state, outcome))
        return context.publish(
            event_kind,
            node,
            context.step,
            {
                "command-controls-flow": outcome.controls_flow,
                "goto": outcome.goto,
                "send-targets": tuple(send.target for send in outcome.sends),
                "update-keys": tuple((outcome.update or {}).keys()),
            },
        )

    def _next_targets(
        self,
        node: str,
        state: Mapping[str, Any],
        outcome: NormalizedActionResult,
    ) -> list[str | RuntimeGraphSend]:
        if outcome.controls_flow:
            if self._semantic_graph is not None:
                self._semantic_graph.targets(node, 'control',
                    targets=[*outcome.goto, *[send.target for send in outcome.sends]])
            return [*outcome.goto, *outcome.sends]
        return [*self._edges[node], *self._conditional_targets(node, state)]

    async def _anext_targets(
        self,
        node: str,
        state: Mapping[str, Any],
        outcome: NormalizedActionResult,
    ) -> list[str | RuntimeGraphSend]:
        if outcome.controls_flow:
            if self._semantic_graph is not None:
                await self._semantic_graph.atargets(node, 'control',
                    targets=[*outcome.goto, *[send.target for send in outcome.sends]])
            return [*outcome.goto, *outcome.sends]
        return [*self._edges[node], *await self._aconditional_targets(node, state)]

    def _conditional_targets(
        self, node: str, state: Mapping[str, Any]
    ) -> list[str | RuntimeGraphSend]:
        targets: list[str | RuntimeGraphSend] = []
        for edge in self._conditional_edges[node]:
            router = self.routers.get(edge.router)
            if router is None:
                raise RuntimeGraphError(f"missing runtime graph router: {edge.router}")
            route = router(state)
            targets.extend(self._resolve_conditional_route(edge.router, edge.routes, route, node=node))
        return targets

    async def _aconditional_targets(
        self, node: str, state: Mapping[str, Any]
    ) -> list[str | RuntimeGraphSend]:
        targets: list[str | RuntimeGraphSend] = []
        for edge in self._conditional_edges[node]:
            router = self.routers.get(edge.router)
            if router is None:
                raise RuntimeGraphError(f"missing runtime graph router: {edge.router}")
            route = router(state)
            if inspect.isawaitable(route):
                route = await route
            if self._semantic_graph is not None:
                if isinstance(route, RuntimeGraphSend) or _is_send_sequence(route):
                    sends = [route] if isinstance(route, RuntimeGraphSend) else list(route)
                    await self._semantic_graph.atargets(node, 'control', targets=[send.target for send in sends])
                    targets.extend(sends)
                else:
                    labels = list(route) if _is_route_sequence(route) else [route]
                    targets.extend(await self._semantic_graph.atargets(node, 'route', router=edge.router, labels=labels))
            else:
                targets.extend(self._resolve_conditional_route(edge.router, edge.routes, route, node=node))
        return targets

    def _resolve_conditional_route(
        self,
        router_name: str,
        routes: Mapping[str, str],
        route: Any,
        *, node: str | None = None,
    ) -> list[str | RuntimeGraphSend]:
        if self._semantic_graph is not None:
            if isinstance(route, RuntimeGraphSend) or _is_send_sequence(route):
                sends = [route] if isinstance(route, RuntimeGraphSend) else list(route)
                self._semantic_graph.targets(node, 'control', targets=[send.target for send in sends])
                return sends
            labels = list(route) if _is_route_sequence(route) else [route]
            return self._semantic_graph.targets(node, 'route', router=router_name, labels=labels)
        if isinstance(route, RuntimeGraphSend):
            self._validate_runtime_target(route.target)
            return [route]
        if _is_send_sequence(route):
            for send in route:
                self._validate_runtime_target(send.target)
            return list(route)
        if _is_route_sequence(route):
            return [
                self._resolve_route_name(router_name, routes, route_name)
                for route_name in route
            ]
        if isinstance(route, str):
            return [self._resolve_route_name(router_name, routes, route)]
        raise RuntimeGraphError(
            f"router {router_name} returned unsupported route: {route!r}"
        )

    def _resolve_route_name(
        self,
        router_name: str,
        routes: Mapping[str, str],
        route_name: str,
    ) -> str:
        if routes:
            try:
                target = routes[route_name]
            except KeyError as exc:
                raise RuntimeGraphError(
                    f"router {router_name} returned unknown route: {route_name}"
                ) from exc
        else:
            target = route_name
        self._validate_runtime_target(target)
        return target

    def _validate_runtime_target(self, target: str) -> None:
        check_endpoint(target, set(self.plan.nodes))

    def _raise_interrupted(
        self,
        context: "GraphRunContext",
        node: str,
        interrupt: RuntimeGraphInterrupt,
    ) -> None:
        context.publish(
            "interrupt",
            node,
            context.step,
            {
                "value": interrupt.value,
                "resumable": interrupt.resumable,
                "trace": tuple(context.trace),
            },
        )
        raise RuntimeGraphInterrupted(
            interrupt,
            node=node,
            step=context.step,
            state=context.state,
            trace=context.trace,
            pending=tuple(context.pending),
            events=tuple(context.events),
        )

    def _validate_plan(self) -> None:
        node_set = set(self.plan.nodes)
        for edge in self.plan.edges:
            check_endpoint(edge.source, node_set)
            check_endpoint(edge.target, node_set)
        for edge in self.plan.conditional_edges:
            check_endpoint(edge.source, node_set)
            for target in edge.routes.values():
                check_endpoint(target, node_set)

    def _validate_actions(self) -> None:
        missing = sorted(set(self.plan.nodes) - set(self.actions))
        if missing:
            raise RuntimeGraphError(
                "missing runtime graph actions for nodes: " + ", ".join(missing)
            )


def _is_send_sequence(value: Any) -> bool:
    if not isinstance(value, Sequence):
        return False
    if isinstance(value, (str, bytes, bytearray)):
        return False
    return all(isinstance(item, RuntimeGraphSend) for item in value)


def _is_route_sequence(value: Any) -> bool:
    if not isinstance(value, Sequence):
        return False
    if isinstance(value, (str, bytes, bytearray)):
        return False
    return all(isinstance(item, str) for item in value)


__all__ = [
    "RuntimeGraphExecutor",
    "bind_runtime_action",
    "linear_plan",
]
