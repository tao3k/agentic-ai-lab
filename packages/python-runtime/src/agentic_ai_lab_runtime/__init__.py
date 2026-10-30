# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Public package facade for the Agentic AI Lab Python runtime."""

from .builder import RuntimeGraphBuilder
from .semantic_runtime import SemanticRuntime, SemanticRuntimeError
from .crewai import (
    CrewAIAgentSpec,
    CrewAIFlowResult,
    CrewAIFlowSpec,
    CrewAITaskSpec,
    create_crewai_flow_executor,
    crewai_flow_plan,
    crewai_flow_receipt,
    run_crewai_flow,
)
from .checkpoints import (
    FileRuntimeGraphCheckpointer,
    MemoryRuntimeGraphCheckpointer,
    RuntimeGraphCheckpoint,
    RuntimeGraphCheckpointError,
)
from .durable import (
    TursoRuntimeGraphCheckpointer,
    TursoRuntimeGraphStore,
)
from .batched_evidence import (
    BatchedEvidenceLeaf,
    BatchedMerkleProof,
    BatchedMerkleProofStep,
    batched_evidence_leaf,
    batched_merkle_proof,
    batched_merkle_proof_verify,
    batched_merkle_root,
    batched_merkle_root_digests,
)
from .durable_turso_backend import (
    TursoRuntimeGraphBackend,
    turso_runtime_graph_backend,
)
from .durable_adapter import RuntimeDurableAdapter
from .durable_envelope import (
    RuntimeDurableEnvelopeManifest,
    coerce_runtime_durable_envelope_manifest,
)
from .durable_policy import (
    RuntimeDurablePolicyError,
    RuntimeDurablePolicyManifest,
    coerce_runtime_durable_policy_manifest,
)
from .event_stream import (
    DEFAULT_RUNTIME_GRAPH_STREAM_MODES,
    RuntimeGraphStreamProjection,
)
from .evidence import TursoAuthorizedEffectEvidenceStore
from .evidence_model import (
    AuthorizedEffectEvidenceError,
    AuthorizedEffectEvidenceReconciliation,
    AuthorizedEffectEvidenceReservation,
    AuthorizedEffectEvidenceReceipt,
    BatchedEvidenceCommitReceipt,
    authorized_effect_evidence_from_native,
    authorized_effect_evidence_receipt,
)
from ._scheme_load import clear_load_cache, load, precompile_load, preproject_load
from .funflow import (
    AnyioFunFlowRuntime,
    FunFlowDag,
    FunFlowPlanProjection,
    FunFlowRunReceipt,
    FunFlowRuntimeError,
    FunFlowSandbox,
    FunFlowStep,
    FunFlowStepReceipt,
)
from .json_schema_contract import (
    json_schema_to_scheme_contract,
    load_json_schema,
)
from .materialization import RuntimeGraphBindings, describe_runtime_graph_plan
from .messages import (
    RuntimeGraphMessage,
    RuntimeGraphToolCall,
    add_messages,
    ai_message,
    human_message,
    tool_message,
)
from .prebuilt import create_tool_call_loop, tools_condition
from .program import (
    RuntimeGraphExecution,
    RuntimeGraphProgram,
    RuntimeGraphRegistries,
)
from .receipts import RuntimeReceipt, parse_runtime_receipt
from .runtime import RuntimeGraphRuntime, RuntimeGraphRuntimeError
from .runtime_graph import (
    END,
    START,
    RuntimeGraphCommand,
    RuntimeGraphConditionalEdge,
    RuntimeGraphEdge,
    RuntimeGraphError,
    RuntimeGraphEvent,
    RuntimeGraphExecutor,
    RuntimeGraphInterrupt,
    RuntimeGraphInterrupted,
    RuntimeGraphPlan,
    RuntimeGraphSend,
    RuntimeRouteResult,
    linear_plan,
)
from .stores import (
    FileRuntimeGraphStore,
    MemoryRuntimeGraphStore,
    RuntimeGraphStoreError,
    RuntimeGraphStoreItem,
)
from .subgraphs import RuntimeGraphSubgraph
from .tools import RuntimeGraphTool, RuntimeGraphToolError, RuntimeGraphToolNode

__all__ = (
    "SemanticRuntime",
    "SemanticRuntimeError",
    "RuntimeGraphBindings",
    "BatchedEvidenceLeaf",
    "BatchedMerkleProof",
    "BatchedMerkleProofStep",
    "batched_evidence_leaf",
    "batched_merkle_proof",
    "batched_merkle_proof_verify",
    "batched_merkle_root",
    "batched_merkle_root_digests",
    "RuntimeGraphBuilder",
    "CrewAIAgentSpec",
    "CrewAIFlowResult",
    "CrewAIFlowSpec",
    "CrewAITaskSpec",
    "create_crewai_flow_executor",
    "crewai_flow_plan",
    "crewai_flow_receipt",
    "run_crewai_flow",
    "describe_runtime_graph_plan",
    "RuntimeGraphExecution",
    "RuntimeGraphProgram",
    "RuntimeGraphRegistries",
    "RuntimeReceipt",
    "parse_runtime_receipt",
    "END",
    "START",
    "RuntimeGraphConditionalEdge",
    "RuntimeGraphCommand",
    "RuntimeGraphSend",
    "RuntimeGraphEdge",
    "RuntimeGraphEvent",
    "RuntimeGraphError",
    "RuntimeGraphInterrupt",
    "RuntimeGraphInterrupted",
    "RuntimeGraphExecutor",
    "RuntimeGraphPlan",
    "RuntimeGraphSubgraph",
    "RuntimeGraphRuntime",
    "RuntimeGraphRuntimeError",
    "RuntimeRouteResult",
    "RuntimeGraphMessage",
    "RuntimeGraphToolCall",
    "RuntimeGraphTool",
    "RuntimeGraphToolError",
    "RuntimeGraphToolNode",
    "add_messages",
    "ai_message",
    "create_tool_call_loop",
    "human_message",
    "tool_message",
    "tools_condition",
    "FileRuntimeGraphStore",
    "MemoryRuntimeGraphStore",
    "RuntimeGraphStoreError",
    "RuntimeGraphStoreItem",
    "linear_plan",
    "FileRuntimeGraphCheckpointer",
    "MemoryRuntimeGraphCheckpointer",
    "RuntimeGraphCheckpoint",
    "RuntimeGraphCheckpointError",
    "TursoRuntimeGraphCheckpointer",
    "TursoRuntimeGraphStore",
    "TursoRuntimeGraphBackend",
    "turso_runtime_graph_backend",
    "RuntimeDurableAdapter",
    "RuntimeDurableEnvelopeManifest",
    "RuntimeDurablePolicyError",
    "RuntimeDurablePolicyManifest",
    "coerce_runtime_durable_envelope_manifest",
    "coerce_runtime_durable_policy_manifest",
    "RuntimeGraphStreamProjection",
    "DEFAULT_RUNTIME_GRAPH_STREAM_MODES",
    "AuthorizedEffectEvidenceError",
    "AuthorizedEffectEvidenceReconciliation",
    "AuthorizedEffectEvidenceReservation",
    "AuthorizedEffectEvidenceReceipt",
    "BatchedEvidenceCommitReceipt",
    "TursoAuthorizedEffectEvidenceStore",
    "authorized_effect_evidence_from_native",
    "authorized_effect_evidence_receipt",
    "load",
    "precompile_load",
    "preproject_load",
    "clear_load_cache",
    "AnyioFunFlowRuntime",
    "FunFlowDag",
    "FunFlowPlanProjection",
    "FunFlowRunReceipt",
    "FunFlowRuntimeError",
    "FunFlowSandbox",
    "FunFlowStep",
    "FunFlowStepReceipt",
    "json_schema_to_scheme_contract",
    "load_json_schema",
)
