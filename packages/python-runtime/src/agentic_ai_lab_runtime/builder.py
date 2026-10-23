# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any, Mapping

from .materialization import RuntimeGraphBindings
from .program import RuntimeGraphProgram, RuntimeGraphRegistries
from .runtime import RuntimeGraphRuntime
from .runtime_graph import (
    END,
    START,
    RuntimeAction,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeReducer,
    RuntimeRouter,
)


@dataclass
class RuntimeGraphBuilder:
    nodes: dict[str, RuntimeAction] = field(default_factory=dict)
    edges: list[RuntimeGraphEdge] = field(default_factory=list)
    conditional_edges: list[RuntimeGraphConditionalEdge] = field(default_factory=list)
    routers: dict[str, RuntimeRouter] = field(default_factory=dict)
    reducers: dict[str, RuntimeReducer] = field(default_factory=dict)
    metadata: dict[str, object] = field(default_factory=dict)
    step_limit: int = 100

    def add_node(self, name: str, action: RuntimeAction) -> RuntimeGraphBuilder:
        self.nodes[name] = action
        return self

    def add_sequence(
        self,
        nodes: Mapping[str, RuntimeAction] | Sequence[tuple[str, RuntimeAction]],
    ) -> RuntimeGraphBuilder:
        items = tuple(nodes.items() if isinstance(nodes, Mapping) else nodes)
        if not items:
            raise RuntimeGraphError("runtime graph sequence cannot be empty")
        previous: str | None = None
        for name, action in items:
            self.add_node(name, action)
            if previous is not None:
                self.add_edge(previous, name)
            previous = name
        return self

    def add_edge(self, source: str, target: str) -> RuntimeGraphBuilder:
        self.edges.append(RuntimeGraphEdge(source, target))
        return self

    def set_entry_point(self, name: str) -> RuntimeGraphBuilder:
        return self.add_edge(START, name)

    def set_finish_point(self, name: str) -> RuntimeGraphBuilder:
        return self.add_edge(name, END)

    def add_conditional_edges(
        self,
        source: str,
        router: str | RuntimeRouter,
        routes: Mapping[str, str] | None = None,
        *,
        name: str | None = None,
    ) -> RuntimeGraphBuilder:
        if isinstance(router, str):
            router_name = router
        else:
            router_name = name or f"{source}:router:{len(self.conditional_edges)}"
            self.routers[router_name] = router
        self.conditional_edges.append(
            RuntimeGraphConditionalEdge(source, router_name, dict(routes or {}))
        )
        return self

    def add_reducer(
        self,
        state_key: str,
        reducer: RuntimeReducer,
    ) -> RuntimeGraphBuilder:
        self.reducers[state_key] = reducer
        return self

    def compile(
        self,
        *,
        runtime: RuntimeGraphRuntime | None = None,
        thread_id: str | None = None,
        store: Any = None,
        checkpointer: Any = None,
        metadata: Mapping[str, Any] | None = None,
    ) -> RuntimeGraphExecutor:
        selected = _runtime_from_compile_options(runtime, thread_id=thread_id,
            store=store, checkpointer=checkpointer, metadata=metadata, default_backend='reference')
        semantic_graph = None
        if selected.backend == 'native':
            from .semantic_runtime import SemanticRuntime
            if not isinstance(selected.semantic_context, SemanticRuntime):
                raise RuntimeGraphError('native builder requires a qualified semantic context')
            semantic_graph = selected.semantic_context.bind_graph(self.plan(), RuntimeGraphBindings(
                node_actions={node: node for node in self.nodes},
                state_reducers={key: key for key in self.reducers}))
        return RuntimeGraphExecutor(
            self.plan(),
            self.nodes,
            routers=self.routers,
            reducers=self.reducers,
            runtime=selected,
            semantic_graph=semantic_graph,
        )

    def compile_program(
        self,
        *,
        runtime: RuntimeGraphRuntime | None = None,
        thread_id: str | None = None,
        store: Any = None,
        checkpointer: Any = None,
        metadata: Mapping[str, Any] | None = None,
    ) -> RuntimeGraphProgram:
        return RuntimeGraphProgram(
            plan=self.plan(),
            graph_bindings=RuntimeGraphBindings(
                node_actions={node: node for node in self.nodes},
                state_reducers={key: key for key in self.reducers},
            ),
            registries=RuntimeGraphRegistries(
                actions=dict(self.nodes),
                routers=dict(self.routers),
                reducers=dict(self.reducers),
            ),
            runtime=_runtime_from_compile_options(
                runtime,
                thread_id=thread_id,
                store=store,
                checkpointer=checkpointer,
                metadata=metadata,
            ),
        )

    def compile_reference_program(self) -> RuntimeGraphProgram:
        return self.compile_program(runtime=RuntimeGraphRuntime.reference())

    def plan(self) -> RuntimeGraphPlan:
        return RuntimeGraphPlan(
            nodes=tuple(self.nodes),
            edges=tuple(self.edges),
            conditional_edges=tuple(self.conditional_edges),
            step_limit=self.step_limit,
            metadata=dict(self.metadata),
        )


def _runtime_from_compile_options(
    runtime: RuntimeGraphRuntime | None,
    *,
    thread_id: str | None,
    store: Any,
    checkpointer: Any,
    metadata: Mapping[str, Any] | None,
    default_backend: str = 'native',
) -> RuntimeGraphRuntime | None:
    if runtime is None:
        if thread_id is None and store is None and checkpointer is None and metadata is None:
            return RuntimeGraphRuntime(backend=default_backend)
        return RuntimeGraphRuntime(
            backend=default_backend,
            thread_id=thread_id,
            store=store,
            checkpointer=checkpointer,
            metadata=dict(metadata or {}),
        )
    if thread_id is None and store is None and checkpointer is None and metadata is None:
        return runtime
    return RuntimeGraphRuntime(
        thread_id=thread_id if thread_id is not None else runtime.thread_id,
        store=store if store is not None else runtime.store,
        checkpointer=checkpointer if checkpointer is not None else runtime.checkpointer,
        metadata={**dict(runtime.metadata), **dict(metadata or {})},
        backend=runtime.backend,
        native_context=runtime.native_context,
        semantic_context=runtime.semantic_context,
    )
