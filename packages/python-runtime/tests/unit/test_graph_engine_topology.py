# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import anyio
import pytest

from agentic_ai_lab_runtime.graph_engine import (
    FunflowTaskSpec,
    GraphCedarHandoff,
    GraphEngineError,
    GraphEngineRuntime,
    JournalHandoffIntent,
    MemoryTaskActorIndexStore,
    SubordinateBranchSpec,
    coerce_apex_convergence_receipt,
    coerce_cedar_handoff,
    coerce_journal_handoff_intent,
    condense_graph_sccs,
    plan_disjoint_frontier,
)


def test_graph_engine_library_does_not_force_pyturso_import() -> None:
    import agentic_ai_lab_runtime.graph_engine as ge

    assert "pyturso" not in ge.__dict__
    assert isinstance(GraphEngineRuntime().index_store, MemoryTaskActorIndexStore)


def test_disjoint_frontier_fans_out_readonly_and_serializes_write_conflicts() -> None:
    tasks = (
        FunflowTaskSpec("read-a", read_footprint=("repo/a.ss",), c4_priority=1),
        FunflowTaskSpec("read-b", read_footprint=("repo/b.ss",), c4_priority=2),
        FunflowTaskSpec(
            "write-a-1",
            read_footprint=("repo/a.ss",),
            write_footprint=("repo/a.ss",),
            depends_on=("read-a",),
            c4_priority=3,
        ),
        FunflowTaskSpec(
            "write-a-2",
            read_footprint=("repo/a.ss",),
            write_footprint=("repo/a.ss",),
            depends_on=("read-a",),
            c4_priority=4,
        ),
    )

    plan = plan_disjoint_frontier(tasks)
    assert plan.subagents_spawned == 0
    assert plan.llm_calls == 0
    assert plan.max_wave_width == 2
    assert [w.task_ids for w in plan.waves] == [
        ("read-a", "read-b"),
        ("write-a-1",),
        ("write-a-2",),
    ]

    async def scenario() -> None:
        rt = GraphEngineRuntime()
        active_peak = 0
        active_now = 0

        async def run_task(spec: FunflowTaskSpec) -> str:
            nonlocal active_now, active_peak
            active_now += 1
            active_peak = max(active_peak, active_now)
            await anyio.sleep(0.01)
            active_now -= 1
            return f"ok:{spec.task_id}"

        run_plan, outputs = await rt.run_frontier(tasks, run_task)
        assert run_plan == plan
        assert active_peak == 2
        assert outputs["write-a-2"] == "ok:write-a-2"

    anyio.run(scenario)


def test_tarjan_scc_condensation_and_branch_non_finality() -> None:
    condensation = condense_graph_sccs(
        nodes=("ingest", "plan", "verify", "publish"),
        edges=(("ingest", "plan"), ("plan", "verify"), ("verify", "plan"), ("verify", "publish")),
    )
    assert condensation.has_cycles is True
    assert [scc.node_ids for scc in condensation.sccs] == [
        ("ingest",),
        ("plan", "verify"),
        ("publish",),
    ]
    assert [scc.cyclic for scc in condensation.sccs] == [False, True, False]

    with pytest.raises(GraphEngineError, match="can NEVER finalize"):
        SubordinateBranchSpec(
            branch_id="br-bad",
            branch_kind="subordinate-task",
            trunk_id="trunk-1",
            serving_apex_id="ob-apex",
            target_obligation_id="ob-read",
            shared_context_cut=1,
            kv_prefix_digest="sha256:shared",
            can_finalize_trunk=True,  # type: ignore[arg-type]
        )


def test_scheme_hyphenated_handoff_coercion_preserves_inert_boundaries() -> None:
    apex = coerce_apex_convergence_receipt(
        {
            "trunk-id": "trunk-42",
            "apex-obligation-id": "ob-apex-42",
            "shared-context-cut": 3,
            "kv-prefix-digest": "sha256:kv42",
            "absorbed-branch-ids-c4-order": ["D1", "D2"],
        }
    )
    assert apex.absorbed_branch_ids == ("D1", "D2")

    handoff = coerce_journal_handoff_intent(
        {
            "trunk-id": "trunk-42",
            "journal-epoch": 7,
            "event-kind": "task-actor-settled",
            "payload-digest": "sha256:p42",
            "runtime-executed?": False,
        }
    )
    assert isinstance(handoff, JournalHandoffIntent)
    assert handoff.runtime_executed is False

    cedar = coerce_cedar_handoff(
        {
            "policy-id": "pol/graph-scope",
            "trunk-id": "trunk-42",
            "bound-cut": 3,
            "runtime-executed?": False,
        }
    )
    assert isinstance(cedar, GraphCedarHandoff)
    with pytest.raises(GraphEngineError, match="must remain inert"):
        coerce_cedar_handoff(
            {"policy-id": "pol/bad", "trunk-id": "trunk-42", "runtime-executed?": True}
        )
