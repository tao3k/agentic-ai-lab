# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Pure runtime-graph domain description, independent of the retired C ABI."""

from __future__ import annotations

from dataclasses import dataclass, field
from hashlib import sha256
from typing import Mapping

from .runtime_graph import RuntimeGraphPlan


@dataclass(frozen=True)
class RuntimeGraphBindings:
    """Runtime action and reducer symbols for a typed graph plan."""

    node_actions: Mapping[str, str] = field(default_factory=dict)
    state_reducers: Mapping[str, str] = field(default_factory=dict)

    def action_for(self, node: str) -> str:
        return self.node_actions.get(node, node)


def describe_runtime_graph_plan(
    plan: RuntimeGraphPlan,
    graph_bindings: RuntimeGraphBindings | None = None,
) -> bytes:
    """Return a deterministic domain receipt without crossing a runtime ABI."""

    bindings = graph_bindings or RuntimeGraphBindings()
    _validate_graph_bindings(plan, bindings)
    canonical = repr(
        (
            tuple(plan.nodes),
            tuple((edge.source, edge.target) for edge in plan.edges),
            tuple(
                (edge.source, edge.router, tuple(sorted(edge.routes.items())))
                for edge in plan.conditional_edges
            ),
            plan.step_limit,
            tuple(sorted(bindings.node_actions.items())),
            tuple(sorted(bindings.state_reducers.items())),
        )
    ).encode("utf-8")
    digest = sha256(canonical).hexdigest()[:16]
    lines = (
        "agentic-ai-lab-receipt.v1",
        "kind=runtime-graph-domain-validation",
        f"nodes={len(plan.nodes)}",
        f"node-actions={len(plan.nodes)}",
        f"state-reducers={len(bindings.state_reducers)}",
        f"edges={len(plan.edges)}",
        f"conditional-routes={sum(len(edge.routes) for edge in plan.conditional_edges)}",
        f"step-limit={plan.step_limit}",
        f"plan-digest={digest}",
    )
    return ("\n".join(lines) + "\n").encode("utf-8")


def _validate_graph_bindings(
    plan: RuntimeGraphPlan,
    graph_bindings: RuntimeGraphBindings,
) -> None:
    nodes = set(plan.nodes)
    extra_actions = sorted(
        node for node in graph_bindings.node_actions if node not in nodes
    )
    if extra_actions:
        raise ValueError(
            "node action bindings reference unknown nodes: "
            + ", ".join(extra_actions)
        )
