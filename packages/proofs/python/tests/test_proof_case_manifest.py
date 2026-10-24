# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

import pytest

from agentic_ai_lab_proof.cli import main
from agentic_ai_lab_proof.proof_case_emit import generated_artifacts
from agentic_ai_lab_proof.proof_case_manifest import load_proof_case_schema


PROOF_ROOT = Path(__file__).parents[2]
MANIFEST = PROOF_ROOT / "proof-case-vector-v1.toml"


def test_manifest_has_stable_native_layout() -> None:
    schema = load_proof_case_schema(MANIFEST)

    assert schema.version == 1
    assert schema.endianness == "little"
    assert schema.alignment == 8
    assert schema.total_size == 424
    assert len(schema.fingerprint) == 32
    assert (
        schema.fingerprint_hex
        == "1627b834b99c2b23e4ee0019d38c672dfb86d6bfc44d55afaf18ad501160853a"
    )
    assert schema.required_obligation_mask == 0xFF
    assert schema.proof_identity.digest_algorithm == "sha256"
    assert schema.proof_identity.vector_domain != schema.proof_identity.theorem_set_domain
    assert schema.proof_identity.theorems == tuple(
        obligation.name for obligation in schema.obligations
    )
    assert schema.fields[-1].offset + schema.fields[-1].width == schema.total_size


def test_generated_artifacts_are_fresh() -> None:
    assert main(["emit-proof-case-artifacts", "--check"]) == 0


def test_generated_vectors_have_exact_and_truncated_sizes() -> None:
    schema = load_proof_case_schema(MANIFEST)
    artifacts = generated_artifacts(schema)
    positive = bytes.fromhex(
        artifacts[Path("vectors/proof_case_vector_v1_positive.hex")]
    )
    malformed = bytes.fromhex(
        artifacts[Path("vectors/proof_case_vector_v1_malformed_truncated.hex")]
    )

    assert len(positive) == schema.total_size
    assert len(malformed) == schema.total_size - 1
    assert positive[8:40] == schema.fingerprint


def test_duplicate_tags_are_rejected(tmp_path: Path) -> None:
    text = MANIFEST.read_text(encoding="utf-8").replace(
        'name = "deny"\ntag = 2', 'name = "deny"\ntag = 1'
    )
    candidate = tmp_path / "duplicate-tag.toml"
    candidate.write_text(text, encoding="utf-8")

    with pytest.raises(ValueError, match="duplicate mediation_outcomes tag"):
        load_proof_case_schema(candidate)


def test_overlapping_fields_are_rejected(tmp_path: Path) -> None:
    text = MANIFEST.read_text(encoding="utf-8").replace(
        'name = "case_kind"\noffset = 4', 'name = "case_kind"\noffset = 3'
    )
    candidate = tmp_path / "overlap.toml"
    candidate.write_text(text, encoding="utf-8")

    with pytest.raises(ValueError, match="field overlap"):
        load_proof_case_schema(candidate)


def test_duplicate_obligation_bits_are_rejected(tmp_path: Path) -> None:
    text = MANIFEST.read_text(encoding="utf-8").replace(
        'name = "effect_digest_bound"\nbit = 1',
        'name = "effect_digest_bound"\nbit = 0',
    )
    candidate = tmp_path / "duplicate-obligation-bit.toml"
    candidate.write_text(text, encoding="utf-8")

    with pytest.raises(ValueError, match="duplicate obligation bit"):
        load_proof_case_schema(candidate)


def test_theorem_set_must_match_canonical_obligations(tmp_path: Path) -> None:
    text = MANIFEST.read_text(encoding="utf-8").replace(
        '  "policy_revision_bound",\n  "effect_digest_bound",',
        '  "effect_digest_bound",\n  "policy_revision_bound",',
    )
    candidate = tmp_path / "reordered-theorem-set.toml"
    candidate.write_text(text, encoding="utf-8")

    with pytest.raises(ValueError, match="theorem set must match"):
        load_proof_case_schema(candidate)
