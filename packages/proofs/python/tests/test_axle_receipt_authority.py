# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import json

import pytest

from agentic_ai_lab_proof.axle_receipt_authority import (
    AXLE_RECEIPT_ENGINE_IDENTITY_V1,
    AxleClosureReceiptAuthorityV1,
    declare_axle_closure_receipt_v1,
    parse_axle_closure_artifact_v1,
)
from agentic_ai_lab_proof.receipt_acceptance_authority import (
    ReceiptAcceptanceAuthorityError,
)


SOURCE_DIGEST = (
    "sha256:1111111111111111111111111111111111111111111111111111111111111111"
)
EXACT_DIGEST = (
    "sha256:2222222222222222222222222222222222222222222222222222222222222222"
)
INDEPENDENT_DIGEST = (
    "sha256:3333333333333333333333333333333333333333333333333333333333333333"
)


def axle_artifact() -> dict:
    roots = ["Proof.root"]
    return {
        "closure": {
            "base_imports": [],
            "declarations": [],
            "lean_version": "4.31.0",
            "owner_modules": ["Proof"],
            "proof_base_imports": [],
            "proof_base_interface": [],
            "root_declarations": roots,
            "root_module": "Proof",
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
        },
        "exact_bundle": {
            "bundle_digest": EXACT_DIGEST,
            "canonical_source": "theorem root : True := by trivial",
            "canonical_source_digest": SOURCE_DIGEST,
            "declarations": [
                {
                    "kind": "theorem",
                    "local_dependencies": [],
                    "name": "Proof.root",
                }
            ],
            "environment": "lean-4.31.0",
            "lean_closure_digest": SOURCE_DIGEST,
            "root_declarations": roots,
            "schema_id": "agentic-ai-lab.axle-exact-declaration-closure.v1",
            "source_declarations": ["Proof.root"],
            "theorem2sorry": {
                "messages": [],
                "request": {},
                "root_declaration_kinds": {"Proof.root": "theorem"},
                "root_declarations": roots,
                "schema_id": "agentic-ai-lab.axle-root-theorem-obligation.v1",
                "status": "generated",
            },
            "verification": {
                "failed_declarations": [],
                "lean_messages": [],
                "okay": True,
                "request": {},
                "roundtrip": {},
                "schema_id": (
                    "agentic-ai-lab.axle-root-declaration-validation.v1"
                ),
                "status": "accepted",
                "theorem_proof": {},
                "timings": {},
                "tool_messages": [],
            },
        },
        "exact_bundle_digest": EXACT_DIGEST,
        "independent_declaration_bundle": {
            "axle_environment": {
                "imports": [],
                "lean_toolchain": "lean-4.31.0",
                "name": "lean-4.31.0",
            },
            "canonical_source_digest": SOURCE_DIGEST,
            "declarations": [],
            "lean_toolchain": "lean-4.31.0",
            "proof_base_declarations": [],
            "proof_base_imports": [],
            "proof_base_interface_digest": SOURCE_DIGEST,
            "resolved_sources": [
                {
                    "lake_manifest_digest": SOURCE_DIGEST,
                    "package_id": "agentic-ai-lab-proof",
                    "revision": "test",
                    "source_tree_digest": SOURCE_DIGEST,
                }
            ],
            "root_declarations": roots,
            "root_module": "Proof",
            "schema_id": "agentic-ai-lab.independent-declaration-bundle.v1",
        },
        "independent_declaration_bundle_digest": INDEPENDENT_DIGEST,
        "preflight": {
            "axle_base_timeout_seconds": 10.0,
            "axle_environment": "lean-4.31.0",
            "axle_operation_timeout_seconds": 30.0,
            "closure_digest": SOURCE_DIGEST,
            "declaration_count": 1,
            "lean_export_timeout_seconds": 60.0,
            "owner_sources": [],
            "proof_base_imports": [],
            "proof_base_interface_count": 0,
            "root_declarations": roots,
            "root_module": "Proof",
            "schema_id": "agentic-ai-lab.axle-closure-preflight.v1",
        },
    }


def json_bytes(value: object, *, indent: int | None = None) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        indent=indent,
        separators=None if indent is not None else (",", ":"),
        sort_keys=True,
    ).encode()


def test_declaration_canonicalizes_real_owner_artifact_shape() -> None:
    declared = declare_axle_closure_receipt_v1(
        json_bytes(axle_artifact(), indent=2)
    )

    assert declared.engine_identity == AXLE_RECEIPT_ENGINE_IDENTITY_V1
    parsed = parse_axle_closure_artifact_v1(
        declared.canonical_receipt_bytes,
        require_canonical_bytes=True,
    )
    assert parsed.canonical_bytes == declared.canonical_receipt_bytes
    assert parsed.request.root_declarations == ("Proof.root",)


def test_owner_reverification_issues_complete_bound_evidence() -> None:
    declared = declare_axle_closure_receipt_v1(
        json_bytes(axle_artifact())
    )
    authority = AxleClosureReceiptAuthorityV1(
        reverify=lambda request: declared.canonical_receipt_bytes
    )

    verified = authority.validate(declared)

    assert verified.root_declarations == ("Proof.root",)
    assert verified.independent_bundle_digest == INDEPENDENT_DIGEST
    assert (
        verified.acceptance.bound_source_identity_digest
        == verified.source_identity.digest
    )
    assert (
        verified.acceptance.bound_provided_interface_digest
        == verified.provided_interface.digest
    )


def test_owner_request_preserves_root_order_before_graph_canonicalization() -> None:
    artifact = axle_artifact()
    ordered_roots = ["Proof.z", "Proof.a"]
    artifact["closure"]["root_declarations"] = ordered_roots
    artifact["preflight"]["root_declarations"] = ordered_roots
    artifact["exact_bundle"]["root_declarations"] = ordered_roots
    artifact["exact_bundle"]["theorem2sorry"][
        "root_declarations"
    ] = ordered_roots
    artifact["independent_declaration_bundle"][
        "root_declarations"
    ] = ordered_roots
    declared = declare_axle_closure_receipt_v1(json_bytes(artifact))
    requests = []

    def reverify(request):
        requests.append(request)
        return declared.canonical_receipt_bytes

    verified = AxleClosureReceiptAuthorityV1(
        reverify=reverify
    ).validate(declared)

    assert requests[0].root_declarations == ("Proof.z", "Proof.a")
    assert verified.root_declarations == ("Proof.a", "Proof.z")


def test_owner_reverification_rejects_substituted_bundle() -> None:
    claimed = axle_artifact()
    claimed["exact_bundle_digest"] = (
        "sha256:4444444444444444444444444444444444444444444444444444444444444444"
    )
    claimed["exact_bundle"]["bundle_digest"] = claimed[
        "exact_bundle_digest"
    ]
    declared = declare_axle_closure_receipt_v1(json_bytes(claimed))
    fresh = declare_axle_closure_receipt_v1(
        json_bytes(axle_artifact())
    ).canonical_receipt_bytes
    authority = AxleClosureReceiptAuthorityV1(
        reverify=lambda request: fresh
    )

    with pytest.raises(ReceiptAcceptanceAuthorityError) as error:
        authority.validate(declared)

    assert error.value.code == "axle-owner-reverification-mismatch"


def test_rejected_axle_status_cannot_be_declared_as_authority_evidence() -> None:
    rejected = axle_artifact()
    rejected["exact_bundle"]["verification"]["status"] = "rejected"
    rejected["exact_bundle"]["verification"]["okay"] = False
    rejected["exact_bundle"]["verification"]["failed_declarations"] = [
        "Proof.root"
    ]

    with pytest.raises(ReceiptAcceptanceAuthorityError) as error:
        declare_axle_closure_receipt_v1(json_bytes(rejected))

    assert error.value.code == "axle-receipt-not-accepted"


def test_unknown_owner_artifact_field_is_not_an_extension_point() -> None:
    artifact = axle_artifact()
    artifact["exact_bundle"]["legacy_status"] = "accepted"

    with pytest.raises(ReceiptAcceptanceAuthorityError) as error:
        declare_axle_closure_receipt_v1(json_bytes(artifact))

    assert error.value.code == "axle-receipt-shape-mismatch"
