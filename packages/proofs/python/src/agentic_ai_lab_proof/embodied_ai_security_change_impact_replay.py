# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import json

from agentic_ai_lab_proof.embodied_ai_security_relation_graph import (
    ArchitectureNode,
    ArchitectureRelation,
    NodeKind,
    RelationKind,
    TypedRelationGraph,
    project_change_impact,
)


def canonical_graph() -> TypedRelationGraph:
    nodes = (
        ArchitectureNode("robot-motion-stack", NodeKind.SYSTEM_COMPONENT),
        ArchitectureNode("motion-authority", NodeKind.ASSET),
        ArchitectureNode("command-injection", NodeKind.THREAT),
        ArchitectureNode("uncommanded-motion", NodeKind.RISK),
        ArchitectureNode("require-signed-command", NodeKind.SECURITY_REQUIREMENT),
        ArchitectureNode("command-admission-control", NodeKind.CONTROL),
        ArchitectureNode("command-admission-test", NodeKind.VERIFICATION_EVIDENCE),
        ArchitectureNode("residual-motion-risk", NodeKind.RESIDUAL_RISK),
        ArchitectureNode("safety-owner-acceptance", NodeKind.AUTHORITY_ACCEPTANCE),
        ArchitectureNode("motion-runtime-feedback", NodeKind.RUN_FEEDBACK),
    )
    relation_specs = (
        ("r01", RelationKind.OWNS, "robot-motion-stack", "motion-authority"),
        ("r02", RelationKind.EXPOSED_TO, "motion-authority", "command-injection"),
        ("r03", RelationKind.REALIZES, "command-injection", "uncommanded-motion"),
        ("r04", RelationKind.DERIVES, "uncommanded-motion", "require-signed-command"),
        (
            "r05",
            RelationKind.IMPLEMENTED_BY,
            "require-signed-command",
            "command-admission-control",
        ),
        (
            "r06",
            RelationKind.VERIFIED_BY,
            "command-admission-control",
            "command-admission-test",
        ),
        ("r07", RelationKind.LEAVES, "uncommanded-motion", "residual-motion-risk"),
        (
            "r08",
            RelationKind.ACCEPTED_BY,
            "residual-motion-risk",
            "safety-owner-acceptance",
        ),
        (
            "r09",
            RelationKind.OBSERVED_BY,
            "robot-motion-stack",
            "motion-runtime-feedback",
        ),
    )
    relations = tuple(
        ArchitectureRelation(
            relation_id=relation_id,
            kind=kind,
            source_id=source_id,
            target_id=target_id,
            forward=True,
            evidence_requirements=("typed-owner", "receipt-root"),
        )
        for relation_id, kind, source_id, target_id in relation_specs
    )
    return TypedRelationGraph(
        graph_id="embodied-ai-security-graph-v1", nodes=nodes, relations=relations
    )


def main() -> None:
    receipt = project_change_impact(canonical_graph(), ("robot-motion-stack",))
    print(json.dumps(receipt.to_dict(), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
