# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

import pytest

from agentic_ai_lab_proof.axle_exact_closure import ExactAxleClosure, SourceDeclaration
from agentic_ai_lab_proof.independent_bundle_projection import (
    IndependentBundleProjectionError,
    build_independent_declaration_bundle,
)
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanDeclaration,
    LeanDeclarationClosure,
    LeanOwnerSource,
    LeanProofBaseInterfaceDeclaration,
)


def fixture_values(
    tmp_path: Path,
) -> tuple[
    LeanDeclarationClosure,
    ExactAxleClosure,
    tuple[LeanOwnerSource, ...],
]:
    source_path = tmp_path / "Example" / "Root.lean"
    source_path.parent.mkdir()
    source_path.write_text("theorem Example.safe : True := by trivial\n")
    source_digest = "sha256:" + "a" * 64
    closure = LeanDeclarationClosure(
        lean_version="4.31.0",
        root_module="Example.Root",
        root_declarations=("Example.safe",),
        base_imports=("Init",),
        proof_base_imports=(),
        proof_base_interface=(),
        owner_modules=("Example.Root",),
        declarations=(
            LeanDeclaration(
                name="Example.safe",
                kind="theorem",
                owner_module="Example.Root",
                local_dependencies=(),
            ),
        ),
    )
    exact = ExactAxleClosure(
        lean_closure_digest=closure.closure_digest,
        environment="lean-4.31.0",
        root_declarations=("Example.safe",),
        source_declarations=("Example.safe",),
        declarations=(
            SourceDeclaration(
                name="Example.safe",
                kind="theorem",
                declaration="theorem safe : True := by trivial",
                local_dependencies=(),
            ),
        ),
        canonical_source="theorem Example.safe : True := by trivial\n",
        theorem2sorry={"request": {"id": "statement"}},
        verification={"okay": True, "request": {"id": "verify"}},
    )
    sources = (
        LeanOwnerSource(
            module="Example.Root",
            path=source_path,
            owner_path="Example/Root.lean",
            source_digest=source_digest,
        ),
    )
    return closure, exact, sources


def test_projects_lake_and_owner_evidence_into_independent_bundle(
    tmp_path: Path,
) -> None:
    closure, exact, sources = fixture_values(tmp_path)
    (tmp_path / "lake-manifest.json").write_text('{"name":"«agentic-ai-lab-proof»","packages":[]}\n')

    bundle = build_independent_declaration_bundle(
        closure=closure,
        exact=exact,
        sources=sources,
        lean_root=tmp_path,
    )

    assert bundle.root_declarations == ("Example.safe",)
    assert bundle.axle_environment.name == "lean-4.31.0"
    assert bundle.resolved_sources[0].package_id == "agentic-ai-lab-proof"
    assert bundle.resolved_sources[0].revision.startswith("workspace:")
    assert bundle.declarations[0].owner_path == "Example/Root.lean"
    assert bundle.declarations[0].owner_source_digest == sources[0].source_digest


def test_runtime_receipts_do_not_change_independent_bundle_identity(
    tmp_path: Path,
) -> None:
    closure, exact, sources = fixture_values(tmp_path)
    (tmp_path / "lake-manifest.json").write_text('{"name":"agentic-ai-lab-proof","packages":[]}\n')
    changed_receipt = ExactAxleClosure(
        **{
            **exact.__dict__,
            "theorem2sorry": {"request": {"id": "different"}},
            "verification": {"okay": True, "timings": {"total": 999}},
        }
    )

    first = build_independent_declaration_bundle(
        closure=closure,
        exact=exact,
        sources=sources,
        lean_root=tmp_path,
    )
    second = build_independent_declaration_bundle(
        closure=closure,
        exact=changed_receipt,
        sources=sources,
        lean_root=tmp_path,
    )

    assert first.bundle_digest == second.bundle_digest


def test_unused_proof_base_interface_declarations_preserve_typed_identity(
    tmp_path: Path,
) -> None:
    closure, exact, sources = fixture_values(tmp_path)
    closure = LeanDeclarationClosure(
        **{
            **closure.__dict__,
            "proof_base_imports": ("Cedar.Spec",),
            "proof_base_interface": (
                LeanProofBaseInterfaceDeclaration(
                    name="Cedar.Data.Map._sizeOf_inst",
                    declaration_role="instance",
                    level_params=("u", "v"),
                    type_source="SizeOf (Cedar.Data.Map α β)",
                    value_source="Cedar.Data.Map.instSizeOf",
                ),
                LeanProofBaseInterfaceDeclaration(
                    name="Cedar.Data.Map.empty",
                    declaration_role="definition",
                    level_params=("u", "v"),
                    type_source="Cedar.Data.Map α β",
                    value_source="{}",
                ),
            ),
        }
    )
    (tmp_path / "lake-manifest.json").write_text('{"name":"agentic-ai-lab-proof","packages":[]}\n')

    bundle = build_independent_declaration_bundle(
        closure=closure,
        exact=exact,
        sources=sources,
        lean_root=tmp_path,
    )

    assert tuple(
        (declaration.name, declaration.kind, declaration.local_dependencies)
        for declaration in bundle.proof_base_declarations
    ) == (
        ("Cedar.Data.Map._sizeOf_inst", "axiom", ()),
        ("Cedar.Data.Map.empty", "def", ()),
    )


def test_missing_lake_manifest_fails_closed(tmp_path: Path) -> None:
    closure, exact, sources = fixture_values(tmp_path)

    with pytest.raises(
        IndependentBundleProjectionError,
        match="lake-manifest-unreadable",
    ):
        build_independent_declaration_bundle(
            closure=closure,
            exact=exact,
            sources=sources,
            lean_root=tmp_path,
        )
