# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Topology, capability, and inert handoff data types for `GraphEngine`."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any, Literal

BranchKind = Literal[
    "context-enrichment-detour",
    "divergent-exploration",
    "subordinate-task",
]

VALID_BRANCH_KINDS: frozenset[str] = frozenset(
    {
        "context-enrichment-detour",
        "divergent-exploration",
        "subordinate-task",
    }
)


class GraphEngineError(RuntimeError):
    """Raised when a GraphEngine or TaskActor contract invariant is violated."""


def field_get(mapping: Mapping[str, Any], *keys: str, default: Any = None) -> Any:
    for key in keys:
        if key in mapping:
            return mapping[key]
    return default


def digest_payload(payload: Mapping[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return f"sha256:{hashlib.sha256(canonical).hexdigest()}"


@dataclass(frozen=True, slots=True)
class CapabilityEnvelope:
    """Attenuated capability envelope (`denied_caps` always override `allowed_caps`)."""

    owner_id: str
    allowed_caps: tuple[str, ...] = ()
    denied_caps: tuple[str, ...] = ()
    egress_allowed: bool = False

    def permits(self, capability: str) -> tuple[bool, str]:
        if capability in self.denied_caps:
            return False, "capability-explicitly-denied"
        if capability not in self.allowed_caps:
            return False, "capability-not-granted"
        return True, "admitted"


@dataclass(frozen=True, slots=True)
class FunflowTaskSpec:
    """One deterministic task node scheduled by C4 disjoint parallel frontier waves."""

    task_id: str
    read_footprint: tuple[str, ...] = ()
    write_footprint: tuple[str, ...] = ()
    depends_on: tuple[str, ...] = ()
    c4_priority: int = 10
    effect_class: str = "pure-cas"

    def conflicts_with(self, other: "FunflowTaskSpec") -> bool:
        my_writes = set(self.write_footprint)
        other_writes = set(other.write_footprint)
        if not my_writes and not other_writes:
            return False
        my_reads = set(self.read_footprint)
        other_reads = set(other.read_footprint)
        return bool(
            (my_writes & other_writes)
            or (my_writes & other_reads)
            or (other_writes & my_reads)
        )


@dataclass(frozen=True, slots=True)
class FunflowWaveSpec:
    """One parallel wave whose tasks are pairwise footprint-disjoint."""

    wave_index: int
    task_ids: tuple[str, ...]
    parallel: bool


@dataclass(frozen=True, slots=True)
class FunflowFrontierPlan:
    """C4 disjoint parallel execution plan (0 subagents, 0 LLM calls)."""

    waves: tuple[FunflowWaveSpec, ...]
    max_wave_width: int
    total_tasks: int
    subagents_spawned: Literal[0] = 0
    llm_calls: Literal[0] = 0
    schema: str = "agentic-ai-lab.graph-engine.frontier-plan.v1"


@dataclass(frozen=True, slots=True)
class SubordinateBranchSpec:
    """Subordinate branch growing from a ContextTrunk (NEVER finalizes the Trunk)."""

    branch_id: str
    branch_kind: BranchKind
    trunk_id: str
    serving_apex_id: str
    target_obligation_id: str
    shared_context_cut: int
    kv_prefix_digest: str
    c4_priority: int = 10
    required_for_apex: bool = True
    can_finalize_trunk: Literal[False] = False

    def __post_init__(self) -> None:
        if self.branch_kind not in VALID_BRANCH_KINDS:
            raise GraphEngineError(f"invalid branch_kind: {self.branch_kind!r}")
        if self.can_finalize_trunk is not False:
            raise GraphEngineError("subordinate branch can NEVER finalize the ContextTrunk")


@dataclass(frozen=True, slots=True)
class ApexConvergenceReceipt:
    """Receipt emitted when a ContextTrunk converges at its Apex obligation."""

    trunk_id: str
    apex_obligation_id: str
    shared_context_cut: int
    kv_prefix_digest: str
    absorbed_branch_ids: tuple[str, ...] = ()
    total_llm_calls: int = 0
    total_det_tasks: int = 0
    receipt_digest: str = ""
    schema: str = "agentic-ai-lab.loop-engine.apex-convergence.v1"

    def __post_init__(self) -> None:
        if not self.trunk_id or not self.apex_obligation_id:
            raise GraphEngineError("trunk_id and apex_obligation_id are required")
        if not self.receipt_digest:
            digest = digest_payload(
                {
                    "schema": self.schema,
                    "trunk_id": self.trunk_id,
                    "apex_obligation_id": self.apex_obligation_id,
                    "shared_context_cut": self.shared_context_cut,
                    "kv_prefix_digest": self.kv_prefix_digest,
                    "absorbed_branch_ids": list(self.absorbed_branch_ids),
                    "total_llm_calls": self.total_llm_calls,
                    "total_det_tasks": self.total_det_tasks,
                }
            )
            object.__setattr__(self, "receipt_digest", digest)


@dataclass(frozen=True, slots=True)
class CyclicSccSpec:
    """One strongly connected component produced by Tarjan SCC condensation."""

    scc_id: str
    node_ids: tuple[str, ...]
    cyclic: bool


@dataclass(frozen=True, slots=True)
class CyclicSccCondensation:
    """Unified condensation DAG over both acyclic nodes and cyclic feedback subgraphs."""

    sccs: tuple[CyclicSccSpec, ...]
    topological_scc_order: tuple[str, ...]
    has_cycles: bool
    schema: str = "agentic-ai-lab.graph-engine.scc-condensation.v1"


@dataclass(frozen=True, slots=True)
class JournalHandoffIntent:
    """Inert Marlin / `+sqlite-turso` persistence handoff (`runtime_executed=False`)."""

    trunk_id: str
    journal_epoch: int
    event_kind: str
    payload_digest: str
    snapshot: Mapping[str, Any] = field(default_factory=dict)
    runtime_executed: bool = False
    schema: str = "agentic-ai-lab.graph-engine.journal-handoff-intent.v1"

    def __post_init__(self) -> None:
        if self.runtime_executed:
            raise GraphEngineError("JournalHandoffIntent must remain inert (runtime_executed=False)")


@dataclass(frozen=True, slots=True)
class GraphCedarHandoff:
    """Inert Cedar authorization handoff (`runtime_executed=False`)."""

    policy_id: str
    trunk_id: str
    bound_cut: int
    grant_epoch: int = 1
    policy_valid: bool = True
    runtime_executed: bool = False
    schema: str = "agentic-ai-lab.graph-engine.cedar-handoff.v1"

    def __post_init__(self) -> None:
        if self.runtime_executed:
            raise GraphEngineError("GraphCedarHandoff must remain inert (runtime_executed=False)")
