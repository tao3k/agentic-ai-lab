# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared-vector and proof tests for AC-08 Batched Merkle evidence."""

from agentic_ai_lab_runtime import (
    batched_evidence_leaf,
    batched_merkle_proof,
    batched_merkle_proof_verify,
    batched_merkle_root,
)


def _leaf(index: int):
    return batched_evidence_leaf(
        f"leaf-{index}", index, f"nonce-{index}", index + 1, index + 1,
        f"payload-{index}", "semantic-root", "execution-root",
        f"observation-{index}", "committed",
    )


def test_python_matches_scheme_five_leaf_root_vector() -> None:
    leaves = tuple(_leaf(index) for index in range(5))
    assert batched_merkle_root(leaves) == (
        "54df6832e111d73aaede740c7affc02a4a5966913c65feae3f3d367b9cbc60b5"
    )
    assert all(
        batched_merkle_proof_verify(
            leaves[index], batched_merkle_proof(leaves, index)
        )
        for index in range(len(leaves))
    )


def test_reorder_omission_and_substitution_fail_closed() -> None:
    leaves = tuple(_leaf(index) for index in range(5))
    root = batched_merkle_root(leaves)
    assert batched_merkle_root((leaves[1], leaves[0], *leaves[2:])) != root
    assert batched_merkle_root(leaves[1:]) != root
    assert not batched_merkle_proof_verify(
        _leaf(99), batched_merkle_proof(leaves, 2)
    )
