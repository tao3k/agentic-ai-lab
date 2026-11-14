# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime.checkpoints import RuntimeGraphCheckpoint
from agentic_ai_lab_runtime.durable import TursoRuntimeGraphCheckpointer
from agentic_ai_lab_runtime.durable_policy import (
    RuntimeDurablePolicyError,
    RuntimeDurablePolicyManifest,
    coerce_runtime_durable_policy_manifest,
)


def test_runtime_durable_policy_manifest_parses_scheme_bytes() -> None:
    manifest = coerce_runtime_durable_policy_manifest(
        b"policy-id=agentic-ai-lab-durable-policy.v1\n"
        b"owner=scheme\n"
        b"checkpoint-id-strategy=provided\n"
        b"require-plan-digest-match=true\n"
        b"history-retention-limit=2\n"
        b"backend-driver=turso\n"
        b"backend-concurrent-writes=true\n"
        b"backend-ai-vector-search=true\n"
        b"backend-sync-model=local-first-push-pull\n"
    )

    assert manifest.owner == "scheme"
    assert manifest.checkpoint_id_strategy == "provided"
    assert manifest.require_plan_digest_match is True
    assert manifest.history_retention_limit == 2
    assert manifest.backend["driver"] == "turso"
    assert manifest.backend["concurrent-writes"] == "true"
    assert manifest.backend["ai-vector-search"] == "true"
    assert manifest.backend["sync-model"] == "local-first-push-pull"
    assert b"checkpoint-id-strategy=provided" in manifest.receipt


def test_runtime_durable_policy_rejects_non_scheme_owner() -> None:
    with pytest.raises(RuntimeDurablePolicyError, match="owner must be scheme"):
        coerce_runtime_durable_policy_manifest({"owner": "python"})


def test_turso_checkpointer_honors_provided_checkpoint_id_policy(tmp_path) -> None:
    checkpointer = TursoRuntimeGraphCheckpointer(
        tmp_path / "provided.db",
        policy=RuntimeDurablePolicyManifest(checkpoint_id_strategy="provided"),
    )

    with pytest.raises(RuntimeDurablePolicyError, match="checkpoint_id is required"):
        checkpointer.save(_checkpoint(""))

    saved = checkpointer.save(_checkpoint("provided-1"))

    assert saved.checkpoint_id == "provided-1"


def test_turso_checkpointer_honors_history_retention_policy(tmp_path) -> None:
    checkpointer = TursoRuntimeGraphCheckpointer(
        tmp_path / "retention.db",
        policy=RuntimeDurablePolicyManifest(history_retention_limit=2),
    )

    checkpointer.save(_checkpoint(""))
    checkpointer.save(_checkpoint(""))
    checkpointer.save(_checkpoint(""))

    assert len(checkpointer.history("thread-1")) == 2


def _checkpoint(checkpoint_id: str) -> RuntimeGraphCheckpoint:
    return RuntimeGraphCheckpoint(
        checkpoint_id=checkpoint_id,
        thread_id="thread-1",
        interrupt=None,
        node="load",
        step=1,
        state={"value": 1},
        trace=("load",),
    )
