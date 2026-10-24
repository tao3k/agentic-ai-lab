# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import pytest

from agentic_ai_lab_runtime import (
    END,
    START,
    FileRuntimeGraphStore,
    MemoryRuntimeGraphStore,
    RuntimeGraphEdge,
    RuntimeGraphExecutor,
    RuntimeGraphPlan,
    RuntimeGraphStoreError,
)


def _assert_store_round_trip(store) -> None:
    first = store.put(("users", "alice"), "profile", {"name": "Alice"})
    second = store.put(("users", "alice"), "settings", {"theme": "dark"})
    updated = store.put(("users", "alice"), "profile", {"name": "Alice B"})
    store.put(("users", "bob"), "profile", {"name": "Bob"})

    assert first.created_at == updated.created_at
    assert updated.updated_at >= first.updated_at
    assert store.get(("users", "alice"), "profile").value == {"name": "Alice B"}
    assert [item.key for item in store.list(("users", "alice"))] == [
        "profile",
        "settings",
    ]
    assert {item.namespace for item in store.search(("users",))} == {
        ("users", "alice"),
        ("users", "bob"),
    }
    store.delete(("users", "alice"), "settings")
    assert store.get(("users", "alice"), "settings") is None
    assert second.key == "settings"


def test_memory_runtime_graph_store_round_trip() -> None:
    _assert_store_round_trip(MemoryRuntimeGraphStore())


def test_file_runtime_graph_store_round_trip(tmp_path) -> None:
    first = FileRuntimeGraphStore(tmp_path)

    _assert_store_round_trip(first)

    second = FileRuntimeGraphStore(tmp_path)
    assert second.get(("users", "alice"), "profile").value == {"name": "Alice B"}


def test_runtime_graph_store_rejects_empty_namespace() -> None:
    store = MemoryRuntimeGraphStore()

    with pytest.raises(RuntimeGraphStoreError, match="namespace"):
        store.put((), "key", "value")


def test_runtime_graph_action_can_use_store_closure() -> None:
    store = MemoryRuntimeGraphStore()
    executor = RuntimeGraphExecutor(
        RuntimeGraphPlan(
            nodes=("remember", "recall"),
            edges=(
                RuntimeGraphEdge(START, "remember"),
                RuntimeGraphEdge("remember", "recall"),
                RuntimeGraphEdge("recall", END),
            ),
        ),
        {
            "remember": lambda state: {
                "stored": store.put(("users", state["user"]), "name", state["name"]).key
            },
            "recall": lambda state: {
                "remembered": store.get(("users", state["user"]), "name").value
            },
        },
    )

    state = executor.invoke({"user": "alice", "name": "Alice"})

    assert state["stored"] == "name"
    assert state["remembered"] == "Alice"
