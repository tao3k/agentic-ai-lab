# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Session-free `TaskActor`, C4 Steering, Index, and Workbench Tab data types."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any, Literal

from ._graph_engine_topology_types import (
    BranchKind,
    CapabilityEnvelope,
    GraphEngineError,
    field_get,
)

ActorKind = Literal["convergent-task", "open-focus"]
ScopeMode = Literal["project", "detached"]
TaskActorStatus = Literal["active", "parked", "settled"]
SteeringTarget = Literal["trunk", "branch"]
BranchJoinStatus = Literal["in-flight", "completed", "failed", "defeated", "cancelled", "superseded"]
SettlementOutcome = Literal["converged", "cancelled", "failed", "denied", "parked"]
WorkbenchTabMode = Literal[
    "pinned",
    "active",
    "peek-readonly",
    "archived-pending-blur",
]

VALID_SETTLEMENT_OUTCOMES: frozenset[str] = frozenset(
    {"converged", "cancelled", "failed", "denied", "parked"}
)


@dataclass(frozen=True, slots=True)
class SteeringMessage:
    """C4 mid-flight steering message targeting either the Main Trunk or a derived Branch."""

    message_id: str
    target: SteeringTarget
    payload: str
    c4_priority: int = 1
    anchor_node_id: str | None = None
    join_node_id: str | None = None
    branch_id: str | None = None
    branch_kind: BranchKind = "subordinate-task"
    required_for_join: bool = True
    supersede_stale_branches: bool = True
    schema: str = "agentic-ai-lab.graph-engine.steering-message.v1"


@dataclass(frozen=True, slots=True)
class BranchJoinRecord:
    """Tracks a derived branch anchored at `anchor_node_id` that must re-converge at `join_node_id`."""

    branch_id: str
    anchor_node_id: str
    join_node_id: str
    c4_priority: int = 1
    required_for_join: bool = True
    status: BranchJoinStatus = "in-flight"


@dataclass(frozen=True, slots=True)
class TrunkJoinGateResult:
    can_continue: bool
    reason: str
    join_node_id: str
    blocking_branch_ids: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class TaskActor:
    """Session-free lightweight task over governed structural Context."""

    task_id: str
    scope_ids: tuple[str, ...]
    capability_envelope: CapabilityEnvelope
    trunk_id: str | None = None
    apex_obligation_id: str | None = None
    shared_context_cut: int = 1
    kv_prefix_digest: str = "sha256:detached-isolated-prefix"
    actor_kind: ActorKind = "convergent-task"
    scope_mode: ScopeMode = "project"
    title: str = ""
    worktree: str = "main"
    headless: bool = False
    fencing_epoch: int = 1
    status: TaskActorStatus = "active"
    steering_log: tuple[SteeringMessage, ...] = ()
    branch_joins: tuple[BranchJoinRecord, ...] = ()
    session_free: Literal[True] = True
    llm_sessions_spawned: Literal[0] = 0
    schema: str = "agentic-ai-lab.graph-engine.task-actor.v1"

    def __post_init__(self) -> None:
        if not self.task_id:
            raise GraphEngineError("TaskActor.task_id must be non-empty")
        if not self.scope_ids:
            raise GraphEngineError("TaskActor.scope_ids must name at least one governance scope")
        if self.actor_kind == "convergent-task" and (not self.trunk_id or not self.apex_obligation_id):
            raise GraphEngineError("convergent-task TaskActor requires trunk_id and apex_obligation_id")
        if not self.title:
            object.__setattr__(self, "title", self.task_id)


@dataclass(frozen=True, slots=True)
class TaskActorScopeDecision:
    admitted: bool
    reason: str
    task_id: str
    target_scope: str
    required_cap: str
    scope_mode: ScopeMode = "project"
    session_free: Literal[True] = True


@dataclass(frozen=True, slots=True)
class TaskActorIndexEntry:
    """Settled immutable task record stored in `TaskActorIndexStore` and queryable by `task_id`."""

    task_id: str
    title: str
    worktree: str
    actor_kind: ActorKind
    scope_mode: ScopeMode
    scope_ids: tuple[str, ...]
    fencing_epoch: int
    trunk_id: str | None
    apex_obligation_id: str | None
    shared_context_cut: int
    kv_prefix_digest: str
    receipt_digest: str | None = None
    absorbed_branch_ids: tuple[str, ...] = ()
    total_llm_calls: int = 0
    total_det_tasks: int = 0
    outcome: SettlementOutcome = "converged"
    reason_note: str = ""
    status: str = "done"
    archived: bool = True
    queryable_by_id: bool = True
    detached_ephemeral: bool = False
    session_free: Literal[True] = True
    schema: str = "agentic-ai-lab.graph-engine.task-actor-index-entry.v1"

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema": self.schema,
            "task_id": self.task_id,
            "title": self.title,
            "worktree": self.worktree,
            "actor_kind": self.actor_kind,
            "scope_mode": self.scope_mode,
            "scope_ids": list(self.scope_ids),
            "fencing_epoch": self.fencing_epoch,
            "trunk_id": self.trunk_id,
            "apex_obligation_id": self.apex_obligation_id,
            "shared_context_cut": self.shared_context_cut,
            "kv_prefix_digest": self.kv_prefix_digest,
            "receipt_digest": self.receipt_digest,
            "absorbed_branch_ids": list(self.absorbed_branch_ids),
            "total_llm_calls": self.total_llm_calls,
            "total_det_tasks": self.total_det_tasks,
            "outcome": self.outcome,
            "reason_note": self.reason_note,
            "status": self.status,
            "archived": self.archived,
            "queryable_by_id": self.queryable_by_id,
            "detached_ephemeral": self.detached_ephemeral,
            "session_free": True,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "TaskActorIndexEntry":
        return cls(
            task_id=str(field_get(data, "task_id", "task-id")),
            title=str(field_get(data, "title", default="")),
            worktree=str(field_get(data, "worktree", default="main")),
            actor_kind=field_get(data, "actor_kind", "actor-kind", default="convergent-task"),
            scope_mode=field_get(data, "scope_mode", "scope-mode", default="project"),
            scope_ids=tuple(str(s) for s in field_get(data, "scope_ids", "scope-ids", default=())),
            fencing_epoch=int(field_get(data, "fencing_epoch", "fencing-epoch", default=1)),
            trunk_id=field_get(data, "trunk_id", "trunk-id", default=None),
            apex_obligation_id=field_get(data, "apex_obligation_id", "apex-obligation-id", default=None),
            shared_context_cut=int(field_get(data, "shared_context_cut", "shared-context-cut", default=1)),
            kv_prefix_digest=str(field_get(data, "kv_prefix_digest", "kv-prefix-digest", default="")),
            receipt_digest=field_get(data, "receipt_digest", "receipt-digest", default=None),
            absorbed_branch_ids=tuple(
                str(b)
                for b in field_get(data, "absorbed_branch_ids", "absorbed-branch-ids", default=())
            ),
            total_llm_calls=int(field_get(data, "total_llm_calls", "total-llm-calls", default=0)),
            total_det_tasks=int(field_get(data, "total_det_tasks", "total-det-tasks", default=0)),
            outcome=field_get(data, "outcome", default="converged"),
            reason_note=str(field_get(data, "reason_note", "reason-note", default="")),
            status=str(field_get(data, "status", default="done")),
            archived=bool(field_get(data, "archived", "archived?", default=True)),
            detached_ephemeral=bool(
                field_get(data, "detached_ephemeral", "detached-ephemeral?", default=False)
            ),
        )


@dataclass(frozen=True, slots=True)
class TaskActorLookupResult:
    """Read-only ID query result (`actors_spawned=0`, `llm_sessions_spawned=0`)."""

    found: bool
    task_id: str
    entry: TaskActorIndexEntry | None
    mode: Literal["peek-readonly", "not-found"]
    actors_spawned: Literal[0] = 0
    llm_sessions_spawned: Literal[0] = 0


@dataclass(frozen=True, slots=True)
class WorkbenchTabItem:
    id: str
    label: str
    kind: Literal["index", "task"]
    closable: bool
    mode: WorkbenchTabMode
    archived: bool = False
    status: str = "active"
    outcome: str | None = None
    worktree: str = "main"
    scope_ids: tuple[str, ...] = ()
    trunk_id: str | None = None


@dataclass(frozen=True, slots=True)
class WorkbenchTabProjection:
    """Pure UI tab projection over lightweight `TaskActor`s + `TaskActorIndexStore`."""

    pinned_tabs: tuple[WorkbenchTabItem, ...]
    dynamic_tabs: tuple[WorkbenchTabItem, ...]
    archived_index: tuple[TaskActorIndexEntry, ...]
    visible_tab_ids: tuple[str, ...]
    headless_actor_ids: tuple[str, ...]
    active_actor_count: int
    settled_index_count: int
    session_free: Literal[True] = True
    schema: str = "agentic-ai-lab.durable.workbench-tab-projection.v1"
