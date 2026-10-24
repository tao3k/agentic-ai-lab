# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import replace
import json

import pytest

import agentic_ai_lab_proof.cli as proof_cli
from agentic_ai_lab_proof.proof_base_receipt_graph import (
    AcceptedProofBaseReceiptNodeV1,
    AcceptedReceiptEvidenceV1,
    CanonicalInterfaceV1,
    CanonicalSourceIdentityV1,
    NamedInterfaceAssumptionV1,
    PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1,
    ProofBaseReceiptGraphV1,
    ReceiptInterfaceEdgeV1,
    sha256_digest,
)
from agentic_ai_lab_proof.proof_base_receipt_graph_audit import (
    PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1,
    ProofBaseReceiptGraphAuditError,
    decode_proof_base_receipt_graph_audit_v1,
    encode_proof_base_receipt_graph_audit_v1,
)
from agentic_ai_lab_proof.receipt_acceptance_authority import (
    AuthorityVerifiedReceiptEvidenceV1,
    DeclaredReceiptEvidenceV1,
    ReceiptAcceptanceAuthorityError,
)


def interface(payload: bytes) -> CanonicalInterfaceV1:
    return CanonicalInterfaceV1(
        canonical_bytes=payload,
        digest=sha256_digest(payload),
    )


def graph_node(
    node_id: str,
    *,
    provided: CanonicalInterfaceV1,
    assumptions: tuple[NamedInterfaceAssumptionV1, ...],
    declaration: str,
) -> AcceptedProofBaseReceiptNodeV1:
    source_bytes = f"source:{node_id}".encode()
    source_identity = CanonicalSourceIdentityV1(
        canonical_bytes=source_bytes,
        digest=sha256_digest(source_bytes),
    )
    bundle_digest = sha256_digest(f"bundle:{node_id}".encode())
    receipt_bytes = b"\x00accepted:" + node_id.encode() + b"\xff"
    acceptance = AcceptedReceiptEvidenceV1(
        engine_identity="axle+lean",
        canonical_receipt_bytes=receipt_bytes,
        receipt_digest=sha256_digest(receipt_bytes),
        bound_source_identity_digest=source_identity.digest,
        bound_independent_bundle_digest=bundle_digest,
        bound_provided_interface_digest=provided.digest,
        decision="accepted",
    )
    return AcceptedProofBaseReceiptNodeV1(
        node_id=node_id,
        source_identity=source_identity,
        independent_bundle_digest=bundle_digest,
        root_declarations=(declaration,),
        provided_interface=provided,
        assumed_interfaces=assumptions,
        acceptance=acceptance,
    )


def accepted_graph() -> ProofBaseReceiptGraphV1:
    base_interface = interface(b"\x00base-interface\xff")
    terminal_interface = interface(b"terminal-interface")
    base = graph_node(
        "base",
        provided=base_interface,
        assumptions=(),
        declaration="AgenticAILabProof.Base.verified",
    )
    terminal = graph_node(
        "terminal",
        provided=terminal_interface,
        assumptions=(
            NamedInterfaceAssumptionV1(
                assumption_id="base",
                interface=base_interface,
            ),
        ),
        declaration="AgenticAILabProof.Terminal.verified",
    )
    return ProofBaseReceiptGraphV1(
        schema_id=PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1,
        nodes=(terminal, base),
        edges=(
            ReceiptInterfaceEdgeV1(
                supplier_node_id="base",
                consumer_node_id="terminal",
                consumer_assumption_id="base",
            ),
        ),
        terminal_node_id="terminal",
    )


def canonical_json(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode()


def decoded_object(graph: ProofBaseReceiptGraphV1 | None = None) -> dict:
    return json.loads(
        encode_proof_base_receipt_graph_audit_v1(
            accepted_graph() if graph is None else graph
        )
    )


class StaticReceiptAuthority:
    def __init__(self, graph: ProofBaseReceiptGraphV1) -> None:
        self._evidence = {
            node.acceptance.receipt_digest: (
                AuthorityVerifiedReceiptEvidenceV1(
                    acceptance=node.acceptance,
                    source_identity=node.source_identity,
                    independent_bundle_digest=(
                        node.independent_bundle_digest
                    ),
                    provided_interface=node.provided_interface,
                    root_declarations=node.root_declarations,
                )
            )
            for node in graph.nodes
        }

    def validate(
        self,
        declared: DeclaredReceiptEvidenceV1,
    ) -> AuthorityVerifiedReceiptEvidenceV1:
        evidence = self._evidence.get(declared.receipt_digest)
        if evidence is None:
            raise ReceiptAcceptanceAuthorityError(
                "receipt-not-issued",
                "test authority did not issue this receipt",
            )
        if (
            evidence.acceptance.engine_identity
            != declared.engine_identity
            or evidence.acceptance.canonical_receipt_bytes
            != declared.canonical_receipt_bytes
        ):
            raise ReceiptAcceptanceAuthorityError(
                "receipt-content-mismatch",
                "declared receipt differs from authority evidence",
            )
        return evidence


def decode_audit(
    payload: bytes,
    graph: ProofBaseReceiptGraphV1 | None = None,
):
    authority_graph = accepted_graph() if graph is None else graph
    return decode_proof_base_receipt_graph_audit_v1(
        payload,
        authority=StaticReceiptAuthority(authority_graph),
    )


def test_canonical_audit_round_trip_preserves_typed_graph_and_receipt() -> None:
    graph = accepted_graph()
    encoded = encode_proof_base_receipt_graph_audit_v1(graph)

    decoded = decode_audit(encoded, graph)

    assert decoded.graph == graph
    assert decoded.verified_receipt == graph.verify()
    assert decoded.canonical_audit_bytes == encoded
    assert json.loads(encoded)["schema_id"] == (
        PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1
    )


def test_encoding_is_independent_of_input_node_order() -> None:
    graph = accepted_graph()
    reordered = replace(graph, nodes=tuple(reversed(graph.nodes)))

    assert encode_proof_base_receipt_graph_audit_v1(graph) == (
        encode_proof_base_receipt_graph_audit_v1(reordered)
    )


def test_rejects_any_other_audit_schema() -> None:
    artifact = decoded_object()
    artifact["schema_id"] = "agentic-ai-lab.proof-base-receipt-graph-audit"

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "invalid-audit-schema"


def test_rejects_missing_or_unknown_fields() -> None:
    missing = decoded_object()
    del missing["graph"]["terminal_node_id"]
    unknown = decoded_object()
    unknown["graph"]["alternate_terminal"] = "terminal"

    with pytest.raises(ProofBaseReceiptGraphAuditError) as missing_error:
        decode_audit(canonical_json(missing))
    with pytest.raises(ProofBaseReceiptGraphAuditError) as unknown_error:
        decode_audit(canonical_json(unknown))

    assert missing_error.value.code == "audit-shape-mismatch"
    assert unknown_error.value.code == "audit-shape-mismatch"


def test_rejects_duplicate_json_keys() -> None:
    payload = (
        b'{"graph":{},"schema_id":"'
        + PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1.encode()
        + b'","schema_id":"'
        + PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1.encode()
        + b'","verified_composition_receipt":{}}'
    )

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(payload)

    assert error.value.code == "duplicate-audit-key"


def test_rejects_noncanonical_json_bytes() -> None:
    encoded = encode_proof_base_receipt_graph_audit_v1(accepted_graph())
    noncanonical = json.dumps(json.loads(encoded), indent=2).encode()

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(noncanonical)

    assert error.value.code == "noncanonical-audit-bytes"


def test_rejects_noncanonical_hex_even_when_it_decodes_to_same_bytes() -> None:
    artifact = decoded_object()
    source_hex = artifact["graph"]["nodes"][0]["source_identity"][
        "canonical_bytes_hex"
    ]
    artifact["graph"]["nodes"][0]["source_identity"][
        "canonical_bytes_hex"
    ] = source_hex.upper()

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "noncanonical-audit-hex"


def test_rejects_declared_verified_receipt_that_differs_from_graph() -> None:
    artifact = decoded_object()
    artifact["verified_composition_receipt"]["node_count"] = 999

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "verified-receipt-mismatch"


def test_rejects_transport_graph_with_unresolved_edge() -> None:
    artifact = decoded_object()
    artifact["graph"]["edges"][0]["consumer_assumption_id"] = "missing"

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "invalid-audit-graph"


def test_rejects_integer_fields_encoded_as_json_booleans() -> None:
    artifact = decoded_object()
    artifact["verified_composition_receipt"]["node_count"] = True

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "audit-type-mismatch"


def test_audit_cannot_mint_acceptance_from_self_reported_fields() -> None:
    artifact = decoded_object()
    artifact["graph"]["nodes"][0]["acceptance"]["decision"] = "accepted"

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact))

    assert error.value.code == "audit-shape-mismatch"


def test_substituted_authority_receipt_cannot_bind_another_node() -> None:
    graph = accepted_graph()
    artifact = decoded_object(graph)
    artifact["graph"]["nodes"][0]["acceptance"] = artifact["graph"]["nodes"][1][
        "acceptance"
    ]

    with pytest.raises(ProofBaseReceiptGraphAuditError) as error:
        decode_audit(canonical_json(artifact), graph)

    assert error.value.code in {
        "authority-root-declaration-mismatch",
        "authority-node-binding-mismatch",
    }


def test_standard_cli_requires_authority_before_writing_output(
    tmp_path,
    monkeypatch,
) -> None:
    graph = accepted_graph()
    input_path = tmp_path / "receipt-graph.json"
    output_path = tmp_path / "verified-receipt-graph.json"
    input_path.write_bytes(
        encode_proof_base_receipt_graph_audit_v1(graph)
    )
    monkeypatch.setattr(
        proof_cli,
        "LiveAxleClosureReceiptAuthorityV1",
        lambda **arguments: StaticReceiptAuthority(graph),
    )

    result = proof_cli.main(
        [
            "verify-receipt-graph-audit",
            "--input",
            str(input_path),
            "--output",
            str(output_path),
            "--lean-root",
            str(tmp_path),
        ]
    )

    assert result == 0
    assert output_path.read_bytes() == input_path.read_bytes()
