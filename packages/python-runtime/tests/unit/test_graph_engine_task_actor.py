# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

import pytest

from agentic_ai_lab_runtime.graph_engine import (
    ApexConvergenceReceipt,
    CapabilityEnvelope,
    FileTaskActorIndexStore,
    GraphEngineError,
    GraphEngineRuntime,
    SteeringMessage,
)


def test_c4_mid_flight_steering_anchor_join_and_trunk_supersede() -> None:
    rt = GraphEngineRuntime()
    env = CapabilityEnvelope(owner_id="owner", allowed_caps=("context-read",))
    actor = rt.spawn_task_actor(
        task_id="task-dfg",
        trunk_id="trunk-dfg",
        apex_obligation_id="ob-apex",
        scope_ids=("scope/core",),
        shared_context_cut=1,
        kv_prefix_digest="sha256:structural",
        capability_envelope=env,
    )

    actor = rt.steer_task_actor(
        actor,
        SteeringMessage(
            message_id="steer-1",
            target="branch",
            payload="Checklist D1",
            c4_priority=1,
            anchor_node_id="D",
            join_node_id="F",
            branch_id="D1",
        ),
    )
    actor = rt.steer_task_actor(
        actor,
        SteeringMessage(
            message_id="steer-2",
            target="branch",
            payload="Checklist D2",
            c4_priority=2,
            anchor_node_id="D",
            join_node_id="F",
            branch_id="D2",
        ),
    )
    assert rt.can_continue_trunk_at_join(actor, "F").reason == "required-branches-still-in-flight"

    a_d1_done = rt.complete_anchored_branch(actor, "D1", outcome="completed")
    a_d2_defeated = rt.complete_anchored_branch(a_d1_done, "D2", outcome="defeated")
    gate_defeated = rt.can_continue_trunk_at_join(a_d2_defeated, "F")
    assert gate_defeated.can_continue is False
    assert gate_defeated.blocking_branch_ids == ("D2",)

    a_both_done = rt.complete_anchored_branch(a_d1_done, "D2", outcome="completed")
    assert rt.can_continue_trunk_at_join(a_both_done, "F").can_continue is True

    pivoted = rt.steer_task_actor(
        actor,
        SteeringMessage(
            message_id="steer-trunk",
            target="trunk",
            payload="Pivot trunk",
            c4_priority=0,
            supersede_stale_branches=True,
        ),
    )
    assert pivoted.fencing_epoch == 2
    assert rt.can_continue_trunk_at_join(pivoted, "F").can_continue is True


def test_open_focus_detached_scope_all_terminal_settlement_and_workbench_tabs(
    tmp_path: Path,
) -> None:
    index_file = tmp_path / "task-actor-index.json"
    rt = GraphEngineRuntime(index_store=FileTaskActorIndexStore(index_file))
    env = CapabilityEnvelope(
        owner_id="actor-owner",
        allowed_caps=("context-read", "repo-scan"),
        denied_caps=("host-egress",),
    )

    detached = rt.spawn_open_focus(
        task_id="adhoc-q",
        scope_ids=("scope/detached",),
        capability_envelope=env,
        scope_mode="detached",
    )
    _, det_entry, _ = rt.settle_task_actor(detached, outcome="cancelled", reason_note="answered")
    assert det_entry.detached_ephemeral is True
    assert rt.lookup_by_id("adhoc-q").found is False

    focus = rt.spawn_open_focus(
        task_id="task-ui",
        scope_ids=("scope/workspace", "scope/design"),
        capability_envelope=env,
        title="Refactor GraphEngine",
    )
    ui_actor = rt.promote_focus_to_task_actor(
        focus,
        trunk_id="trunk-ui",
        apex_obligation_id="ob-apex-ui",
        shared_context_cut=2,
        kv_prefix_digest="sha256:shared-structural-prefix",
    )
    assert ui_actor.fencing_epoch == 2

    failed_actor = rt.spawn_task_actor(
        task_id="task-fail",
        trunk_id="trunk-fail",
        apex_obligation_id="ob-apex-fail",
        scope_ids=("scope/workspace",),
        shared_context_cut=2,
        kv_prefix_digest="sha256:shared-structural-prefix",
        capability_envelope=env,
        title="Failed Migration",
    )
    with pytest.raises(GraphEngineError, match="trunk-not-converged"):
        rt.settle_task_actor(failed_actor, None, outcome="converged")
    settled_fail, fail_entry, _ = rt.settle_task_actor(
        failed_actor, outcome="failed", reason_note="compile error"
    )
    assert fail_entry.outcome == "failed"

    apex_receipt = ApexConvergenceReceipt(
        trunk_id="trunk-ui",
        apex_obligation_id="ob-apex-ui",
        shared_context_cut=2,
        kv_prefix_digest="sha256:shared-structural-prefix",
        absorbed_branch_ids=("D1", "D2"),
        total_llm_calls=0,
        total_det_tasks=2,
    )
    settled_ui, ui_entry, handoff = rt.settle_task_actor(ui_actor, apex_receipt, journal_epoch=5)
    assert settled_ui.status == "settled"
    assert ui_entry.outcome == "converged"
    assert handoff.runtime_executed is False

    rt2 = GraphEngineRuntime(index_store=FileTaskActorIndexStore(index_file))
    hit_fail = rt2.lookup_by_id("task-fail")
    assert hit_fail.found is True
    assert hit_fail.mode == "peek-readonly"
    assert hit_fail.actors_spawned == 0
    assert hit_fail.entry is not None
    assert hit_fail.entry.outcome == "failed"

    proj = rt2.project_workbench_tabs([settled_ui, settled_fail], peek_ids=("task-fail",))
    assert proj.session_free is True
    assert proj.visible_tab_ids == ("index", "task-fail")
    assert proj.dynamic_tabs[0].mode == "peek-readonly"
    assert proj.dynamic_tabs[0].outcome == "failed"
