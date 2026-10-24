# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime import (
    END,
    START,
    FileRuntimeGraphCheckpointer,
    MemoryRuntimeGraphCheckpointer,
    RuntimeGraphBindings,
    RuntimeGraphCheckpoint,
    RuntimeGraphCheckpointError,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
)


def _approval_program() -> RuntimeGraphProgram:
    plan = RuntimeGraphPlan(
        nodes=("load", "approve", "done"),
        edges=(
            RuntimeGraphEdge(START, "load"),
            RuntimeGraphEdge("load", "approve"),
            RuntimeGraphEdge("approve", "done"),
            RuntimeGraphEdge("done", END),
        ),
    )
    return RuntimeGraphProgram.reference(
        plan=plan,
        graph_bindings=RuntimeGraphBindings(
            node_actions={
                "load": "poo.load",
                "approve": "poo.approve",
                "done": "poo.done",
            }
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "poo.load": lambda state: {"value": 42},
                "poo.approve": lambda state: RuntimeGraphInterrupt(
                    {"question": "approve?", "value": state["value"]}
                ),
                "poo.done": lambda state: {
                    "status": "approved" if state["approved"] else "rejected"
                },
            }
        ),
    )


def test_runtime_graph_checkpoint_round_trips_interruption() -> None:
    interrupted = RuntimeGraphInterrupted(
        RuntimeGraphInterrupt({"question": "approve?"}),
        node="approve",
        step=2,
        state={"value": 42},
        trace=("load", "approve"),
        pending=("done",),
    )

    checkpoint = RuntimeGraphCheckpoint.from_interrupted("thread-1", interrupted)
    restored = checkpoint.to_interrupted()

    assert checkpoint.thread_id == "thread-1"
    assert restored.node == "approve"
    assert restored.step == 2
    assert restored.state == {"value": 42}
    assert restored.trace == ("load", "approve")
    assert restored.pending == ("done",)
    assert restored.interrupt.value == {"question": "approve?"}


def test_memory_runtime_graph_checkpointer_reports_missing_thread() -> None:
    checkpointer = MemoryRuntimeGraphCheckpointer()

    with pytest.raises(RuntimeGraphCheckpointError, match="missing"):
        checkpointer.load_interrupted("missing-thread")


def test_memory_runtime_graph_checkpointer_updates_checkpoint_state() -> None:
    interrupted = RuntimeGraphInterrupted(
        RuntimeGraphInterrupt({"question": "approve?"}),
        node="approve",
        step=2,
        state={"value": 42, "unchanged": True},
        trace=("load", "approve"),
        pending=("done",),
    )
    checkpointer = MemoryRuntimeGraphCheckpointer()

    checkpointer.save_interrupted("thread-1", interrupted)
    updated = checkpointer.update_state("thread-1", {"value": 100})
    history = checkpointer.history("thread-1")

    assert updated.checkpoint_id
    assert updated.state == {"value": 100, "unchanged": True}
    assert checkpointer.inspect("thread-1").state == {"value": 100, "unchanged": True}
    assert len(history) == 2
    assert history[0].state == {"value": 42, "unchanged": True}
    assert checkpointer.load_at("thread-1", history[0].checkpoint_id).state == {
        "value": 42,
        "unchanged": True,
    }


def test_file_runtime_graph_checkpointer_persists_across_instances(tmp_path) -> None:
    interrupted = RuntimeGraphInterrupted(
        RuntimeGraphInterrupt({"question": "approve?"}),
        node="approve",
        step=2,
        state={"value": 42},
        trace=("load", "approve"),
        pending=("done",),
    )
    first = FileRuntimeGraphCheckpointer(tmp_path)
    thread_id = "tenant/user:thread-1"

    first.save_interrupted(thread_id, interrupted)
    second = FileRuntimeGraphCheckpointer(tmp_path)
    restored = second.load_interrupted(thread_id)

    assert first.has(thread_id)
    assert restored.node == "approve"
    assert restored.state == {"value": 42}
    assert restored.trace == ("load", "approve")
    assert restored.pending == ("done",)
    second.clear(thread_id)
    assert not first.has(thread_id)


def test_file_runtime_graph_checkpointer_updates_checkpoint_state(tmp_path) -> None:
    interrupted = RuntimeGraphInterrupted(
        RuntimeGraphInterrupt({"question": "approve?"}),
        node="approve",
        step=2,
        state={"value": 42, "unchanged": True},
        trace=("load", "approve"),
        pending=("done",),
    )
    first = FileRuntimeGraphCheckpointer(tmp_path)

    first.save_interrupted("thread-1", interrupted)
    first.update_state("thread-1", {"value": 100})
    second = FileRuntimeGraphCheckpointer(tmp_path)
    history = second.history("thread-1")

    assert second.inspect("thread-1").state == {"value": 100, "unchanged": True}
    assert len(history) == 2
    assert history[0].state == {"value": 42, "unchanged": True}
    assert second.load_at("thread-1", history[0].checkpoint_id).state == {
        "value": 42,
        "unchanged": True,
    }


def test_runtime_graph_program_thread_checkpoint_resume() -> None:
    program = _approval_program()
    checkpointer = MemoryRuntimeGraphCheckpointer()

    with pytest.raises(RuntimeGraphInterrupted):
        program.invoke_thread(
            "thread-1",
            {},
            checkpointer,
            trace_key="trace",
        )

    assert checkpointer.has("thread-1")
    assert checkpointer.inspect("thread-1").plan_digest is not None
    checkpointer.update_state("thread-1", {"value": 100})

    execution = program.resume_thread(
        "thread-1",
        {"approved": True},
        checkpointer,
        trace_key="trace",
    )

    assert execution.state["status"] == "approved"
    assert execution.state["value"] == 100
    assert execution.state["trace"] == ["load", "approve", "done"]
    assert execution.trace == ("load", "approve", "done")
    assert not checkpointer.has("thread-1")


def test_runtime_graph_program_rejects_checkpoint_for_changed_plan() -> None:
    program = _approval_program()
    checkpointer = MemoryRuntimeGraphCheckpointer()

    with pytest.raises(RuntimeGraphInterrupted):
        program.invoke_thread(
            "thread-1",
            {},
            checkpointer,
            trace_key="trace",
        )

    changed_plan = RuntimeGraphPlan(
        nodes=("load", "approve", "audit", "done"),
        edges=(
            RuntimeGraphEdge(START, "load"),
            RuntimeGraphEdge("load", "approve"),
            RuntimeGraphEdge("approve", "audit"),
            RuntimeGraphEdge("audit", "done"),
            RuntimeGraphEdge("done", END),
        ),
    )
    changed_program = RuntimeGraphProgram.reference(
        plan=changed_plan,
        graph_bindings=RuntimeGraphBindings(
            node_actions={
                "load": "poo.load",
                "approve": "poo.approve",
                "audit": "poo.audit",
                "done": "poo.done",
            }
        ),
        registries=RuntimeGraphRegistries(
            actions={
                "poo.load": lambda state: {"value": 42},
                "poo.approve": lambda state: RuntimeGraphInterrupt(
                    {"question": "approve?", "value": state["value"]}
                ),
                "poo.audit": lambda state: {"audited": True},
                "poo.done": lambda state: {
                    "status": "approved" if state["approved"] else "rejected"
                },
            }
        ),
    )

    with pytest.raises(RuntimeGraphError, match="plan digest mismatch"):
        changed_program.resume_thread(
            "thread-1",
            {"approved": True},
            checkpointer,
            trace_key="trace",
        )


def test_runtime_graph_program_file_checkpoint_resume(tmp_path) -> None:
    program = _approval_program()
    first = FileRuntimeGraphCheckpointer(tmp_path)

    with pytest.raises(RuntimeGraphInterrupted):
        program.invoke_thread(
            "thread-1",
            {},
            first,
            trace_key="trace",
        )

    second = FileRuntimeGraphCheckpointer(tmp_path)
    execution = program.resume_thread(
        "thread-1",
        {"approved": True},
        second,
        trace_key="trace",
    )

    assert execution.state["status"] == "approved"
    assert execution.state["trace"] == ["load", "approve", "done"]
    assert execution.trace == ("load", "approve", "done")
    assert not second.has("thread-1")
