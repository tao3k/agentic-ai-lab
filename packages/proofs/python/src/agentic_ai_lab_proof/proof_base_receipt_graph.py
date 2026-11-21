# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import heapq
import re


PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1 = "agentic-ai-lab.proof-base-receipt-graph.v1"
VERIFIED_COMPOSITION_RECEIPT_SCHEMA_V1 = (
    "agentic-ai-lab.verified-composition-receipt.v1"
)

_SHA256_PATTERN = re.compile(r"sha256:[0-9a-f]{64}")


class ProofBaseReceiptGraphError(ValueError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def sha256_digest(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def _require_nonempty(label: str, value: str) -> None:
    if not value:
        raise ProofBaseReceiptGraphError(
            f"empty-{label.replace('_', '-')}",
            f"{label} must be non-empty",
        )


def _require_digest(label: str, value: str) -> None:
    if _SHA256_PATTERN.fullmatch(value) is None:
        raise ProofBaseReceiptGraphError(
            "invalid-digest",
            f"{label} must be a canonical sha256 digest",
        )


def _require_canonical_payload(
    label: str,
    payload: bytes,
    digest: str,
) -> None:
    if type(payload) is not bytes:
        raise ProofBaseReceiptGraphError(
            "non-canonical-bytes",
            f"{label} must be bytes",
        )
    _require_digest(f"{label}_digest", digest)
    computed = sha256_digest(payload)
    if computed != digest:
        raise ProofBaseReceiptGraphError(
            "canonical-payload-digest-mismatch",
            f"{label} computed {computed}, declared {digest}",
        )


def _frame(label: str, payload: bytes) -> bytes:
    label_bytes = label.encode("utf-8")
    return (
        len(label_bytes).to_bytes(4, "big")
        + label_bytes
        + len(payload).to_bytes(8, "big")
        + payload
    )


@dataclass(frozen=True)
class CanonicalInterfaceV1:
    canonical_bytes: bytes
    digest: str

    def __post_init__(self) -> None:
        _require_canonical_payload(
            "canonical_interface",
            self.canonical_bytes,
            self.digest,
        )


@dataclass(frozen=True)
class CanonicalSourceIdentityV1:
    canonical_bytes: bytes
    digest: str

    def __post_init__(self) -> None:
        _require_canonical_payload(
            "canonical_source_identity",
            self.canonical_bytes,
            self.digest,
        )


@dataclass(frozen=True)
class NamedInterfaceAssumptionV1:
    assumption_id: str
    interface: CanonicalInterfaceV1

    def __post_init__(self) -> None:
        _require_nonempty("assumption_id", self.assumption_id)


@dataclass(frozen=True)
class AcceptedReceiptEvidenceV1:
    engine_identity: str
    canonical_receipt_bytes: bytes
    receipt_digest: str
    bound_source_identity_digest: str
    bound_independent_bundle_digest: str
    bound_provided_interface_digest: str
    decision: str

    def __post_init__(self) -> None:
        _require_nonempty("engine_identity", self.engine_identity)
        _require_canonical_payload(
            "acceptance_receipt",
            self.canonical_receipt_bytes,
            self.receipt_digest,
        )
        _require_digest(
            "bound_source_identity_digest",
            self.bound_source_identity_digest,
        )
        _require_digest(
            "bound_independent_bundle_digest",
            self.bound_independent_bundle_digest,
        )
        _require_digest(
            "bound_provided_interface_digest",
            self.bound_provided_interface_digest,
        )
        if self.decision != "accepted":
            raise ProofBaseReceiptGraphError(
                "receipt-not-accepted",
                "receipt decision must be exactly accepted",
            )


@dataclass(frozen=True)
class AcceptedProofBaseReceiptNodeV1:
    node_id: str
    source_identity: CanonicalSourceIdentityV1
    independent_bundle_digest: str
    root_declarations: tuple[str, ...]
    provided_interface: CanonicalInterfaceV1
    assumed_interfaces: tuple[NamedInterfaceAssumptionV1, ...]
    acceptance: AcceptedReceiptEvidenceV1

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "root_declarations",
            tuple(sorted(self.root_declarations)),
        )
        object.__setattr__(
            self,
            "assumed_interfaces",
            tuple(
                sorted(
                    self.assumed_interfaces,
                    key=lambda item: item.assumption_id,
                )
            ),
        )
        _require_nonempty("node_id", self.node_id)
        _require_digest(
            "independent_bundle_digest",
            self.independent_bundle_digest,
        )
        if not self.root_declarations:
            raise ProofBaseReceiptGraphError(
                "empty-root-declarations",
                "an accepted proof-base receipt must own at least one root declaration",
            )
        if any(not declaration for declaration in self.root_declarations):
            raise ProofBaseReceiptGraphError(
                "empty-root-declaration",
                "root declarations must be non-empty",
            )
        if len(set(self.root_declarations)) != len(self.root_declarations):
            raise ProofBaseReceiptGraphError(
                "duplicate-root-declaration",
                f"node {self.node_id} repeats a root declaration",
            )
        assumption_ids = tuple(
            assumption.assumption_id for assumption in self.assumed_interfaces
        )
        if len(set(assumption_ids)) != len(assumption_ids):
            raise ProofBaseReceiptGraphError(
                "duplicate-assumption-id",
                f"node {self.node_id} repeats an assumption id",
            )
        expected_bindings = (
            self.source_identity.digest,
            self.independent_bundle_digest,
            self.provided_interface.digest,
        )
        observed_bindings = (
            self.acceptance.bound_source_identity_digest,
            self.acceptance.bound_independent_bundle_digest,
            self.acceptance.bound_provided_interface_digest,
        )
        if observed_bindings != expected_bindings:
            raise ProofBaseReceiptGraphError(
                "acceptance-binding-mismatch",
                (
                    f"accepted receipt for {self.node_id} must bind its source, "
                    "independent bundle, and provided interface"
                ),
            )


@dataclass(frozen=True)
class ReceiptInterfaceEdgeV1:
    supplier_node_id: str
    consumer_node_id: str
    consumer_assumption_id: str

    def __post_init__(self) -> None:
        _require_nonempty("supplier_node_id", self.supplier_node_id)
        _require_nonempty("consumer_node_id", self.consumer_node_id)
        _require_nonempty(
            "consumer_assumption_id",
            self.consumer_assumption_id,
        )
        if self.supplier_node_id == self.consumer_node_id:
            raise ProofBaseReceiptGraphError(
                "self-edge",
                f"node {self.supplier_node_id} cannot supply itself",
            )


@dataclass(frozen=True)
class VerifiedCompositionReceiptV1:
    schema_id: str
    graph_digest: str
    terminal_node_id: str
    topological_order: tuple[str, ...]
    node_count: int
    edge_count: int
    root_declaration_count: int


@dataclass(frozen=True)
class ProofBaseReceiptGraphV1:
    schema_id: str
    nodes: tuple[AcceptedProofBaseReceiptNodeV1, ...]
    edges: tuple[ReceiptInterfaceEdgeV1, ...]
    terminal_node_id: str

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "nodes",
            tuple(sorted(self.nodes, key=lambda item: item.node_id)),
        )
        object.__setattr__(
            self,
            "edges",
            tuple(
                sorted(
                    self.edges,
                    key=lambda item: (
                        item.supplier_node_id,
                        item.consumer_node_id,
                        item.consumer_assumption_id,
                    ),
                )
            ),
        )

    def verify(self) -> VerifiedCompositionReceiptV1:
        if self.schema_id != PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1:
            raise ProofBaseReceiptGraphError(
                "invalid-schema",
                f"expected {PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1}",
            )
        if not self.nodes:
            raise ProofBaseReceiptGraphError(
                "empty-receipt-graph",
                "the receipt graph must contain at least one accepted node",
            )

        nodes_by_id = {node.node_id: node for node in self.nodes}
        if len(nodes_by_id) != len(self.nodes):
            raise ProofBaseReceiptGraphError(
                "duplicate-node-id",
                "receipt node identities must be unique",
            )
        if self.terminal_node_id not in nodes_by_id:
            raise ProofBaseReceiptGraphError(
                "unresolved-terminal-node",
                f"terminal node {self.terminal_node_id} does not exist",
            )

        declaration_owners: dict[str, str] = {}
        for node in self.nodes:
            for declaration in node.root_declarations:
                previous_owner = declaration_owners.get(declaration)
                if previous_owner is not None:
                    raise ProofBaseReceiptGraphError(
                        "root-declaration-owner-overlap",
                        (
                            f"{declaration} is owned by both "
                            f"{previous_owner} and {node.node_id}"
                        ),
                    )
                declaration_owners[declaration] = node.node_id

        assumptions: dict[tuple[str, str], NamedInterfaceAssumptionV1] = {}
        for node in self.nodes:
            for assumption in node.assumed_interfaces:
                assumptions[(node.node_id, assumption.assumption_id)] = assumption

        supplied_assumptions: set[tuple[str, str]] = set()
        adjacency = {node.node_id: set() for node in self.nodes}
        indegree = {node.node_id: 0 for node in self.nodes}

        for edge in self.edges:
            supplier = nodes_by_id.get(edge.supplier_node_id)
            consumer = nodes_by_id.get(edge.consumer_node_id)
            if supplier is None or consumer is None:
                raise ProofBaseReceiptGraphError(
                    "unresolved-edge-node",
                    (
                        f"edge {edge.supplier_node_id} -> "
                        f"{edge.consumer_node_id} does not resolve"
                    ),
                )

            assumption_key = (
                edge.consumer_node_id,
                edge.consumer_assumption_id,
            )
            assumption = assumptions.get(assumption_key)
            if assumption is None:
                raise ProofBaseReceiptGraphError(
                    "unresolved-interface-assumption",
                    (
                        f"{edge.consumer_node_id} has no assumption "
                        f"{edge.consumer_assumption_id}"
                    ),
                )
            if assumption_key in supplied_assumptions:
                raise ProofBaseReceiptGraphError(
                    "multiply-supplied-interface-assumption",
                    (
                        f"{edge.consumer_node_id}/"
                        f"{edge.consumer_assumption_id} has multiple suppliers"
                    ),
                )
            if supplier.provided_interface != assumption.interface:
                raise ProofBaseReceiptGraphError(
                    "canonical-interface-mismatch",
                    (
                        f"{edge.supplier_node_id} does not provide the exact "
                        f"canonical bytes assumed by {edge.consumer_node_id}/"
                        f"{edge.consumer_assumption_id}"
                    ),
                )

            supplied_assumptions.add(assumption_key)
            if edge.consumer_node_id not in adjacency[edge.supplier_node_id]:
                adjacency[edge.supplier_node_id].add(edge.consumer_node_id)
                indegree[edge.consumer_node_id] += 1

        unresolved_assumptions = set(assumptions) - supplied_assumptions
        if unresolved_assumptions:
            unresolved = sorted(unresolved_assumptions)[0]
            raise ProofBaseReceiptGraphError(
                "unresolved-interface-assumption",
                f"{unresolved[0]}/{unresolved[1]} has no supplier edge",
            )

        if adjacency[self.terminal_node_id]:
            raise ProofBaseReceiptGraphError(
                "terminal-node-has-consumer",
                f"terminal node {self.terminal_node_id} must be a sink",
            )

        ready = [node_id for node_id, degree in indegree.items() if degree == 0]
        heapq.heapify(ready)
        topological_order: list[str] = []
        while ready:
            node_id = heapq.heappop(ready)
            topological_order.append(node_id)
            for consumer_id in sorted(adjacency[node_id]):
                indegree[consumer_id] -= 1
                if indegree[consumer_id] == 0:
                    heapq.heappush(ready, consumer_id)

        if len(topological_order) != len(self.nodes):
            raise ProofBaseReceiptGraphError(
                "cyclic-receipt-graph",
                "receipt dependencies must form a DAG",
            )

        reverse_adjacency = {node.node_id: set() for node in self.nodes}
        for supplier_id, consumer_ids in adjacency.items():
            for consumer_id in consumer_ids:
                reverse_adjacency[consumer_id].add(supplier_id)
        reaches_terminal = {self.terminal_node_id}
        frontier = [self.terminal_node_id]
        while frontier:
            consumer_id = frontier.pop()
            for supplier_id in reverse_adjacency[consumer_id]:
                if supplier_id not in reaches_terminal:
                    reaches_terminal.add(supplier_id)
                    frontier.append(supplier_id)
        disconnected = set(nodes_by_id) - reaches_terminal
        if disconnected:
            raise ProofBaseReceiptGraphError(
                "node-outside-terminal-closure",
                (
                    f"node {sorted(disconnected)[0]} does not contribute to "
                    f"terminal {self.terminal_node_id}"
                ),
            )

        return VerifiedCompositionReceiptV1(
            schema_id=VERIFIED_COMPOSITION_RECEIPT_SCHEMA_V1,
            graph_digest=self._graph_digest(),
            terminal_node_id=self.terminal_node_id,
            topological_order=tuple(topological_order),
            node_count=len(self.nodes),
            edge_count=len(self.edges),
            root_declaration_count=len(declaration_owners),
        )

    def _graph_digest(self) -> str:
        payload = bytearray()
        payload.extend(_frame("schema_id", self.schema_id.encode("utf-8")))
        payload.extend(
            _frame("terminal_node_id", self.terminal_node_id.encode("utf-8"))
        )
        for node in sorted(self.nodes, key=lambda item: item.node_id):
            node_payload = bytearray()
            node_payload.extend(_frame("node_id", node.node_id.encode("utf-8")))
            node_payload.extend(
                _frame(
                    "source_identity",
                    node.source_identity.canonical_bytes,
                )
            )
            node_payload.extend(
                _frame(
                    "source_identity_digest",
                    node.source_identity.digest.encode("ascii"),
                )
            )
            node_payload.extend(
                _frame(
                    "independent_bundle_digest",
                    node.independent_bundle_digest.encode("ascii"),
                )
            )
            node_payload.extend(
                _frame(
                    "provided_interface",
                    node.provided_interface.canonical_bytes,
                )
            )
            node_payload.extend(
                _frame(
                    "provided_interface_digest",
                    node.provided_interface.digest.encode("ascii"),
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_engine",
                    node.acceptance.engine_identity.encode("utf-8"),
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_receipt",
                    node.acceptance.canonical_receipt_bytes,
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_receipt_digest",
                    node.acceptance.receipt_digest.encode("ascii"),
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_bound_source_identity_digest",
                    node.acceptance.bound_source_identity_digest.encode("ascii"),
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_bound_independent_bundle_digest",
                    node.acceptance.bound_independent_bundle_digest.encode(
                        "ascii"
                    ),
                )
            )
            node_payload.extend(
                _frame(
                    "acceptance_bound_provided_interface_digest",
                    node.acceptance.bound_provided_interface_digest.encode(
                        "ascii"
                    ),
                )
            )
            for declaration in sorted(node.root_declarations):
                node_payload.extend(
                    _frame("root_declaration", declaration.encode("utf-8"))
                )
            for assumption in sorted(
                node.assumed_interfaces,
                key=lambda item: item.assumption_id,
            ):
                assumption_payload = bytearray()
                assumption_payload.extend(
                    _frame(
                        "assumption_id",
                        assumption.assumption_id.encode("utf-8"),
                    )
                )
                assumption_payload.extend(
                    _frame(
                        "interface",
                        assumption.interface.canonical_bytes,
                    )
                )
                assumption_payload.extend(
                    _frame(
                        "interface_digest",
                        assumption.interface.digest.encode("ascii"),
                    )
                )
                node_payload.extend(
                    _frame("assumption", bytes(assumption_payload))
                )
            payload.extend(_frame("node", bytes(node_payload)))

        for edge in sorted(
            self.edges,
            key=lambda item: (
                item.supplier_node_id,
                item.consumer_node_id,
                item.consumer_assumption_id,
            ),
        ):
            edge_payload = bytearray()
            edge_payload.extend(
                _frame(
                    "supplier_node_id",
                    edge.supplier_node_id.encode("utf-8"),
                )
            )
            edge_payload.extend(
                _frame(
                    "consumer_node_id",
                    edge.consumer_node_id.encode("utf-8"),
                )
            )
            edge_payload.extend(
                _frame(
                    "consumer_assumption_id",
                    edge.consumer_assumption_id.encode("utf-8"),
                )
            )
            payload.extend(_frame("edge", bytes(edge_payload)))

        return sha256_digest(bytes(payload))


__all__ = [
    "AcceptedProofBaseReceiptNodeV1",
    "AcceptedReceiptEvidenceV1",
    "CanonicalInterfaceV1",
    "CanonicalSourceIdentityV1",
    "NamedInterfaceAssumptionV1",
    "PROOF_BASE_RECEIPT_GRAPH_SCHEMA_V1",
    "ProofBaseReceiptGraphError",
    "ProofBaseReceiptGraphV1",
    "ReceiptInterfaceEdgeV1",
    "VERIFIED_COMPOSITION_RECEIPT_SCHEMA_V1",
    "VerifiedCompositionReceiptV1",
    "sha256_digest",
]
