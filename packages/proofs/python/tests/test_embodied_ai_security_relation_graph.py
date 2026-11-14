# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from dataclasses import replace

import pytest

from agentic_ai_lab_proof.embodied_ai_security_change_impact_replay import canonical_graph
from agentic_ai_lab_proof.embodied_ai_security_relation_graph import (
    ArchitectureNode,
    NodeKind,
    project_change_impact,
    validate_typed_relation_graph,
)


def test_canonical_graph_is_typed_and_closed() -> None:
    result = validate_typed_relation_graph(canonical_graph())
    assert result.admitted
    assert result.issues == ()


def test_dangling_relation_fails_closed() -> None:
    graph = canonical_graph()
    bad_relation = replace(graph.relations[0], source_id="missing-component")
    result = validate_typed_relation_graph(
        replace(graph, relations=(bad_relation, *graph.relations[1:]))
    )
    assert not result.admitted
    assert result.issues == ("missing-source:r01",)


def test_label_only_relation_cannot_cross_node_kinds() -> None:
    graph = canonical_graph()
    bad_nodes = tuple(
        ArchitectureNode(node.node_id, NodeKind.THREAT)
        if node.node_id == "command-admission-control"
        else node
        for node in graph.nodes
    )
    result = validate_typed_relation_graph(replace(graph, nodes=bad_nodes))
    assert not result.admitted
    assert "relation-kind-mismatch:r05" in result.issues
    assert "relation-kind-mismatch:r06" in result.issues


def test_missing_relation_evidence_requirement_fails_closed() -> None:
    graph = canonical_graph()
    bad_relation = replace(graph.relations[0], evidence_requirements=())
    result = validate_typed_relation_graph(
        replace(graph, relations=(bad_relation, *graph.relations[1:]))
    )
    assert not result.admitted
    assert result.issues == ("missing-evidence-requirement:r01",)


def test_invalid_graph_cannot_project_change_impact() -> None:
    graph = canonical_graph()
    bad_relation = replace(graph.relations[0], forward=False)
    with pytest.raises(ValueError, match="invalid-typed-relation-graph"):
        project_change_impact(
            replace(graph, relations=(bad_relation, *graph.relations[1:])),
            ("robot-motion-stack",),
        )


def test_unknown_change_subject_fails_closed() -> None:
    with pytest.raises(ValueError, match="unknown-changed-node"):
        project_change_impact(canonical_graph(), ("unknown-component",))


def test_change_impact_invalidates_evidence_and_acceptance() -> None:
    receipt = project_change_impact(canonical_graph(), ("robot-motion-stack",))
    assert receipt.invalidated_evidence_ids == ("command-admission-test",)
    assert receipt.invalidated_acceptance_ids == ("safety-owner-acceptance",)
    assert receipt.reopened_verification_obligations == (
        "verify:command-admission-control",
    )


def test_change_impact_is_order_and_replay_deterministic() -> None:
    graph = canonical_graph()
    first = project_change_impact(graph, ("robot-motion-stack",))
    second = project_change_impact(
        replace(graph, nodes=tuple(reversed(graph.nodes))),
        ("robot-motion-stack", "robot-motion-stack"),
    )
    assert first.to_dict() == second.to_dict()
