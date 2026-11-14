# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Durable runtime adapters driven by Scheme policy manifests."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

from .durable import TursoRuntimeGraphCheckpointer, TursoRuntimeGraphStore
from .durable_envelope import (
    RuntimeDurableEnvelopeManifest,
    coerce_runtime_durable_envelope_manifest,
)
from .durable_policy import (
    RuntimeDurablePolicyManifest,
    coerce_runtime_durable_policy_manifest,
)


@dataclass(frozen=True)
class RuntimeDurableAdapter:
    policy: RuntimeDurablePolicyManifest
    store: Any
    checkpointer: Any
    backend: str

    @classmethod
    def turso(
        cls,
        database: str | Path = ":memory:",
        *,
        policy: RuntimeDurablePolicyManifest | dict[str, Any] | bytes | None = None,
    ) -> "RuntimeDurableAdapter":
        manifest = coerce_runtime_durable_policy_manifest(policy)
        return cls(
            policy=manifest,
            store=TursoRuntimeGraphStore(database, policy=manifest),
            checkpointer=TursoRuntimeGraphCheckpointer(database, policy=manifest),
            backend="turso",
        )

    @classmethod
    def turso_from_envelope(
        cls,
        database: str | Path = ":memory:",
        *,
        envelope: RuntimeDurableEnvelopeManifest | dict[str, Any] | bytes | None = None,
    ) -> "RuntimeDurableAdapter":
        manifest = coerce_runtime_durable_envelope_manifest(envelope)
        return cls.turso(database, policy=manifest.to_policy_manifest())

    def receipt(self) -> bytes:
        fields = {
            "manifest-schema": self.policy.manifest_schema,
            "policy-id": self.policy.policy_id,
            "owner": self.policy.owner,
            "backend": self.backend,
            "checkpoint-id-strategy": self.policy.checkpoint_id_strategy,
            "require-plan-digest-match": str(
                self.policy.require_plan_digest_match
            ).lower(),
            "checkpoint-store": self.policy.checkpoint_store,
            "repair-mode": self.policy.repair_mode,
            "action-classes": ",".join(self.policy.action_classes),
            "runtime-owner": self.policy.runtime_owner,
            "receipt-schema": self.policy.receipt_schema,
            "receipt-kind": self.policy.receipt_kind,
            "receipt-valid": str(self.policy.receipt_valid).lower(),
            "receipt-diagnostic-count": str(self.policy.receipt_diagnostic_count),
        }
        if self.policy.history_retention_limit is not None:
            fields["history-retention-limit"] = str(self.policy.history_retention_limit)
        backend = getattr(self.store, "backend", None)
        if backend is not None:
            fields.update(backend.receipt_fields())
        lines = ["agentic-ai-lab-durable-adapter.v1"]
        lines.extend(f"{key}={value}" for key, value in fields.items())
        return ("\n".join(lines) + "\n").encode("utf-8")

    def has(self, thread_id: str) -> bool:
        return self.checkpointer.has(thread_id)

    async def ahas(self, thread_id: str) -> bool:
        return await self.checkpointer.ahas(thread_id)

    def inspect(self, thread_id: str) -> Any:
        return self.checkpointer.inspect(thread_id)

    async def ainspect(self, thread_id: str) -> Any:
        return await self.checkpointer.ainspect(thread_id)

    def history(self, thread_id: str) -> tuple[Any, ...]:
        return self.checkpointer.history(thread_id)

    async def ahistory(self, thread_id: str) -> tuple[Any, ...]:
        return await self.checkpointer.ahistory(thread_id)

    def load_at(self, thread_id: str, checkpoint_id: str) -> Any:
        return self.checkpointer.load_at(thread_id, checkpoint_id)

    async def aload_at(self, thread_id: str, checkpoint_id: str) -> Any:
        return await self.checkpointer.aload_at(thread_id, checkpoint_id)

    def update_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> Any:
        return self.checkpointer.update_state(thread_id, update, replace=replace)

    async def aupdate_state(
        self,
        thread_id: str,
        update: Mapping[str, Any],
        *,
        replace: bool = False,
    ) -> Any:
        return await self.checkpointer.aupdate_state(
            thread_id,
            update,
            replace=replace,
        )

    def clear(self, thread_id: str) -> None:
        self.checkpointer.clear(thread_id)

    async def aclear(self, thread_id: str) -> None:
        await self.checkpointer.aclear(thread_id)

    def invoke_thread(
        self,
        program: Any,
        thread_id: str,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> Any:
        return program.invoke_thread(
            thread_id,
            dict(initial_state),
            self.checkpointer,
            trace_key=trace_key,
        )

    async def ainvoke_thread(
        self,
        program: Any,
        thread_id: str,
        initial_state: Mapping[str, Any],
        *,
        trace_key: str | None = None,
    ) -> Any:
        return await program.ainvoke_thread(
            thread_id,
            dict(initial_state),
            self.checkpointer,
            trace_key=trace_key,
        )

    def resume_thread(
        self,
        program: Any,
        thread_id: str,
        resume_result: object,
        *,
        trace_key: str | None = None,
        clear: bool = True,
    ) -> Any:
        return program.resume_thread(
            thread_id,
            resume_result,
            self.checkpointer,
            trace_key=trace_key,
            clear=clear,
        )

    async def aresume_thread(
        self,
        program: Any,
        thread_id: str,
        resume_result: object,
        *,
        trace_key: str | None = None,
        clear: bool = True,
    ) -> Any:
        return await program.aresume_thread(
            thread_id,
            resume_result,
            self.checkpointer,
            trace_key=trace_key,
            clear=clear,
        )


__all__ = ["RuntimeDurableAdapter"]
