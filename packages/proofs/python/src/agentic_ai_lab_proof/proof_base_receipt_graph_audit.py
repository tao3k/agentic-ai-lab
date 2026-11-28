# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
import json
import re
from typing import Any

from .proof_base_receipt_graph import (
    AcceptedProofBaseReceiptNodeV1,
    AcceptedReceiptEvidenceV1,
    CanonicalInterfaceV1,
    CanonicalSourceIdentityV1,
    NamedInterfaceAssumptionV1,
    ProofBaseReceiptGraphError,
    ProofBaseReceiptGraphV1,
    ReceiptInterfaceEdgeV1,
    VerifiedCompositionReceiptV1,
)
from .receipt_acceptance_authority import (
    DeclaredReceiptEvidenceV1,
    ReceiptAcceptanceAuthorityError,
    ReceiptAcceptanceAuthorityV1,
)


PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1 = (
    "agentic-ai-lab.proof-base-receipt-graph-audit.v1"
)

_LOWER_HEX_PATTERN = re.compile(r"(?:[0-9a-f]{2})*")


class ProofBaseReceiptGraphAuditError(ValueError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


@dataclass(frozen=True)
class DecodedProofBaseReceiptGraphAuditV1:
    graph: ProofBaseReceiptGraphV1
    verified_receipt: VerifiedCompositionReceiptV1
    canonical_audit_bytes: bytes


def _exact_object(
    value: Any,
    *,
    label: str,
    keys: frozenset[str],
) -> dict[str, Any]:
    if type(value) is not dict:
        raise ProofBaseReceiptGraphAuditError(
            "audit-type-mismatch",
            f"{label} must be an object",
        )
    actual_keys = frozenset(value)
    if actual_keys != keys:
        missing = sorted(keys - actual_keys)
        unknown = sorted(actual_keys - keys)
        raise ProofBaseReceiptGraphAuditError(
            "audit-shape-mismatch",
            f"{label} missing={missing} unknown={unknown}",
        )
    return value


def _exact_array(value: Any, *, label: str) -> list[Any]:
    if type(value) is not list:
        raise ProofBaseReceiptGraphAuditError(
            "audit-type-mismatch",
            f"{label} must be an array",
        )
    return value


def _exact_string(value: Any, *, label: str) -> str:
    if type(value) is not str:
        raise ProofBaseReceiptGraphAuditError(
            "audit-type-mismatch",
            f"{label} must be a string",
        )
    return value


def _exact_integer(value: Any, *, label: str) -> int:
    if type(value) is not int:
        raise ProofBaseReceiptGraphAuditError(
            "audit-type-mismatch",
            f"{label} must be an integer",
        )
    return value


def _decode_hex(value: Any, *, label: str) -> bytes:
    encoded = _exact_string(value, label=label)
    if _LOWER_HEX_PATTERN.fullmatch(encoded) is None:
        raise ProofBaseReceiptGraphAuditError(
            "noncanonical-audit-hex",
            f"{label} must use even-length lowercase hexadecimal",
        )
    return bytes.fromhex(encoded)


def _reject_duplicate_object_keys(
    pairs: list[tuple[str, Any]],
) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ProofBaseReceiptGraphAuditError(
                "duplicate-audit-key",
                f"duplicate object key {key}",
            )
        result[key] = value
    return result


def _interface_object(interface: CanonicalInterfaceV1) -> dict[str, Any]:
    return {
        "canonical_bytes_hex": interface.canonical_bytes.hex(),
        "digest": interface.digest,
    }


def _source_identity_object(
    source_identity: CanonicalSourceIdentityV1,
) -> dict[str, Any]:
    return {
        "canonical_bytes_hex": source_identity.canonical_bytes.hex(),
        "digest": source_identity.digest,
    }


def _acceptance_object(
    acceptance: AcceptedReceiptEvidenceV1,
) -> dict[str, Any]:
    return {
        "canonical_receipt_bytes_hex": (
            acceptance.canonical_receipt_bytes.hex()
        ),
        "engine_identity": acceptance.engine_identity,
        "receipt_digest": acceptance.receipt_digest,
    }


def _node_object(
    node: AcceptedProofBaseReceiptNodeV1,
) -> dict[str, Any]:
    return {
        "acceptance": _acceptance_object(node.acceptance),
        "assumed_interfaces": [
            {
                "assumption_id": assumption.assumption_id,
                "interface": _interface_object(assumption.interface),
            }
            for assumption in sorted(
                node.assumed_interfaces,
                key=lambda item: item.assumption_id,
            )
        ],
        "independent_bundle_digest": node.independent_bundle_digest,
        "node_id": node.node_id,
        "provided_interface": _interface_object(node.provided_interface),
        "root_declarations": sorted(node.root_declarations),
        "source_identity": _source_identity_object(node.source_identity),
    }


def _edge_object(edge: ReceiptInterfaceEdgeV1) -> dict[str, Any]:
    return {
        "consumer_assumption_id": edge.consumer_assumption_id,
        "consumer_node_id": edge.consumer_node_id,
        "supplier_node_id": edge.supplier_node_id,
    }


def _verified_receipt_object(
    receipt: VerifiedCompositionReceiptV1,
) -> dict[str, Any]:
    return {
        "edge_count": receipt.edge_count,
        "graph_digest": receipt.graph_digest,
        "node_count": receipt.node_count,
        "root_declaration_count": receipt.root_declaration_count,
        "schema_id": receipt.schema_id,
        "terminal_node_id": receipt.terminal_node_id,
        "topological_order": list(receipt.topological_order),
    }


def _audit_object(
    graph: ProofBaseReceiptGraphV1,
    receipt: VerifiedCompositionReceiptV1,
) -> dict[str, Any]:
    return {
        "graph": {
            "edges": [
                _edge_object(edge)
                for edge in sorted(
                    graph.edges,
                    key=lambda item: (
                        item.supplier_node_id,
                        item.consumer_node_id,
                        item.consumer_assumption_id,
                    ),
                )
            ],
            "nodes": [
                _node_object(node)
                for node in sorted(
                    graph.nodes,
                    key=lambda item: item.node_id,
                )
            ],
            "schema_id": graph.schema_id,
            "terminal_node_id": graph.terminal_node_id,
        },
        "schema_id": PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1,
        "verified_composition_receipt": _verified_receipt_object(receipt),
    }


def encode_proof_base_receipt_graph_audit_v1(
    graph: ProofBaseReceiptGraphV1,
) -> bytes:
    receipt = graph.verify()
    return json.dumps(
        _audit_object(graph, receipt),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _parse_interface(
    value: Any,
    *,
    label: str,
) -> CanonicalInterfaceV1:
    interface = _exact_object(
        value,
        label=label,
        keys=frozenset({"canonical_bytes_hex", "digest"}),
    )
    return CanonicalInterfaceV1(
        canonical_bytes=_decode_hex(
            interface["canonical_bytes_hex"],
            label=f"{label}.canonical_bytes_hex",
        ),
        digest=_exact_string(
            interface["digest"],
            label=f"{label}.digest",
        ),
    )


def _parse_source_identity(value: Any) -> CanonicalSourceIdentityV1:
    source_identity = _exact_object(
        value,
        label="node.source_identity",
        keys=frozenset({"canonical_bytes_hex", "digest"}),
    )
    return CanonicalSourceIdentityV1(
        canonical_bytes=_decode_hex(
            source_identity["canonical_bytes_hex"],
            label="node.source_identity.canonical_bytes_hex",
        ),
        digest=_exact_string(
            source_identity["digest"],
            label="node.source_identity.digest",
        ),
    )


def _parse_acceptance(
    value: Any,
    authority: ReceiptAcceptanceAuthorityV1,
):
    acceptance = _exact_object(
        value,
        label="node.acceptance",
        keys=frozenset(
            {
                "canonical_receipt_bytes_hex",
                "engine_identity",
                "receipt_digest",
            }
        ),
    )
    try:
        declared = DeclaredReceiptEvidenceV1(
            engine_identity=_exact_string(
                acceptance["engine_identity"],
                label="node.acceptance.engine_identity",
            ),
            canonical_receipt_bytes=_decode_hex(
                acceptance["canonical_receipt_bytes_hex"],
                label="node.acceptance.canonical_receipt_bytes_hex",
            ),
            receipt_digest=_exact_string(
                acceptance["receipt_digest"],
                label="node.acceptance.receipt_digest",
            ),
        )
        return authority.validate(declared)
    except ReceiptAcceptanceAuthorityError as error:
        raise ProofBaseReceiptGraphAuditError(
            "authority-receipt-rejected",
            f"{error.code}: {error.detail}",
        ) from error


def _parse_node(
    value: Any,
    authority: ReceiptAcceptanceAuthorityV1,
) -> AcceptedProofBaseReceiptNodeV1:
    node = _exact_object(
        value,
        label="graph.node",
        keys=frozenset(
            {
                "acceptance",
                "assumed_interfaces",
                "independent_bundle_digest",
                "node_id",
                "provided_interface",
                "root_declarations",
                "source_identity",
            }
        ),
    )
    assumptions = []
    for assumption_value in _exact_array(
        node["assumed_interfaces"],
        label="node.assumed_interfaces",
    ):
        assumption = _exact_object(
            assumption_value,
            label="node.assumed_interface",
            keys=frozenset({"assumption_id", "interface"}),
        )
        assumptions.append(
            NamedInterfaceAssumptionV1(
                assumption_id=_exact_string(
                    assumption["assumption_id"],
                    label="node.assumed_interface.assumption_id",
                ),
                interface=_parse_interface(
                    assumption["interface"],
                    label="node.assumed_interface.interface",
                ),
            )
        )
    root_declarations = tuple(
        _exact_string(
            declaration,
            label="node.root_declaration",
        )
        for declaration in _exact_array(
            node["root_declarations"],
            label="node.root_declarations",
        )
    )
    authority_evidence = _parse_acceptance(
        node["acceptance"],
        authority,
    )
    source_identity = _parse_source_identity(node["source_identity"])
    independent_bundle_digest = _exact_string(
        node["independent_bundle_digest"],
        label="node.independent_bundle_digest",
    )
    provided_interface = _parse_interface(
        node["provided_interface"],
        label="node.provided_interface",
    )
    if authority_evidence.root_declarations != tuple(
        sorted(root_declarations)
    ):
        raise ProofBaseReceiptGraphAuditError(
            "authority-root-declaration-mismatch",
            "authority roots must equal the graph node roots",
        )
    if (
        authority_evidence.source_identity != source_identity
        or authority_evidence.independent_bundle_digest
        != independent_bundle_digest
        or authority_evidence.provided_interface != provided_interface
    ):
        raise ProofBaseReceiptGraphAuditError(
            "authority-node-binding-mismatch",
            "authority-derived identities must equal the graph node identities",
        )
    return AcceptedProofBaseReceiptNodeV1(
        node_id=_exact_string(node["node_id"], label="node.node_id"),
        source_identity=source_identity,
        independent_bundle_digest=independent_bundle_digest,
        root_declarations=root_declarations,
        provided_interface=provided_interface,
        assumed_interfaces=tuple(assumptions),
        acceptance=authority_evidence.acceptance,
    )


def _parse_edge(value: Any) -> ReceiptInterfaceEdgeV1:
    edge = _exact_object(
        value,
        label="graph.edge",
        keys=frozenset(
            {
                "consumer_assumption_id",
                "consumer_node_id",
                "supplier_node_id",
            }
        ),
    )
    return ReceiptInterfaceEdgeV1(
        supplier_node_id=_exact_string(
            edge["supplier_node_id"],
            label="edge.supplier_node_id",
        ),
        consumer_node_id=_exact_string(
            edge["consumer_node_id"],
            label="edge.consumer_node_id",
        ),
        consumer_assumption_id=_exact_string(
            edge["consumer_assumption_id"],
            label="edge.consumer_assumption_id",
        ),
    )


def _parse_declared_receipt(value: Any) -> dict[str, Any]:
    receipt = _exact_object(
        value,
        label="verified_composition_receipt",
        keys=frozenset(
            {
                "edge_count",
                "graph_digest",
                "node_count",
                "root_declaration_count",
                "schema_id",
                "terminal_node_id",
                "topological_order",
            }
        ),
    )
    return {
        "edge_count": _exact_integer(
            receipt["edge_count"],
            label="verified_composition_receipt.edge_count",
        ),
        "graph_digest": _exact_string(
            receipt["graph_digest"],
            label="verified_composition_receipt.graph_digest",
        ),
        "node_count": _exact_integer(
            receipt["node_count"],
            label="verified_composition_receipt.node_count",
        ),
        "root_declaration_count": _exact_integer(
            receipt["root_declaration_count"],
            label="verified_composition_receipt.root_declaration_count",
        ),
        "schema_id": _exact_string(
            receipt["schema_id"],
            label="verified_composition_receipt.schema_id",
        ),
        "terminal_node_id": _exact_string(
            receipt["terminal_node_id"],
            label="verified_composition_receipt.terminal_node_id",
        ),
        "topological_order": [
            _exact_string(
                node_id,
                label="verified_composition_receipt.topological_order",
            )
            for node_id in _exact_array(
                receipt["topological_order"],
                label="verified_composition_receipt.topological_order",
            )
        ],
    }


def decode_proof_base_receipt_graph_audit_v1(
    audit_bytes: bytes,
    *,
    authority: ReceiptAcceptanceAuthorityV1,
) -> DecodedProofBaseReceiptGraphAuditV1:
    if type(audit_bytes) is not bytes:
        raise ProofBaseReceiptGraphAuditError(
            "audit-type-mismatch",
            "audit artifact must be bytes",
        )
    try:
        decoded = json.loads(
            audit_bytes.decode("utf-8"),
            object_pairs_hook=_reject_duplicate_object_keys,
        )
    except ProofBaseReceiptGraphAuditError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ProofBaseReceiptGraphAuditError(
            "invalid-audit-json",
            str(error),
        ) from error

    artifact = _exact_object(
        decoded,
        label="audit",
        keys=frozenset(
            {
                "graph",
                "schema_id",
                "verified_composition_receipt",
            }
        ),
    )
    schema_id = _exact_string(
        artifact["schema_id"],
        label="audit.schema_id",
    )
    if schema_id != PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1:
        raise ProofBaseReceiptGraphAuditError(
            "invalid-audit-schema",
            f"expected {PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1}",
        )

    graph_object = _exact_object(
        artifact["graph"],
        label="graph",
        keys=frozenset(
            {
                "edges",
                "nodes",
                "schema_id",
                "terminal_node_id",
            }
        ),
    )
    graph = ProofBaseReceiptGraphV1(
        schema_id=_exact_string(
            graph_object["schema_id"],
            label="graph.schema_id",
        ),
        nodes=tuple(
            _parse_node(node, authority)
            for node in _exact_array(
                graph_object["nodes"],
                label="graph.nodes",
            )
        ),
        edges=tuple(
            _parse_edge(edge)
            for edge in _exact_array(
                graph_object["edges"],
                label="graph.edges",
            )
        ),
        terminal_node_id=_exact_string(
            graph_object["terminal_node_id"],
            label="graph.terminal_node_id",
        ),
    )
    try:
        receipt = graph.verify()
    except ProofBaseReceiptGraphError as error:
        raise ProofBaseReceiptGraphAuditError(
            "invalid-audit-graph",
            f"{error.code}: {error.detail}",
        ) from error

    declared_receipt = _parse_declared_receipt(
        artifact["verified_composition_receipt"]
    )
    if declared_receipt != _verified_receipt_object(receipt):
        raise ProofBaseReceiptGraphAuditError(
            "verified-receipt-mismatch",
            "declared verified composition receipt does not match the graph",
        )

    canonical_audit_bytes = encode_proof_base_receipt_graph_audit_v1(graph)
    if audit_bytes != canonical_audit_bytes:
        raise ProofBaseReceiptGraphAuditError(
            "noncanonical-audit-bytes",
            "accepted audit bytes must equal the unique v1 encoding",
        )

    return DecodedProofBaseReceiptGraphAuditV1(
        graph=graph,
        verified_receipt=receipt,
        canonical_audit_bytes=canonical_audit_bytes,
    )


__all__ = [
    "DecodedProofBaseReceiptGraphAuditV1",
    "PROOF_BASE_RECEIPT_GRAPH_AUDIT_SCHEMA_V1",
    "ProofBaseReceiptGraphAuditError",
    "decode_proof_base_receipt_graph_audit_v1",
    "encode_proof_base_receipt_graph_audit_v1",
]
