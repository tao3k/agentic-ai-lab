# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
from hashlib import sha256
import json


class NodeKind(StrEnum):
    SYSTEM_COMPONENT = "system-component"
    ASSET = "asset"
    THREAT = "threat"
    RISK = "risk"
    SECURITY_REQUIREMENT = "security-requirement"
    CONTROL = "control"
    VERIFICATION_EVIDENCE = "verification-evidence"
    RESIDUAL_RISK = "residual-risk"
    AUTHORITY_ACCEPTANCE = "authority-acceptance"
    RUN_FEEDBACK = "run-feedback"


class RelationKind(StrEnum):
    OWNS = "owns"
    EXPOSED_TO = "exposed-to"
    REALIZES = "realizes"
    DERIVES = "derives"
    IMPLEMENTED_BY = "implemented-by"
    VERIFIED_BY = "verified-by"
    LEAVES = "leaves"
    ACCEPTED_BY = "accepted-by"
    OBSERVED_BY = "observed-by"


ALLOWED_RELATION_KINDS: dict[RelationKind, tuple[NodeKind, NodeKind]] = {
    RelationKind.OWNS: (NodeKind.SYSTEM_COMPONENT, NodeKind.ASSET),
    RelationKind.EXPOSED_TO: (NodeKind.ASSET, NodeKind.THREAT),
    RelationKind.REALIZES: (NodeKind.THREAT, NodeKind.RISK),
    RelationKind.DERIVES: (NodeKind.RISK, NodeKind.SECURITY_REQUIREMENT),
    RelationKind.IMPLEMENTED_BY: (NodeKind.SECURITY_REQUIREMENT, NodeKind.CONTROL),
    RelationKind.VERIFIED_BY: (NodeKind.CONTROL, NodeKind.VERIFICATION_EVIDENCE),
    RelationKind.LEAVES: (NodeKind.RISK, NodeKind.RESIDUAL_RISK),
    RelationKind.ACCEPTED_BY: (
        NodeKind.RESIDUAL_RISK,
        NodeKind.AUTHORITY_ACCEPTANCE,
    ),
    RelationKind.OBSERVED_BY: (NodeKind.SYSTEM_COMPONENT, NodeKind.RUN_FEEDBACK),
}


@dataclass(frozen=True)
class ArchitectureNode:
    node_id: str
    kind: NodeKind


@dataclass(frozen=True)
class ArchitectureRelation:
    relation_id: str
    kind: RelationKind
    source_id: str
    target_id: str
    forward: bool
    evidence_requirements: tuple[str, ...]


@dataclass(frozen=True)
class TypedRelationGraph:
    graph_id: str
    nodes: tuple[ArchitectureNode, ...]
    relations: tuple[ArchitectureRelation, ...]


@dataclass(frozen=True)
class GraphValidation:
    admitted: bool
    issues: tuple[str, ...]


@dataclass(frozen=True)
class ChangeImpactReceipt:
    schema_id: str
    graph_id: str
    graph_digest: str
    changed_node_ids: tuple[str, ...]
    affected_node_ids: tuple[str, ...]
    invalidated_evidence_ids: tuple[str, ...]
    invalidated_acceptance_ids: tuple[str, ...]
    reopened_verification_obligations: tuple[str, ...]
    trace_root: str

    def to_dict(self) -> dict[str, object]:
        return {
            "affectedNodeIds": list(self.affected_node_ids),
            "changedNodeIds": list(self.changed_node_ids),
            "graphDigest": self.graph_digest,
            "graphId": self.graph_id,
            "invalidatedAcceptanceIds": list(self.invalidated_acceptance_ids),
            "invalidatedEvidenceIds": list(self.invalidated_evidence_ids),
            "reopenedVerificationObligations": list(
                self.reopened_verification_obligations
            ),
            "schemaId": self.schema_id,
            "traceRoot": self.trace_root,
        }


def _canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def graph_digest(graph: TypedRelationGraph) -> str:
    payload = {
        "graphId": graph.graph_id,
        "nodes": [
            {"kind": node.kind.value, "nodeId": node.node_id}
            for node in sorted(graph.nodes, key=lambda item: item.node_id)
        ],
        "relations": [
            {
                "evidenceRequirements": sorted(relation.evidence_requirements),
                "forward": relation.forward,
                "kind": relation.kind.value,
                "relationId": relation.relation_id,
                "sourceId": relation.source_id,
                "targetId": relation.target_id,
            }
            for relation in sorted(graph.relations, key=lambda item: item.relation_id)
        ],
    }
    return f"sha256:{sha256(_canonical_json(payload).encode()).hexdigest()}"


def validate_typed_relation_graph(graph: TypedRelationGraph) -> GraphValidation:
    issues: list[str] = []
    node_by_id: dict[str, ArchitectureNode] = {}
    relation_ids: set[str] = set()

    if not graph.graph_id:
        issues.append("empty-graph-id")

    for node in graph.nodes:
        if not node.node_id:
            issues.append("empty-node-id")
        elif node.node_id in node_by_id:
            issues.append(f"duplicate-node:{node.node_id}")
        else:
            node_by_id[node.node_id] = node

    for relation in graph.relations:
        if not relation.relation_id:
            issues.append("empty-relation-id")
        elif relation.relation_id in relation_ids:
            issues.append(f"duplicate-relation:{relation.relation_id}")
        relation_ids.add(relation.relation_id)

        source = node_by_id.get(relation.source_id)
        target = node_by_id.get(relation.target_id)
        if source is None:
            issues.append(f"missing-source:{relation.relation_id}")
        if target is None:
            issues.append(f"missing-target:{relation.relation_id}")
        if not relation.forward:
            issues.append(f"non-forward-relation:{relation.relation_id}")
        if not relation.evidence_requirements:
            issues.append(f"missing-evidence-requirement:{relation.relation_id}")
        expected = ALLOWED_RELATION_KINDS[relation.kind]
        if source is not None and target is not None:
            observed = (source.kind, target.kind)
            if observed != expected:
                issues.append(f"relation-kind-mismatch:{relation.relation_id}")

    return GraphValidation(admitted=not issues, issues=tuple(sorted(set(issues))))


def project_change_impact(
    graph: TypedRelationGraph, changed_node_ids: tuple[str, ...]
) -> ChangeImpactReceipt:
    validation = validate_typed_relation_graph(graph)
    if not validation.admitted:
        raise ValueError("invalid-typed-relation-graph:" + ",".join(validation.issues))

    node_by_id = {node.node_id: node for node in graph.nodes}
    changed = tuple(sorted(set(changed_node_ids)))
    missing = tuple(node_id for node_id in changed if node_id not in node_by_id)
    if not changed:
        raise ValueError("empty-change-set")
    if missing:
        raise ValueError("unknown-changed-node:" + ",".join(missing))

    outgoing: dict[str, list[str]] = {}
    for relation in graph.relations:
        outgoing.setdefault(relation.source_id, []).append(relation.target_id)

    affected = set(changed)
    frontier = list(changed)
    while frontier:
        source_id = frontier.pop()
        for target_id in sorted(outgoing.get(source_id, [])):
            if target_id not in affected:
                affected.add(target_id)
                frontier.append(target_id)

    affected_ids = tuple(sorted(affected))
    invalidated_evidence = tuple(
        node_id
        for node_id in affected_ids
        if node_by_id[node_id].kind is NodeKind.VERIFICATION_EVIDENCE
    )
    invalidated_acceptance = tuple(
        node_id
        for node_id in affected_ids
        if node_by_id[node_id].kind is NodeKind.AUTHORITY_ACCEPTANCE
    )
    reopened = tuple(
        f"verify:{node_id}"
        for node_id in affected_ids
        if node_by_id[node_id].kind is NodeKind.CONTROL
    )

    payload = {
        "affectedNodeIds": list(affected_ids),
        "changedNodeIds": list(changed),
        "graphDigest": graph_digest(graph),
        "graphId": graph.graph_id,
        "invalidatedAcceptanceIds": list(invalidated_acceptance),
        "invalidatedEvidenceIds": list(invalidated_evidence),
        "reopenedVerificationObligations": list(reopened),
        "schemaId": "agentic-ai-lab.ai-security.change-impact-receipt.v1",
    }
    trace_root = f"sha256:{sha256(_canonical_json(payload).encode()).hexdigest()}"
    return ChangeImpactReceipt(
        schema_id=str(payload["schemaId"]),
        graph_id=graph.graph_id,
        graph_digest=str(payload["graphDigest"]),
        changed_node_ids=changed,
        affected_node_ids=affected_ids,
        invalidated_evidence_ids=invalidated_evidence,
        invalidated_acceptance_ids=invalidated_acceptance,
        reopened_verification_obligations=reopened,
        trace_root=trace_root,
    )
