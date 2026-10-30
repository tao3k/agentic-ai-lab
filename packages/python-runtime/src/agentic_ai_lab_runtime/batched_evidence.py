# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Language-neutral AC-08 Batched Merkle evidence projection."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

_LEAF_DOMAIN = "agentic-ai-lab.batched-evidence-leaf.draft.1|"
_NODE_DOMAIN = "agentic-ai-lab.batched-merkle-node.draft.1|"


@dataclass(frozen=True, slots=True)
class BatchedEvidenceLeaf:
    leaf_id: str
    index: int
    nonce: str
    first_sequence: int
    last_sequence: int
    payload_digest: str
    semantic_root: str
    previous_execution_root: str
    observation_digest: str
    outcome: str
    digest: str


@dataclass(frozen=True, slots=True)
class BatchedMerkleProofStep:
    direction: str
    sibling_digest: str


@dataclass(frozen=True, slots=True)
class BatchedMerkleProof:
    leaf_index: int
    leaf_count: int
    steps: tuple[BatchedMerkleProofStep, ...]
    root_digest: str


def batched_evidence_leaf(
    leaf_id: str, index: int, nonce: str, first_sequence: int,
    last_sequence: int, payload_digest: str, semantic_root: str,
    previous_execution_root: str, observation_digest: str, outcome: str,
) -> BatchedEvidenceLeaf:
    fields = (
        leaf_id, index, nonce, first_sequence, last_sequence, payload_digest,
        semantic_root, previous_execution_root, observation_digest, outcome,
    )
    digest = _digest(_LEAF_DOMAIN, fields)
    return BatchedEvidenceLeaf(*fields, digest)


def batched_merkle_root(leaves: tuple[BatchedEvidenceLeaf, ...]) -> str:
    return _root(tuple(leaf.digest for leaf in leaves))


def batched_merkle_root_digests(digests: tuple[bytes, ...]) -> bytes:
    if any(len(digest) != 32 for digest in digests):
        raise ValueError("Batched Merkle digest must be exactly 32 bytes")
    return bytes.fromhex(_root(tuple(digest.hex() for digest in digests)))


def batched_merkle_proof(
    leaves: tuple[BatchedEvidenceLeaf, ...], index: int,
) -> BatchedMerkleProof:
    if not 0 <= index < len(leaves):
        raise IndexError("Batched Merkle proof index out of bounds")
    level = tuple(leaf.digest for leaf in leaves)
    cursor = index
    steps: list[BatchedMerkleProofStep] = []
    while len(level) > 1:
        sibling_index = min(cursor + 1, len(level) - 1) if cursor % 2 == 0 else cursor - 1
        direction = "right" if cursor % 2 == 0 else "left"
        steps.append(BatchedMerkleProofStep(direction, level[sibling_index]))
        level = _next_level(level)
        cursor //= 2
    return BatchedMerkleProof(index, len(leaves), tuple(steps), level[0])


def batched_merkle_proof_verify(
    leaf: BatchedEvidenceLeaf, proof: BatchedMerkleProof,
) -> bool:
    current = leaf.digest
    for step in proof.steps:
        if step.direction == "left":
            current = _node(step.sibling_digest, current)
        elif step.direction == "right":
            current = _node(current, step.sibling_digest)
        else:
            return False
    return current == proof.root_digest


def _root(level: tuple[str, ...]) -> str:
    if not level:
        raise ValueError("Batched Merkle tree requires at least one leaf")
    while len(level) > 1:
        level = _next_level(level)
    return level[0]


def _next_level(level: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(
        _node(level[index], level[min(index + 1, len(level) - 1)])
        for index in range(0, len(level), 2)
    )


def _node(left: str, right: str) -> str:
    return _digest(_NODE_DOMAIN, (left, right))


def _digest(domain: str, fields: tuple[object, ...]) -> str:
    packet = domain + "".join(_frame(field) for field in fields)
    return hashlib.sha256(packet.encode("utf-8")).hexdigest()


def _frame(value: object) -> str:
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise TypeError("non-canonical Batched Merkle field")
    if isinstance(value, int) and value < 0:
        raise ValueError("Batched Merkle integer fields must be non-negative")
    text = str(value)
    return f"{len(text.encode('utf-8'))}:{text}"


__all__ = (
    "BatchedEvidenceLeaf",
    "BatchedMerkleProof",
    "BatchedMerkleProofStep",
    "batched_evidence_leaf",
    "batched_merkle_proof",
    "batched_merkle_proof_verify",
    "batched_merkle_root",
    "batched_merkle_root_digests",
)
