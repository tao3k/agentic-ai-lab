# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pure C4 disjoint frontier scheduler, Tarjan SCC condensation, and Scheme handoff coercers."""

from __future__ import annotations

from collections.abc import Iterable, Mapping, Sequence
from typing import Any

from ._graph_engine_topology_types import (
    ApexConvergenceReceipt,
    CyclicSccCondensation,
    CyclicSccSpec,
    FunflowFrontierPlan,
    FunflowTaskSpec,
    FunflowWaveSpec,
    GraphCedarHandoff,
    GraphEngineError,
    JournalHandoffIntent,
    field_get,
)


def plan_disjoint_frontier(tasks: Sequence[FunflowTaskSpec]) -> FunflowFrontierPlan:
    """Schedule C4 pairwise-disjoint parallel waves (`0 subagents, 0 LLM`)."""
    by_id: dict[str, FunflowTaskSpec] = {}
    for task in tasks:
        if task.task_id in by_id:
            raise GraphEngineError(f"duplicate task_id in frontier: {task.task_id!r}")
        by_id[task.task_id] = task

    for task in tasks:
        for dep in task.depends_on:
            if dep not in by_id:
                raise GraphEngineError(
                    f"task {task.task_id!r} depends on missing task {dep!r}"
                )

    remaining = dict(by_id)
    completed: set[str] = set()
    waves: list[FunflowWaveSpec] = []

    while remaining:
        ready = sorted(
            (t for t in remaining.values() if all(d in completed for d in t.depends_on)),
            key=lambda t: (t.c4_priority, t.task_id),
        )
        if not ready:
            raise GraphEngineError(
                "cycle detected in FunFlow DAG frontier; use condense_graph_sccs for cyclic subgraphs"
            )

        wave_tasks: list[FunflowTaskSpec] = []
        for candidate in ready:
            if all(not candidate.conflicts_with(chosen) for chosen in wave_tasks):
                wave_tasks.append(candidate)

        wave_ids = tuple(t.task_id for t in wave_tasks)
        waves.append(
            FunflowWaveSpec(
                wave_index=len(waves),
                task_ids=wave_ids,
                parallel=len(wave_ids) > 1,
            )
        )
        for tid in wave_ids:
            completed.add(tid)
            del remaining[tid]

    max_width = max((len(w.task_ids) for w in waves), default=0)
    return FunflowFrontierPlan(
        waves=tuple(waves),
        max_wave_width=max_width,
        total_tasks=len(tasks),
    )


def condense_graph_sccs(
    nodes: Sequence[str],
    edges: Iterable[tuple[str, str]],
) -> CyclicSccCondensation:
    """Exact Tarjan SCC condensation unifying acyclic DAGs and cyclic feedback loops."""
    node_set = set(nodes)
    adj: dict[str, list[str]] = {n: [] for n in nodes}
    self_loops: set[str] = set()
    for src, dst in edges:
        if src not in node_set or dst not in node_set:
            raise GraphEngineError(f"edge ({src!r} -> {dst!r}) references unknown node")
        adj[src].append(dst)
        if src == dst:
            self_loops.add(src)

    index_counter = 0
    indices: dict[str, int] = {}
    lowlink: dict[str, int] = {}
    stack: list[str] = []
    on_stack: set[str] = set()
    raw_components: list[tuple[str, ...]] = []

    def strongconnect(v: str) -> None:
        nonlocal index_counter
        indices[v] = index_counter
        lowlink[v] = index_counter
        index_counter += 1
        stack.append(v)
        on_stack.add(v)

        for w in adj[v]:
            if w not in indices:
                strongconnect(w)
                lowlink[v] = min(lowlink[v], lowlink[w])
            elif w in on_stack:
                lowlink[v] = min(lowlink[v], indices[w])

        if lowlink[v] == indices[v]:
            comp: list[str] = []
            while True:
                w = stack.pop()
                on_stack.remove(w)
                comp.append(w)
                if w == v:
                    break
            raw_components.append(tuple(sorted(comp)))

    for n in nodes:
        if n not in indices:
            strongconnect(n)

    ordered = list(reversed(raw_components))
    specs = tuple(
        CyclicSccSpec(
            scc_id=f"scc-{idx}",
            node_ids=comp,
            cyclic=(len(comp) > 1) or (comp[0] in self_loops),
        )
        for idx, comp in enumerate(ordered)
    )
    return CyclicSccCondensation(
        sccs=specs,
        topological_scc_order=tuple(spec.scc_id for spec in specs),
        has_cycles=any(spec.cyclic for spec in specs),
    )


def coerce_apex_convergence_receipt(
    data: ApexConvergenceReceipt | Mapping[str, Any],
) -> ApexConvergenceReceipt:
    if isinstance(data, ApexConvergenceReceipt):
        return data
    return ApexConvergenceReceipt(
        trunk_id=str(field_get(data, "trunk_id", "trunk-id")),
        apex_obligation_id=str(field_get(data, "apex_obligation_id", "apex-obligation-id")),
        shared_context_cut=int(field_get(data, "shared_context_cut", "shared-context-cut", default=1)),
        kv_prefix_digest=str(field_get(data, "kv_prefix_digest", "kv-prefix-digest", default="")),
        absorbed_branch_ids=tuple(
            str(b)
            for b in field_get(
                data,
                "absorbed_branch_ids",
                "absorbed-branch-ids-c4-order",
                "absorbed-branch-ids",
                default=(),
            )
        ),
        total_llm_calls=int(field_get(data, "total_llm_calls", "total-llm-calls", default=0)),
        total_det_tasks=int(field_get(data, "total_det_tasks", "total-det-tasks", default=0)),
        receipt_digest=str(field_get(data, "receipt_digest", "receipt-digest", default="")),
    )


def coerce_journal_handoff_intent(
    data: JournalHandoffIntent | Mapping[str, Any],
) -> JournalHandoffIntent:
    if isinstance(data, JournalHandoffIntent):
        return data
    return JournalHandoffIntent(
        trunk_id=str(field_get(data, "trunk_id", "trunk-id")),
        journal_epoch=int(field_get(data, "journal_epoch", "journal-epoch", default=1)),
        event_kind=str(field_get(data, "event_kind", "event-kind", default="checkpoint")),
        payload_digest=str(field_get(data, "payload_digest", "payload-digest", default="")),
        snapshot=dict(field_get(data, "snapshot", default={}) or {}),
        runtime_executed=bool(field_get(data, "runtime_executed", "runtime-executed?", default=False)),
    )


def coerce_cedar_handoff(
    data: GraphCedarHandoff | Mapping[str, Any],
) -> GraphCedarHandoff:
    if isinstance(data, GraphCedarHandoff):
        return data
    return GraphCedarHandoff(
        policy_id=str(field_get(data, "policy_id", "policy-id")),
        trunk_id=str(field_get(data, "trunk_id", "trunk-id")),
        bound_cut=int(field_get(data, "bound_cut", "bound-cut", default=1)),
        grant_epoch=int(field_get(data, "grant_epoch", "grant-epoch", default=1)),
        policy_valid=bool(field_get(data, "policy_valid", "policy-valid?", default=True)),
        runtime_executed=bool(field_get(data, "runtime_executed", "runtime-executed?", default=False)),
    )
