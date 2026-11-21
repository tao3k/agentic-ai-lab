# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import replace

import pytest

from agentic_ai_lab_proof.proof_base_receipt_graph import (
    AcceptedProofBaseReceiptNodeV1,
    AcceptedReceiptEvidenceV1,
    CanonicalInterfaceV1,
    CanonicalSourceIdentityV1,
    NamedInterfaceAssumptionV1,
    PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1,
    ProofBaseReceiptGraphError,
    ProofBaseReceiptGraphV1,
    ReceiptInterfaceEdgeV1,
    VERIFIED_COMPOSITION_RECEIPT_SCHEMA_V1,
    sha256_digest,
)


def canonical_interface(payload: bytes) -> CanonicalInterfaceV1:
    return CanonicalInterfaceV1(
        canonical_bytes=payload,
        digest=sha256_digest(payload),
    )


def acceptance(
    node_id: str,
    source_identity: CanonicalSourceIdentityV1,
    bundle_digest: str,
    provided_interface: CanonicalInterfaceV1,
) -> AcceptedReceiptEvidenceV1:
    payload = f"accepted:{node_id}".encode()
    return AcceptedReceiptEvidenceV1(
        engine_identity="axle+lean",
        canonical_receipt_bytes=payload,
        receipt_digest=sha256_digest(payload),
        bound_source_identity_digest=source_identity.digest,
        bound_independent_bundle_digest=bundle_digest,
        bound_provided_interface_digest=provided_interface.digest,
        decision="accepted",
    )


def node(
    node_id: str,
    provided: CanonicalInterfaceV1,
    assumptions: tuple[NamedInterfaceAssumptionV1, ...],
    declaration: str,
) -> AcceptedProofBaseReceiptNodeV1:
    source_payload = f"source:{node_id}".encode()
    bundle_payload = f"bundle:{node_id}".encode()
    source_identity = CanonicalSourceIdentityV1(
        canonical_bytes=source_payload,
        digest=sha256_digest(source_payload),
    )
    bundle_digest = sha256_digest(bundle_payload)
    return AcceptedProofBaseReceiptNodeV1(
        node_id=node_id,
        source_identity=source_identity,
        independent_bundle_digest=bundle_digest,
        root_declarations=(declaration,),
        provided_interface=provided,
        assumed_interfaces=assumptions,
        acceptance=acceptance(
            node_id,
            source_identity,
            bundle_digest,
            provided,
        ),
    )


def accepted_chain() -> ProofBaseReceiptGraphV1:
    base_interface = canonical_interface(b"canonical-interface:base")
    terminal_interface = canonical_interface(b"canonical-interface:terminal")
    base = node(
        "base",
        base_interface,
        (),
        "AgenticAILabProof.Base.verified",
    )
    terminal = node(
        "terminal",
        terminal_interface,
        (
            NamedInterfaceAssumptionV1(
                assumption_id="base-interface",
                interface=base_interface,
            ),
        ),
        "AgenticAILabProof.Terminal.verified",
    )
    return ProofBaseReceiptGraphV1(
        schema_id=PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1,
        nodes=(terminal, base),
        edges=(
            ReceiptInterfaceEdgeV1(
                supplier_node_id="base",
                consumer_node_id="terminal",
                consumer_assumption_id="base-interface",
            ),
        ),
        terminal_node_id="terminal",
    )


def test_accepts_closed_receipt_dag_and_emits_deterministic_receipt() -> None:
    graph = accepted_chain()

    receipt = graph.verify()
    reordered = replace(
        graph,
        nodes=tuple(reversed(graph.nodes)),
    ).verify()

    assert receipt.schema_id == VERIFIED_COMPOSITION_RECEIPT_SCHEMA_V1
    assert receipt.topological_order == ("base", "terminal")
    assert receipt.node_count == 2
    assert receipt.edge_count == 1
    assert receipt.root_declaration_count == 2
    assert receipt.graph_digest == reordered.graph_digest


def test_typed_graph_has_one_canonical_member_order() -> None:
    graph = accepted_chain()
    terminal = next(item for item in graph.nodes if item.node_id == "terminal")
    additional_assumption = NamedInterfaceAssumptionV1(
        assumption_id="another-role",
        interface=terminal.assumed_interfaces[0].interface,
    )
    reordered_terminal = replace(
        terminal,
        root_declarations=("z.declaration", "a.declaration"),
        assumed_interfaces=(
            terminal.assumed_interfaces[0],
            additional_assumption,
        ),
    )
    canonical_terminal = replace(
        terminal,
        root_declarations=("a.declaration", "z.declaration"),
        assumed_interfaces=(
            additional_assumption,
            terminal.assumed_interfaces[0],
        ),
    )
    reordered_graph = ProofBaseReceiptGraphV1(
        schema_id=graph.schema_id,
        nodes=tuple(
            reversed(graph.nodes)
        ),
        edges=tuple(reversed(graph.edges)),
        terminal_node_id=graph.terminal_node_id,
    )

    assert reordered_terminal == canonical_terminal
    assert reordered_graph == graph


def test_rejects_every_schema_other_than_the_single_v1_schema() -> None:
    graph = replace(accepted_chain(), schema_id="proof-base-receipt-graph")

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        graph.verify()

    assert error.value.code == "invalid-schema"


def test_rejects_nonaccepted_receipt_evidence() -> None:
    graph = accepted_chain()
    base = next(item for item in graph.nodes if item.node_id == "base")

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        replace(base.acceptance, decision="rejected")

    assert error.value.code == "receipt-not-accepted"


def test_rejects_acceptance_evidence_bound_to_another_bundle() -> None:
    graph = accepted_chain()
    base = next(item for item in graph.nodes if item.node_id == "base")
    mismatched_acceptance = replace(
        base.acceptance,
        bound_independent_bundle_digest=sha256_digest(b"another-bundle"),
    )

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        replace(base, acceptance=mismatched_acceptance)

    assert error.value.code == "acceptance-binding-mismatch"


def test_rejects_canonical_payload_digest_mismatch() -> None:
    with pytest.raises(ProofBaseReceiptGraphError) as error:
        CanonicalInterfaceV1(
            canonical_bytes=b"canonical-interface",
            digest=sha256_digest(b"different-interface"),
        )

    assert error.value.code == "canonical-payload-digest-mismatch"


def test_rejects_digest_valid_but_nonidentical_interface_bytes() -> None:
    graph = accepted_chain()
    terminal = next(item for item in graph.nodes if item.node_id == "terminal")
    different = canonical_interface(b"canonical-interface:different")
    mismatched_terminal = replace(
        terminal,
        assumed_interfaces=(
            NamedInterfaceAssumptionV1(
                assumption_id="base-interface",
                interface=different,
            ),
        ),
    )
    mismatched_graph = replace(
        graph,
        nodes=tuple(
            mismatched_terminal if item.node_id == "terminal" else item
            for item in graph.nodes
        ),
    )

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        mismatched_graph.verify()

    assert error.value.code == "canonical-interface-mismatch"


def test_rejects_unresolved_interface_assumption() -> None:
    graph = replace(accepted_chain(), edges=())

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        graph.verify()

    assert error.value.code == "unresolved-interface-assumption"


def test_rejects_cyclic_receipt_dependency() -> None:
    graph = accepted_chain()
    base = next(item for item in graph.nodes if item.node_id == "base")
    terminal = next(item for item in graph.nodes if item.node_id == "terminal")
    terminal_interface = terminal.provided_interface
    sink = node(
        "sink",
        canonical_interface(b"canonical-interface:sink"),
        (
            NamedInterfaceAssumptionV1(
                assumption_id="terminal-interface",
                interface=terminal_interface,
            ),
        ),
        "AgenticAILabProof.Sink.verified",
    )
    cyclic_base = replace(
        base,
        assumed_interfaces=(
            NamedInterfaceAssumptionV1(
                assumption_id="terminal-interface",
                interface=terminal_interface,
            ),
        ),
    )
    cyclic_graph = replace(
        graph,
        nodes=(
            *(
                cyclic_base if item.node_id == "base" else item
                for item in graph.nodes
            ),
            sink,
        ),
        edges=(
            *graph.edges,
            ReceiptInterfaceEdgeV1(
                supplier_node_id="terminal",
                consumer_node_id="base",
                consumer_assumption_id="terminal-interface",
            ),
            ReceiptInterfaceEdgeV1(
                supplier_node_id="terminal",
                consumer_node_id="sink",
                consumer_assumption_id="terminal-interface",
            ),
        ),
        terminal_node_id="sink",
    )

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        cyclic_graph.verify()

    assert error.value.code == "cyclic-receipt-graph"


def test_one_supplier_can_close_multiple_named_consumer_assumptions() -> None:
    graph = accepted_chain()
    terminal = next(item for item in graph.nodes if item.node_id == "terminal")
    base_interface = next(
        item for item in graph.nodes if item.node_id == "base"
    ).provided_interface
    extended_terminal = replace(
        terminal,
        assumed_interfaces=(
            *terminal.assumed_interfaces,
            NamedInterfaceAssumptionV1(
                assumption_id="same-base-interface-under-another-role",
                interface=base_interface,
            ),
        ),
    )
    extended_graph = replace(
        graph,
        nodes=tuple(
            extended_terminal if item.node_id == "terminal" else item
            for item in graph.nodes
        ),
        edges=(
            *graph.edges,
            ReceiptInterfaceEdgeV1(
                supplier_node_id="base",
                consumer_node_id="terminal",
                consumer_assumption_id=(
                    "same-base-interface-under-another-role"
                ),
            ),
        ),
    )

    receipt = extended_graph.verify()

    assert receipt.topological_order == ("base", "terminal")
    assert receipt.edge_count == 2


def test_rejects_node_outside_terminal_closure() -> None:
    graph = accepted_chain()
    unrelated = node(
        "unrelated",
        canonical_interface(b"canonical-interface:unrelated"),
        (),
        "AgenticAILabProof.Unrelated.verified",
    )
    disconnected_graph = replace(
        graph,
        nodes=(*graph.nodes, unrelated),
    )

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        disconnected_graph.verify()

    assert error.value.code == "node-outside-terminal-closure"


def test_rejects_overlapping_root_declaration_owners() -> None:
    graph = accepted_chain()
    terminal = next(item for item in graph.nodes if item.node_id == "terminal")
    overlapping_terminal = replace(
        terminal,
        root_declarations=("AgenticAILabProof.Base.verified",),
    )
    overlapping_graph = replace(
        graph,
        nodes=tuple(
            overlapping_terminal if item.node_id == "terminal" else item
            for item in graph.nodes
        ),
    )

    with pytest.raises(ProofBaseReceiptGraphError) as error:
        overlapping_graph.verify()

    assert error.value.code == "root-declaration-owner-overlap"
