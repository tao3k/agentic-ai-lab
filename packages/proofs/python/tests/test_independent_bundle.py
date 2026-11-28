# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from dataclasses import replace

import pytest

from agentic_ai_lab_proof.independent_bundle import (
    AxleEnvironmentIdentity,
    BundleValidationError,
    DeclarationIdentity,
    IndependentDeclarationBundle,
    ResolvedSourceIdentity,
)


DIGEST_A = f"sha256:{'a' * 64}"
DIGEST_B = f"sha256:{'b' * 64}"
DIGEST_C = f"sha256:{'c' * 64}"


def environment() -> AxleEnvironmentIdentity:
    return AxleEnvironmentIdentity(
        name="lean-4.31.0",
        lean_toolchain="leanprover/lean4:v4.31.0",
        imports=("import Mathlib",),
    )


def source(package_id: str = "agentic-ai-lab-proof") -> ResolvedSourceIdentity:
    return ResolvedSourceIdentity(
        package_id=package_id,
        revision="test-revision",
        source_tree_digest=DIGEST_A,
        lake_manifest_digest=DIGEST_B,
    )


def declaration(
    name: str,
    dependencies: tuple[str, ...] = (),
) -> DeclarationIdentity:
    return DeclarationIdentity(
        name=name,
        kind="theorem",
        owner_path="AgenticAILabProof/PooC4/Enterprise/Test.lean",
        owner_source_digest=DIGEST_C,
        local_dependencies=dependencies,
    )


def bundle() -> IndependentDeclarationBundle:
    return IndependentDeclarationBundle(
        root_module="AgenticAILabProof.PooC4.Enterprise.Test",
        root_declarations=("Enterprise.Test.safe",),
        lean_toolchain="leanprover/lean4:v4.31.0",
        axle_environment=environment(),
        resolved_sources=(source(),),
        proof_base_imports=(),
        proof_base_interface_digest=(
            "sha256:"
            "430d7aa9516de4639b168ff4eed0cfead7af8113a89f7c738872242fbc067237"
        ),
        proof_base_declarations=(),
        declarations=(
            declaration("Enterprise.Test.base"),
            declaration(
                "Enterprise.Test.safe",
                ("Enterprise.Test.base",),
            ),
        ),
        canonical_source=(
            "import Mathlib\n"
            "def Enterprise.Test.base : Nat := 1\n"
            "theorem Enterprise.Test.safe : "
            "Enterprise.Test.base = 1 := rfl\n"
        ),
    )


def test_proof_base_interface_is_disjoint_and_dependency_complete() -> None:
    from dataclasses import replace

    from agentic_ai_lab_proof.independent_bundle import (
        ProofBaseInterfaceDeclarationIdentity,
        canonical_proof_base_interface_digest,
    )

    proof_base_declarations = (
        ProofBaseInterfaceDeclarationIdentity(
            name="ProofBase.Interface",
            kind="axiom",
            level_params=(),
            type_source="Type",
            value_source=None,
        ),
    )
    value = replace(
        bundle(),
        proof_base_imports=("AgenticAILabProof.ProofBase",),
        proof_base_interface_digest=canonical_proof_base_interface_digest(
            ("AgenticAILabProof.ProofBase",),
            proof_base_declarations,
        ),
        proof_base_declarations=proof_base_declarations,
        declarations=(
            declaration(
                "Enterprise.Test.base",
                ("ProofBase.Interface",),
            ),
            declaration(
                "Enterprise.Test.safe",
                ("Enterprise.Test.base",),
            ),
        ),
    )

    manifest = value.canonical_manifest()
    assert manifest["proof_base_imports"] == ["AgenticAILabProof.ProofBase"]
    assert manifest["proof_base_interface_digest"] == (
        canonical_proof_base_interface_digest(
            ("AgenticAILabProof.ProofBase",),
            proof_base_declarations,
        )
    )
    assert manifest["proof_base_declarations"] == [
        {
            "kind": "axiom",
            "level_params": [],
            "local_dependencies": [],
            "name": "ProofBase.Interface",
            "type_source": "Type",
            "value_source": None,
        }
    ]
    assert {
        declaration_record["name"]
        for declaration_record in manifest["declarations"]
    } == {"Enterprise.Test.base", "Enterprise.Test.safe"}


def test_proof_base_interface_digest_mismatch_fails_closed() -> None:
    from dataclasses import replace

    with pytest.raises(
        BundleValidationError,
        match="proof-base-interface-digest-mismatch",
    ):
        replace(
            bundle(),
            proof_base_interface_digest=f"sha256:{'f' * 64}",
        )


def test_bundle_digest_is_deterministic_for_canonical_identity() -> None:
    left = bundle()
    right = replace(
        left,
        root_declarations=tuple(reversed(left.root_declarations)),
        resolved_sources=tuple(reversed(left.resolved_sources)),
    )

    assert left.canonical_manifest() == right.canonical_manifest()
    assert left.bundle_digest == right.bundle_digest


def test_source_change_changes_bundle_identity() -> None:
    original = bundle()
    changed = replace(
        original,
        canonical_source=f"{original.canonical_source}\n-- changed\n",
    )

    assert original.canonical_source_digest != changed.canonical_source_digest
    assert original.bundle_digest != changed.bundle_digest


def test_missing_local_dependency_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="missing-local-dependency",
    ):
        replace(
            original,
            declarations=(
                declaration(
                    "Enterprise.Test.safe",
                    ("Enterprise.Test.missing",),
                ),
            ),
        )


def test_non_topological_order_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="non-topological-order",
    ):
        replace(
            original,
            declarations=tuple(reversed(original.declarations)),
        )


def test_root_outside_closure_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="root-outside-closure",
    ):
        replace(
            original,
            root_declarations=("Enterprise.Test.unknown",),
        )


def test_duplicate_declaration_identity_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="duplicate-declaration",
    ):
        replace(
            original,
            declarations=(
                declaration("Enterprise.Test.safe"),
                declaration("Enterprise.Test.safe"),
            ),
        )


def test_ambiguous_package_source_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="ambiguous-resolved-source",
    ):
        replace(
            original,
            resolved_sources=(source(), source()),
        )


def test_toolchain_mismatch_fails_closed() -> None:
    original = bundle()

    with pytest.raises(
        BundleValidationError,
        match="toolchain-mismatch",
    ):
        replace(
            original,
            lean_toolchain="leanprover/lean4:v4.30.0",
        )


def test_project_environment_requires_revision() -> None:
    with pytest.raises(
        BundleValidationError,
        match="incomplete-environment-source",
    ):
        AxleEnvironmentIdentity(
            name="agentic-ai-lab-test",
            lean_toolchain="leanprover/lean4:v4.31.0",
            imports=("import AgenticAILabProof",),
            repo_url="https://example.invalid/agentic-ai-lab.git",
        )


def test_invalid_digest_fails_closed() -> None:
    with pytest.raises(
        BundleValidationError,
        match="invalid-digest",
    ):
        ResolvedSourceIdentity(
            package_id="agentic-ai-lab-proof",
            revision="test-revision",
            source_tree_digest="latest",
            lake_manifest_digest=DIGEST_B,
        )
