# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public `GraphEngine`, C4 Steering & Session-free `TaskActor` Python library facade."""

from __future__ import annotations

from ._graph_engine_actor_types import (
    ActorKind,
    BranchJoinRecord,
    BranchJoinStatus,
    ScopeMode,
    SettlementOutcome,
    SteeringMessage,
    SteeringTarget,
    TaskActor,
    TaskActorIndexEntry,
    TaskActorLookupResult,
    TaskActorScopeDecision,
    TaskActorStatus,
    TrunkJoinGateResult,
    WorkbenchTabItem,
    WorkbenchTabMode,
    WorkbenchTabProjection,
)
from ._graph_engine_planners import (
    coerce_apex_convergence_receipt,
    coerce_cedar_handoff,
    coerce_journal_handoff_intent,
    condense_graph_sccs,
    plan_disjoint_frontier,
)
from ._graph_engine_runtime import GraphEngineRuntime
from ._graph_engine_stores import (
    FileTaskActorIndexStore,
    MemoryTaskActorIndexStore,
    TaskActorIndexStore,
)
from ._graph_engine_topology_types import (
    ApexConvergenceReceipt,
    BranchKind,
    CapabilityEnvelope,
    CyclicSccCondensation,
    CyclicSccSpec,
    FunflowFrontierPlan,
    FunflowTaskSpec,
    FunflowWaveSpec,
    GraphCedarHandoff,
    GraphEngineError,
    JournalHandoffIntent,
    SubordinateBranchSpec,
)

__all__ = [
    "ActorKind",
    "ApexConvergenceReceipt",
    "BranchJoinRecord",
    "BranchJoinStatus",
    "BranchKind",
    "CapabilityEnvelope",
    "CyclicSccCondensation",
    "CyclicSccSpec",
    "FileTaskActorIndexStore",
    "FunflowFrontierPlan",
    "FunflowTaskSpec",
    "FunflowWaveSpec",
    "GraphCedarHandoff",
    "GraphEngineError",
    "GraphEngineRuntime",
    "JournalHandoffIntent",
    "MemoryTaskActorIndexStore",
    "ScopeMode",
    "SettlementOutcome",
    "SteeringMessage",
    "SteeringTarget",
    "SubordinateBranchSpec",
    "TaskActor",
    "TaskActorIndexEntry",
    "TaskActorIndexStore",
    "TaskActorLookupResult",
    "TaskActorScopeDecision",
    "TaskActorStatus",
    "TrunkJoinGateResult",
    "WorkbenchTabItem",
    "WorkbenchTabMode",
    "WorkbenchTabProjection",
    "coerce_apex_convergence_receipt",
    "coerce_cedar_handoff",
    "coerce_journal_handoff_intent",
    "condense_graph_sccs",
    "plan_disjoint_frontier",
]
