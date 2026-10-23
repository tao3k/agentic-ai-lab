# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from struct import pack_into

import pytest

from agentic_ai_lab_proof.generated.proof_case_vector import FIELD_OFFSETS, VECTOR_SIZE
from agentic_ai_lab_proof.proof_case_emit import generated_artifacts
from agentic_ai_lab_proof.proof_case_manifest import load_proof_case_schema
from agentic_ai_lab_proof.proof_case_runtime import (
    NativeProofCaseRuntime,
    ProofCaseError,
    ProofStatus,
    VectorDivergence,
    assert_native_differential,
    first_vector_divergence,
    proof_case_vector_digest,
    validate_proof_case_vector,
)


REPO_ROOT = Path(__file__).parents[4]
PROOF_ROOT = Path(__file__).parents[2]


@pytest.fixture(scope="session")
def native_runtime(tmp_path_factory: pytest.TempPathFactory) -> NativeProofCaseRuntime:
    output = tmp_path_factory.mktemp("runtime-c") / (
        "libagentic_ai_lab_proof.dylib" if sys.platform == "darwin" else "libagentic_ai_lab_proof.so"
    )
    link_mode = "-dynamiclib" if sys.platform == "darwin" else "-shared"
    subprocess.run(
        [
            "cc",
            "-std=c11",
            "-O2",
            "-fPIC",
            link_mode,
            "-I",
            str(REPO_ROOT / "bindings/runtime-c/include"),
            str(REPO_ROOT / "bindings/runtime-c/src/proof_case_v1.c"),
            "-o",
            str(output),
        ],
        check=True,
    )
    return NativeProofCaseRuntime(output)


def positive_vector() -> bytes:
    schema = load_proof_case_schema(PROOF_ROOT / "proof-case-vector-v1.toml")
    return bytes.fromhex(
        generated_artifacts(schema)[Path("vectors/proof_case_vector_v1_positive.hex")]
    )


def scheme_vector() -> tuple[bytes, bytes]:
    env = os.environ.copy()
    env.setdefault("GERBIL_PATH", str(REPO_ROOT / ".gerbil"))
    env.setdefault("GERBIL_LOADPATH", ":".join(
        (str(Path(env["GERBIL_PATH"]) / "lib"), str(REPO_ROOT / "core"), str(REPO_ROOT))))
    completed = subprocess.run(
        [
            "just",
            "emit-proof-case-vector",
        ],
        cwd=REPO_ROOT,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )
    receipt = dict(line.split("=", 1) for line in completed.stdout.splitlines())
    return bytes.fromhex(receipt["vector"]), bytes.fromhex(receipt["digest"])


def test_native_cffi_round_trip_matches_python_contract(
    native_runtime: NativeProofCaseRuntime,
) -> None:
    vector = positive_vector()
    layout = assert_native_differential(native_runtime, vector)

    assert layout.required_size == VECTOR_SIZE
    assert validate_proof_case_vector(vector) is ProofStatus.OK


def test_layout_negotiates_once_and_hot_path_reuses_caller_buffer(
    native_runtime: NativeProofCaseRuntime,
) -> None:
    vector = positive_vector()
    first = bytearray(VECTOR_SIZE)
    second = bytearray([0xA5]) * VECTOR_SIZE

    first_layout = native_runtime.validate_and_write(vector, first)
    second_layout = native_runtime.validate_and_write(vector, second)

    assert first_layout == second_layout
    assert native_runtime.layout_measurements == 1
    assert first == vector
    assert second == vector


def test_caller_buffer_capacity_failure_is_atomic(
    native_runtime: NativeProofCaseRuntime,
) -> None:
    output = bytearray([0xA5]) * (VECTOR_SIZE - 1)

    with pytest.raises(ProofCaseError) as caught:
        native_runtime.validate_and_write(positive_vector(), output)
    assert caught.value.status is ProofStatus.BUFFER_TOO_SMALL
    assert output == bytearray([0xA5]) * (VECTOR_SIZE - 1)


def test_scheme_c_python_and_lean_fixture_share_one_vector(
    native_runtime: NativeProofCaseRuntime,
) -> None:
    generated = positive_vector()
    scheme, scheme_digest = scheme_vector()

    assert first_vector_divergence(
        generated,
        scheme,
        expected_owner="manifest/lean",
        actual_owner="scheme",
    ) is None
    assert proof_case_vector_digest(scheme) == scheme_digest
    assert_native_differential(native_runtime, scheme)


def test_scheme_process_reproduces_vector_and_digest() -> None:
    first_vector, first_digest = scheme_vector()
    second_vector, second_digest = scheme_vector()

    assert first_vector == second_vector
    assert first_digest == second_digest


def test_differential_reports_first_owner_and_field() -> None:
    generated = positive_vector()
    mutated = bytearray(generated)
    mutated[FIELD_OFFSETS["effect_digest"]] ^= 1

    assert first_vector_divergence(
        generated,
        bytes(mutated),
        expected_owner="manifest/lean",
        actual_owner="scheme",
    ) == VectorDivergence(
        "manifest/lean", "scheme", "effect_digest", FIELD_OFFSETS["effect_digest"]
    )


@pytest.mark.parametrize(
    ("field", "value", "expected"),
    [
        ("abi_version", 2, ProofStatus.SCHEMA_MISMATCH),
        ("required_obligation_mask", 0x100, ProofStatus.UNSUPPORTED_OBLIGATION),
        ("mediation_outcome", 99, ProofStatus.MALFORMED_EVIDENCE),
    ],
)
def test_python_and_c_reject_mutations_with_same_status(
    native_runtime: NativeProofCaseRuntime,
    field: str,
    value: int,
    expected: ProofStatus,
) -> None:
    vector = bytearray(positive_vector())
    format_ = "<Q" if field == "required_obligation_mask" else "<I"
    pack_into(format_, vector, FIELD_OFFSETS[field], value)

    assert validate_proof_case_vector(bytes(vector)) is expected
    with pytest.raises(ProofCaseError) as caught:
        assert_native_differential(native_runtime, bytes(vector))
    assert caught.value.status is expected


def test_python_and_c_reject_truncated_vector(
    native_runtime: NativeProofCaseRuntime,
) -> None:
    vector = positive_vector()[:-1]

    assert validate_proof_case_vector(vector) is ProofStatus.MALFORMED_EVIDENCE
    with pytest.raises(ProofCaseError) as caught:
        assert_native_differential(native_runtime, vector)
    assert caught.value.status is ProofStatus.MALFORMED_EVIDENCE


@pytest.mark.parametrize(
    ("field", "value", "format_", "expected"),
    [
        ("case_kind", 0, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("case_kind", 2, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("mediation_outcome", 0, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("mediation_outcome", 4, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("durability_profile", 0, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("durability_profile", 4, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("obligation_count", 9, "<I", ProofStatus.MALFORMED_EVIDENCE),
        ("required_obligation_mask", 0x100, "<Q", ProofStatus.UNSUPPORTED_OBLIGATION),
        ("present_obligation_mask", 0x100, "<Q", ProofStatus.UNSUPPORTED_OBLIGATION),
    ],
)
def test_table_driven_structural_mutations_fail_closed(
    native_runtime: NativeProofCaseRuntime,
    field: str,
    value: int,
    format_: str,
    expected: ProofStatus,
) -> None:
    vector = bytearray(positive_vector())
    pack_into(format_, vector, FIELD_OFFSETS[field], value)

    assert validate_proof_case_vector(bytes(vector)) is expected
    with pytest.raises(ProofCaseError) as caught:
        assert_native_differential(native_runtime, bytes(vector))
    assert caught.value.status is expected


@pytest.mark.parametrize(
    "field",
    [
        "token_digest",
        "policy_revision",
        "effect_digest",
        "semantic_root",
        "execution_root",
        "batch_root",
        "subject_binding",
        "resource_binding",
        "action_binding",
        "previous_evidence_root",
    ],
)
def test_digest_and_root_substitution_changes_receipt_identity(field: str) -> None:
    canonical = positive_vector()
    substituted = bytearray(canonical)
    substituted[FIELD_OFFSETS[field]] ^= 1
    substituted = bytes(substituted)

    assert validate_proof_case_vector(substituted) is ProofStatus.OK
    assert proof_case_vector_digest(substituted) != proof_case_vector_digest(canonical)
    assert first_vector_divergence(
        canonical,
        substituted,
        expected_owner="verified-receipt",
        actual_owner="substituted-vector",
    ) == VectorDivergence(
        "verified-receipt", "substituted-vector", field, FIELD_OFFSETS[field]
    )


@pytest.mark.parametrize("reserved_index", [0, 11])
def test_reserved_boundary_bytes_fail_closed(
    native_runtime: NativeProofCaseRuntime, reserved_index: int
) -> None:
    vector = bytearray(positive_vector())
    vector[FIELD_OFFSETS["reserved"] + reserved_index] = 1

    assert validate_proof_case_vector(bytes(vector)) is ProofStatus.MALFORMED_EVIDENCE
    with pytest.raises(ProofCaseError) as caught:
        assert_native_differential(native_runtime, bytes(vector))
    assert caught.value.status is ProofStatus.MALFORMED_EVIDENCE
