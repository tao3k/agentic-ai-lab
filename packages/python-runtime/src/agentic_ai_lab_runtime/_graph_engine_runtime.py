# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Backend-agnostic Python runtime adapter for `GraphEngine`, C4 Steering & Session-free `TaskActor`."""

from __future__ import annotations

import inspect
from collections.abc import Awaitable, Callable, Iterable, Sequence
from dataclasses import replace
from typing import Any, Literal

import anyio

from ._graph_engine_actor_types import (
    VALID_SETTLEMENT_OUTCOMES,
    BranchJoinRecord,
    ScopeMode,
    SettlementOutcome,
    SteeringMessage,
    TaskActor,
    TaskActorIndexEntry,
    TaskActorLookupResult,
    TaskActorScopeDecision,
    TaskActorStatus,
    TrunkJoinGateResult,
    WorkbenchTabItem,
    WorkbenchTabProjection,
)
from ._graph_engine_planners import condense_graph_sccs, plan_disjoint_frontier
from ._graph_engine_stores import MemoryTaskActorIndexStore, TaskActorIndexStore
from ._graph_engine_topology_types import (
    ApexConvergenceReceipt,
    CapabilityEnvelope,
    CyclicSccCondensation,
    FunflowFrontierPlan,
    FunflowTaskSpec,
    GraphEngineError,
    JournalHandoffIntent,
    digest_payload,
)

TaskExecutor = Callable[[FunflowTaskSpec], Any | Awaitable[Any]]


def _project_settled_tabs(
    settled_entries: tuple[TaskActorIndexEntry, ...],
    peek_set: set[str],
    focused_task_id: str | None,
    focused_tab_archive: Literal["on-blur", "immediate"],
) -> list[WorkbenchTabItem]:
    tabs: list[WorkbenchTabItem] = []
    for entry in settled_entries:
        mode: Literal["peek-readonly", "archived-pending-blur"] | None = None
        if entry.task_id in peek_set:
            mode = "peek-readonly"
        elif focused_task_id == entry.task_id and focused_tab_archive == "on-blur":
            mode = "archived-pending-blur"
        if mode is not None:
            tabs.append(
                WorkbenchTabItem(
                    id=entry.task_id,
                    label=entry.title,
                    kind="task",
                    closable=True,
                    mode=mode,
                    archived=True,
                    status=entry.status,
                    outcome=entry.outcome,
                    worktree=entry.worktree,
                    scope_ids=entry.scope_ids,
                    trunk_id=entry.trunk_id,
                )
            )
    return tabs


class GraphEngineRuntime:
    """Backend-agnostic Python Library consumer for `GraphEngine`, C4 Steering & Session-free `TaskActor`."""

    def __init__(self, index_store: TaskActorIndexStore | None = None) -> None:
        self.index_store: TaskActorIndexStore = index_store or MemoryTaskActorIndexStore()

    def spawn_task_actor(
        self,
        *,
        task_id: str,
        trunk_id: str,
        apex_obligation_id: str,
        scope_ids: Sequence[str],
        shared_context_cut: int,
        kv_prefix_digest: str,
        capability_envelope: CapabilityEnvelope,
        title: str = "",
        worktree: str = "main",
        scope_mode: ScopeMode = "project",
        headless: bool = False,
    ) -> TaskActor:
        return TaskActor(
            task_id=task_id,
            trunk_id=trunk_id,
            apex_obligation_id=apex_obligation_id,
            scope_ids=tuple(scope_ids),
            shared_context_cut=shared_context_cut,
            kv_prefix_digest=kv_prefix_digest,
            capability_envelope=capability_envelope,
            actor_kind="convergent-task",
            scope_mode=scope_mode,
            title=title or task_id,
            worktree=worktree,
            headless=headless,
        )

    def spawn_open_focus(
        self,
        *,
        task_id: str,
        scope_ids: Sequence[str],
        capability_envelope: CapabilityEnvelope,
        title: str = "",
        worktree: str = "main",
        scope_mode: ScopeMode = "project",
        shared_context_cut: int = 1,
        kv_prefix_digest: str = "sha256:shared-structural-prefix",
        headless: bool = False,
    ) -> TaskActor:
        return TaskActor(
            task_id=task_id,
            scope_ids=tuple(scope_ids),
            capability_envelope=capability_envelope,
            shared_context_cut=0 if scope_mode == "detached" else shared_context_cut,
            kv_prefix_digest=(
                "sha256:detached-isolated-prefix"
                if scope_mode == "detached"
                else kv_prefix_digest
            ),
            actor_kind="open-focus",
            scope_mode=scope_mode,
            title=title or task_id,
            worktree=worktree,
            headless=headless,
        )

    def promote_focus_to_task_actor(
        self,
        actor: TaskActor,
        *,
        trunk_id: str,
        apex_obligation_id: str,
        shared_context_cut: int,
        kv_prefix_digest: str,
    ) -> TaskActor:
        if actor.status == "settled":
            raise GraphEngineError("cannot promote a settled TaskActor")
        return replace(
            actor,
            actor_kind="convergent-task",
            trunk_id=trunk_id,
            apex_obligation_id=apex_obligation_id,
            shared_context_cut=shared_context_cut,
            kv_prefix_digest=kv_prefix_digest,
            fencing_epoch=actor.fencing_epoch + 1,
            status="active",
        )

    def steer_task_actor(self, actor: TaskActor, message: SteeringMessage) -> TaskActor:
        """Apply a C4 mid-flight SteeringMessage (`target='trunk'` or `target='branch'`)."""
        if actor.status != "active":
            raise GraphEngineError("task-actor-not-active: cannot steer non-active TaskActor")
        next_log = (*actor.steering_log, message)
        if message.target == "trunk":
            next_joins = tuple(
                replace(j, status="superseded")
                if (message.supersede_stale_branches and j.status == "in-flight")
                else j
                for j in actor.branch_joins
            )
            return replace(
                actor,
                fencing_epoch=actor.fencing_epoch + 1,
                shared_context_cut=(
                    actor.shared_context_cut + 1
                    if message.supersede_stale_branches
                    else actor.shared_context_cut
                ),
                steering_log=next_log,
                branch_joins=next_joins,
            )

        if actor.trunk_id is None:
            raise GraphEngineError("branch-steering-requires-trunk")
        if not (message.anchor_node_id and message.join_node_id and message.branch_id):
            raise GraphEngineError("missing-anchor-join-or-branch-id")
        join_rec = BranchJoinRecord(
            branch_id=message.branch_id,
            anchor_node_id=message.anchor_node_id,
            join_node_id=message.join_node_id,
            c4_priority=message.c4_priority,
            required_for_join=message.required_for_join,
            status="in-flight",
        )
        return replace(actor, steering_log=next_log, branch_joins=(*actor.branch_joins, join_rec))

    def complete_anchored_branch(
        self,
        actor: TaskActor,
        branch_id: str,
        *,
        outcome: Literal["completed", "failed", "defeated", "cancelled"] = "completed",
    ) -> TaskActor:
        next_joins = tuple(
            replace(j, status=outcome) if j.branch_id == branch_id else j
            for j in actor.branch_joins
        )
        return replace(actor, branch_joins=next_joins)

    def can_continue_trunk_at_join(
        self,
        actor: TaskActor,
        join_node_id: str,
    ) -> TrunkJoinGateResult:
        relevant = [
            j
            for j in actor.branch_joins
            if j.join_node_id == join_node_id
            and j.required_for_join
            and j.status != "superseded"
        ]
        blocked = [j.branch_id for j in relevant if j.status in ("failed", "defeated", "cancelled")]
        if blocked:
            return TrunkJoinGateResult(
                can_continue=False,
                reason="required-branch-failed-or-defeated",
                join_node_id=join_node_id,
                blocking_branch_ids=tuple(blocked),
            )
        in_flight = [j.branch_id for j in relevant if j.status == "in-flight"]
        if in_flight:
            return TrunkJoinGateResult(
                can_continue=False,
                reason="required-branches-still-in-flight",
                join_node_id=join_node_id,
                blocking_branch_ids=tuple(in_flight),
            )
        return TrunkJoinGateResult(
            can_continue=True,
            reason="all-required-branches-converged",
            join_node_id=join_node_id,
        )

    def admit_scope_access(
        self,
        actor: TaskActor,
        target_scope: str,
        required_cap: str,
    ) -> TaskActorScopeDecision:
        if actor.status != "active":
            ok, reason = False, "task-actor-not-active"
        elif target_scope not in actor.scope_ids:
            ok, reason = False, "scope-out-of-bounds"
        else:
            ok, reason = actor.capability_envelope.permits(required_cap)
        return TaskActorScopeDecision(
            admitted=ok,
            reason=reason,
            task_id=actor.task_id,
            target_scope=target_scope,
            required_cap=required_cap,
            scope_mode=actor.scope_mode,
        )

    def park_task_actor(self, actor: TaskActor) -> TaskActor:
        return actor if actor.status == "settled" else replace(actor, status="parked")

    def resume_task_actor(self, actor: TaskActor) -> TaskActor:
        if actor.status == "settled":
            return actor
        return replace(actor, status="active", fencing_epoch=actor.fencing_epoch + 1)

    def plan_disjoint_frontier(self, tasks: Sequence[FunflowTaskSpec]) -> FunflowFrontierPlan:
        return plan_disjoint_frontier(tasks)

    async def run_frontier(
        self,
        tasks: Sequence[FunflowTaskSpec],
        executor: TaskExecutor,
    ) -> tuple[FunflowFrontierPlan, dict[str, Any]]:
        """Execute each pairwise-disjoint wave concurrently via AnyIO green tasks."""
        plan = plan_disjoint_frontier(tasks)
        by_id = {task.task_id: task for task in tasks}
        results: dict[str, Any] = {}

        async def _run_one(task: FunflowTaskSpec) -> None:
            out = executor(task)
            if inspect.isawaitable(out):
                out = await out
            results[task.task_id] = out

        for wave in plan.waves:
            if len(wave.task_ids) == 1:
                await _run_one(by_id[wave.task_ids[0]])
            else:
                async with anyio.create_task_group() as tg:
                    for tid in wave.task_ids:
                        tg.start_soon(_run_one, by_id[tid])
        return plan, results

    def condense_sccs(
        self,
        nodes: Sequence[str],
        edges: Iterable[tuple[str, str]],
    ) -> CyclicSccCondensation:
        return condense_graph_sccs(nodes, edges)

    def settle_task_actor(
        self,
        actor: TaskActor,
        apex_receipt: ApexConvergenceReceipt | None = None,
        *,
        outcome: SettlementOutcome = "converged",
        reason_note: str = "",
        journal_epoch: int = 1,
    ) -> tuple[TaskActor, TaskActorIndexEntry, JournalHandoffIntent]:
        """Settle a TaskActor (converged, cancelled, failed, denied, or parked) into `index_store`."""
        if outcome not in VALID_SETTLEMENT_OUTCOMES:
            raise GraphEngineError(f"invalid settlement outcome: {outcome!r}")
        if outcome == "converged":
            if apex_receipt is None:
                raise GraphEngineError(
                    "trunk-not-converged: ApexConvergenceReceipt is required for outcome='converged'"
                )
            if apex_receipt.trunk_id != actor.trunk_id or (
                apex_receipt.apex_obligation_id != actor.apex_obligation_id
            ):
                raise GraphEngineError("apex receipt does not match TaskActor trunk/apex identity")

        next_status: TaskActorStatus = "parked" if outcome == "parked" else "settled"
        settled_actor = replace(actor, status=next_status)
        entry = TaskActorIndexEntry(
            task_id=actor.task_id,
            title=actor.title,
            worktree=actor.worktree,
            actor_kind=actor.actor_kind,
            scope_mode=actor.scope_mode,
            scope_ids=actor.scope_ids,
            fencing_epoch=actor.fencing_epoch,
            trunk_id=actor.trunk_id,
            apex_obligation_id=actor.apex_obligation_id,
            shared_context_cut=(
                apex_receipt.shared_context_cut if apex_receipt else actor.shared_context_cut
            ),
            kv_prefix_digest=(
                apex_receipt.kv_prefix_digest if apex_receipt else actor.kv_prefix_digest
            ),
            receipt_digest=apex_receipt.receipt_digest if apex_receipt else None,
            absorbed_branch_ids=apex_receipt.absorbed_branch_ids if apex_receipt else (),
            total_llm_calls=apex_receipt.total_llm_calls if apex_receipt else 0,
            total_det_tasks=apex_receipt.total_det_tasks if apex_receipt else 0,
            outcome=outcome,
            reason_note=reason_note,
            status="done" if outcome == "converged" else outcome,
            archived=(outcome != "parked"),
            detached_ephemeral=(actor.scope_mode == "detached"),
        )
        if actor.scope_mode != "detached":
            self.index_store.put(entry)
        snapshot = entry.to_dict()
        handoff = JournalHandoffIntent(
            trunk_id=actor.trunk_id or actor.task_id,
            journal_epoch=journal_epoch,
            event_kind="task-actor-settled",
            payload_digest=digest_payload(snapshot),
            snapshot=snapshot,
            runtime_executed=False,
        )
        return settled_actor, entry, handoff

    def lookup_by_id(self, task_id: str) -> TaskActorLookupResult:
        entry = self.index_store.get(task_id)
        if entry is None:
            return TaskActorLookupResult(found=False, task_id=task_id, entry=None, mode="not-found")
        return TaskActorLookupResult(found=True, task_id=task_id, entry=entry, mode="peek-readonly")

    def project_workbench_tabs(
        self,
        actors: Sequence[TaskActor],
        *,
        peek_ids: Sequence[str] = (),
        focused_task_id: str | None = None,
        focused_tab_archive: Literal["on-blur", "immediate"] = "on-blur",
    ) -> WorkbenchTabProjection:
        pinned = (
            WorkbenchTabItem(id="index", label="Index", kind="index", closable=False, mode="pinned"),
        )
        active_actors = [a for a in actors if a.status != "settled"]
        headless_ids = tuple(a.task_id for a in active_actors if a.headless)
        active_tabs = [
            WorkbenchTabItem(
                id=a.task_id,
                label=a.title,
                kind="task",
                closable=True,
                mode="active",
                status=a.status,
                worktree=a.worktree,
                scope_ids=a.scope_ids,
                trunk_id=a.trunk_id,
            )
            for a in active_actors
            if not a.headless
        ]
        settled_entries = self.index_store.list_entries()
        dynamic = tuple(
            active_tabs
            + _project_settled_tabs(settled_entries, set(peek_ids), focused_task_id, focused_tab_archive)
        )
        return WorkbenchTabProjection(
            pinned_tabs=pinned,
            dynamic_tabs=dynamic,
            archived_index=settled_entries,
            visible_tab_ids=("index", *(tab.id for tab in dynamic)),
            headless_actor_ids=headless_ids,
            active_actor_count=len(active_actors),
            settled_index_count=len(settled_entries),
        )
